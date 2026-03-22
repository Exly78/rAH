-- StarterPlayerScripts.ProgressionUI
-- Demo progression UI — tabbed interface for Stats / Classes / Perks.
-- Press P to toggle open/close.

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StatData  = require(game.ReplicatedStorage.Modules.Data.StatData)
local ClassData = require(game.ReplicatedStorage.Modules.Data.ClassData)
local PerkData  = require(game.ReplicatedStorage.Modules.Data.PerkData)
local ProgressionRemotes = require(game.ReplicatedStorage.Modules.Remotes.ProgressionRemotes)

-- ===== CONSTANTS =====
local BG_COLOR       = Color3.fromRGB(18, 18, 22)
local PANEL_COLOR    = Color3.fromRGB(28, 28, 34)
local ACCENT_COLOR   = Color3.fromRGB(120, 80, 220)
local TEXT_COLOR     = Color3.fromRGB(220, 215, 230)
local DIM_COLOR      = Color3.fromRGB(130, 125, 140)
local SUCCESS_COLOR  = Color3.fromRGB(80, 200, 120)
local DANGER_COLOR   = Color3.fromRGB(220, 80, 60)
local STAT_COLORS = {
	Strength     = Color3.fromRGB(220, 80, 60),
	Agility      = Color3.fromRGB(100, 200, 120),
	Endurance    = Color3.fromRGB(80, 140, 220),
	Dexterity    = Color3.fromRGB(200, 160, 60),
	Intelligence = Color3.fromRGB(160, 80, 220),
	Faith        = Color3.fromRGB(240, 210, 80),
}

-- ===== STATE =====
local playerData = nil
local activeTab  = "Stats"
local isOpen     = false

