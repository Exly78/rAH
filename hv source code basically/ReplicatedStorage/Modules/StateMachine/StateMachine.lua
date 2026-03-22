local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(owner, defaultStateName)
	local self = setmetatable({}, StateMachine)
	self.Owner = owner
	self.States = {}
	self.CurrentState = nil
	self.PreviousState = nil
	self.DefaultState = defaultStateName
	
	return self
end

function StateMachine:RegisterState(state)
	state.StateMachine = self  
	self.States[state.Name] = state
end

function StateMachine:Start()
	if self.DefaultState then
		self:SetState(self.DefaultState)
	end
end

function StateMachine:SetState(name, payload)
	local newState = self.States[name]
	if not newState then
		warn("[StateMachine] State not found: " .. tostring(name))
		return false
	end

	if self.CurrentState then
		if not self.CurrentState:CanTransitionTo(name) then
			print("[StateMachine] Transition blocked by CanTransitionTo: " .. self.CurrentState.Name .. " -> " .. name)
			return false
		end
	else

	end

	if self.CurrentState then
		self.CurrentState:OnExit()
		self.PreviousState = self.CurrentState
	end

	print("[StateMachine] Transitioning: " .. (self.PreviousState and self.PreviousState.Name or "None") .. " -> " .. name)
	self.CurrentState = newState
	self.CurrentState:OnEnter(payload)
	return true
end

function StateMachine:Update(dt)
	if self.CurrentState then
		self.CurrentState:Update(dt)
	end
end

function StateMachine:IsInState(name)
	return self.CurrentState and self.CurrentState.Name == name
end

function StateMachine:GetCurrentState()
	return self.CurrentState and self.CurrentState.Name or "None"
end

function StateMachine:Destroy()
	if self.CurrentState then
		self.CurrentState:OnExit()
	end
	self.CurrentState = nil
	self.PreviousState = nil
	self.States = {}
end

return StateMachine
