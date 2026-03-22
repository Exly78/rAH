local UserInputService = game:GetService("UserInputService")

local InputController = {}
InputController.__index = InputController

function InputController.new()
	local self = setmetatable({}, InputController)

	self.InputState = {
		W = false, A = false, S = false, D = false, Shift = false
	}

	-- Double tap logic
	self.SprintToggled = false
	self._lastTapTimes = { W = 0, A = 0, S = 0, D = 0 }
	self._doubleTapWindow = 0.3

	self._connections = {}
	self:SetupInput()

	return self
end

function InputController:SetupInput()
	local inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		local currentTime = tick()
		local isShiftLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

		local key = input.KeyCode

		if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D then
			local keyString = key.Name
			self.InputState[keyString] = true

			-- Double Tap Logic
			if (keyString == "W") or (not isShiftLock) then
				if currentTime - self._lastTapTimes[keyString] <= self._doubleTapWindow then
					self.SprintToggled = not self.SprintToggled
				end
				self._lastTapTimes[keyString] = currentTime
			end

		elseif key == Enum.KeyCode.LeftShift then
			self.InputState.Shift = true
		end
	end)

	local inputEnded = UserInputService.InputEnded:Connect(function(input)
		local key = input.KeyCode
		if self.InputState[key.Name] ~= nil then
			self.InputState[key.Name] = false
		elseif key == Enum.KeyCode.LeftShift then
			self.InputState.Shift = false
		end
	end)

	table.insert(self._connections, inputBegan)
	table.insert(self._connections, inputEnded)
end

function InputController:GetMoveVector()
	local moveDir = Vector3.new(0, 0, 0)
	if self.InputState.W then moveDir += Vector3.new(0, 0, -1) end
	if self.InputState.S then moveDir += Vector3.new(0, 0, 1) end
	if self.InputState.A then moveDir += Vector3.new(-1, 0, 0) end
	if self.InputState.D then moveDir += Vector3.new(1, 0, 0) end
	return moveDir
end

function InputController:ResetSprint()
	self.SprintToggled = false
end

function InputController:Destroy()
	for _, conn in ipairs(self._connections) do conn:Disconnect() end
end

return InputController
