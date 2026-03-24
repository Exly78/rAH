-- StarterPlayer.StarterPlayerScripts.MainScript

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then return end

local Modules             = game.ReplicatedStorage:WaitForChild("Modules")
local CharacterController = require(Modules.Controllers:WaitForChild("CharacterController"))

-- ===== CLIENT-SIDE DEBOUNCES =====
local DODGE_CD = 0.65
local BLOCK_CD = 0.50
local JUMP_CD  = 0.30

-- Upvalues — reassigned on every respawn so all closures below see the new values
local controller
local humanoid
local character
local dodgeTime = 0
local blockTime = 0
local jumpTime  = 0

local function initCharacter(newCharacter)
	if controller then
		controller:Destroy()
	end

	character   = newCharacter
	controller  = CharacterController.new(character, {})
	humanoid    = controller.Humanoid

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	controller.WantsDodge     = false
	controller.WantsBlock     = false
	controller.IsHoldingBlock = false
	controller.WantsSlide     = false
	controller.IsHoldingCrouch = false

	-- Reset debounces so they don't carry over from before death
	dodgeTime = 0
	blockTime = 0
	jumpTime  = 0

	print("=== COMBAT SYSTEM READY ===")
end

-- Connect BEFORE fetching character to avoid missing the event on fast respawns
player.CharacterAdded:Connect(function(newCharacter)
	-- Wait for humanoid so CharacterController can find it immediately
	newCharacter:WaitForChild("Humanoid", 10)
	initCharacter(newCharacter)
end)

initCharacter(player.Character or player.CharacterAdded:Wait())

-- ===== INPUT HANDLING =====
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not controller then return end

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
			controller.WantsBlock     = true
			controller.IsHoldingBlock = true
		end
	end

	-- Equip / Unequip (E)
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
			if controller.StateMachine:IsInState("Slide") then
				controller.CombatController:PerformSlideAttack()
			else
				controller.CombatController:PerformBasicAttack()
			end
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
			controller.WantsSlide      = true
			controller.IsHoldingCrouch = true
		end
	end
end)

UIS.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not controller then return end

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
	if not controller then return end
	local success, err = pcall(function()
		controller:Update(dt)
	end)
	if not success then
		warn("Controller update error:", err)
	end
end)