-- ===== UI BUILD =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ProgressionUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(0, 640, 0, 480)
mainFrame.Position        = UDim2.new(0.5, -320, 0.5, -240)
mainFrame.BackgroundColor3 = BG_COLOR
mainFrame.BorderSizePixel = 0
mainFrame.Visible         = false
mainFrame.Parent          = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size              = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3  = PANEL_COLOR
titleBar.BorderSizePixel   = 0
titleBar.Parent            = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size              = UDim2.new(0.7, 0, 1, 0)
titleLabel.Position          = UDim2.new(0.05, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "PROGRESSION"
titleLabel.TextColor3        = TEXT_COLOR
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 16
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.Parent            = titleBar

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name             = "PointsLabel"
pointsLabel.Size             = UDim2.new(0.3, -10, 1, 0)
pointsLabel.Position         = UDim2.new(0.7, 0, 0, 0)
pointsLabel.BackgroundTransparency = 1
pointsLabel.Text             = "Points: 0"
pointsLabel.TextColor3       = ACCENT_COLOR
pointsLabel.Font             = Enum.Font.GothamBold
pointsLabel.TextSize         = 14
pointsLabel.TextXAlignment   = Enum.TextXAlignment.Right
pointsLabel.Parent           = titleBar

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size              = UDim2.new(1, 0, 0, 36)
tabBar.Position          = UDim2.new(0, 0, 0, 44)
tabBar.BackgroundColor3  = PANEL_COLOR
tabBar.BorderSizePixel   = 0
tabBar.Parent            = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection   = Enum.FillDirection.Horizontal
tabLayout.Padding         = UDim.new(0, 2)
tabLayout.Parent          = tabBar

-- Content area
local contentArea = Instance.new("Frame")
contentArea.Name             = "ContentArea"
contentArea.Size             = UDim2.new(1, 0, 1, -80)
contentArea.Position         = UDim2.new(0, 0, 0, 80)
contentArea.BackgroundTransparency = 1
contentArea.Parent           = mainFrame

-- ===== HELPER FUNCTIONS =====
local function makeLabel(text, size, position, parent, color, font, align)
	local l = Instance.new("TextLabel")
	l.Size = size or UDim2.new(1, 0, 0, 20)
	l.Position = position or UDim2.new(0, 0, 0, 0)
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = color or TEXT_COLOR
	l.Font = font or Enum.Font.Gotham
	l.TextSize = 13
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function makeButton(text, size, position, parent, color)
	local b = Instance.new("TextButton")
	b.Size = size or UDim2.new(0, 80, 0, 28)
	b.Position = position or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = color or ACCENT_COLOR
	b.BorderSizePixel = 0
	b.Text = text or ""
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local function makeScrollFrame(size, position, parent)
	local sf = Instance.new("ScrollingFrame")
	sf.Size = size
	sf.Position = position or UDim2.new(0, 0, 0, 0)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 4
	sf.ScrollBarImageColor3 = ACCENT_COLOR
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.Parent = parent
	return sf
end

local function flash(label, text, color)
	label.Text = text
	label.TextColor3 = color
	task.delay(2, function()
		if label and label.Parent then
			label.Text = ""
		end
	end)
end

-- ===== TAB CREATION =====
local tabFrames = {}
local tabButtons = {}
local statusLabel -- shared status message label at bottom

local function makeTab(name)
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(0, 200, 1, 0)
	btn.BackgroundColor3 = PANEL_COLOR
	btn.BorderSizePixel  = 0
	btn.Text             = name
	btn.TextColor3       = DIM_COLOR
	btn.Font             = Enum.Font.GothamBold
	btn.TextSize         = 14
	btn.Parent           = tabBar
	tabButtons[name]     = btn

	local frame = Instance.new("Frame")
	frame.Size               = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Visible            = false
	frame.Parent             = contentArea
	tabFrames[name]          = frame

	btn.MouseButton1Click:Connect(function()
		activeTab = name
		refreshAll()
	end)
end

makeTab("Stats")
makeTab("Classes")
makeTab("Perks")

-- Status label at bottom of main frame
statusLabel = Instance.new("TextLabel")
statusLabel.Size             = UDim2.new(0.9, 0, 0, 20)
statusLabel.Position         = UDim2.new(0.05, 0, 1, -28)
statusLabel.BackgroundTransparency = 1
statusLabel.Text             = ""
statusLabel.TextColor3       = SUCCESS_COLOR
statusLabel.Font             = Enum.Font.Gotham
statusLabel.TextSize         = 12
statusLabel.TextXAlignment   = Enum.TextXAlignment.Center
statusLabel.Parent           = mainFrame

-- ===== STATS TAB =====
local function buildStatsTab()
	local frame = tabFrames["Stats"]
	for _, c in ipairs(frame:GetChildren()) do c:Destroy() end
	if not playerData then return end

	local scroll = makeScrollFrame(UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), frame)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent  = scroll

	local statNames = StatData:GetAllStatNames()
	for _, statName in ipairs(statNames) do
		local statDef    = StatData:GetStat(statName)
		local currentVal = (playerData.Stats and playerData.Stats[statName]) or 0
		local color      = STAT_COLORS[statName] or TEXT_COLOR

		local row = Instance.new("Frame")
		row.Size             = UDim2.new(1, -10, 0, 56)
		row.BackgroundColor3 = PANEL_COLOR
		row.BorderSizePixel  = 0
		row.Parent           = scroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		-- Colored left bar
		local bar = Instance.new("Frame")
		bar.Size             = UDim2.new(0, 4, 0.7, 0)
		bar.Position         = UDim2.new(0, 8, 0.15, 0)
		bar.BackgroundColor3 = color
		bar.BorderSizePixel  = 0
		bar.Parent           = row
		Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

		-- Stat name + abbrev
		local nameLabel = makeLabel(
			statDef.Abbreviation .. "  " .. statDef.DisplayName,
			UDim2.new(0.35, 0, 0.5, 0),
			UDim2.new(0.03, 16, 0, 4),
			row, color, Enum.Font.GothamBold
		)

		-- Description
		makeLabel(
			statDef.Description,
			UDim2.new(0.55, 0, 0.4, 0),
			UDim2.new(0.03, 16, 0.5, 2),
			row, DIM_COLOR
		).TextSize = 11

		-- Current value
		makeLabel(
			tostring(currentVal),
			UDim2.new(0.1, 0, 1, 0),
			UDim2.new(0.7, 0, 0, 0),
			row, TEXT_COLOR, Enum.Font.GothamBold, Enum.TextXAlignment.Center
		).TextSize = 20

		-- Spend button
		local spendBtn = makeButton("+", UDim2.new(0, 32, 0, 32), UDim2.new(0.85, 0, 0.5, -16), row, ACCENT_COLOR)
		spendBtn.MouseButton1Click:Connect(function()
			if not playerData or playerData.AvailablePoints <= 0 then
				flash(statusLabel, "No points available!", DANGER_COLOR)
				return
			end
			local result = ProgressionRemotes.SpendStatPoint:InvokeServer(statName)
			if result.success then
				flash(statusLabel, "+" .. statName .. "!", SUCCESS_COLOR)
			else
				flash(statusLabel, result.reason or "Failed", DANGER_COLOR)
			end
		end)
	end
