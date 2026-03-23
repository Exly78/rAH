local AnimationManager = {}
AnimationManager.__index = AnimationManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local AnimationsFolder = Assets:WaitForChild("Animations")

local WEAPON_ANIMATION_PATHS = {
	Equip = {"equip", "equip2"},
	Unequip = {"unequip", "unequip2"},
	Attack1 = {"Attacking/swing1"},
	Attack2 = {"Attacking/swing2"},
	Attack3 = {"Attacking/swing3"},
	Attack4 = {"Attacking/swing4"},
	Attack5 = {"Attacking/swing5"},
	Block = {"Blocking/blocking"},
	ParryStart = {"Blocking/parrystart"},
	Parry1 = {"Blocking/trueparry1"},
	Parry2 = {"Blocking/trueparry2"},
	Parried = {"Blocking/parried"},
	Sprint = {"Sprint"},
	WeaponIdle = {"weaponidle"},
	Walk = {"Walk"},
	Critical    = {"Attacking/critical"},
	CriticalAlt = {"Attacking/criticalalt"},
	SlideAttack = {"Attacking/SlideAttack"},

}

local UNIVERSAL_ANIMATIONS = {
	Sprint = "Movement/Sprint",
	Spin = "Movement/Dash/Spin",
	DashForward = "Movement/Dash/DashForward",
	DashBackward = "Movement/Dash/DashBackward",
	DashForwardLeft = "Movement/Dash/DashForwardLeft",
	DashBackwardLeft = "Movement/Dash/DashBackwardLeft",
	DashForwardRight = "Movement/Dash/DashForwardRight",
	DashBackwardRight = "Movement/Dash/DashBackwardRight",
	DashLeft = "Movement/Dash/DashLeft",
	DashRight = "Movement/Dash/DashRight",
	AirDash = "Movement/Dash/AirDash",
	Slide = "Movement/Slide",
	Crouch = "Movement/Crouch",

}

local BASE_ANIMATIONS = {
	Idle = "Combat/Idle",
}

function AnimationManager.new(character)
	local self = setmetatable({}, AnimationManager)
	self.Character = character
	self.Humanoid = character:WaitForChild("Humanoid")
	self.Animator = self.Humanoid:WaitForChild("Animator")

	self.LoadedTracks = {}
	self.CurrentTracks = {}
	self._baseTrack = nil
	self._isDestroyed = false

	self._cleanupConnection = nil
	self:StartCleanup()

	self:PreloadAll()
	return self
end

function AnimationManager:StartCleanup()
	if self._cleanupConnection then 
		task.cancel(self._cleanupConnection)
		self._cleanupConnection = nil
	end

	self._cleanupConnection = task.spawn(function()
		while self.Character and self.Character.Parent do
			task.wait(0.5)
			if self._isDestroyed then break end
			self:CleanupStoppedTracks()
		end
	end)
end

function AnimationManager:CleanupStoppedTracks()
	for i = #self.CurrentTracks, 1, -1 do
		local track = self.CurrentTracks[i]
		if not track or not track.IsPlaying then
			table.remove(self.CurrentTracks, i)
		end
	end
end

function AnimationManager:_findAnimation(baseFolder, path)
	if not baseFolder then return nil end
	local parts = string.split(path, "/")
	local current = baseFolder
	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part)
		if not current then return nil end
	end
	if current:IsA("Animation") then return current end
	return current:FindFirstChildWhichIsA("Animation")
end

function AnimationManager:_loadTrack(animationObject)
	if not animationObject then return nil end
	local animId = animationObject.AnimationId
	if self.LoadedTracks[animId] and self.LoadedTracks[animId].IsPlaying == false then
		self.LoadedTracks[animId]:Stop(0)
	end

	if self.LoadedTracks[animId] then return self.LoadedTracks[animId] end

	local success, track = pcall(function()
		return self.Animator:LoadAnimation(animationObject)
	end)
	if success and track then
		self.LoadedTracks[animId] = track
		return track
	end
	return nil
end

function AnimationManager:_playTracks(animObjects, fadeTime, isBase, isAttack)
	fadeTime = fadeTime or 0.15
	local newTracks = {}

	if isAttack then
		for i = #self.CurrentTracks, 1, -1 do
			local track = self.CurrentTracks[i]
			if track and track ~= self._baseTrack then
				local baseName = track.Animation and track.Animation.Name or ""
				if baseName:match("swing") or baseName:match("Attack") or baseName:match("Dash") then
					track:Stop(0)
					table.remove(self.CurrentTracks, i)
				end
			end
		end
	end

	for i = #self.CurrentTracks, 1, -1 do
		local track = self.CurrentTracks[i]
		if track and track ~= self._baseTrack then
			local trackName = track.Animation and track.Animation.Name or ""

			local playingName = animObjects[1] and animObjects[1].Name or ""

			local shouldRemove = false

			if playingName:match("Sprint") and trackName:match("idle") then
				shouldRemove = true
			end

			if playingName:match("idle") and trackName:match("Sprint") then
				shouldRemove = true
			end

			if playingName:match("swing") or playingName:match("Attack") then
				if trackName:match("idle") or trackName:match("Sprint") then
					shouldRemove = true
				end
			end

			if playingName:match("equip") or playingName:match("unequip") then
				if trackName:match("idle") or trackName:match("Sprint") then
					shouldRemove = true
				end
			end

			if shouldRemove then
				track:Stop(fadeTime)
				table.remove(self.CurrentTracks, i)
			end
		end
	end

	for _, animObj in ipairs(animObjects) do
		local track = self:_loadTrack(animObj)
		if track then
			if isBase then
				self._baseTrack = track  
			end
			track:Play(fadeTime, 1, 1)
			table.insert(newTracks, track)
		end
	end

	for _, track in ipairs(newTracks) do
		if not table.find(self.CurrentTracks, track) then
			table.insert(self.CurrentTracks, track)
		end
	end

	if self._baseTrack and not table.find(self.CurrentTracks, self._baseTrack) then
		table.insert(self.CurrentTracks, self._baseTrack)
	end

	self:CleanupStoppedTracks()
	return newTracks
