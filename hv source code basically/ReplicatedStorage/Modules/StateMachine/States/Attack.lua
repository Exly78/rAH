local State = require(script.Parent.Parent.State)
local HitboxManager = require(game.ReplicatedStorage.Modules.Managers.HitboxManager)
local CombatRemotes = require(game.ReplicatedStorage.Modules.Remotes.CombatRemotes)
local SkillData = require(game.ReplicatedStorage.Modules.Data.SkillData)

local AttackState = setmetatable({}, State)
AttackState.__index = AttackState

function AttackState.new()
	local self = State.new("Attack", 5)
	self.SkillName = nil
	self.AttackType = nil
	self.IsFinished = false
	self.Timer = 0
	self.ComboIndex = 1
	self.ComboQueuingEnabled = false
	self.HitboxManager = HitboxManager.new()
	self.ActiveHitTargets = {}
	return setmetatable(self, AttackState)
end

function AttackState:OnEnter(payload)
	local owner = self:GetOwner()
	local combat = owner.CombatController
	local movement = owner.MovementController

	payload = payload or {}

	self.IsFinished = false
	self.Timer = 0
	self.ActiveHitTargets = {}
	self.ComboQueuingEnabled = false
	self.InEndlag = false
	self.EndlagTimer = 0
	self.HitboxCreated = false

	if movement._sprintAnimPlaying then
		movement:ForceStopSprintAnimation()
	end

	if payload.attackType then
		self.AttackType = payload.attackType
		self.ComboIndex = payload.comboIndex or 1
		self.EndlagDuration = payload.endlag or 0.2
		self.SkillName = nil

		local track = owner.AnimationManager:GetCurrentTrack()
		if track then
			self.KeyframeConnection = track.KeyframeReached:Connect(function(key)
				if key == "Hit" and not self.HitboxCreated then
					self.HitboxCreated = true
					self:CreateHitbox(owner, self.ComboIndex)

					if self.KeyframeConnection then
						self.KeyframeConnection:Disconnect()
						self.KeyframeConnection = nil
					end
				end
			end)

			task.delay(track.Length * 0.6, function()
				if not self.IsFinished then
					self.ComboQueuingEnabled = true
					combat.CanQueueNextAttack = true
				end
			end)

			self.AnimationConnection = track.Stopped:Connect(function()
				self.InEndlag = true
			end)
		else
			warn("[AttackState] No animation track found, fallback endlag")
			self.InEndlag = true
		end

	elseif payload.skillName then
		self.SkillName = payload.skillName
		self.AttackType = nil
		self.EndlagDuration = payload.endlag or 0.3

		if combat.ExecuteSkill then
			combat:ExecuteSkill(self.SkillName, function()
				self.InEndlag = true
			end)
		else
			local skill = SkillData:GetSkill(self.SkillName)
			owner.AnimationManager:Play(skill.Animation or self.SkillName)
			task.delay(skill.Duration or 1, function() self.InEndlag = true end)
		end
	else
		self.IsFinished = true
		owner.StateMachine:SetState("Idle")
	end
end

function AttackState:CreateHitbox(owner, comboIndex)
	local skillName = self.SkillName or "BasicAttack"
	local skill = SkillData:GetSkill(skillName)
	if not skill then
		warn("[AttackState] Skill data missing for", skillName)
		return
	end

	local char = owner.Character

	if skill.Continuous then
		self.HitboxManager:CreateContinuous(char, {
			Duration = skill.Duration,
			Interval = skill.Interval or 0.07,
			Size = skill.HitboxSize,
			ForwardOffset = skill.HitboxOffset,
			OnHit = function(target)
				CombatRemotes.CreateHitbox:FireServer(skillName, comboIndex)
			end
		})
	else
		local hits = self.HitboxManager:CreateSingle(char, owner.RootPart.CFrame, skill.HitboxSize)
		for _, target in ipairs(hits) do
			CombatRemotes.CreateHitbox:FireServer(skillName, comboIndex)
		end
	end
end

function AttackState:Update(dt)
	if self.InEndlag then
		self.EndlagTimer = (self.EndlagTimer or 0) + dt

		if self.EndlagTimer >= self.EndlagDuration and not self.IsFinished then
			local owner = self:GetOwner()
			local combat = owner.CombatController

			self.IsFinished = true

			if combat.QueuedAttack then
				combat.QueuedAttack = false

				owner.StateMachine:SetState("Idle")
				combat:PerformBasicAttack()
			else
				owner.StateMachine:SetState("Idle")
			end
		end
	end
end

function AttackState:OnExit()
	if self.AnimationConnection then
		self.AnimationConnection:Disconnect()
		self.AnimationConnection = nil
	end
	if self.KeyframeConnection then
		self.KeyframeConnection:Disconnect()
		self.KeyframeConnection = nil
	end

	self.SkillName = nil
	self.AttackType = nil
	self.IsFinished = false
	self.Timer = 0
	self.AnimationTrack = nil
	self.EndlagTimer = 0
	self.InEndlag = false
	self.HitboxCreated = false
	self.ComboIndex = 1
	self.ComboQueuingEnabled = false
	self.ActiveHitTargets = {}
end

function AttackState:CanTransitionTo(nextStateName)
	return nextStateName == "Hitstun" 
		or nextStateName == "KnockedOut" 
		or nextStateName == "Idle"
end

return AttackState