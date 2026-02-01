local TagManager = {}
TagManager.__index = TagManager

local characterTags = {}

local onTagAddedCallbacks = {}
local onTagRemovedCallbacks = {}

local function cleanupExpiredTags(character)
	local tags = characterTags[character]
	if not tags then return end

	local currentTime = tick()
	for tagName, tagData in pairs(tags) do
		if tagData.expiryTime and currentTime >= tagData.expiryTime then
			tags[tagName] = nil
			for _, callback in ipairs(onTagRemovedCallbacks) do
				task.spawn(callback, character, tagName)
			end
		end
	end
end

function TagManager.Initialize(character)
	if not character then
		warn("TagManager: Cannot initialize nil character")
		return
	end

	if not characterTags[character] then
		characterTags[character] = {}
	end

	if character:IsA("Model") then
		character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				TagManager.Cleanup(character)
			end
		end)
	end
end

function TagManager.AddTag(character, tagName, duration)
	if not character or not tagName then
		warn("TagManager: Invalid character or tag name")
		return
	end

	if not characterTags[character] then
		TagManager.Initialize(character)
	end

	local tags = characterTags[character]
	local currentTime = tick()
	local wasRefreshed = tags[tagName] ~= nil

	tags[tagName] = {
		addedTime = currentTime,
		expiryTime = duration and (currentTime + duration) or nil,
		duration = duration
	}

	if not wasRefreshed then
		for _, callback in ipairs(onTagAddedCallbacks) do
			task.spawn(callback, character, tagName, duration)
		end
	end

	if duration then
		task.delay(duration, function()
			if characterTags[character] and characterTags[character][tagName] then
				local tagData = characterTags[character][tagName]
				if tagData.addedTime == currentTime then
					TagManager.RemoveTag(character, tagName)
				end
			end
		end)
	end
end

function TagManager.RemoveTag(character, tagName)
	if not character or not tagName then return end

	local tags = characterTags[character]
	if not tags or not tags[tagName] then return end

	tags[tagName] = nil

	for _, callback in ipairs(onTagRemovedCallbacks) do
		task.spawn(callback, character, tagName)
	end
end

function TagManager.HasTag(character, tagName)
	if not character or not tagName then return false end
	local tags = characterTags[character]
	if not tags then return false end
	cleanupExpiredTags(character)
	return tags[tagName] ~= nil
end

function TagManager.GetTags(character)
	if not character then return {} end

	cleanupExpiredTags(character)

	local tags = characterTags[character]
	if not tags then return {} end

	local activeTags = {}
	for tagName, _ in pairs(tags) do
		table.insert(activeTags, tagName)
	end

	return activeTags
end

function TagManager.GetTagTimeRemaining(character, tagName)
	if not character or not tagName then return nil end

	local tags = characterTags[character]
	if not tags or not tags[tagName] then return nil end

	local tagData = tags[tagName]
	if not tagData.expiryTime then return nil end

	local remaining = tagData.expiryTime - tick()
	return remaining > 0 and remaining or 0
end

function TagManager.ClearAllTags(character)
	if not character then return end

	local tags = characterTags[character]
	if not tags then return end

	for tagName, _ in pairs(tags) do
		for _, callback in ipairs(onTagRemovedCallbacks) do
			task.spawn(callback, character, tagName)
		end
	end

	characterTags[character] = {}
end

function TagManager.Cleanup(character)
	if not character then return end

	TagManager.ClearAllTags(character)
	characterTags[character] = nil
end

function TagManager.OnTagAdded(callback)
	if type(callback) ~= "function" then
		warn("TagManager: OnTagAdded requires a function")
		return
	end

	table.insert(onTagAddedCallbacks, callback)
end

function TagManager.OnTagRemoved(callback)
	if type(callback) ~= "function" then
		warn("TagManager: OnTagRemoved requires a function")
		return
	end

	table.insert(onTagRemovedCallbacks, callback)
end

return TagManager


--[[
EXAMPLE USAGE:

-- In a LocalScript or Script:
local TagManager = require(path.to.TagManager)

-- Initialize callbacks (optional)
TagManager.OnTagAdded(function(character, tagName, duration)
	print(character.Name .. " received tag: " .. tagName)
end)

TagManager.OnTagRemoved(function(character, tagName)
	print(character.Name .. " lost tag: " .. tagName)
end)

-- In your CharacterController or combat system:
local function applyHitstun(character)
	TagManager.AddTag(character, "Hitstunned", 0.8)
end

-- In your movement logic:
local function updateMovement(character, moveDirection)
	-- Check if character can move
	if TagManager.HasTag(character, "Hitstunned") then
		-- Character is stunned, prevent movement
		return
	end
	
	if TagManager.HasTag(character, "Slowed") then
		-- Apply slow effect
		moveDirection = moveDirection * 0.5
	end
	
	-- Apply movement...
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:Move(moveDirection)
	end
end

-- Example: Apply hitstun when hit
local function onCharacterHit(character, damage)
	-- Deal damage
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
	end
	
	-- Apply hitstun
	applyHitstun(character)
end

-- Example: Check tag time remaining
local function checkStunDuration(character)
	local remaining = TagManager.GetTagTimeRemaining(character, "Hitstunned")
	if remaining then
		print("Stun ends in " .. remaining .. " seconds")
	end
end

-- Example: Multiple tags with different durations
TagManager.AddTag(character, "Burning", 5)      -- Burns for 5 seconds
TagManager.AddTag(character, "Slowed", 3)       -- Slowed for 3 seconds
TagManager.AddTag(character, "Poisoned", 10)    -- Poisoned for 10 seconds

-- Check all active tags
local activeTags = TagManager.GetTags(character)
for _, tag in ipairs(activeTags) do
	print("Active tag: " .. tag)
end

-- Refresh a tag by adding it again
TagManager.AddTag(character, "Hitstunned", 0.8)  -- First application
task.wait(0.4)
TagManager.AddTag(character, "Hitstunned", 0.8)  -- Refreshes duration back to 0.8s

-- Manual tag removal
TagManager.RemoveTag(character, "Burning")

-- Clear all tags
TagManager.ClearAllTags(character)
]]