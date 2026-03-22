-- ServerScriptService.Services.PlayerDataService
-- Owns all persistent player data.
-- Saves to DataStore on leave, loads on join.
-- All other systems read/write through here — never touch DataStore directly.

local Players       = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local StatData   = require(game.ReplicatedStorage.Modules.Data.StatData)
local PerkData   = require(game.ReplicatedStorage.Modules.Data.PerkData)

local DATASTORE_KEY_PREFIX = "HollowVeil_v1_"
local SAVE_RETRY_ATTEMPTS  = 3
local SAVE_RETRY_DELAY     = 2

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

-- In-memory cache: [userId] = playerData table
local _store  = {}
-- DataStore instance
local _ds

pcall(function()
	_ds = DataStoreService:GetDataStore("PlayerProgression_v1")
end)

-- ===== DEFAULT DATA =====
local function defaultData()
	return {
		-- Core stats (points invested per stat)
		Stats = {
			Strength     = 0,
			Agility      = 0,
			Endurance    = 0,
			Dexterity    = 0,
			Intelligence = 0,
			Faith        = 0,
		},

		-- Total investment points available to spend
		AvailablePoints   = 0,

		-- Total points ever spent (used for True Class gating)
		TotalPointsSpent  = 0,

		-- Class progression
		CurrentClass      = nil,    -- e.g. "Warrior"
		UnlockedClasses   = {},     -- list of all classes ever unlocked

		-- Perk state
		Perks             = {},     -- list of perkName strings currently held
		PerkMilestonesSeen = 0,     -- how many perk milestones have triggered
		PendingPerkPick   = nil,    -- offered perk names if a pick hasn't been made yet
		-- { perks = {"PerkA", "PerkB", ...} }

		-- Lives
		Lives             = 3,
		MaxLives          = 3,

		-- Progression flags
		CompletedMilestones = {},   -- { ["Complete the Trial of Iron"] = true }
		IsVeilTouched       = false,
		VeilRealmMinutes    = 0,

		-- Meta
		Level             = 1,
		Experience        = 0,
	}
end

-- ===== LOAD =====
local function loadFromStore(userId)
	if not _ds then return defaultData() end

	local key = DATASTORE_KEY_PREFIX .. tostring(userId)
	local success, result = pcall(function()
		return _ds:GetAsync(key)
	end)

	if success and result then
		-- Merge loaded data with defaults so new fields always exist
		local defaults = defaultData()
		for k, v in pairs(defaults) do
			if result[k] == nil then result[k] = v end
		end
		-- Ensure Stats sub-table has all keys
		for statName in pairs(defaults.Stats) do
			if result.Stats[statName] == nil then result.Stats[statName] = 0 end
		end
		print("[PlayerDataService] Loaded data for userId:", userId)
		return result
	else
		if not success then
			warn("[PlayerDataService] Failed to load for", userId, ":", result)
		end
		print("[PlayerDataService] Using default data for:", userId)
		return defaultData()
	end
end

-- ===== SAVE =====
local function saveToStore(userId, data)
	if not _ds then return end

	local key = DATASTORE_KEY_PREFIX .. tostring(userId)
	for attempt = 1, SAVE_RETRY_ATTEMPTS do
		local success, err = pcall(function()
			_ds:SetAsync(key, data)
		end)
		if success then
			print("[PlayerDataService] Saved data for:", userId)
			return true
		else
			warn("[PlayerDataService] Save attempt", attempt, "failed for", userId, ":", err)
			if attempt < SAVE_RETRY_ATTEMPTS then
				task.wait(SAVE_RETRY_DELAY)
			end
		end
	end
	warn("[PlayerDataService] All save attempts failed for:", userId)
	return false
end

-- ===== PUBLIC API =====

function PlayerDataService:GetData(player)
	return _store[player.UserId]
end

function PlayerDataService:SetData(player, data)
	_store[player.UserId] = data
end

-- Mutates a field and saves immediately
function PlayerDataService:UpdateData(player, updateFn)
	local data = _store[player.UserId]
	if not data then
		warn("[PlayerDataService] No data for player:", player.Name)
		return
	end
	updateFn(data)
	-- Async save — don't block
	task.spawn(saveToStore, player.UserId, data)
end

-- Returns a snapshot safe to send to client (no sensitive server-only fields needed)
function PlayerDataService:GetClientSnapshot(player)
	local data = _store[player.UserId]
	if not data then return nil end

	return {
		Stats               = data.Stats,
		AvailablePoints     = data.AvailablePoints,
		TotalPointsSpent    = data.TotalPointsSpent,
		CurrentClass        = data.CurrentClass,
		UnlockedClasses     = data.UnlockedClasses,
		Perks               = data.Perks,
		PendingPerkPick     = data.PendingPerkPick,
		Lives               = data.Lives,
		MaxLives            = data.MaxLives,
		Level               = data.Level,
		Experience          = data.Experience,
		CompletedMilestones = data.CompletedMilestones,
		IsVeilTouched       = data.IsVeilTouched,
	}
end

-- ===== LIFECYCLE =====

function PlayerDataService:OnPlayerAdded(player)
	local data = loadFromStore(player.UserId)
	_store[player.UserId] = data
	print("[PlayerDataService] Initialized data for:", player.Name)
end

function PlayerDataService:OnPlayerRemoving(player)
	local data = _store[player.UserId]
	if data then
		saveToStore(player.UserId, data)
	end
	_store[player.UserId] = nil
end

-- ===== INIT =====
function PlayerDataService:Init()
	Players.PlayerAdded:Connect(function(p) self:OnPlayerAdded(p) end)
	Players.PlayerRemoving:Connect(function(p) self:OnPlayerRemoving(p) end)

	-- Handle players already in-game if script loads late
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function() self:OnPlayerAdded(p) end)
	end

	-- Bind to Close event to save everyone on server shutdown
	game:BindToClose(function()
		for userId, data in pairs(_store) do
			saveToStore(userId, data)
		end
	end)

	print("[PlayerDataService] Ready")
end

return PlayerDataService
