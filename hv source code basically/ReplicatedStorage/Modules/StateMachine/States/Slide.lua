--ReplicatedStorage.Modules.StateMachine.States.Slide

local State = require(script.Parent.Parent.State)
local CombatRemotes = require(game.ReplicatedStorage.Modules.Remotes.CombatRemotes)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SlideState = setmetatable({}, State)
SlideState.__index = SlideState

-- ===== CONFIG =====
local SLIDE_CONFIG = {
	INITIAL_SPEED = 50,           -- Starting slide speed (you changed this!)
	MIN_SPRINT_SPEED = 18,        -- Minimum sprint speed to initiate slide
	DECELERATION_FLAT = 40,       -- How fast you slow down on flat ground (studs/s²)
	DECELERATION_UPHILL = 60,     -- Faster slowdown going uphill
	ACCELERATION_DOWNHILL = 15,   -- Speed gain going downhill
	MIN_SLIDE_SPEED = 8,          -- Below this, slide ends
	SLOPE_THRESHOLD = 0.03,       -- Minimum slope to be considered a slope (LOWERED from 0.1)
	STEEP_SLOPE = 0.5,            -- Slope angle where gravity really kicks in
	JUMP_MOMENTUM_KEEP = 0.7,     -- Keep 70% of slide speed when jumping out
	JUMP_FORWARD_BOOST = 15,      -- Extra forward push when jumping (studs)
	JUMP_VERTICAL_BOOST = 25,     -- Vertical jump boost (studs)
	CROUCH_SPEED = 7,             -- Movement speed while crouching
	CROUCH_HEIGHT = 0.5,          -- Humanoid height multiplier when crouched
	CAMERA_STEER_INFLUENCE = 0.8, -- How much camera affects slide direction (0 = none, 1 = full)
}

function SlideState.new()
	local self = State.new("Slide", 4)  -- Priority 4 (lower than dodge)
	self.SlideSpeed = 0
	self.SlideDirection = Vector3.new()
	self.IsSliding = false
	self.IsCrouching = false
	self.OriginalHeight = 0
	self.SlideConnection = nil
	self.HoldingCrouch = false
	self.RaycastParams = nil
	self.CrouchAnimTrack = nil
	self.WasOnSlope = false
	self.SlopeTransitionCooldown = 0
	return setmetatable(self, SlideState)
end

function SlideState:OnEnter(payload)
	local owner = self:GetOwner()
	if not owner or not owner.RootPart then return end

	payload = payload or {}

	self.HoldingCrouch = payload.holding or false

	-- Check if sprinting (WalkSpeed will be 26 if sprinting)
	local isSprinting = owner.Humanoid.WalkSpeed >= SLIDE_CONFIG.MIN_SPRINT_SPEED

	-- Store original height
	self.OriginalHeight = owner.Humanoid.HipHeight

	-- Stop sprint animation if active
	if owner.MovementController and owner.MovementController._sprintAnimPlaying then
		owner.MovementController:ForceStopSprintAnimation()
	end

	-- Setup raycast params for slope detection
	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterDescendantsInstances = {owner.Character}
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	-- Check if on ground
	local isOnGround = self:CheckGrounded(owner)

	if not isOnGround then
		owner.StateMachine:SetState("Idle")
		return
	end

	-- Determine if sliding or crouching
	if isSprinting then
		-- SLIDE
		self:StartSlide(owner)
	else
		-- CROUCH
		self:StartCrouch(owner)
	end
end

function SlideState:CheckGrounded(owner)
	if not owner or not owner.RootPart then return false end

	local rayOrigin = owner.RootPart.Position
	local rayDirection = Vector3.new(0, -5, 0)

	local rayResult = workspace:Raycast(rayOrigin, rayDirection, self.RaycastParams)
	return rayResult ~= nil
end

