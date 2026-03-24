--ReplicatedStorage.Modules.StateMachine.States.Block

local State = require(script.Parent.Parent.State)
local TagManager = require(game.ReplicatedStorage.Modules.Managers.TagManager)
local CombatRemotes = require(game.ReplicatedStorage.Modules.Remotes.CombatRemotes)

local BlockState = setmetatable({}, State)
BlockState.__index = BlockState

-- Config
local PARRY_WINDOW = 0.20  -- First 0.2 seconds = parry frames
local BLOCK_STAMINA_DRAIN = 5
local PARRY_SLOWDOWN = 0.3
local BLOCK_SLOWDOWN = 0.5

function BlockState.new()
	local self = State.new("Block", 6)
	self.Timer = 0
	self.IsParryWindow = false
	self.IsBlocking = false
	self.HoldingBlock = false
	self.ParryStartupFinished = false
	self.AnimationConnection = nil
	self.ParrySucceeded = false
	self._parrySuccessConn = nil
	return setmetatable(self, BlockState)
end

function BlockState:OnEnter(payload)
	local owner = self:GetOwner()
	payload = payload or {}

	self.Timer = 0
	self.IsParryWindow = true
	self.IsBlocking = false
	self.HoldingBlock = payload.holding or false
	self.ParryStartupFinished = false
	self.ParrySucceeded = false

	-- Stop sprint animation if active
	if owner.MovementController and owner.MovementController._sprintAnimPlaying then
		owner.MovementController:ForceStopSprintAnimation()
	end

	-- Set parry state using TAGS (client-side for local feedback)
	TagManager.AddTag(owner.Character, "CanParry", PARRY_WINDOW)
	TagManager.AddTag(owner.Character, "Parrying", PARRY_WINDOW)

	-- Notify server to set server-side parry tags
	CombatRemotes.BlockStarted:FireServer(PARRY_WINDOW)

	local character = owner.Character
	self._parrySuccessConn = CombatRemotes.ParrySuccess.OnClientEvent:Connect(function(target)
		if target ~= character then return end
		self:OnParrySuccess()
	end)

	-- Slow movement during parry
	owner.Humanoid.WalkSpeed = owner.Humanoid.WalkSpeed * PARRY_SLOWDOWN

	-- Play parry startup animation
	local playingTracks = owner.AnimationManager:Play(self:GetBlockAnimationName(owner, "ParryStart"), 0.1)

	-- Connect to animation finished event
	if playingTracks and playingTracks[1] then
		local track = playingTracks[1]
		self.AnimationConnection = track.Stopped:Connect(function()
			self.ParryStartupFinished = true
		end)
	else
		task.delay(PARRY_WINDOW, function()
			self.ParryStartupFinished = true
		end)
	end

end

function BlockState:Update(dt)
	local owner = self:GetOwner()
	self.Timer = self.Timer + dt

	-- If parry succeeded, don't process normal logic (we're playing parry anim then exiting)
	if self.ParrySucceeded then return end

	-- ===== PARRY WINDOW (0 - 0.2s or until animation finishes) =====
	if self.IsParryWindow then
		if self.Timer >= PARRY_WINDOW and self.ParryStartupFinished then
			self.IsParryWindow = false
			owner.Character:SetAttribute("CanParry", false)

			if self.HoldingBlock then
				self:EnterBlockState(owner)
			else
					CombatRemotes.BlockEnded:FireServer()
				owner.StateMachine:SetState("Idle")
				return
			end
		elseif not self.HoldingBlock and self.ParryStartupFinished then
				CombatRemotes.BlockEnded:FireServer()
			owner.StateMachine:SetState("Idle")
			return
		end

		-- ===== BLOCKING STATE (after parry window) =====
	elseif self.IsBlocking then
		if not self.HoldingBlock then
				CombatRemotes.BlockEnded:FireServer()
			owner.StateMachine:SetState("Idle")
			return
		end
	end
end

