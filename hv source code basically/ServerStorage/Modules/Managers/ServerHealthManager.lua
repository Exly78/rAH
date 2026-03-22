--ServerStorage.Modules.Managers.ServerHealthManager
-- Tracks real HP server-side in a Lua table.
-- Humanoid.Health stays at max so clients/exploiters can't read real values.
-- Only the owning player receives their real HP via FireClient.

local ServerHealthManager = {}
ServerHealthManager.__index = ServerHealthManager

local Players = game:GetService("Players")
local CombatRemotes = require(game.ServerStorage.Modules.Remotes.CombatRemotes)

-- ===== CONSTRUCTOR =====
function ServerHealthManager.new()
	local self = setmetatable({}, ServerHealthManager)

	-- [character Model] = { Health = number, MaxHealth = number }
	self.HealthData = {}

	print("[ServerHealthManager] Initialized")
	return self
end

-- ===== REGISTER CHARACTER =====
-- Call this when a character spawns. Reads initial MaxHealth from Humanoid,
-- then locks Humanoid.Health to max so clients see nothing real.
function ServerHealthManager:RegisterCharacter(character)
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		warn("[ServerHealthManager] No Humanoid on", character.Name)
		return
	end

	local maxHP = humanoid.MaxHealth or 100

	self.HealthData[character] = {
		Health = maxHP,
		MaxHealth = maxHP,
	}

	-- Lock Humanoid to always show full health (fake value for clients)
	humanoid.Health = humanoid.MaxHealth
	humanoid.HealthDisplayDistance = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	-- Prevent anything from changing Humanoid.Health externally
	-- If something does change it (like a reset), snap it back
	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		local data = self.HealthData[character]
		if data and data.Health > 0 then
			-- Keep Humanoid alive and faked unless we killed them
			if humanoid.Health ~= humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
		end
	end)

	-- Send initial HP to owning player
	self:SendHealthUpdate(character)

	-- Cleanup when character is removed
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self.HealthData[character] = nil
		end
	end)

	print("[ServerHealthManager] Registered", character.Name, "| HP:", maxHP, "/", maxHP)
end

-- ===== TAKE DAMAGE =====
-- Returns { died = bool, finalDamage = number, newHealth = number }
function ServerHealthManager:TakeDamage(character, amount)
	local data = self.HealthData[character]
	if not data then
		warn("[ServerHealthManager] TakeDamage on unregistered character:", character.Name)
		return { died = false, finalDamage = 0, newHealth = 0 }
	end

	if data.Health <= 0 then
		return { died = false, finalDamage = 0, newHealth = 0 }
	end

	local finalDamage = math.floor(math.max(0, amount))
	data.Health = math.max(0, data.Health - finalDamage)

	-- Send update to owning player only
	self:SendHealthUpdate(character)

	-- Handle death
	if data.Health <= 0 then
		self:OnDeath(character)
		return { died = true, finalDamage = finalDamage, newHealth = 0 }
	end

	return { died = false, finalDamage = finalDamage, newHealth = data.Health }
end

-- ===== HEAL =====
function ServerHealthManager:Heal(character, amount)
	local data = self.HealthData[character]
	if not data then return end
	if data.Health <= 0 then return end -- Can't heal dead characters

	data.Health = math.min(data.MaxHealth, data.Health + math.floor(amount))

	self:SendHealthUpdate(character)
	print("[ServerHealthManager]", character.Name, "healed for", amount, "| HP:", data.Health)
end

-- ===== SET HEALTH (direct set, for respawns etc.) =====
function ServerHealthManager:SetHealth(character, newHealth)
	local data = self.HealthData[character]
	if not data then return end

	data.Health = math.clamp(math.floor(newHealth), 0, data.MaxHealth)
	self:SendHealthUpdate(character)

	if data.Health <= 0 then
		self:OnDeath(character)
	end
end

-- ===== SET MAX HEALTH =====
function ServerHealthManager:SetMaxHealth(character, newMax)
	local data = self.HealthData[character]
	if not data then return end

	local oldMax = data.MaxHealth
	data.MaxHealth = math.floor(math.max(1, newMax))

	-- Scale current health proportionally
	if oldMax > 0 then
		data.Health = math.floor(data.Health * (data.MaxHealth / oldMax))
	end

	-- Update fake Humanoid max too
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.MaxHealth = data.MaxHealth
		humanoid.Health = data.MaxHealth  -- Keep faked
	end

	self:SendHealthUpdate(character)
end

-- ===== QUERIES =====
function ServerHealthManager:GetHealth(character)
	local data = self.HealthData[character]
	return data and data.Health or 0
end

function ServerHealthManager:GetMaxHealth(character)
	local data = self.HealthData[character]
	return data and data.MaxHealth or 0
end

function ServerHealthManager:IsDead(character)
	local data = self.HealthData[character]
	if not data then return true end
	return data.Health <= 0
end

function ServerHealthManager:IsAlive(character)
	return not self:IsDead(character)
end

function ServerHealthManager:GetHealthPercent(character)
	local data = self.HealthData[character]
	if not data or data.MaxHealth <= 0 then return 0 end
	return data.Health / data.MaxHealth
end

-- ===== SEND HP TO OWNING PLAYER =====
function ServerHealthManager:SendHealthUpdate(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local data = self.HealthData[character]
	if not data then return end

	CombatRemotes.UpdateHealth:FireClient(player, character.Name, data.Health, data.MaxHealth)
end

-- ===== DEATH HANDLING =====
function ServerHealthManager:OnDeath(character)
	print("[ServerHealthManager]", character.Name, "has died!")

	-- Actually kill the Humanoid so Roblox death mechanics trigger
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end

	-- Fire death event for other systems to hook into
	-- (you can connect to this via OnDeath callback)
	if self._onDeathCallback then
		self._onDeathCallback(character)
	end
end

-- ===== DEATH CALLBACK =====
-- Register a function to call when any character dies
function ServerHealthManager:SetDeathCallback(callback)
	self._onDeathCallback = callback
end

-- ===== CLEANUP =====
function ServerHealthManager:CleanupCharacter(character)
	self.HealthData[character] = nil
end

function ServerHealthManager:Destroy()
	table.clear(self.HealthData)
	self._onDeathCallback = nil
	print("[ServerHealthManager] Destroyed")
end

return ServerHealthManager