function SlideState:StartSlide(owner)
	self.IsSliding = true
	self.IsCrouching = false

	if owner.MovementController then
		owner.MovementController:ForceStopSprintAnimation()
		owner.MovementController.IsSprinting = false
		if owner.InputController and owner.InputController.ResetSprint then
			owner.InputController:ResetSprint()
		end
	end

	-- Get slide direction based on control mode
	local isShiftLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	local moveDir = owner.Humanoid.MoveDirection

	if isShiftLocked or moveDir.Magnitude < 0.1 then
		-- Shift lock or no input: use camera forward
		local camera = workspace.CurrentCamera
		local cameraForward = camera.CFrame.LookVector
		self.SlideDirection = Vector3.new(cameraForward.X, 0, cameraForward.Z).Unit
	else
		-- Free cam: use the direction the character is actually moving
		self.SlideDirection = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
	end
	self.SlideSpeed = SLIDE_CONFIG.INITIAL_SPEED

	-- Disable normal movement but KEEP AutoRotate for shift-lock
	owner.Humanoid.WalkSpeed = 0
	owner.Humanoid.JumpHeight = 0  -- Can't jump during slide (until cancelled)
	-- DON'T set AutoRotate = false (allows shift-lock rotation)

	-- Crouch character
	owner.Humanoid.HipHeight = self.OriginalHeight * SLIDE_CONFIG.CROUCH_HEIGHT

	owner.AnimationManager:Play("Slide", 0.1)

	self.SlideConnection = RunService.Heartbeat:Connect(function(dt)
		self:UpdateSlidePhysics(owner, dt)
	end)
end

function SlideState:StartCrouch(owner)
	self.IsSliding = false
	self.IsCrouching = true
	owner.Character:SetAttribute("IsCrouching", true)
	CombatRemotes.CrouchStarted:FireServer()

	if owner.MovementController then
		owner.MovementController:ForceStopSprintAnimation()
		owner.MovementController.IsSprinting = false
		if owner.InputController and owner.InputController.ResetSprint then
			owner.InputController:ResetSprint()
		end
	end

	owner.Humanoid.WalkSpeed = SLIDE_CONFIG.CROUCH_SPEED
	owner.Humanoid.JumpHeight = 5  -- Reduced jump height

	-- Crouch character
	owner.Humanoid.HipHeight = self.OriginalHeight * SLIDE_CONFIG.CROUCH_HEIGHT

	local playingTracks = owner.AnimationManager:Play("Crouch", 0.1, false)
	if playingTracks and playingTracks[1] then
		self.CrouchAnimTrack = playingTracks[1]
		self.CrouchAnimTrack:AdjustSpeed(0)
	end
end

