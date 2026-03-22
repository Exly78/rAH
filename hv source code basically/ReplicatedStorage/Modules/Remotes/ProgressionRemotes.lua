-- ReplicatedStorage.Modules.Remotes.ProgressionRemotes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local function GetOrCreate(name, class)
	local existing = RemotesFolder:FindFirstChild(name)
	if existing then return existing end
	local r = Instance.new(class)
	r.Name = name
	r.Parent = RemotesFolder
	return r
end

local ProgressionRemotes = {}

-- Client → Server
ProgressionRemotes.SpendStatPoint     = GetOrCreate("SpendStatPoint",    "RemoteFunction") -- args: statName → returns {success, reason, newData}
ProgressionRemotes.UnlockClass        = GetOrCreate("UnlockClass",       "RemoteFunction") -- args: className → returns {success, reason, newData}
ProgressionRemotes.PickPerk           = GetOrCreate("PickPerk",          "RemoteFunction") -- args: perkName → returns {success, reason, newData}
ProgressionRemotes.RequestPlayerData  = GetOrCreate("RequestPlayerData", "RemoteFunction") -- no args → returns full playerData snapshot

-- Server → Client
ProgressionRemotes.PlayerDataUpdated  = GetOrCreate("PlayerDataUpdated",  "RemoteEvent")  -- fires whenever server updates playerData
ProgressionRemotes.PerkMilestoneReady = GetOrCreate("PerkMilestoneReady", "RemoteEvent")  -- fires when a perk pick is available, sends offered perk names

return ProgressionRemotes
