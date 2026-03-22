local State = require(script.Parent.Parent.State)

local HitstunState = setmetatable({}, State)
HitstunState.__index = HitstunState

function HitstunState.new()
	local self = State.new("Hitstun", 10)  
	self.Duration = 0
	self.ElapsedTime = 0
	return setmetatable(self, HitstunState)
end

function HitstunState:OnEnter(payload)
	local owner = self:GetOwner()

	payload = payload or {}
	self.Duration = payload.duration or 0.3
	self.ElapsedTime = 0

	--owner:PlayAnimation("Hitstun")
	owner:SetInvulnerable(false)
end

function HitstunState:Update(dt)
	self.ElapsedTime = self.ElapsedTime + dt

	if self.ElapsedTime >= self.Duration then
		self:GetOwner().StateMachine:SetState("Idle")
	end
end

function HitstunState:CanTransitionTo(nextStateName)
	return nextStateName == "Idle" or nextStateName == "Death"
end

return HitstunState
