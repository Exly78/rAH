local MovementController = {}
MovementController.__index = MovementController

local WALK_SPEEDS = {
	EQUIPPED_NORMAL = 14,
	EQUIPPED_SPRINT = 26,
	UNEQUIPPED_NORMAL = 16,
	UNEQUIPPED_SPRINT = 26,
	LOCKED = 4
}

local MOVEMENT_LOCKED_STATES = {
	"Attack",
	"Hitstun",
	"KnockedOut"
}

function MovementController.new(characterController)
	local self = setmetatable({}, MovementController)

	self.CC = characterController
	self.Character = characterController.Character
	self.Humanoid = self.Character:WaitForChild("Humanoid")

	self.IsMoving = false
	self.IsSprinting = false

	self._wasSprintingLastFrame = false
	self._sprintAnimPlaying = false

	return self
end

function MovementController:Update(dt, moveVector, sprintToggled)
	self.IsMoving = moveVector.Magnitude > 0
	local moveDir = self.IsMoving and moveVector.Unit or Vector3.zero

	local inDodge = self.CC.StateMachine:IsInState("Dodge")

	-- Movement locked (except dodge)
	if self:IsMovementLocked() and not inDodge then
		self.Humanoid:Move(Vector3.zero, false)
		self.Humanoid.WalkSpeed = WALK_SPEEDS.LOCKED

		if self.IsSprinting or self._sprintAnimPlaying or sprintToggled then
			self.IsSprinting = false
			self.CC.InputController:ResetSprint()
			self._wasSprintingLastFrame = false
			self:ForceStopSprintAnimation()
		end
		return
	end

	-- Normal movement
	if not inDodge then
		self.Humanoid:Move(moveDir, false)
		self:UpdateWalkSpeed(sprintToggled)
	end

	if not self:IsMovementLocked() and not inDodge then
		self:UpdateSprintAnimation()
		self:UpdateIdle()
	end
end

function MovementController:UpdateWalkSpeed(sprintToggled)
	local isEquipped = self.Character:GetAttribute("IsEquipped") or false

	if not self.IsMoving and sprintToggled then
		self.CC.InputController:ResetSprint()
		sprintToggled = false
	end

	self.IsSprinting = sprintToggled and self.IsMoving

	if isEquipped then
		self.Humanoid.WalkSpeed =
			self.IsSprinting and WALK_SPEEDS.EQUIPPED_SPRINT or WALK_SPEEDS.EQUIPPED_NORMAL
	else
		self.Humanoid.WalkSpeed =
			self.IsSprinting and WALK_SPEEDS.UNEQUIPPED_SPRINT or WALK_SPEEDS.UNEQUIPPED_NORMAL
	end
end

function MovementController:IsMovementLocked()
	for _, stateName in ipairs(MOVEMENT_LOCKED_STATES) do
		if self.CC.StateMachine:IsInState(stateName) then
			return true
		end
	end
	return false
end

function MovementController:UpdateIdle()
	if self.IsSprinting or self._sprintAnimPlaying or self.IsMoving then return end
	self.CC:PlayIdle()
end

function MovementController:UpdateSprintAnimation()
	if self.CC.StateMachine:IsInState("Dodge") then
		-- Hard interrupt; sprint will be resumed explicitly later
		self._wasSprintingLastFrame = false
		-- We mark it as not playing so that when dodge ends, it restarts the animation
		self._sprintAnimPlaying = false 
		return
	end

	-- Detect weapon/equip change to force restart animation
	local weapon = self.CC.CombatController.CurrentWeapon
	local isEquipped = self.Character:GetAttribute("IsEquipped")
	local currentSprintKey = (weapon and isEquipped) and (weapon .. "_Sprint") or "Sprint"

	if self._lastSprintKey ~= currentSprintKey then
		if self._sprintAnimPlaying then
			self:StopSprintAnimation()
			self._wasSprintingLastFrame = false -- Force restart
		end
		self._lastSprintKey = currentSprintKey
	end

	local shouldSprint = self.IsSprinting and self.IsMoving

	if shouldSprint and not self._wasSprintingLastFrame then
		self:StartSprintAnimation()
	elseif not shouldSprint and self._wasSprintingLastFrame then
		self:StopSprintAnimation()
	end

	self._wasSprintingLastFrame = shouldSprint
end

function MovementController:StartSprintAnimation()
	if self._sprintAnimPlaying then return end

	local weapon = self.CC.CombatController.CurrentWeapon
	local isEquipped = self.Character:GetAttribute("IsEquipped")
	local sprintKey = (weapon and isEquipped) and (weapon .. "_Sprint") or "Sprint"

	if weapon then
		self.CC.AnimationManager:Stop(weapon .. "_WeaponIdle", 0.05)
	end

	local success = self.CC.AnimationManager:Play(sprintKey, 0.1, false)
	if success then
		self._sprintAnimPlaying = true
	end
end

function MovementController:StopSprintAnimation()
	if not self._sprintAnimPlaying then return end

	local weapon = self.CC.CombatController.CurrentWeapon
	local sprintKey =
		(weapon and self.Character:GetAttribute("IsEquipped"))
		and (weapon .. "_Sprint")
		or "Sprint"

	self.CC.AnimationManager:Stop(sprintKey, 0.15)
	self._sprintAnimPlaying = false
end

function MovementController:ForceStopSprintAnimation()
	if not self._sprintAnimPlaying then return end

	local weapon = self.CC.CombatController.CurrentWeapon
	local sprintKey =
		(weapon and self.Character:GetAttribute("IsEquipped"))
		and (weapon .. "_Sprint")
		or "Sprint"

	self.CC.AnimationManager:Stop(sprintKey, 0)
	self._sprintAnimPlaying = false
end

function MovementController:TryResumeSprint()
	if not self.IsMoving or not self.IsSprinting then return end
	if self._sprintAnimPlaying then return end
	self._wasSprintingLastFrame = false
end

return MovementController
