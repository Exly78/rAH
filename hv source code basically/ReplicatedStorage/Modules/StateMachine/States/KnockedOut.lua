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

	owner:StopMovement()
	owner:StopAttacking()
	rootPart.Velocity = Vector3.new(0, 0, 0) 

	--owner:PlayAnimation("KnockedOut")

	owner:SetVulnerable(true)

	owner:DisableInput()
end

function KnockedOutState:Update(dt)
	self.ElapsedTime = self.ElapsedTime + dt

	if self.ElapsedTime >= self.Duration then
		self:GetOwner().StateMachine:SetState("Idle")
		self:GetOwner():EnableInput()
	end
end

function KnockedOutState:OnExit()
	local owner = self:GetOwner()
	owner:EnableInput()
end

function KnockedOutState:CanTransitionTo(nextStateName)
	return nextStateName == "Idle" or nextStateName == "Death"
end

return KnockedOutState
