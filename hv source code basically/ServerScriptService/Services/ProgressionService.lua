-- ServerScriptService.Services.ProgressionService
-- Handles all progression actions with full validation.
-- Reads/writes through PlayerDataService. Fires remotes back to client.

local Players = game:GetService("Players")

local StatData          = require(game.ReplicatedStorage.Modules.Data.StatData)
local ClassData         = require(game.ReplicatedStorage.Modules.Data.ClassData)
local PerkData          = require(game.ReplicatedStorage.Modules.Data.PerkData)
local ProgressionRemotes = require(game.ReplicatedStorage.Modules.Remotes.ProgressionRemotes)

local ProgressionService = {}
ProgressionService.__index = ProgressionService

function ProgressionService.new(playerDataService)
	local self = setmetatable({}, ProgressionService)
	self.PlayerDataService = playerDataService
	self.ExtraStatBonuses  = {}  -- [userId] = { BonusDamage = n, ... } from class/perk effects
	self.DerivedStats      = {}  -- [userId] = full derived table, server-side only
	self:_setupRemotes()
	print("[ProgressionService] Ready")
	return self
end

-- ===== INTERNAL HELPERS =====

-- Sends the full client snapshot to a player and fires the update event
function ProgressionService:_notifyClient(player)
	local snapshot = self.PlayerDataService:GetClientSnapshot(player)
	if snapshot then
		-- Include derived stats so client UI can display them without character attributes
		snapshot.DerivedStats = self.DerivedStats[player.UserId]
		ProgressionRemotes.PlayerDataUpdated:FireClient(player, snapshot)
	end
end

