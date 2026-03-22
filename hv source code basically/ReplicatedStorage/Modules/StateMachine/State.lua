local State = {}
State.__index = State

function State.new(name, priority)
	local self = setmetatable({}, State)
	self.Name = name
	self.Priority = priority or 0
	self.StateMachine = nil  
	return self
end

function State:GetOwner()
	if not self.StateMachine then
		error("State " .. self.Name .. " has no StateMachine reference")
	end
	return self.StateMachine.Owner
end

function State:OnEnter(payload) end
function State:OnExit() end
function State:Update(dt) end
function State:CanTransitionTo(nextStateName) return true end

return State
