-- ServerStorage.Modules.Managers.ServerStatusManager
-- ============================================================
-- Owns all active status effect state for every registered
-- character. Processes ticks, merges stacks/count from
-- multiple sources, and replicates display data to clients.
--
-- Usage:
--   local mgr = ServerStatusManager.new(healthManager, remotes)
--   mgr:RegisterCharacter(character)
--   mgr:Apply(character, "Bleed", { Stacks = 3, Count = 5 })
--   mgr:NotifyAction(character)   -- call when character attacks/moves
--   mgr:NotifyHit(character, hitContext) -- call when character takes a hit
-- ============================================================

local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local StatusEffectData = require(game.ReplicatedStorage.Modules.Data.StatusEffectData)

local ServerStatusManager = {}
ServerStatusManager.__index = ServerStatusManager

-- ===== CONSTRUCTOR =====
function ServerStatusManager.new(healthManager, remotes)
	local self = setmetatable({}, ServerStatusManager)

	self.HealthManager = healthManager
	self.Remotes       = remotes  -- CombatRemotes (or equivalent)

	-- [character] = {
	--   [effectName] = {
	--     Stacks   : number,
	--     Count    : number,
	--     Timer    : number,  -- only used by OnTime effects (seconds until next tick)
	--   }
	-- }
	self._activeEffects = {}

	-- Heartbeat connection for OnTime effects
	self._heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:_tickTime(dt)
	end)

	print("[ServerStatusManager] Initialized")
	return self
end

-- ===== REGISTER / UNREGISTER =====
function ServerStatusManager:RegisterCharacter(character)
	if self._activeEffects[character] then return end
	self._activeEffects[character] = {}

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:_cleanupCharacter(character)
		end
	end)

	print("[ServerStatusManager] Registered", character.Name)
end

function ServerStatusManager:_cleanupCharacter(character)
	self._activeEffects[character] = nil
end

-- ===== APPLY (add stacks and/or count to an effect) =====
-- options = { Stacks = number, Count = number }
-- Either key is optional; omit to leave that value unchanged.
function ServerStatusManager:Apply(character, effectName, options)
	local charEffects = self._activeEffects[character]
	if not charEffects then
		warn("[ServerStatusManager] Apply called on unregistered character:", character.Name)
		return
	end

	local def = StatusEffectData.Get(effectName)
	if not def then
		warn("[ServerStatusManager] Unknown effect:", effectName)
		return
	end

	local incomingStacks = options.Stacks or 0
	local incomingCount  = options.Count  or 0
	local isNew          = charEffects[effectName] == nil

	if isNew then
		charEffects[effectName] = {
			Stacks = 0,
			Count  = 0,
			Timer  = def.Interval or 1,
		}
	end

	local entry = charEffects[effectName]

	-- Merge and clamp
	entry.Stacks = math.clamp(entry.Stacks + incomingStacks, 0, def.MaxStacks or math.huge)
	entry.Count  = math.clamp(entry.Count  + incomingCount,  0, def.MaxCount  or math.huge)

	-- Fire OnApplied if this is a fresh application
	if isNew and def.OnApplied then
		def.OnApplied(character, entry.Stacks, entry.Count, self:_managers())
	end

	self:_replicate(character)

	print(string.format("[ServerStatusManager] %s → %s | Stacks: %d | Count: %d",
		character.Name, effectName, entry.Stacks, entry.Count))
end

-- ===== NOTIFY ACTION (movement or attack by the afflicted character) =====
-- Call this whenever the character performs an action that could trigger OnAction effects.
function ServerStatusManager:NotifyAction(character)
	self:_triggerByType(character, "OnAction")
end

-- ===== NOTIFY HIT (character received a hit) =====
-- Returns a table of results from OnTrigger callbacks (e.g. damage multipliers).
-- hitContext is passed through to effects for future extensibility.
function ServerStatusManager:NotifyHit(character, hitContext)
	return self:_triggerByType(character, "OnHit", hitContext)
end

