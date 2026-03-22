local CharacterController = {}
CharacterController.__index = CharacterController

-- [[ 1. MODULE DEPENDENCIES ]]
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local CombatController = require(script.Parent.CombatController)

-- External Systems
local StateMachine = require(script.Parent.Parent.StateMachine.StateMachine)
local IdleState = require(script.Parent.Parent.StateMachine.States.Idle)
local AttackState = require(script.Parent.Parent.StateMachine.States.Attack)
local HitstunState = require(script.Parent.Parent.StateMachine.States.Hitstun)
local DodgeState = require(script.Parent.Parent.StateMachine.States.Dodge)
local BlockState = require(script.Parent.Parent.StateMachine.States.Block)  -- NEW
local SlideState = require(script.Parent.Parent.StateMachine.States.Slide)
local KnockedOutState = require(script.Parent.Parent.StateMachine.States.KnockedOut)

local AnimationManager = require(game.ReplicatedStorage.Modules.Managers.AnimationManager)
local TagManager = require(game.ReplicatedStorage.Modules.Managers.TagManager)

-- [[ 2. CONSTRUCTOR ]]
function CharacterController.new(character, playerData)
	local self = setmetatable({}, CharacterController)

	self.Character = character
	self.PlayerData = playerData
	self.Humanoid = character:WaitForChild("Humanoid")
	self.RootPart = character:WaitForChild("HumanoidRootPart")

	self.WantsDodge = false
	self.WantsBlock = false  -- NEW
	self.IsHoldingBlock = false  -- NEW
	self.WantsSlide = false
	self.IsHoldingCrouch = false
	self.IsInvulnerableFlag = false

	TagManager.Initialize(self.Character)

	self.AnimationManager = AnimationManager.new(character)

	self.InputController = InputController.new()
	self.CombatController = CombatController.new(self)   
	self.MovementController = MovementController.new(self) 

	self.StateMachine = StateMachine.new(self, "Idle")
	self.StateMachine:RegisterState(IdleState.new())
	self.StateMachine:RegisterState(AttackState.new())
	self.StateMachine:RegisterState(HitstunState.new())
	self.StateMachine:RegisterState(DodgeState.new())
	self.StateMachine:RegisterState(BlockState.new())  -- NEW
	self.StateMachine:RegisterState(KnockedOutState.new())
	self.StateMachine:RegisterState(SlideState.new())
	self.StateMachine:Start()

	local defaultWeapon = (playerData and playerData.EquippedWeapon) or "Katana"
	self.CombatController.WeaponManager:AddWeaponToCharacter(defaultWeapon)
	self.CombatController.CurrentWeapon = defaultWeapon

	print("[CharacterController] Initialized for " .. character.Name)
	return self
end


function CharacterController:Update(dt)
	-- Get Input
	local moveVec = self.InputController:GetMoveVector()
	local sprintToggled = self.InputController.SprintToggled

	-- Update Sub-Systems
	self.MovementController:Update(dt, moveVec, sprintToggled)
	self.CombatController:Update(dt)
	self.StateMachine:Update(dt)
end


function CharacterController:WantsToDodge()
	return self.WantsDodge
end

function CharacterController:WantsToBlock()  -- NEW
	return self.WantsBlock
end
function CharacterController:WantsToSlide()
	return self.WantsSlide
end

-- FIXED: Using TagManager.HasTag instead of checking state internals
function CharacterController:IsInvulnerable()
	return self.IsInvulnerableFlag 
		or self.StateMachine:IsInState("Dodge")
		or TagManager.HasTag(self.Character, "CanParry")  -- USING TAGS
end

function CharacterController:IsVulnerable()
	return not self.StateMachine:IsInState("Dodge")
		and not self.StateMachine:IsInState("Hitstun")
		and not self.IsInvulnerableFlag
		and not TagManager.HasTag(self.Character, "CanParry")  -- USING TAGS
end

function CharacterController:SetInvulnerable(state)
	self.IsInvulnerableFlag = state
	self.Character:SetAttribute("IsInvulnerable", state)
end

-- Combat / Combo Bridges
function CharacterController:EnableComboQueuing()
	self.CombatController.CanQueueNextAttack = true
end

function CharacterController:HasQueuedAttack()
	return self.CombatController.QueuedAttack
end

function CharacterController:ConsumeQueuedAttack()
	self.CombatController.QueuedAttack = false
end

function CharacterController:PerformBasicAttack()
	self.CombatController:PerformBasicAttack()
end

function CharacterController:ExecuteSkill(skillName, onComplete)
	if self.CombatController.ExecuteSkill then
		self.CombatController:ExecuteSkill(skillName, onComplete)
	else
		if onComplete then onComplete() end
	end
end


function CharacterController:PlayAnimation(animName)
	local weapon = self.CombatController.CurrentWeapon
	local fullKey = weapon and (weapon .. "_" .. animName) or animName
	self.AnimationManager:Play(fullKey)
end

function CharacterController:PlayIdle()
	if self.Character:GetAttribute("IsEquipped") and self.CombatController.CurrentWeapon then
		local idleKey = self.CombatController.CurrentWeapon .. "_WeaponIdle"
		-- Don't restart if already playing
		if self.AnimationManager:IsKeyPlaying(idleKey) then return end
		self.AnimationManager:Play(idleKey, 0.2, false)
	end
end

function CharacterController:ConnectWeldKeyframe(keyframeName, callback)
	local tracks = self.AnimationManager:GetAllTracks()
	for _, track in ipairs(tracks) do
		track.KeyframeReached:Connect(function(kName)
			if kName == keyframeName then callback() end
		end)
	end
end

function CharacterController:IsMovementLocked()
	return self.MovementController:IsMovementLocked()
end

-- [[ 5. CLEANUP ]]
function CharacterController:Destroy()
	self.InputController:Destroy()
	self.CombatController:Destroy()

	TagManager.Cleanup(self.Character)
	self.AnimationManager:Destroy()
	self.StateMachine:Destroy()
end

return CharacterController
