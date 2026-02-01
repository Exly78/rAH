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

CombatRemotes.SkillRequest = GetOrCreateRemote("SkillRequest", "RemoteEvent")
CombatRemotes.CreateHitbox = GetOrCreateRemote("CreateHitbox", "RemoteEvent") 
CombatRemotes.HitConfirm = GetOrCreateRemote("HitConfirm", "RemoteEvent")
CombatRemotes.ApplyHitstun = GetOrCreateRemote("ApplyHitstun", "RemoteEvent")
CombatRemotes.ApplyKnockedOut = GetOrCreateRemote("ApplyKnockedOut", "RemoteEvent")
CombatRemotes.UpdateHealth = GetOrCreateRemote("UpdateHealth", "RemoteEvent")
CombatRemotes.ReplicateState = GetOrCreateRemote("ReplicateState", "RemoteEvent")
CombatRemotes.ValidateHit = GetOrCreateRemote("ValidateHit", "RemoteFunction")
CombatRemotes.WeaponEquipped = GetOrCreateRemote("WeaponEquipped", "RemoteEvent")
CombatRemotes.WeaponUnequipped = GetOrCreateRemote("WeaponUnequipped", "RemoteEvent")

return CombatRemotes