function BlockState:EnterBlockState(owner)
	self.IsBlocking = true

	TagManager.AddTag(owner.Character, "IsBlocking", nil)
	TagManager.AddTag(owner.Character, "Blocking", nil)

	-- Adjust movement speed for blocking
	owner.Humanoid.WalkSpeed = owner.Humanoid.WalkSpeed / PARRY_SLOWDOWN * BLOCK_SLOWDOWN

	-- Play blocking animation
	owner.AnimationManager:Stop(self:GetBlockAnimationName(owner, "ParryStart"), 0.1)
	owner.AnimationManager:Play(self:GetBlockAnimationName(owner, "Block"), 0.1, false)

end

-- ===== PARRY SUCCESS =====
-- Called by CombatController when server confirms we parried an attack.
-- Plays trueparry1 or trueparry2, then exits to Idle after a brief window.
function BlockState:OnParrySuccess()
	if self.ParrySucceeded then return end  -- Only trigger once
	self.ParrySucceeded = true

	local owner = self:GetOwner()

	-- Stop the parrystart animation
	owner.AnimationManager:Stop(self:GetBlockAnimationName(owner, "ParryStart"), 0.05)

	-- Play random parry success animation
	local parryAnim = math.random(1, 2) == 1 and "Parry1" or "Parry2"
	owner.AnimationManager:Play(self:GetBlockAnimationName(owner, parryAnim), 0.05)

	-- Clear parry/block tags (parry is done)
	TagManager.RemoveTag(owner.Character, "CanParry")
	TagManager.RemoveTag(owner.Character, "Parrying")

	-- Restore speed immediately
	local isEquipped = owner.Character:GetAttribute("IsEquipped")
	local baseSpeed = isEquipped and 14 or 16
	owner.Humanoid.WalkSpeed = baseSpeed

	-- Exit to Idle after parry animation plays briefly
	task.delay(0.3, function()
		if owner.StateMachine:IsInState("Block") and self.ParrySucceeded then
			CombatRemotes.BlockEnded:FireServer()
			owner.StateMachine:SetState("Idle")
		end
	end)
end

function BlockState:OnBlockHit()
	local owner = self:GetOwner()
end

function BlockState:OnExit()
	local owner = self:GetOwner()

	if self._parrySuccessConn then
		self._parrySuccessConn:Disconnect()
		self._parrySuccessConn = nil
	end

	if self.AnimationConnection then
		self.AnimationConnection:Disconnect()
		self.AnimationConnection = nil
	end

	-- Always tell the server to clear block state, regardless of how we exited
	-- (normal release fires BlockEnded in Update; hitstun/forced transitions do not)
	CombatRemotes.BlockEnded:FireServer()

	-- Remove all blocking/parry TAGS
	TagManager.RemoveTag(owner.Character, "CanParry")
	TagManager.RemoveTag(owner.Character, "Parrying")
	TagManager.RemoveTag(owner.Character, "IsBlocking")
	TagManager.RemoveTag(owner.Character, "Blocking")

	-- Restore normal movement speed
	local isEquipped = owner.Character:GetAttribute("IsEquipped")
	local baseSpeed = isEquipped and 14 or 16
	owner.Humanoid.WalkSpeed = baseSpeed

	-- Stop all block animations
	owner.AnimationManager:Stop(self:GetBlockAnimationName(owner, "ParryStart"), 0.1)
	owner.AnimationManager:Stop(self:GetBlockAnimationName(owner, "Block"), 0.1)
	owner.AnimationManager:Stop(self:GetBlockAnimationName(owner, "Parry1"), 0.1)
	owner.AnimationManager:Stop(self:GetBlockAnimationName(owner, "Parry2"), 0.1)
	owner.AnimationManager:Stop(self:GetBlockAnimationName(owner, "Parried"), 0.1)

	self.ParryStartupFinished = false
	self.ParrySucceeded = false

end

function BlockState:GetBlockAnimationName(owner, animType)
	local weapon = owner:GetCurrentWeapon()
	if weapon and owner.Character:GetAttribute("IsEquipped") then
		return weapon .. "_" .. animType
	else
		return animType
	end
end

function BlockState:CanTransitionTo(nextStateName)
	return nextStateName == "Hitstun" 
		or nextStateName == "KnockedOut"
		or nextStateName == "Idle"
end

function BlockState:SetHolding(holding)
	self.HoldingBlock = holding
end

return BlockState
