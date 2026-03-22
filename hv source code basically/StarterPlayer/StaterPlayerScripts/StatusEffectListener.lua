-- StarterCharacterScripts (or StarterPlayerScripts).StatusEffectListener
-- ============================================================
-- Listens for status effect updates from the server and
-- renders a simple UI showing active effects, their stacks,
-- and their count.
--
-- The UI is built procedurally – no need for a pre-made
-- ScreenGui in Studio. Each active effect gets an icon frame
-- that updates in real-time.
-- ============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local CombatRemotes    = require(ReplicatedStorage.Modules.Remotes.CombatRemotes)
local StatusEffectData = require(ReplicatedStorage.Modules.Data.StatusEffectData)

local LocalPlayer = Players.LocalPlayer

-- ===== UI SETUP =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StatusEffectsGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer.PlayerGui

-- Container anchored to bottom-left (adjust to taste)
local container = Instance.new("Frame")
container.Name = "EffectsContainer"
container.Size = UDim2.new(0, 300, 0, 64)
container.Position = UDim2.new(0, 16, 1, -80)
container.BackgroundTransparency = 1
container.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = container

-- ===== ICON POOL =====
-- We keep one frame per active effect and reuse/destroy them as effects come and go.
local activeFrames = {}  -- [effectName] = Frame

local ICON_SIZE    = UDim2.new(0, 52, 0, 52)
local CORNER_RADIUS = UDim.new(0, 8)

local function getOrCreateFrame(effectName)
	if activeFrames[effectName] then
		return activeFrames[effectName]
	end

	local def = StatusEffectData.Get(effectName)
	local color = (def and def.Color) or Color3.fromRGB(150, 150, 150)

	-- Outer frame
	local frame = Instance.new("Frame")
	frame.Name = effectName
	frame.Size = ICON_SIZE
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BorderSizePixel = 0
	frame.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = frame

	-- Coloured accent bar at bottom
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(1, 0, 0, 4)
	accent.Position = UDim2.new(0, 0, 1, -4)
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Parent = frame

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = CORNER_RADIUS
	accentCorner.Parent = accent

	-- Effect name label (short – first 4 chars or custom abbreviation)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = string.upper(string.sub(effectName, 1, 4))
	nameLabel.TextColor3 = color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = frame

	-- Stacks label (top-right corner badge)
	local stacksLabel = Instance.new("TextLabel")
	stacksLabel.Name = "StacksLabel"
	stacksLabel.Size = UDim2.new(0.45, 0, 0.38, 0)
	stacksLabel.Position = UDim2.new(0.55, 0, 0.42, 0)
	stacksLabel.BackgroundTransparency = 1
	stacksLabel.Text = "0"
	stacksLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	stacksLabel.TextScaled = true
	stacksLabel.Font = Enum.Font.Gotham
	stacksLabel.Parent = frame

	-- Count label (bottom-left)
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0.45, 0, 0.38, 0)
	countLabel.Position = UDim2.new(0, 2, 0.42, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "0"
	countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	countLabel.TextScaled = true
	countLabel.Font = Enum.Font.Gotham
	countLabel.Parent = frame

	-- Small separator between stacks and count
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(0, 1, 0.3, 0)
	sep.Position = UDim2.new(0.5, 0, 0.48, 0)
	sep.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	sep.BorderSizePixel = 0
	sep.Parent = frame

	activeFrames[effectName] = frame
	return frame
end

local function removeFrame(effectName)
	local frame = activeFrames[effectName]
	if not frame then return end

	-- Fade out then destroy
	local tween = TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		frame:Destroy()
	end)

	activeFrames[effectName] = nil
end

local function updateFrame(effectName, stacks, count)
	local frame = getOrCreateFrame(effectName)

	frame:FindFirstChild("StacksLabel").Text = tostring(stacks)
	frame:FindFirstChild("CountLabel").Text  = tostring(count)

	-- Pulse animation to signal a change
	local accent = frame:FindFirstChild("Accent")
	if accent then
		TweenService:Create(accent, TweenInfo.new(0.1), { Size = UDim2.new(1, 0, 0, 6) }):Play()
		task.delay(0.15, function()
			TweenService:Create(accent, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, 4) }):Play()
		end)
	end
end

-- ===== LISTEN =====
-- Receives a full snapshot each time any effect changes on this character.
-- snapshot = { [effectName] = { Stacks = n, Count = n }, ... }
CombatRemotes.UpdateStatusEffects.OnClientEvent:Connect(function(snapshot)
	-- Collect what's currently displayed
	local currentlyShown = {}
	for effectName, _ in pairs(activeFrames) do
		currentlyShown[effectName] = true
	end

	-- Update or create frames for effects in the snapshot
	for effectName, data in pairs(snapshot) do
		updateFrame(effectName, data.Stacks, data.Count)
		currentlyShown[effectName] = nil  -- mark as still active
	end

	-- Remove frames for effects no longer in the snapshot
	for effectName, _ in pairs(currentlyShown) do
		removeFrame(effectName)
	end
end)