function SlideState:UpdateSlidePhysics(owner, dt)
	if not self.IsSliding then return end
	if not owner or not owner.RootPart then return end

	local rootPart = owner.RootPart
	local humanoid = owner.Humanoid

	-- Decrease slope transition cooldown
	if self.SlopeTransitionCooldown > 0 then
		self.SlopeTransitionCooldown = self.SlopeTransitionCooldown - dt
	end

	-- ===== SLOPE DETECTION =====
	local rayOrigin = rootPart.Position
	local rayDirection = Vector3.new(0, -5, 0)  -- 5 studs down

	local rayResult = workspace:Raycast(rayOrigin, rayDirection, self.RaycastParams)

	local slopeAngle = 0
	local isOnGround = rayResult ~= nil

	if not isOnGround then
		if self.HoldingCrouch then
			self:TransitionToCrouch(owner)
		else
			owner.StateMachine:SetState("Idle")
		end
		return
	end

	local onSlope = false

	if rayResult then
		local normal = rayResult.Normal
		local upVector = Vector3.new(0, 1, 0)

		-- Calculate slope angle (0 = flat, 1 = vertical)
		slopeAngle = 1 - normal:Dot(upVector)

		-- Check if on a slope (with hysteresis to prevent bouncing)
		local effectiveThreshold = SLIDE_CONFIG.SLOPE_THRESHOLD
		if self.WasOnSlope then
			-- Lower threshold when transitioning OFF slope (prevents bouncing)
			effectiveThreshold = SLIDE_CONFIG.SLOPE_THRESHOLD * 0.5
		end

		if slopeAngle > effectiveThreshold then
			onSlope = true
			self.WasOnSlope = true
			self.SlopeTransitionCooldown = 0.3

			-- Disable AutoRotate on slopes (can't turn while sliding downhill)
			humanoid.AutoRotate = false

			-- Project slide direction onto slope
			local slopeRight = upVector:Cross(normal).Unit
			local slopeForward = normal:Cross(slopeRight).Unit

			if slopeForward.Y < 0 then
				self.SlideDirection = slopeForward
			else
				self.SlideDirection = -slopeForward
			end

			-- Face slide direction on slopes
			local lookCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + self.SlideDirection)
			rootPart.CFrame = CFrame.new(rootPart.Position) * (lookCFrame - lookCFrame.Position)
		else
			if self.WasOnSlope and self.SlopeTransitionCooldown > 0 then
				onSlope = true
				humanoid.AutoRotate = false
			else
				self.WasOnSlope = false
				humanoid.AutoRotate = true

				-- ===== STEERING (flat ground only) =====
				local isShiftLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
				local steerDirection

				if isShiftLocked then
					-- Shift lock: steer toward camera forward
					local cameraForward = workspace.CurrentCamera.CFrame.LookVector
					steerDirection = Vector3.new(cameraForward.X, 0, cameraForward.Z).Unit
				else
					-- Free cam: steer toward held keys, or keep current direction if no input
					local moveDir = humanoid.MoveDirection
					if moveDir.Magnitude > 0.1 then
						steerDirection = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
					else
						steerDirection = self.SlideDirection -- no input, go straight
					end
				end

				local currentDir = self.SlideDirection
				self.SlideDirection = (currentDir * (1 - SLIDE_CONFIG.CAMERA_STEER_INFLUENCE) +
					steerDirection * SLIDE_CONFIG.CAMERA_STEER_INFLUENCE).Unit
			end
		end
	end

	-- ===== SPEED CALCULATION =====
	if slopeAngle < SLIDE_CONFIG.SLOPE_THRESHOLD then
		self.SlideSpeed = math.max(
			SLIDE_CONFIG.MIN_SLIDE_SPEED,
			self.SlideSpeed - (SLIDE_CONFIG.DECELERATION_FLAT * dt)
		)
	else
		if self.SlideDirection.Y < -0.05 then
			self.SlideSpeed = self.SlideSpeed + (SLIDE_CONFIG.ACCELERATION_DOWNHILL * slopeAngle * dt)
		else
			self.SlideSpeed = math.max(
				SLIDE_CONFIG.MIN_SLIDE_SPEED,
				self.SlideSpeed - (SLIDE_CONFIG.DECELERATION_UPHILL * slopeAngle * dt)
			)
		end
	end

	-- ===== APPLY VELOCITY =====
	local velocity = self.SlideDirection * self.SlideSpeed

	-- Preserve vertical velocity (gravity/jumping)
	local currentVelocity = rootPart.AssemblyLinearVelocity
	velocity = Vector3.new(velocity.X, currentVelocity.Y, velocity.Z)

	rootPart.AssemblyLinearVelocity = velocity

	-- Character rotation handled differently based on slope
	-- (AutoRotate handles flat ground, manual rotation handles slopes)

	-- ===== END SLIDE IF TOO SLOW =====
	if self.SlideSpeed <= SLIDE_CONFIG.MIN_SLIDE_SPEED then
		local headPosition = owner.Character:FindFirstChild("Head")
		local hasCeiling = false

		if headPosition then
			local rayOrigin = headPosition.Position
			local rayDirection = Vector3.new(0, 2, 0)  -- Check 2 studs up

			local rayResult = workspace:Raycast(rayOrigin, rayDirection, self.RaycastParams)

			if rayResult then
				hasCeiling = true
			end
		end

		-- Transition to crouch if still holding ctrl OR if ceiling detected
		if self.HoldingCrouch or hasCeiling then
			if hasCeiling then
				-- Force holding crouch if ceiling detected
				self.HoldingCrouch = true
			end
			self:TransitionToCrouch(owner)
		else
			owner.StateMachine:SetState("Idle")
		end
	end
end

function SlideState:TransitionToCrouch(owner)
	if self.SlideConnection then
		self.SlideConnection:Disconnect()
		self.SlideConnection = nil
	end

	-- Stop slide animation before starting crouch
	owner.AnimationManager:Stop("Slide", 0.1)

	self.IsSliding = false
	self:StartCrouch(owner)
