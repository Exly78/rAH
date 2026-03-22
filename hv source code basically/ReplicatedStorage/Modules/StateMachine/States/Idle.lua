local State = require(script.Parent.Parent.State)

local KnockedOutState = setmetatable({}, State)
KnockedOutState.__index = KnockedOutState

function KnockedOutState.new()
	local self = State.new("KnockedOut", 15)  
	self.Duration = 0
	self.ElapsedTime = 0
	return setmetatable(self, KnockedOutState)
end

function KnockedOutState:OnEnter(payload)
	local owner = self:GetOwner()
	local character = owner.Character
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not rootPart then return end

	payload = payload or {}
	self.Duration = payload.duration or 2  
	self.ElapsedTime = 0

	-- Stop movement by zeroing velocity and locking speed
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	owner.Humanoid.WalkSpeed = 0

	-- Stop sprint if active
	if owner.MovementController and owner.MovementController._sprintAnimPlaying then
		owner.MovementController:ForceStopSprintAnimation()
	end

	-- Reset combo
	owner.CombatController:ResetCombo()

	--owner:PlayAnimation("KnockedOut")

	owner:SetInvulnerable(false)
end

function KnockedOutState:Update(dt)
	self.ElapsedTime = self.ElapsedTime + dt

	if self.ElapsedTime >= self.Duration then
		self:GetOwner().StateMachine:SetState("Idle")
	end
end

function KnockedOutState:OnExit()
	local owner = self:GetOwner()
	-- Restore walk speed
	local isEquipped = owner.Character:GetAttribute("IsEquipped")
	owner.Humanoid.WalkSpeed = isEquipped and 14 or 16
end

function KnockedOutState:CanTransitionTo(nextStateName)
	return nextStateName == "Idle" or nextStateName == "Death"
end

return KnockedOutState
