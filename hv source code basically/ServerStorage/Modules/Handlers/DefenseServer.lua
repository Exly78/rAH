-- ServerStorage.Modules.Handlers.DefenseServer
-- Handles dodge, block, and parry remote events.

local TagManager = require(game.ReplicatedStorage.Modules.Managers.TagManager)

local DODGE_COOLDOWN     = 0.5
local MAX_DODGE_DURATION = 0.6

local BLOCK_COOLDOWN     = 0.1
local MAX_PARRY_WINDOW   = 0.3
local MAX_BLOCK_DURATION = 10.0

local DefenseServer = {}

function DefenseServer.Setup(managers, CombatRemotes)
	local healthManager = managers.health

	local DodgeCooldowns = {}
	local BlockCooldowns = {}

	CombatRemotes.DodgeStarted.OnServerEvent:Connect(function(player, dodgeDuration)
		if not player or not player.Character then return end

		local character = player.Character
		local humanoid  = character:FindFirstChild("Humanoid")
		if not humanoid or healthManager:IsDead(character) then return end

		dodgeDuration = math.min(tonumber(dodgeDuration) or 0.45, MAX_DODGE_DURATION)
		if dodgeDuration <= 0 then return end

		local userId = player.UserId
		local now    = tick()
		if DodgeCooldowns[userId] and (now - DodgeCooldowns[userId]) < DODGE_COOLDOWN then return end
		DodgeCooldowns[userId] = now

		if TagManager.HasTag(character, "Hitstunned") or TagManager.HasTag(character, "KnockedOut") then return end

		TagManager.Initialize(character)
		TagManager.AddTag(character, "Invulnerable", dodgeDuration)
		TagManager.AddTag(character, "Dodging",      dodgeDuration)
	end)

	CombatRemotes.BlockStarted.OnServerEvent:Connect(function(player, parryWindow)
		if not player or not player.Character then return end

		local character = player.Character
		local humanoid  = character:FindFirstChild("Humanoid")
		if not humanoid or healthManager:IsDead(character) then return end

		parryWindow = math.min(tonumber(parryWindow) or 0.20, MAX_PARRY_WINDOW)
		if parryWindow <= 0 then return end

		local userId = player.UserId
		local now    = tick()
		if BlockCooldowns[userId] and (now - BlockCooldowns[userId]) < BLOCK_COOLDOWN then return end
		BlockCooldowns[userId] = now

		if TagManager.HasTag(character, "Hitstunned") or TagManager.HasTag(character, "KnockedOut") then return end

		TagManager.Initialize(character)
		TagManager.AddTag(character, "CanParry", parryWindow)
		TagManager.AddTag(character, "Parrying", parryWindow)

		task.delay(parryWindow, function()
			if character and character.Parent then
				if not TagManager.HasTag(character, "CanParry") then
					TagManager.AddTag(character, "IsBlocking", MAX_BLOCK_DURATION)
					TagManager.AddTag(character, "Blocking",   MAX_BLOCK_DURATION)
				end
			end
		end)
	end)

	CombatRemotes.BlockEnded.OnServerEvent:Connect(function(player)
		if not player or not player.Character then return end

		local character = player.Character
		TagManager.RemoveTag(character, "CanParry")
		TagManager.RemoveTag(character, "Parrying")
		TagManager.RemoveTag(character, "IsBlocking")
		TagManager.RemoveTag(character, "Blocking")
	end)

	-- Return cooldown tables so CombatServer can clean them up on PlayerRemoving
	return {
		DodgeCooldowns = DodgeCooldowns,
		BlockCooldowns = BlockCooldowns,
	}
end

return DefenseServer