-- Checks if a perk milestone has been reached and offers perks if so
function ProgressionService:_checkPerkMilestone(player, data)
	local totalSpent   = data.TotalPointsSpent
	local milestone    = StatData.Points.PerkMilestoneEvery
	local milestonesEarned = math.floor(totalSpent / milestone)

	if milestonesEarned > data.PerkMilestonesSeen then
		data.PerkMilestonesSeen = milestonesEarned

		-- Offer perks (don't override an unclaimed pick)
		if not data.PendingPerkPick then
			local offered = PerkData:DrawPerks(StatData.Points.PerksOfferedCount, data.Perks)
			data.PendingPerkPick = { Perks = offered }

			print(string.format("[ProgressionService] Perk milestone for %s — offering: %s",
				player.Name, table.concat(offered, ", ")))

			ProgressionRemotes.PerkMilestoneReady:FireClient(player, offered)
		end
	end
end

-- Applies the passive bonuses from a class definition to the server-side stat table
function ProgressionService:_applyClassBonuses(player, classDef)
	local bonus = classDef.PassiveBonus or {}
	if not next(bonus) then return end

	local userId = player.UserId
	if not self.ExtraStatBonuses[userId] then
		self.ExtraStatBonuses[userId] = {}
	end
	for attr, value in pairs(bonus) do
		self.ExtraStatBonuses[userId][attr] = (self.ExtraStatBonuses[userId][attr] or 0) + value
	end

	self:RecalculateDerivedStats(player)
end

-- Applies perk effects to the server-side stat table
function ProgressionService:_applyPerkEffect(player, perkName)
	local perk = PerkData:GetPerk(perkName)
	if not perk then return end

	local effect = perk.Effect or {}

	-- Stat bonuses are additive to the stat table (re-derived on next recalc)
	if effect.StatBonus then
		local data = self.PlayerDataService:GetData(player)
		if data then
			for statName, bonus in pairs(effect.StatBonus) do
				data.Stats[statName] = (data.Stats[statName] or 0) + bonus
			end
		end
	end

	-- Direct derived bonuses go to ExtraStatBonuses (never to character attributes)
	local userId = player.UserId
	if not self.ExtraStatBonuses[userId] then
		self.ExtraStatBonuses[userId] = {}
	end
	for key, value in pairs(effect) do
		if key ~= "StatBonus" then
			self.ExtraStatBonuses[userId][key] = (self.ExtraStatBonuses[userId][key] or 0) + value
		end
	end

	self:RecalculateDerivedStats(player)
end

-- Recalculates all derived stats for a player and stores them server-side only
function ProgressionService:RecalculateDerivedStats(player)
	local data = self.PlayerDataService:GetData(player)
	if not data then return end

	local derived = StatData:CalculateDerived(data.Stats)

	-- Factor in any extra bonuses from class passives and perk direct effects
	local extra = self.ExtraStatBonuses[player.UserId] or {}
	for k, v in pairs(extra) do
		derived[k] = (derived[k] or 0) + v
	end

	-- Store server-side only — never written to character attributes
	self.DerivedStats[player.UserId] = derived
end

-- ===== SPEND STAT POINT =====
function ProgressionService:SpendStatPoint(player, statName)
	local data = self.PlayerDataService:GetData(player)
	if not data then return { success = false, reason = "No player data" } end

	-- Validate stat exists
	if not StatData:GetStat(statName) then
		return { success = false, reason = "Invalid stat: " .. tostring(statName) }
	end

	-- Validate points available
	if data.AvailablePoints <= 0 then
		return { success = false, reason = "No points available" }
	end

	-- Validate cap
	local currentTotal = StatData:TotalPointsSpent(data.Stats)
	if currentTotal >= StatData.Points.PointCap then
		return { success = false, reason = "Point cap reached (" .. StatData.Points.PointCap .. ")" }
	end

	-- Apply
	self.PlayerDataService:UpdateData(player, function(d)
		d.Stats[statName]    = (d.Stats[statName] or 0) + 1
		d.AvailablePoints    = d.AvailablePoints - 1
		d.TotalPointsSpent   = d.TotalPointsSpent + 1
	end)

	-- Re-derive and push to character
	self:RecalculateDerivedStats(player)

	-- Check perk milestone
	self:_checkPerkMilestone(player, self.PlayerDataService:GetData(player))

	-- Notify client
	self:_notifyClient(player)

	print(string.format("[ProgressionService] %s spent 1 point on %s (now: %d)",
		player.Name, statName, data.Stats[statName]))

	return { success = true }
end

-- ===== UNLOCK CLASS =====
function ProgressionService:UnlockClass(player, className)
	local data = self.PlayerDataService:GetData(player)
	if not data then return { success = false, reason = "No player data" } end

	local classDef = ClassData:GetClass(className)
	if not classDef then
		return { success = false, reason = "Class does not exist: " .. tostring(className) }
	end

	-- Check if already this class
	if data.CurrentClass == className then
		return { success = false, reason = "Already " .. className }
	end

	-- Run all checks
	local canUnlock, failReason = ClassData:CanUnlockClass(className, {
		CurrentClass         = data.CurrentClass,
		Stats                = data.Stats,
		TotalPointsSpent     = data.TotalPointsSpent,
		CompletedMilestones  = data.CompletedMilestones,
	})

	if not canUnlock then
		return { success = false, reason = failReason }
	end

	-- Apply
	self.PlayerDataService:UpdateData(player, function(d)
		d.CurrentClass = className
		table.insert(d.UnlockedClasses, className)

		-- Lives reward
		if classDef.LivesOnUnlock and classDef.LivesOnUnlock > 0 then
			d.Lives = math.min(d.MaxLives + classDef.LivesOnUnlock, 10) -- cap at 10
			d.MaxLives = d.Lives
		end
	end)

	-- Apply class passive bonuses to character
	self:_applyClassBonuses(player, classDef)

	-- Notify client
	self:_notifyClient(player)

	print(string.format("[ProgressionService] %s unlocked class: %s", player.Name, className))
	return { success = true }
end

-- ===== PICK PERK =====
function ProgressionService:PickPerk(player, perkName)
	local data = self.PlayerDataService:GetData(player)
	if not data then return { success = false, reason = "No player data" } end

	-- Must have a pending pick
	if not data.PendingPerkPick then
		return { success = false, reason = "No perk pick pending" }
	end

	-- Must be one of the offered perks
	local offered = data.PendingPerkPick.Perks
	local isOffered = false
	for _, name in ipairs(offered) do
		if name == perkName then isOffered = true break end
	end

	if not isOffered then
		return { success = false, reason = "Perk was not offered: " .. tostring(perkName) }
	end

	-- MaxStack check
	local perkDef = PerkData:GetPerk(perkName)
	if not perkDef then
		return { success = false, reason = "Perk does not exist: " .. tostring(perkName) }
	end

	if perkDef.MaxStack == 1 then
		for _, owned in ipairs(data.Perks) do
			if owned == perkName then
				return { success = false, reason = "Already own a unique perk: " .. perkName }
			end
		end
	end

	-- Apply
	self.PlayerDataService:UpdateData(player, function(d)
		table.insert(d.Perks, perkName)
		d.PendingPerkPick = nil
	end)

	-- Apply effect to character
	self:_applyPerkEffect(player, perkName)

	-- Notify client
	self:_notifyClient(player)

	print(string.format("[ProgressionService] %s picked perk: %s", player.Name, perkName))
	return { success = true }
end

-- ===== AWARD POINTS =====
-- Called by other systems (leveling, milestones, trial completion)
function ProgressionService:AwardPoints(player, amount, reason)
	self.PlayerDataService:UpdateData(player, function(d)
		d.AvailablePoints = math.min(d.AvailablePoints + amount, StatData.Points.PointCap)
	end)
	self:_notifyClient(player)
	print(string.format("[ProgressionService] Awarded %d points to %s (%s)", amount, player.Name, reason or ""))
end

-- ===== WEAPON EQUIP CHECK =====
-- Called by CombatServer before allowing a weapon equip
-- Returns: canEquip (bool), reason (string or nil)
function ProgressionService:CanEquipWeapon(player, weaponName)
	local data = self.PlayerDataService:GetData(player)
	if not data then return false, "No player data" end

	local WeaponData = require(game.ReplicatedStorage.Modules.Data.WeaponData)
	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then return false, "Unknown weapon" end

	local weaponType = weapon.WeaponType  -- "Light", "Medium", "Heavy"
	local canEquip, failStat, required = StatData:CanEquipWeaponType(data.Stats, weaponType)

	if not canEquip then
		return false, string.format(
			"Requires %d %s to equip %s weapons (you have %d)",
			required, failStat, weaponType, data.Stats[failStat] or 0
		)
	end

	return true
end

-- ===== REMOTE SETUP =====
function ProgressionService:_setupRemotes()
	ProgressionRemotes.SpendStatPoint.OnServerInvoke = function(player, statName)
		if type(statName) ~= "string" then return { success = false, reason = "Invalid input" } end
		return self:SpendStatPoint(player, statName)
	end

	ProgressionRemotes.UnlockClass.OnServerInvoke = function(player, className)
		if type(className) ~= "string" then return { success = false, reason = "Invalid input" } end
		return self:UnlockClass(player, className)
	end

	ProgressionRemotes.PickPerk.OnServerInvoke = function(player, perkName)
		if type(perkName) ~= "string" then return { success = false, reason = "Invalid input" } end
		return self:PickPerk(player, perkName)
	end

	ProgressionRemotes.RequestPlayerData.OnServerInvoke = function(player)
		return self.PlayerDataService:GetClientSnapshot(player)
	end
end

return ProgressionService