-- ===== INTERNAL: trigger all effects of a given type =====
function ServerStatusManager:_triggerByType(character, triggerType, context)
	local charEffects = self._activeEffects[character]
	if not charEffects then return {} end

	local results = {}

	for effectName, entry in pairs(charEffects) do
		local def = StatusEffectData.Get(effectName)
		if def and def.TriggerType == triggerType and entry.Count > 0 then
			-- Fire the effect
			local result = def.OnTrigger(character, entry.Stacks, self:_managers())
			if result then
				results[effectName] = result
			end

			-- Consume one charge
			entry.Count -= 1

			if entry.Count <= 0 then
				self:_expireEffect(character, effectName, def)
			end
		end
	end

	if next(results) ~= nil or true then
		-- Always replicate after any trigger so UI stays accurate
		self:_replicate(character)
	end

	return results
end

-- ===== INTERNAL: heartbeat tick for OnTime effects =====
function ServerStatusManager:_tickTime(dt)
	for character, charEffects in pairs(self._activeEffects) do
		for effectName, entry in pairs(charEffects) do
			local def = StatusEffectData.Get(effectName)
			if not def then continue end

			-- OnTime effects (e.g. Sunder)
			if def.TriggerType == "OnTime" then
				entry.Timer = entry.Timer - dt
				if entry.Timer <= 0 then
					entry.Timer = def.Interval or 1
					if entry.Count > 0 then
						def.OnTrigger(character, entry.Stacks, self:_managers())
						entry.Count -= 1
						if entry.Count <= 0 then
							self:_expireEffect(character, effectName, def)
						end
						self:_replicate(character)
					end
				end
			end

			if def.PassiveDecay and def.PassiveDecayInterval then
				entry.DecayTimer = (entry.DecayTimer or def.PassiveDecayInterval) - dt
				if entry.DecayTimer <= 0 then
					entry.DecayTimer = def.PassiveDecayInterval
					entry.Count = math.max(0, entry.Count - def.PassiveDecay)
					if entry.Count <= 0 then
						self:_expireEffect(character, effectName, def)
					end
					self:_replicate(character)
				end
			end
		end
	end
end

-- ===== INTERNAL: expire an effect when count hits 0 =====
function ServerStatusManager:_expireEffect(character, effectName, def)
	local charEffects = self._activeEffects[character]
	if not charEffects then return end

	if def and def.OnExpired then
		def.OnExpired(character, self:_managers())
	end

	charEffects[effectName] = nil

	print(string.format("[ServerStatusManager] %s expired on %s", effectName, character.Name))
end

-- ===== REMOVE (manually clear an effect) =====
function ServerStatusManager:Remove(character, effectName)
	local charEffects = self._activeEffects[character]
	if not charEffects then return end

	local def = StatusEffectData.Get(effectName)
	self:_expireEffect(character, effectName, def)
	self:_replicate(character)
end

-- ===== REMOVE ALL effects from a character =====
function ServerStatusManager:RemoveAll(character)
	local charEffects = self._activeEffects[character]
	if not charEffects then return end

	for effectName, _ in pairs(charEffects) do
		local def = StatusEffectData.Get(effectName)
		self:_expireEffect(character, effectName, def)
	end

	self:_replicate(character)
end

-- ===== QUERIES =====
function ServerStatusManager:HasEffect(character, effectName)
	local charEffects = self._activeEffects[character]
	return charEffects ~= nil and charEffects[effectName] ~= nil
end

function ServerStatusManager:GetEffect(character, effectName)
	local charEffects = self._activeEffects[character]
	if not charEffects then return nil end
	return charEffects[effectName]  -- { Stacks, Count, Timer }
end

function ServerStatusManager:GetAllEffects(character)
	return self._activeEffects[character] or {}
end

-- ===== INTERNAL: build managers table for callbacks =====
function ServerStatusManager:_managers()
	return {
		Health = self.HealthManager,
		Status = self,
	}
end

-- ===== INTERNAL: replicate effect state to owning client =====
-- Sends a snapshot: { [effectName] = { Stacks, Count } }
function ServerStatusManager:_replicate(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local charEffects = self._activeEffects[character]
	if not charEffects then return end

	-- Build a lightweight snapshot (no timer data – client doesn't need it)
	local snapshot = {}
	for effectName, entry in pairs(charEffects) do
		snapshot[effectName] = {
			Stacks = entry.Stacks,
			Count  = entry.Count,
		}
	end

	self.Remotes.UpdateStatusEffects:FireClient(player, snapshot)
end

-- ===== CLEANUP =====
function ServerStatusManager:Destroy()
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
	table.clear(self._activeEffects)
	print("[ServerStatusManager] Destroyed")
end

return ServerStatusManager
