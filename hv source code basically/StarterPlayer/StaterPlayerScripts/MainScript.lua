-- StarterPlayer.StarterPlayerScripts.MainScript

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")

local player    = Players.LocalPlayer
if not player then return end

local character = player.Character or player.CharacterAdded:Wait()

local Modules           = game.ReplicatedStorage:WaitForChild("Modules")
local CharacterController = require(Modules.Controllers:WaitForChild("CharacterController"))
local Store             = require(Modules.Controllers:WaitForChild("ControllerStore"))

local controller = CharacterController.new(character, {})
Store.Controller = controller

local humanoid = controller.Humanoid
humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

print("=== COMBAT SYSTEM READY ===")

controller.WantsDodge    = false
controller.WantsBlock    = false
controller.IsHoldingBlock = false

-- ===== INPUT HANDLING =====
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local state = humanoid:GetState()

	-- Jump
	if input.KeyCode == Enum.KeyCode.Space then
		if state ~= Enum.HumanoidStateType.Freefall then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end

	-- Dodge (Q)
	if input.KeyCode == Enum.KeyCode.Q then
		controller.WantsDodge = true
	end

	-- Block / Parry (F)
	if input.KeyCode == Enum.KeyCode.F then
		if controller.StateMachine:IsInState("Block") then
			controller.IsHoldingBlock = true
			local blockState = controller.StateMachine.CurrentState
			if blockState and blockState.SetHolding then
				blockState:SetHolding(true)
			end
		else
			controller.WantsBlock    = true
			controller.IsHoldingBlock = true
		end
	end

	-- Equip / Unequip (E)
	if input.KeyCode == Enum.KeyCode.E then
		if character:GetAttribute("IsEquipped") then
			controller.CombatController:UnequipWeapon()
			print("[CONTROLS] Unequipped")
		else
			controller.CombatController:EquipWeapon("Katana")
			print("[CONTROLS] Equipped")
		end
	end

	-- Critical Attack (R)
	-- Phase is determined inside PerformCriticalAttack based on AltCrit attribute
	if input.KeyCode == Enum.KeyCode.R then
		if character:GetAttribute("IsEquipped") then
			controller.CombatController:PerformCriticalAttack()
		end
	end

	-- Basic Attack (Left Click)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if character:GetAttribute("IsEquipped") then
			controller.CombatController:PerformBasicAttack()
		end
	end
	-- Input Began
	if input.KeyCode == Enum.KeyCode.LeftControl then
		if controller.StateMachine:IsInState("Slide") then
			controller.IsHoldingCrouch = true
			local slideState = controller.StateMachine.CurrentState
			if slideState and slideState.SetHolding then
				slideState:SetHolding(true)
			end
		else
			controller.WantsSlide = true
			controller.IsHoldingCrouch = true
		end
	end

	-- Jump during slide (cancel with momentum)
	if input.KeyCode == Enum.KeyCode.Space then
		if controller.StateMachine:IsInState("Slide") then
			local slideState = controller.StateMachine.CurrentState
			if slideState and slideState.OnJumpCancel then
				slideState:OnJumpCancel()
			end
		end
	end

end)

UIS.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Q then
		controller.WantsDodge = false
	end
	if input.KeyCode == Enum.KeyCode.LeftControl then
		controller.IsHoldingCrouch = false
		if controller.StateMachine:IsInState("Slide") then
			local slideState = controller.StateMachine.CurrentState
			if slideState and slideState.SetHolding then
				slideState:SetHolding(false)
			end
		end
		controller.WantsSlide = false
	end

	if input.KeyCode == Enum.KeyCode.F then
		controller.IsHoldingBlock = false

		if controller.StateMachine:IsInState("Block") then
			local blockState = controller.StateMachine.CurrentState
			if blockState and blockState.SetHolding then
				blockState:SetHolding(false)
			end
		end

		controller.WantsBlock = false
	end
end)

-- ===== MAIN LOOP =====
RunService.Heartbeat:Connect(function(dt)
	local success, err = pcall(function()
		controller:Update(dt)
	end)
	if not success then
		warn("Controller update error:", err)
	end
end)