end

-- ===== CLASSES TAB =====
local function buildClassesTab()
	local frame = tabFrames["Classes"]
	for _, c in ipairs(frame:GetChildren()) do c:Destroy() end
	if not playerData then return end

	local scroll = makeScrollFrame(UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), frame)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent  = scroll

	-- Current class header
	local currentName = playerData.CurrentClass or "None"
	local headerFrame = Instance.new("Frame")
	headerFrame.Size             = UDim2.new(1, -10, 0, 40)
	headerFrame.BackgroundColor3 = PANEL_COLOR
	headerFrame.BorderSizePixel  = 0
	headerFrame.Parent           = scroll
	Instance.new("UICorner", headerFrame).CornerRadius = UDim.new(0, 8)
	makeLabel("Current Class: " .. currentName, UDim2.new(1, -20, 1, 0), UDim2.new(0, 10, 0, 0),
		headerFrame, ACCENT_COLOR, Enum.Font.GothamBold, Enum.TextXAlignment.Left)

	-- Tiers to display
	local tiers = { "Base", "Subclass", "Ascension", "TrueClass" }
	local tierLabels = { Base = "Base Classes", Subclass = "Subclasses", Ascension = "Ascensions", TrueClass = "True Classes" }

	for _, tier in ipairs(tiers) do
		local tierClasses = ClassData:GetClassesByTier(tier)
		if next(tierClasses) then
			-- Tier header
			local tierLabel = makeLabel(tierLabels[tier],
				UDim2.new(1, -10, 0, 24), UDim2.new(0, 0, 0, 0), scroll,
				DIM_COLOR, Enum.Font.GothamBold)
			tierLabel.TextSize = 12

			for className, classDef in pairs(tierClasses) do
				local isCurrentClass = playerData.CurrentClass == className
				local hasUnlocked = false
				for _, u in ipairs(playerData.UnlockedClasses or {}) do
					if u == className then hasUnlocked = true; break end
				end

				-- Check if requirements met (for coloring, not enforcement)
				local canUnlock = ClassData:CanUnlockClass(className, {
					CurrentClass        = playerData.CurrentClass,
					Stats               = playerData.Stats,
					TotalPointsSpent    = playerData.TotalPointsSpent,
					CompletedMilestones = playerData.CompletedMilestones,
				})

				local rowColor = isCurrentClass and Color3.fromRGB(40, 40, 60) or PANEL_COLOR
				local row = Instance.new("Frame")
				row.Size             = UDim2.new(1, -10, 0, 72)
				row.BackgroundColor3 = rowColor
				row.BorderSizePixel  = 0
				row.Parent           = scroll
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

				-- Left color bar (green if unlockable, grey if not)
				local barColor = canUnlock and SUCCESS_COLOR or DIM_COLOR
				if isCurrentClass then barColor = ACCENT_COLOR end
				local bar = Instance.new("Frame")
				bar.Size             = UDim2.new(0, 4, 0.7, 0)
				bar.Position         = UDim2.new(0, 8, 0.15, 0)
				bar.BackgroundColor3 = barColor
				bar.BorderSizePixel  = 0
				bar.Parent           = row
				Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

				makeLabel(classDef.DisplayName, UDim2.new(0.55, 0, 0, 22), UDim2.new(0.03, 18, 0, 6),
					row, TEXT_COLOR, Enum.Font.GothamBold)
				makeLabel(classDef.Description, UDim2.new(0.6, 0, 0, 18), UDim2.new(0.03, 18, 0, 28),
					row, DIM_COLOR).TextSize = 11

				-- Requirements text
				local reqParts = {}
				for statName, val in pairs(classDef.StatRequirements or {}) do
					local have = (playerData.Stats and playerData.Stats[statName]) or 0
					local met = have >= val
					table.insert(reqParts, (met and "✓" or "✗") .. " " .. statName .. " " .. val)
				end
				makeLabel(table.concat(reqParts, "  "), UDim2.new(0.6, 0, 0, 16), UDim2.new(0.03, 18, 0, 50),
					row, DIM_COLOR).TextSize = 10

				-- Unlock/Active button
				if isCurrentClass then
					makeButton("ACTIVE", UDim2.new(0, 70, 0, 28), UDim2.new(0.82, 0, 0.5, -14), row,
						Color3.fromRGB(40, 140, 80))
				elseif hasUnlocked then
					makeButton("OWNED", UDim2.new(0, 70, 0, 28), UDim2.new(0.82, 0, 0.5, -14), row,
						Color3.fromRGB(60, 60, 80))
				else
					local unlockBtn = makeButton("UNLOCK", UDim2.new(0, 70, 0, 28), UDim2.new(0.82, 0, 0.5, -14),
						row, canUnlock and ACCENT_COLOR or Color3.fromRGB(50, 50, 60))
					unlockBtn.MouseButton1Click:Connect(function()
						local result = ProgressionRemotes.UnlockClass:InvokeServer(className)
						if result.success then
							flash(statusLabel, "Unlocked " .. classDef.DisplayName .. "!", SUCCESS_COLOR)
						else
							flash(statusLabel, result.reason or "Cannot unlock", DANGER_COLOR)
						end
					end)
				end
			end
		end
	end