end

function AnimationManager:Play(animKey, fadeTime, isAttack)
	if self._isDestroyed then return false end
	local animsToPlay = {}

	local weaponName, action = string.match(animKey, "^(%w+)_(.+)$")
	if not weaponName then
		local animPath = BASE_ANIMATIONS[animKey] or UNIVERSAL_ANIMATIONS[animKey]
		if not animPath then return false end
		local anim = self:_findAnimation(AnimationsFolder, animPath)
		if anim then table.insert(animsToPlay, anim) end
	else
		local animPaths = WEAPON_ANIMATION_PATHS[action]
		if not animPaths then return false end
		local weaponFolder =
			AnimationsFolder:FindFirstChild("Combat")
			and AnimationsFolder.Combat:FindFirstChild("Weapons")
			and AnimationsFolder.Combat.Weapons:FindFirstChild(weaponName)

		if not weaponFolder then return false end
		for _, path in ipairs(animPaths) do
			local anim = self:_findAnimation(weaponFolder, path)
			if anim then table.insert(animsToPlay, anim) end
		end
	end

	if #animsToPlay == 0 then return false end

	local isBase = (action and action == "WeaponIdle") or false

	return self:_playTracks(animsToPlay, fadeTime, isBase, isAttack)
end

function AnimationManager:UpdateAnimate(animKey, animateScript, animateSlot)
	if self._isDestroyed then return false end
	if not animateScript or not animateSlot then return false end

	local foundAnim
	local weaponName, action = string.match(animKey, "^(%w+)_(.+)$")

	if not weaponName then
		local animPath = BASE_ANIMATIONS[animKey] or UNIVERSAL_ANIMATIONS[animKey]
		if not animPath then return false end
		foundAnim = self:_findAnimation(AnimationsFolder, animPath)
	else
		local paths = WEAPON_ANIMATION_PATHS[action]
		if not paths then return false end

		local weaponFolder =
			AnimationsFolder:FindFirstChild("Combat")
			and AnimationsFolder.Combat:FindFirstChild("Weapons")
			and AnimationsFolder.Combat.Weapons:FindFirstChild(weaponName)

		if not weaponFolder then return false end

		for _, path in ipairs(paths) do
			foundAnim = self:_findAnimation(weaponFolder, path)
			if foundAnim then break end
		end
	end

	if not foundAnim or not foundAnim.AnimationId or foundAnim.AnimationId == "" then
		warn("[AnimationManager] Invalid animation:", animKey)
		return false
	end

	local slotFolder = animateScript:FindFirstChild(animateSlot)
	if not slotFolder then
		warn("[AnimationManager] Animate slot not found:", animateSlot)
		return false
	end

	for _, obj in ipairs(slotFolder:GetChildren()) do
		if obj:IsA("Animation") then
			obj.AnimationId = foundAnim.AnimationId
			return true
		end
	end

	warn("[AnimationManager] No Animation in Animate slot:", animateSlot)
	return false
end

function AnimationManager:Stop(animKey, fadeTime)
	fadeTime = fadeTime or 0.1

	local weaponName, action = string.match(animKey, "^(%w+)_(.+)$")
	local targetAnimId = nil

	if not weaponName then
		local animPath = BASE_ANIMATIONS[animKey] or UNIVERSAL_ANIMATIONS[animKey]
		if animPath then
			local anim = self:_findAnimation(AnimationsFolder, animPath)
			if anim then
				targetAnimId = anim.AnimationId
			end
		end
	else
		local paths = WEAPON_ANIMATION_PATHS[action]
		if paths then
			local weaponFolder =
				AnimationsFolder:FindFirstChild("Combat")
				and AnimationsFolder.Combat:FindFirstChild("Weapons")
				and AnimationsFolder.Combat.Weapons:FindFirstChild(weaponName)

			if weaponFolder then
				for _, path in ipairs(paths) do
					local anim = self:_findAnimation(weaponFolder, path)
					if anim then
						targetAnimId = anim.AnimationId
						break
					end
				end
			end
		end
	end

	if not targetAnimId then return false end

	for i = #self.CurrentTracks, 1, -1 do
		local track = self.CurrentTracks[i]
		if track and track.Animation and track.Animation.AnimationId == targetAnimId then
			track:Stop(fadeTime)
			table.remove(self.CurrentTracks, i)
			-- If we just stopped the base track, clear the reference
			if track == self._baseTrack then
				self._baseTrack = nil
			end
			return true
		end
	end

	return false
