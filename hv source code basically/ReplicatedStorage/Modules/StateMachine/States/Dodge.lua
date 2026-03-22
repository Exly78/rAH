local State = require(script.Parent.Parent.State)
local TagManager = require(script.Parent.Parent.Parent.Managers.TagManager)
local CombatRemotes = require(game.ReplicatedStorage.Modules.Remotes.CombatRemotes)

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DodgeState = setmetatable({}, State)
DodgeState.__index = DodgeState

-- Dodge success config
local SPEED_BOOST_AMOUNT = 8
local SPEED_BOOST_DURATION = 0.75

function DodgeState.new()
	local self = State.new("Dodge", 8)
	self.DodgeDuration = 0.45
	self.Timer = 0
	self.DodgeMotion = nil
	self.AnimationTrack = nil
	self.DodgeDirection = nil
	self.CameraInfluence = 0.6
	self.WasSprinting = false
	self.DodgeSucceeded = false
	return setmetatable(self, DodgeState)
end

function DodgeState:OnEnter(payload)
	local owner = self:GetOwner()
	payload = payload or {}
	self.Timer = 0
	self.DodgeSucceeded = false

	self.WasSprinting = owner.MovementController and owner.MovementController.IsSprinting or false

	if owner.MovementController and owner.MovementController._sprintAnimPlaying then
		owner.MovementController:ForceStopSprintAnimation()
	elseif owner._sprintAnimPlaying and type(owner.ForceStopSprintAnimation) == "function" then
		owner:ForceStopSprintAnimation()
	end

	self.DodgeDirection = self:GetDodgeDirection(owner)
	if not self.DodgeDirection then
		owner.StateMachine:SetState("Idle")
		return
	end

	local humanoid = owner.Humanoid
	local state = humanoid:GetState()
	local isAirDash = (state == Enum.HumanoidStateType.Freefall)

	local animName = isAirDash and "AirDash" or ("Dash" .. self.DodgeDirection)

	print("[DodgeState] Dodging:", self.DodgeDirection, "Anim:", animName)

	local playingTracks = owner.AnimationManager:Play(animName, 0.05)

	if playingTracks and playingTracks[1] then
		self.AnimationTrack = playingTracks[1]
		self.AnimationTrack:AdjustSpeed(1.65)
	else
		warn("[DodgeState] Failed to play/find dodge animation:", animName)
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false

	owner:SetInvulnerable(true)

	TagManager.AddTag(owner.Character, "Invulnerable", self.DodgeDuration)
	TagManager.AddTag(owner.Character, "Dodging", self.DodgeDuration)

	CombatRemotes.DodgeStarted:FireServer(self.DodgeDuration)

	self.DodgeMotion = self:StartDodgeMotion(owner, self.DodgeDirection)
end

function DodgeState:GetDodgeDirection(owner)
	local humanoid = owner.Humanoid
	local state = humanoid:GetState()

	local forward = UIS:IsKeyDown(Enum.KeyCode.W)
	local backward = UIS:IsKeyDown(Enum.KeyCode.S)
	local left = UIS:IsKeyDown(Enum.KeyCode.A)
	local right = UIS:IsKeyDown(Enum.KeyCode.D)

	if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
		if forward and left then return "ForwardLeft"
		elseif forward and right then return "ForwardRight"
		elseif backward and left then return "BackwardLeft"
		elseif backward and right then return "BackwardRight"
		elseif forward then return "Forward"
		elseif backward then return "Backward"
		elseif left then return "Left"
		elseif right then return "Right"
		else return "Backward" end
	end

	if state == Enum.HumanoidStateType.Freefall then
		return "Forward"
	end

	return nil
end