end

-- ===== PERKS TAB =====
local function buildPerksTab()
	local frame = tabFrames["Perks"]
	for _, c in ipairs(frame:GetChildren()) do c:Destroy() end
	if not playerData then return end

	local scroll = makeScrollFrame(UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), frame)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent  = scroll

	-- Pending perk pick banner
	if playerData.PendingPerkPick then
		local banner = Instance.new("Frame")
		banner.Size             = UDim2.new(1, -10, 0, 36)
		banner.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
		banner.BorderSizePixel  = 0
		banner.Parent           = scroll
		Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 8)
		makeLabel("⚡ PERK MILESTONE REACHED — Pick one below!", UDim2.new(1, -20, 1, 0),
			UDim2.new(0, 10, 0, 0), banner, Color3.fromRGB(240, 200, 80), Enum.Font.GothamBold,
			Enum.TextXAlignment.Center)
	end

	-- Owned perks header
	makeLabel("OWNED PERKS (" .. #(playerData.Perks or {}) .. ")",
	UDim2.new(1, -10, 0, 20), nil, scroll, DIM_COLOR, Enum.Font.GothamBold)

	if #(playerData.Perks or {}) == 0 then
		makeLabel("No perks yet — spend points to reach milestones.",
			UDim2.new(1, -10, 0, 20), nil, scroll, DIM_COLOR)
	else
		for _, perkName in ipairs(playerData.Perks) do
			local perkDef = PerkData:GetPerk(perkName)
			if perkDef then
				local rarityDef = PerkData.Rarity[perkDef.Rarity]
				local row = Instance.new("Frame")
				row.Size             = UDim2.new(1, -10, 0, 44)
				row.BackgroundColor3 = PANEL_COLOR
				row.BorderSizePixel  = 0
				row.Parent           = scroll
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

				local barColor = rarityDef and rarityDef.Color or DIM_COLOR
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(0, 4, 0.7, 0)
				bar.Position = UDim2.new(0, 8, 0.15, 0)
				bar.BackgroundColor3 = barColor
				bar.BorderSizePixel = 0
				bar.Parent = row
				Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

				makeLabel(perkDef.DisplayName, UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0.03, 18, 0, 4),
					row, TEXT_COLOR, Enum.Font.GothamBold)
				makeLabel(perkDef.Description, UDim2.new(0.65, 0, 0.45, 0), UDim2.new(0.03, 18, 0, 24),
					row, DIM_COLOR).TextSize = 11
				makeLabel(perkDef.Rarity, UDim2.new(0.15, 0, 0.5, 0), UDim2.new(0.84, 0, 0, 4),
					row, barColor, Enum.Font.GothamBold, Enum.TextXAlignment.Right).TextSize = 11
			end
		end
	end

	-- Offered perks (if pending pick)
	if playerData.PendingPerkPick then
		makeLabel("OFFERED PERKS — Choose 1",
			UDim2.new(1, -10, 0, 24), nil, scroll, Color3.fromRGB(240, 200, 80), Enum.Font.GothamBold)

		for _, perkName in ipairs(playerData.PendingPerkPick.Perks) do
			local perkDef = PerkData:GetPerk(perkName)
			if perkDef then
				local rarityDef = PerkData.Rarity[perkDef.Rarity]
				local row = Instance.new("Frame")
				row.Size             = UDim2.new(1, -10, 0, 56)
				row.BackgroundColor3 = Color3.fromRGB(35, 32, 50)
				row.BorderSizePixel  = 0
				row.Parent           = scroll
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

				local barColor = rarityDef and rarityDef.Color or DIM_COLOR
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(0, 4, 0.7, 0)
				bar.Position = UDim2.new(0, 8, 0.15, 0)
				bar.BackgroundColor3 = barColor
				bar.BorderSizePixel = 0
				bar.Parent = row
				Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

				makeLabel(perkDef.DisplayName, UDim2.new(0.55, 0, 0, 20), UDim2.new(0.03, 18, 0, 6),
					row, TEXT_COLOR, Enum.Font.GothamBold)
				makeLabel(perkDef.Description, UDim2.new(0.6, 0, 0, 18), UDim2.new(0.03, 18, 0, 26),
					row, DIM_COLOR).TextSize = 11
				makeLabel("[" .. perkDef.Rarity .. "]", UDim2.new(0.2, 0, 0, 20), UDim2.new(0.03, 18, 0, 44),
					row, barColor).TextSize = 10

				local pickBtn = makeButton("PICK", UDim2.new(0, 60, 0, 30), UDim2.new(0.86, 0, 0.5, -15),
					row, SUCCESS_COLOR)
				pickBtn.MouseButton1Click:Connect(function()
					local result = ProgressionRemotes.PickPerk:InvokeServer(perkName)
					if result.success then
						flash(statusLabel, "Picked " .. perkDef.DisplayName .. "!", SUCCESS_COLOR)
					else
						flash(statusLabel, result.reason or "Failed", DANGER_COLOR)
					end
				end)
			end
		end
	end
