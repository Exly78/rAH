-- ServerScriptService.ProgressionServer
-- Boots the progression system. Place this in ServerScriptService.

local PlayerDataService  = require(script.Parent.Services.PlayerDataService)
local ProgressionService = require(script.Parent.Services.ProgressionService)

PlayerDataService:Init()
local progressionService = ProgressionService.new(PlayerDataService)

-- ===== AWARD STARTER POINTS (for testing) =====
-- Remove or adjust this once a real leveling system exists.
local Players = game:GetService("Players")
local STARTER_POINTS = 50  -- enough to unlock a base class and invest in some stats

Players.PlayerAdded:Connect(function(player)
	-- Wait for data to load
	task.wait(1)
	local data = PlayerDataService:GetData(player)
	if data and data.AvailablePoints == 0 and data.TotalPointsSpent == 0 then
		progressionService:AwardPoints(player, STARTER_POINTS, "starter grant")
	end
end)

-- Apply derived stats when character spawns
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- let character fully load
		progressionService:RecalculateDerivedStats(player)
	end)
end)

print("[ProgressionServer] Initialized")
