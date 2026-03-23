--ReplicatedStorage.Modules.Remotes.CombatRemotes

local CombatRemotes = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function GetOrCreateRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

-- Combat
CombatRemotes.SkillRequest = GetOrCreateRemote("SkillRequest", "RemoteEvent")
CombatRemotes.CreateHitbox = GetOrCreateRemote("CreateHitbox", "RemoteEvent") 
CombatRemotes.HitConfirm = GetOrCreateRemote("HitConfirm", "RemoteEvent")
CombatRemotes.ApplyHitstun = GetOrCreateRemote("ApplyHitstun", "RemoteEvent")
CombatRemotes.ApplyKnockedOut = GetOrCreateRemote("ApplyKnockedOut", "RemoteEvent")
CombatRemotes.UpdateHealth = GetOrCreateRemote("UpdateHealth", "RemoteEvent")
CombatRemotes.ReplicateState = GetOrCreateRemote("ReplicateState", "RemoteEvent")
CombatRemotes.ValidateHit = GetOrCreateRemote("ValidateHit", "RemoteFunction")
CombatRemotes.UpdateStatusEffects = GetOrCreateRemote("UpdateStatusEffects", "RemoteEvent")


-- Weapon equip/unequip state
CombatRemotes.WeaponEquipped = GetOrCreateRemote("WeaponEquipped", "RemoteEvent")
CombatRemotes.WeaponUnequipped = GetOrCreateRemote("WeaponUnequipped", "RemoteEvent")

-- Weapon model management (client -> server)
CombatRemotes.AddWeapon = GetOrCreateRemote("AddWeapon", "RemoteEvent")
CombatRemotes.RemoveWeapon = GetOrCreateRemote("RemoveWeapon", "RemoteEvent")
CombatRemotes.WeaponWeldToHand = GetOrCreateRemote("WeaponWeldToHand", "RemoteEvent")
CombatRemotes.WeaponWeldToBody = GetOrCreateRemote("WeaponWeldToBody", "RemoteEvent")

-- Defense state (client -> server)
CombatRemotes.DodgeStarted   = GetOrCreateRemote("DodgeStarted",   "RemoteEvent")
CombatRemotes.BlockStarted   = GetOrCreateRemote("BlockStarted",   "RemoteEvent")
CombatRemotes.BlockEnded     = GetOrCreateRemote("BlockEnded",     "RemoteEvent")
CombatRemotes.CrouchStarted  = GetOrCreateRemote("CrouchStarted",  "RemoteEvent")
CombatRemotes.CrouchEnded    = GetOrCreateRemote("CrouchEnded",    "RemoteEvent")

-- Combat feedback (server -> client)
CombatRemotes.DodgeSuccess = GetOrCreateRemote("DodgeSuccess", "RemoteEvent")
CombatRemotes.ParrySuccess = GetOrCreateRemote("ParrySuccess", "RemoteEvent")
CombatRemotes.BlockImpact  = GetOrCreateRemote("BlockImpact", "RemoteEvent")
CombatRemotes.GotParried   = GetOrCreateRemote("GotParried", "RemoteEvent")
CombatRemotes.BlockBroken  = GetOrCreateRemote("BlockBroken", "RemoteEvent")  -- fired when BlockBreak attack shatters a parry/block



return CombatRemotes
