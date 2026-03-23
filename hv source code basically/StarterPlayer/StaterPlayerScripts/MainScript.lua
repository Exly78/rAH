-- StarterPlayer.StarterPlayerScripts.MainScript

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")

local player    = Players.LocalPlayer
if not player then return end

local character = player.Character or player.CharacterAdded:Wait()

local Modules             = game.ReplicatedStorage:WaitForChild("Modules")
local CharacterController = require(Modules.Controllers:WaitForChild("CharacterController"))

local controller = CharacterController.new(character, {})

local humanoid = controller.Humanoid
humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

print("=== COMBAT SYSTEM READY ===")

-- ===== CLIENT-SIDE DEBOUNCES =====
local DODGE_CD  = 0.65  -- slightly longer than DodgeDuration (0.45s)
local BLOCK_CD  = 0.50  -- prevents rapid parry window farming
local JUMP_CD   = 0.30  -- prevents jump spam
local dodgeTime = 0
local blockTime = 0
local jumpTime  = 0

controller.WantsDodge    = false
controller.WantsBlock    = false
controller.IsHoldingBlock = false

-- ===== INPUT HANDLING =====
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local now   = tick()
	local state = humanoid:GetState()

	-- Jump (Space)
	if input.KeyCode == Enum.KeyCode.Space then
		if controller.StateMachine:IsInState("Slide") then
			local slideState = controller.StateMachine.CurrentState
			if slideState and slideState.OnJumpCancel then
				slideState:OnJumpCancel()
			end
		elseif state ~= Enum.HumanoidStateType.Freefall and now >= jumpTime then
			jumpTime = now + JUMP_CD
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end

	-- Dodge (Q)
	if input.KeyCode == Enum.KeyCode.Q and now >= dodgeTime then
		dodgeTime = now + DODGE_CD
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
		elseif now >= blockTime then
			blockTime = now + BLOCK_CD
			controller.WantsBlock    = true
			controller.IsHoldingBlock = true
		end
	end

	-- Equip / Unequip (E) — debounce handled inside CombatController._isEquipping
	if input.KeyCode == Enum.KeyCode.E then
		if character:GetAttribute("IsEquipped") then
			controller.CombatController:UnequipWeapon()
		else
			controller.CombatController:EquipWeapon("Katana")
		end
	end

	-- Critical Attack (R)
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

	-- Crouch / Slide (LeftControl)
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