end

-- ===== REFRESH =====
function refreshAll()
	-- Update tab button colors
	for name, btn in pairs(tabButtons) do
		btn.TextColor3       = name == activeTab and TEXT_COLOR or DIM_COLOR
		btn.BackgroundColor3 = name == activeTab and BG_COLOR or PANEL_COLOR
	end

	for name, frame in pairs(tabFrames) do
		frame.Visible = name == activeTab
	end

	-- Update points label
	if playerData then
		pointsLabel.Text = "Points: " .. (playerData.AvailablePoints or 0)
	end

	-- Rebuild active tab content
	if activeTab == "Stats" then
		buildStatsTab()
	elseif activeTab == "Classes" then
		buildClassesTab()
	elseif activeTab == "Perks" then
		buildPerksTab()
	end
end

-- ===== TOGGLE =====
local function toggleUI()
	isOpen = not isOpen
	mainFrame.Visible = isOpen
	if isOpen then
		-- Fetch latest data
		local snapshot = ProgressionRemotes.RequestPlayerData:InvokeServer()
		if snapshot then
			playerData = snapshot
		end
		refreshAll()
	end
end

-- ===== REMOTE LISTENERS =====
ProgressionRemotes.PlayerDataUpdated.OnClientEvent:Connect(function(snapshot)
	playerData = snapshot
	if isOpen then refreshAll() end
end)

ProgressionRemotes.PerkMilestoneReady.OnClientEvent:Connect(function(offeredPerks)
	playerData = ProgressionRemotes.RequestPlayerData:InvokeServer()
	if not isOpen then
		toggleUI()
		activeTab = "Perks"
	else
		activeTab = "Perks"
	end
	refreshAll()
end)

-- ===== INPUT =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.P then
		toggleUI()
	end
end)

-- Initial data fetch
task.spawn(function()
	task.wait(1.5)
	local snapshot = ProgressionRemotes.RequestPlayerData:InvokeServer()
	if snapshot then
		playerData = snapshot
	end
end)