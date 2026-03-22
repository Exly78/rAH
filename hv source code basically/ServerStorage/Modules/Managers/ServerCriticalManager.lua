-- ServerStorage.Modules.Managers.ServerCriticalManager
-- ============================================================
-- Handles all critical attack logic server-side.
--
-- Supports two crit types automatically based on WeaponData:
--   Single-phase: Phases has 1 entry — just a powered-up hit
--   Multi-phase:  Phases has 2+ entries — Phase 1 marks targets,
--                 Phase 2 executes on them (e.g. Katana)
--
-- CombatServer just calls: criticalManager:HandleCritical(player, phase)
-- ============================================================

local Players    = game:GetService("Players")
local WeaponData = require(game.ReplicatedStorage.Modules.Data.WeaponData)

local ServerCriticalManager = {}
ServerCriticalManager.__index = ServerCriticalManager

function ServerCriticalManager.new(healthManager, combatManager, weaponManager)
	local self = setmetatable({}, ServerCriticalManager)

	self.HealthManager = healthManager
	self.CombatManager = combatManager
	self.WeaponManager = weaponManager

	-- Only used for multi-phase crits
	-- [userId] = { targets = {character,...}, expiryTime = number, weaponName = string }
	self.MarkedTargets = {}

	print("[ServerCriticalManager] Initialized")
	return self
end

-- ===== PUBLIC =====
-- phase = which phase the client is executing (1 or 2)
function ServerCriticalManager:HandleCritical(player, phase)
	local character = player.Character
	if not character then return { success = false, reason = "NoCharacter" } end

	if self.HealthManager:IsDead(character) then
		return { success = false, reason = "Dead" }
	end

	local weaponName = character:GetAttribute("EquippedWeapon")
	if not weaponName then return { success = false, reason = "NoWeapon" } end

	local critData = WeaponData:GetCritical(weaponName)
	if not critData or not critData.Phases then
		warn("[ServerCriticalManager] No critical data for:", weaponName)
		return { success = false, reason = "NoCritData" }
	end

	local phaseCount = #critData.Phases
	local phaseData  = critData.Phases[phase]

	if not phaseData then
		warn("[ServerCriticalManager] Invalid phase", phase, "for", weaponName)
		return { success = false, reason = "InvalidPhase" }
	end

	if phaseCount == 1 then
		return self:_executeSinglePhase(player, character, weaponName, phaseData)
	else
		if phase == 1 then
			return self:_executePhase1(player, character, weaponName, critData, phaseData)
		else
			return self:_executePhase2(player, character, weaponName, phaseData)
		end
	end
end

-- ===== SINGLE-PHASE CRIT =====
function ServerCriticalManager:_executeSinglePhase(player, character, weaponName, phaseData)
	local targets = self:_scanHitbox(character, phaseData)
	local weapon  = WeaponData:GetWeapon(weaponName)
	local hits    = 0

	for _, target in ipairs(targets) do
		local result = self.CombatManager:ApplyDamage(character, target, {
			Damage          = weapon.Damage * phaseData.DamageMultiplier,
			HitstunDuration = phaseData.HitstunDuration,
			PostureDamage   = phaseData.PostureDamage,
			StatusEffects   = phaseData.StatusEffects or {},
			IsCriticalHit   = true,
		})
		if result.hit then hits += 1 end
	end

	print(string.format("[ServerCriticalManager] %s single-phase crit: %d hit(s)", player.Name, hits))
	return { success = true, hits = hits }
end