end

function SlideState:Update(dt)
	local owner = self:GetOwner()
	if not owner then return end

	-- Ground check: exit if player leaves the ground while crouching (e.g. walks off a ledge)
	if self.IsCrouching and not self:CheckGrounded(owner) then
		owner.StateMachine:SetState("Idle")
		return
	end

	-- Check if still holding crouch
	if not self.HoldingCrouch then
		-- Released ctrl - try to stand up

		-- Check if there's a ceiling above (can't stand up if blocked)
		local headPosition = owner.Character:FindFirstChild("Head")
		if headPosition then
			local rayOrigin = headPosition.Position
			local rayDirection = Vector3.new(0, 2, 0)  -- Check 2 studs up

			local rayResult = workspace:Raycast(rayOrigin, rayDirection, self.RaycastParams)

			if rayResult then
				self.HoldingCrouch = true
				return
			end
		end

		-- No ceiling - safe to stand up
		owner.StateMachine:SetState("Idle")
		return
	end

	-- If crouching (not sliding), adjust animation speed based on movement
	if self.IsCrouching and self.CrouchAnimTrack then
		local moveSpeed = owner.Humanoid.MoveDirection.Magnitude

		if moveSpeed > 0.1 then
			-- Moving - play animation at normal speed
			self.CrouchAnimTrack:AdjustSpeed(1)
		else
			-- Not moving - freeze animation
			self.CrouchAnimTrack:AdjustSpeed(0)
		end
	end
end

function SlideState:OnJumpCancel()
	-- Called when player presses space during slide
	local owner = self:GetOwner()
	if not owner or not owner.RootPart then 
		warn("[SlideState] Owner or RootPart is nil in OnJumpCancel")
		return
	end

	if self.IsSliding then
		-- Keep momentum in slide direction
		local horizontalMomentum = self.SlideDirection * self.SlideSpeed * SLIDE_CONFIG.JUMP_MOMENTUM_KEEP

		-- Add forward boost (extra push in slide direction)
		local forwardBoost = self.SlideDirection * SLIDE_CONFIG.JUMP_FORWARD_BOOST

		local currentVel = owner.RootPart.AssemblyLinearVelocity

		owner.RootPart.AssemblyLinearVelocity = Vector3.new(
			horizontalMomentum.X + forwardBoost.X,  -- Momentum + boost
			currentVel.Y + SLIDE_CONFIG.JUMP_VERTICAL_BOOST,  -- Vertical boost
			horizontalMomentum.Z + forwardBoost.Z   -- Momentum + boost
		)

		-- Exit slide
		owner.StateMachine:SetState("Idle")
	end
end

function SlideState:OnExit()
	local owner = self:GetOwner()
	if not owner then return end

	-- Disconnect physics
	if self.SlideConnection then
		self.SlideConnection:Disconnect()
		self.SlideConnection = nil
	end

	-- Cleanup crouch animation track
	if self.CrouchAnimTrack then
		self.CrouchAnimTrack = nil
	end

	-- Restore humanoid
	owner.Humanoid.HipHeight = self.OriginalHeight
	owner.Humanoid.WalkSpeed = 16  -- Reset to base (MovementController will handle equipped state)
	owner.Humanoid.JumpHeight = 7.2
	owner.Humanoid.AutoRotate = true
	-- AutoRotate is already true (we never disabled it)

	-- Clear crouch attribute
	owner.Character:SetAttribute("IsCrouching", false)
	if self.IsCrouching then
		CombatRemotes.CrouchEnded:FireServer()
	end

	-- Stop animations
	owner.AnimationManager:Stop("Slide", 0.1)
	owner.AnimationManager:Stop("Crouch", 0.1)
end

function SlideState:CanTransitionTo(nextStateName)
	-- Can be interrupted by hitstun/knockedout
	return nextStateName == "Hitstun"
		or nextStateName == "KnockedOut"
		or nextStateName == "Idle"
end

-- Update holding status from input
function SlideState:SetHolding(holding)
	self.HoldingCrouch = holding
end

return SlideState