function DodgeState:StartDodgeMotion(owner, direction)
	local rootPart = owner.RootPart
	local humanoid = owner.Humanoid
	local state = humanoid:GetState()
	local cam = Workspace.CurrentCamera

	local dashDir
	local isAirDash = (state == Enum.HumanoidStateType.Freefall)

	if isAirDash then
		dashDir = cam.CFrame.LookVector
	else
		local camLook = cam.CFrame.LookVector
		local camRight = cam.CFrame.RightVector
		local camForward = Vector3.new(camLook.X, 0, camLook.Z).Unit
		local camRightFlat = Vector3.new(camRight.X, 0, camRight.Z).Unit

		local inputDir
		if direction == "Forward" then inputDir = camForward
		elseif direction == "Backward" then inputDir = -camForward
		elseif direction == "Left" then inputDir = -camRightFlat
		elseif direction == "Right" then inputDir = camRightFlat
		elseif direction == "ForwardLeft" then inputDir = (camForward - camRightFlat).Unit
		elseif direction == "ForwardRight" then inputDir = (camForward + camRightFlat).Unit
		elseif direction == "BackwardLeft" then inputDir = (-camForward - camRightFlat).Unit
		elseif direction == "BackwardRight" then inputDir = (-camForward + camRightFlat).Unit
		else inputDir = camForward end

		local charForward = rootPart.CFrame.LookVector
		local charRight = rootPart.CFrame.RightVector

		local charRelativeDir
		if direction == "Forward" then charRelativeDir = charForward
		elseif direction == "Backward" then charRelativeDir = -charForward
		elseif direction == "Left" then charRelativeDir = -charRight
		elseif direction == "Right" then charRelativeDir = charRight
		elseif direction == "ForwardLeft" then charRelativeDir = (charForward - charRight).Unit
		elseif direction == "ForwardRight" then charRelativeDir = (charForward + charRight).Unit
		elseif direction == "BackwardLeft" then charRelativeDir = (-charForward - charRight).Unit
		elseif direction == "BackwardRight" then charRelativeDir = (-charForward + charRight).Unit
		else charRelativeDir = charForward end

		dashDir = (inputDir * self.CameraInfluence + charRelativeDir * (1 - self.CameraInfluence)).Unit
	end

	if not dashDir or dashDir.Magnitude == 0 then
		dashDir = Vector3.new(0, 0, -1)
	end
	dashDir = dashDir.Unit

	local groundDuration = self.DodgeDuration      
	local airDuration    = 0.22                    
	local duration       = isAirDash and airDuration or groundDuration

	local groundSpeed = 40
	local airSpeed    = 70
	local dashSpeed   = isAirDash and airSpeed or groundSpeed

	local startVel = rootPart.AssemblyLinearVelocity
	local startY   = startVel.Y
	local dashVelocity = dashDir * dashSpeed

	local startTime = tick()
	local connection

	connection = RunService.RenderStepped:Connect(function(dt)
		local elapsed = tick() - startTime
		if elapsed >= duration then
			connection:Disconnect()
			if isAirDash then
				local kept = dashVelocity * 0.4
				local current = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(kept.X, current.Y, kept.Z)
			else
				local current = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(0, current.Y, 0)
			end
			return
		end

		if isAirDash then
			local pos = rootPart.Position
			rootPart.CFrame = CFrame.lookAt(pos, pos + dashDir)
		end

		rootPart.AssemblyLinearVelocity = Vector3.new(dashVelocity.X, startY, dashVelocity.Z)
	end)

	return connection
end

function DodgeState:Update(dt)
	self.Timer += dt
	if self.Timer >= self.DodgeDuration and not self.DodgeSucceeded then
		self:ExitDodge()
	end
end

-- ===== PERFECT DODGE =====
-- Called by CombatController when server confirms an attack was dodged.
-- Cancels the roll early, plays spin anim, gives speed boost.
function DodgeState:OnDodgeSuccess()
	if self.DodgeSucceeded then return end  -- Only trigger once per dodge
	self.DodgeSucceeded = true

	local owner = self:GetOwner()
	print("[DodgeState] PERFECT DODGE!")

	-- Kill the dash motion immediately
	if self.DodgeMotion then
		self.DodgeMotion:Disconnect()
		self.DodgeMotion = nil
	end

	-- Stop residual velocity
	local current = owner.RootPart.AssemblyLinearVelocity
	owner.RootPart.AssemblyLinearVelocity = Vector3.new(0, current.Y, 0)

	-- Cancel dash animation, play spin
	owner.AnimationManager:StopAll(0.05, false)
	owner.AnimationManager:Play("Spin", 0.05)

	-- Restore movement immediately
	owner:SetInvulnerable(false)
	owner.Character:SetAttribute("DodgeFrames", false)
	owner.Humanoid.AutoRotate = true
	owner.Humanoid.JumpHeight = 7.2

	-- Speed boost
	local isEquipped = owner.Character:GetAttribute("IsEquipped")
	local baseSpeed = isEquipped and 14 or 16
	owner.Humanoid.WalkSpeed = baseSpeed + SPEED_BOOST_AMOUNT

	-- Remove speed boost after duration
	task.delay(SPEED_BOOST_DURATION, function()
		if owner and owner.Humanoid then
			local equippedNow = owner.Character:GetAttribute("IsEquipped")
			local currentBase = equippedNow and 14 or 16
			-- Only reset if we haven't entered another state that changed speed
			if owner.Humanoid.WalkSpeed == currentBase + SPEED_BOOST_AMOUNT then
				local sprinting = owner.MovementController and owner.MovementController.IsSprinting
				owner.Humanoid.WalkSpeed = sprinting and 26 or currentBase
			end
		end
	end)

	-- Exit to Idle
	owner.StateMachine:SetState("Idle")
end

function DodgeState:ExitDodge()
	local owner = self:GetOwner()

	owner:SetInvulnerable(false)
	owner.Character:SetAttribute("DodgeFrames", false)
	owner.Humanoid.AutoRotate = true
	owner.Humanoid.JumpHeight = 7.2

	if self.DodgeMotion then
		self.DodgeMotion:Disconnect()
		self.DodgeMotion = nil
	end
	if self.WasSprinting and owner.MovementController then
		owner.MovementController:TryResumeSprint()
	end

	owner.StateMachine:SetState("Idle")
end

function DodgeState:OnExit()
	local owner = self:GetOwner()

	if self.DodgeMotion then
		self.DodgeMotion:Disconnect()
		self.DodgeMotion = nil
	end

	owner:SetInvulnerable(false)
	owner.Character:SetAttribute("DodgeFrames", false)
	owner.Humanoid.AutoRotate = true
	owner.Humanoid.JumpHeight = 7.2
end

function DodgeState:CanTransitionTo(nextStateName)
	return nextStateName == "Hitstun" 
		or nextStateName == "KnockedOut" 
		or nextStateName == "Idle"
end

return DodgeState
