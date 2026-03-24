-- StarterPlayerScripts.HealthListener (LocalScript)
-- Slider = actual HP (moves immediately)
-- SecondSlider = trailing bar (shows where HP was, catches up after delay)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local CombatRemotes = require(ReplicatedStorage.Modules.Remotes.CombatRemotes)

local UI_ASSETS = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI")
local POSTURE_BAR_TEMPLATE = UI_ASSETS:WaitForChild("PostureBar")

-- Wait for UI
local StatsGui = Player:WaitForChild("PlayerGui"):WaitForChild("StatsGui")
local HealthFrame = StatsGui:WaitForChild("Health")
local Slider = HealthFrame:WaitForChild("Slider")
local SecondSlider = HealthFrame:WaitForChild("SecondSlider")
local PercentLabel = HealthFrame:WaitForChild("Percent")

-- The ACTUAL full size of the bar (not 1,0,1,0)
local FULL_SIZE = UDim2.new(0.952, 0, 1.118, 0)

-- Config
local HP_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TRAIL_DELAY = 0.5
local TRAIL_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local trailThread = nil

local function GetBarSize(percent)
	return UDim2.new(
		FULL_SIZE.X.Scale * percent, FULL_SIZE.X.Offset,
		FULL_SIZE.Y.Scale, FULL_SIZE.Y.Offset
	)
end

-- Initialize at full
Slider.Size = FULL_SIZE
SecondSlider.Size = FULL_SIZE
PercentLabel.Text = "100%"

-- [[ HEALTH LOGIC ]]
CombatRemotes.UpdateHealth.OnClientEvent:Connect(function(characterName, health, maxHealth)
	if not Player.Character or characterName ~= Player.Character.Name then return end

	local percent = (maxHealth > 0) and (health / maxHealth) or 0
	percent = math.clamp(percent, 0, 1)

	-- Immediately tween the main HP bar
	TweenService:Create(Slider, HP_TWEEN, {
		Size = GetBarSize(percent)
	}):Play()

	-- Update text
	PercentLabel.Text = math.floor(percent * 100) .. "%"

	-- Cancel any pending trail tween
	if trailThread then
		task.cancel(trailThread)
		trailThread = nil
	end

	-- Trail bar: wait, then catch up
	trailThread = task.delay(TRAIL_DELAY, function()
		TweenService:Create(SecondSlider, TRAIL_TWEEN, {
			Size = GetBarSize(percent)
		}):Play()
		trailThread = nil
	end)
end)

Player.CharacterAdded:Connect(function()
	Slider.Size = FULL_SIZE
	SecondSlider.Size = FULL_SIZE
	PercentLabel.Text = "100%"

	if trailThread then
		task.cancel(trailThread)
		trailThread = nil
	end
end)

-- [[ DYNAMIC POSTURE BILLBOARD LOGIC ]]
local ActivePostureBars = {}

local function SetupPostureBar(character)
	if ActivePostureBars[character] then return end

	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then return end

	local gui = POSTURE_BAR_TEMPLATE:Clone()
	gui.Parent = rootPart
	gui.Adornee = rootPart
	gui.Enabled = false

	local slider = gui:FindFirstChild("Slider", true) or gui:FindFirstChildWhichIsA("Frame", true)

	ActivePostureBars[character] = {
		Gui = gui,
		Slider = slider,
		HideTime = 0,
		CurrentPosture = 0,
		MaxPosture = 100,
	}
end

-- Posture updates come from the server via remote (owning player only, never a character attribute)
CombatRemotes.UpdatePosture.OnClientEvent:Connect(function(posture, maxPosture)
	local character = Player.Character
	if not character then return end
	local data = ActivePostureBars[character]
	if not data then return end

	data.CurrentPosture = posture
	data.MaxPosture = maxPosture

	if posture > 0 then
		data.Gui.Enabled = true
		data.HideTime = tick() + 5
	end

	if data.Slider then
		data.Slider.AnchorPoint = Vector2.new(0, 1)
		local percent = math.clamp(posture / maxPosture, 0, 1)
		local targetSize = UDim2.new(0.8, 0, 0.97 * percent, 0)
		local targetPosition = UDim2.new(0.18, 0, 1, 0)
		TweenService:Create(data.Slider, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = targetSize,
			Position = targetPosition
		}):Play()
	end
end)

-- Call SetupPostureBar strictly for the Local Player
Player.CharacterAdded:Connect(function(character)
	SetupPostureBar(character)
end)

if Player.Character then
	task.spawn(SetupPostureBar, Player.Character)
end

RunService.Heartbeat:Connect(function()
	local now = tick()
	for character, data in pairs(ActivePostureBars) do
		if not character.Parent then
			if data.Gui then data.Gui:Destroy() end
			ActivePostureBars[character] = nil
			continue
		end

		local currentPosture = data.CurrentPosture or 0
		if currentPosture == 0 and now > data.HideTime then
			data.Gui.Enabled = false
		end
	end
end)

print("[HealthListener] Listening for HP and Posture UI Updates")
