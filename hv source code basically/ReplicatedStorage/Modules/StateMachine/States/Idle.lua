--ReplicatedStorage.Modules.StateMachine.States.Idle (UPDATED WITH BLOCK)

local State = require(script.Parent.Parent.State)

local IdleState = setmetatable({}, State)
IdleState.__index = IdleState

function IdleState.new()
	local self = State.new("Idle", 0)
	return setmetatable(self, IdleState)
end

function IdleState:OnEnter()
	local owner = self:GetOwner() 
	local combat = owner.CombatController

	if owner.Character:GetAttribute("IsEquipped") and combat.CurrentWeapon then
		local idleAnim = combat.CurrentWeapon .. "_WeaponIdle"
		owner.AnimationManager:Play(idleAnim, 0.2)
	end
end

function IdleState:Update(dt)
	local owner = self:GetOwner()

	-- Check for dodge input
	if owner.WantsDodge then
		local isVulnerable = not owner.IsInvulnerableFlag 

		if isVulnerable then
			owner.StateMachine:SetState("Dodge")
		end
	end
	-- NEW: Check for slide/crouch
	if owner.WantsSlide or owner:WantsToSlide() then
		owner.StateMachine:SetState("Slide", {
			holding = owner.IsHoldingCrouch
		})
		return
	end
	-- NEW: Check for block input
	if owner.WantsBlock or owner:WantsToBlock() then
		owner.StateMachine:SetState("Block", {
			holding = owner.IsHoldingBlock
		})
	end
end

function IdleState:OnExit()
end

function IdleState:CanTransitionTo(nextStateName)
	return true
end

return IdleState