-- ===== MULTI-PHASE: PHASE 1 =====
function ServerCriticalManager:_executePhase1(player, character, weaponName, critData, phaseData)
	local targets = self:_scanHitbox(character, phaseData)
	local weapon  = WeaponData:GetWeapon(weaponName)
	local hits    = 0

	for _, target in ipairs(targets) do
		local result = self.CombatManager:ApplyDamage(character, target, {
			Damage          = weapon.Damage * phaseData.DamageMultiplier,
			HitstunDuration = phaseData.HitstunDuration,
			PostureDamage   = phaseData.PostureDamage,
			StatusEffects   = phaseData.StatusEffects or {},
			IsCriticalHit   = true,
		})
		if result.hit then hits += 1 end
	end

	if #targets > 0 then
		local window = critData.AltCritWindow or 8
		self.MarkedTargets[player.UserId] = {
			targets    = targets,
			expiryTime = tick() + window,
			weaponName = weaponName,
		}
		character:SetAttribute("AltCrit", true)

		print(string.format("[ServerCriticalManager] %s Phase1 hit %d target(s) — AltCrit open for %ds",
			player.Name, #targets, window))

		task.delay(window, function()
			if self.MarkedTargets[player.UserId] then
				self.MarkedTargets[player.UserId] = nil
				if character and character.Parent then
					character:SetAttribute("AltCrit", nil)
				end
				print("[ServerCriticalManager] AltCrit expired for", player.Name)
			end
		end)
	else
		print("[ServerCriticalManager]", player.Name, "Phase1 missed")
	end

	return { success = true, hits = hits }
end

-- ===== MULTI-PHASE: PHASE 2 =====
function ServerCriticalManager:_executePhase2(player, character, weaponName, phaseData)
	local userId = player.UserId

	if not character:GetAttribute("AltCrit") then
		warn("[ServerCriticalManager] Phase2 without AltCrit:", player.Name)
		return { success = false, reason = "NotUnlocked" }
	end

	local marked = self.MarkedTargets[userId]
	if not marked or tick() > marked.expiryTime or #marked.targets == 0 then
		warn("[ServerCriticalManager] Phase2: no valid marked targets for", player.Name)
		character:SetAttribute("AltCrit", nil)
		self.MarkedTargets[userId] = nil
		return { success = false, reason = "NoMarkedTargets" }
	end

	if marked.weaponName ~= weaponName then
		warn("[ServerCriticalManager] Phase2 weapon mismatch for", player.Name)
		return { success = false, reason = "WeaponMismatch" }
	end

	local targets    = marked.targets
	local weapon     = WeaponData:GetWeapon(weaponName)
	local baseDamage = weapon.Damage * phaseData.DamageMultiplier

	character:SetAttribute("AltCrit", nil)
	self.MarkedTargets[userId] = nil

	local rapidHits     = phaseData.RapidHits        or 1
	local rapidInterval = phaseData.RapidHitInterval or 0.065
	local totalHits     = 0

	task.spawn(function()
		for i = 1, rapidHits do
			for _, target in ipairs(targets) do
				if target.Parent and self.HealthManager:IsAlive(target) then
					local result = self.CombatManager:ApplyDamage(character, target, {
						Damage          = baseDamage,
						HitstunDuration = phaseData.HitstunDuration,
						PostureDamage   = phaseData.PostureDamage,
						StatusEffects   = phaseData.StatusEffects or {},
						IsCriticalHit   = true,
					})
					if result.hit then totalHits += 1 end
				end
			end
			if i < rapidHits then task.wait(rapidInterval) end
		end
		print(string.format("[ServerCriticalManager] %s Phase2: %d/%d hits",
			player.Name, totalHits, rapidHits * #targets))
	end)

	return { success = true }
end

-- ===== INTERNAL: shared hitbox scan =====
function ServerCriticalManager:_scanHitbox(character, phaseData)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return {} end

	local hitboxSize = phaseData.HitboxSize   or Vector3.new(6, 6, 6)
	local offset     = phaseData.HitboxOffset or 5
	local hitboxPos  = rootPart.Position + rootPart.CFrame.LookVector * offset

	local hitEntities = workspace:GetPartBoundsInRadius(hitboxPos, (hitboxSize / 2).Magnitude)
	local targets     = {}
	local seenChars   = {}

	for _, part in ipairs(hitEntities) do
		local targetChar = part:FindFirstAncestorOfClass("Model")
		if targetChar and not seenChars[targetChar] and targetChar ~= character then
			local targetHumanoid = targetChar:FindFirstChild("Humanoid")
			if targetHumanoid then
				if not self.HealthManager.HealthData[targetChar] then
					if not Players:GetPlayerFromCharacter(targetChar) then
						self.CombatManager:InitializeCharacter(targetChar)
					end
				end
				if self.HealthManager:IsAlive(targetChar) then
					local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
					if targetRoot and self.CombatManager:ValidateHitbox(character, targetRoot.Position, hitboxSize, offset) then
						seenChars[targetChar] = true
						table.insert(targets, targetChar)
					end
				end
			end
		end
	end

	return targets
end

-- ===== QUERIES =====
function ServerCriticalManager:HasMarkedTargets(player)
	local marked = self.MarkedTargets[player.UserId]
	return marked ~= nil and tick() <= marked.expiryTime
end

function ServerCriticalManager:IsMultiPhase(weaponName)
	local critData = WeaponData:GetCritical(weaponName)
	return critData ~= nil and #critData.Phases > 1
end

-- ===== CLEANUP =====
function ServerCriticalManager:CleanupPlayer(player)
	local character = player.Character
	self.MarkedTargets[player.UserId] = nil
	if character and character.Parent then
		character:SetAttribute("AltCrit", nil)
	end
end

function ServerCriticalManager:Destroy()
	table.clear(self.MarkedTargets)
	print("[ServerCriticalManager] Destroyed")
end

return ServerCriticalManager
