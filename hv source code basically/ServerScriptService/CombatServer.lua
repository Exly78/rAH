-- ServerScriptService.CombatServer
-- Entry point: initialises all server managers and boots handler modules.

local Players               = game:GetService("Players")
local CombatRemotes         = require(game.ReplicatedStorage.Modules.Remotes.CombatRemotes)
local ServerCombatManager   = require(game.ServerStorage.Modules.Managers.ServerCombatManager)
local ServerHealthManager   = require(game.ServerStorage.Modules.Managers.ServerHealthManager)
local ServerStatusManager   = require(game.ServerStorage.Modules.Managers.ServerStatusManager)
local ServerCriticalManager = require(game.ServerStorage.Modules.Managers.ServerCriticalManager)
local ServerWeaponManager   = require(game.ServerStorage.Modules.Weapons.ServerWeaponManager)

local WeaponServer  = require(game.ServerStorage.Modules.Handlers.WeaponServer)
local DefenseServer = require(game.ServerStorage.Modules.Handlers.DefenseServer)
local HitboxServer  = require(game.ServerStorage.Modules.Handlers.HitboxServer)

-- ===== MANAGER INIT =====
local healthManager   = ServerHealthManager.new()
local statusManager   = ServerStatusManager.new(healthManager, CombatRemotes)
local combatManager   = ServerCombatManager.new(healthManager, statusManager)
local weaponManager   = ServerWeaponManager.new()
local criticalManager = ServerCriticalManager.new(healthManager, combatManager, weaponManager)
combatManager:SetupPlayerListeners()

local managers = {
	health   = healthManager,
	status   = statusManager,
	combat   = combatManager,
	weapon   = weaponManager,
	critical = criticalManager,
}

-- ===== BOOT HANDLER MODULES =====
WeaponServer.Setup(managers, CombatRemotes)
local defenseHandles = DefenseServer.Setup(managers, CombatRemotes)
local hitboxHandles  = HitboxServer.Setup(managers, CombatRemotes)

-- ===== PLAYER CLEANUP =====
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId

	hitboxHandles.AuthorizedSkills[userId]       = nil
	defenseHandles.DodgeCooldowns[userId]        = nil
	defenseHandles.BlockCooldowns[userId]        = nil

	criticalManager:CleanupPlayer(player)
	combatManager:Cleanup(player)

	if player.Character then
		statusManager:RemoveAll(player.Character)
		weaponManager:CleanupCharacter(player.Character)
	end
end)

print("[SERVER] Combat system initialized")