end

function AnimationManager:StopAll(fadeTime, keepBase)
	fadeTime = fadeTime or 0.1
	keepBase = keepBase or false

	for i = #self.CurrentTracks, 1, -1 do
		local track = self.CurrentTracks[i]
		if track then
			if keepBase and track == self._baseTrack then
			else
				track:Stop(fadeTime)
				table.remove(self.CurrentTracks, i)
			end
		end
	end

end

function AnimationManager:StopAllIncludingBase(fadeTime)
	fadeTime = fadeTime or 0.1

	for i = #self.CurrentTracks, 1, -1 do
		local track = self.CurrentTracks[i]
		if track then
			track:Stop(fadeTime)
			table.remove(self.CurrentTracks, i)
		end
	end

	self._baseTrack = nil
end

function AnimationManager:OnKeyframe(keyframeName, callback)
	local tracks = self:GetAllTracks()

	if #tracks == 0 then
		warn("[AnimationManager] No tracks to connect keyframe listener")
		return
	end

	for _, track in ipairs(tracks) do
		local conn
		conn = track.KeyframeReached:Connect(function(kf)
			if kf == keyframeName then
				callback()
				if conn then conn:Disconnect() end
			end
		end)
	end
end

function AnimationManager:PreloadAll()
	if self._isDestroyed then return end

	local function preloadPaths(paths, folder)
		for _, path in pairs(paths) do
			local anim = self:_findAnimation(folder, path)
			if anim then self:_loadTrack(anim) end
		end
	end

	preloadPaths(BASE_ANIMATIONS, AnimationsFolder)
	preloadPaths(UNIVERSAL_ANIMATIONS, AnimationsFolder)

	local combatFolder = AnimationsFolder:FindFirstChild("Combat")
	local weaponsRoot = combatFolder and combatFolder:FindFirstChild("Weapons")
	if weaponsRoot then
		for _, weaponFolder in ipairs(weaponsRoot:GetChildren()) do
			if weaponFolder:IsA("Folder") then
				for _, paths in pairs(WEAPON_ANIMATION_PATHS) do
					for _, relPath in ipairs(paths) do
						local anim = self:_findAnimation(weaponFolder, relPath)
						if anim then self:_loadTrack(anim) end
					end
				end
			end
		end
	end

end

function AnimationManager:Destroy()
	if self._isDestroyed then return end
	self._isDestroyed = true

	if self._cleanupConnection then
		task.cancel(self._cleanupConnection)
		self._cleanupConnection = nil
	end

	for _, track in ipairs(self.CurrentTracks) do
		if track then track:Stop(0) end
	end
	table.clear(self.CurrentTracks)
	table.clear(self.LoadedTracks)
	self._baseTrack = nil
end

function AnimationManager:GetCurrentTrack()
	self:CleanupStoppedTracks()
	return self.CurrentTracks[1]
end

function AnimationManager:GetAllTracks()
	self:CleanupStoppedTracks()
	return self.CurrentTracks
end

function AnimationManager:IsPlaying()
	self:CleanupStoppedTracks()
	for _, track in ipairs(self.CurrentTracks) do
		if track and track.IsPlaying then return true end
	end
	return false
end

-- Check if a specific animation key is currently playing
function AnimationManager:IsKeyPlaying(animKey)
	if self._isDestroyed then return false end

	-- Resolve the animKey to animation object(s), same logic as Play()
	local targetIds = {}

	local weaponName, action = string.match(animKey, "^(%w+)_(.+)$")
	if not weaponName then
		local animPath = BASE_ANIMATIONS[animKey] or UNIVERSAL_ANIMATIONS[animKey]
		if animPath then
			local anim = self:_findAnimation(AnimationsFolder, animPath)
			if anim then targetIds[anim.AnimationId] = true end
		end
	else
		local animPaths = WEAPON_ANIMATION_PATHS[action]
		if animPaths then
			local weaponFolder =
				AnimationsFolder:FindFirstChild("Combat")
				and AnimationsFolder.Combat:FindFirstChild("Weapons")
				and AnimationsFolder.Combat.Weapons:FindFirstChild(weaponName)

			if weaponFolder then
				for _, path in ipairs(animPaths) do
					local anim = self:_findAnimation(weaponFolder, path)
					if anim then targetIds[anim.AnimationId] = true end
				end
			end
		end
	end

	if not next(targetIds) then return false end

	-- Check if any matching track is currently playing
	for _, track in ipairs(self.CurrentTracks) do
		if track and track.IsPlaying and track.Animation then
			if targetIds[track.Animation.AnimationId] then
				return true
			end
		end
	end

	return false
end

return AnimationManager
