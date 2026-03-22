--ReplicatedStorage.Modules.StateMachine.States.Attack
-- FIXED: Client no longer detects hits (prevents exploits)

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
		-- For crits, skillName is passed explicitly. For basic attacks it stays nil
		-- and CreateHitbox falls back to "BasicAttack".
		self.SkillName = payload.skillName or nil

		local track = payload.track or owner.AnimationManager:GetCurrentTrack()
		if track then
			local animName = track.Animation and track.Animation.Name or "Unknown"
			print("[AttackState] Firing attack! Track length:", track.Length, "| Animation Name:", animName)
			self.KeyframeConnection = track:GetMarkerReachedSignal("Hit"):Connect(function()
				print("[AttackState] Hit marker reached on", animName)
				if not self.HitboxCreated then
					self.HitboxCreated = true
					self:CreateHitbox(owner, self.ComboIndex)

					if self.KeyframeConnection then
						self.KeyframeConnection:Disconnect()
						self.KeyframeConnection = nil
					end
				end
			end)

			-- fallback if marker doesn't exist
			task.delay(track.Length * 0.9, function()
				if not self.HitboxCreated and not self.IsFinished then
					print("[AttackState] Fallback hitbox creation (no Hit marker found)")
					self.HitboxCreated = true
					self:CreateHitbox(owner, self.ComboIndex)
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

-- ===== FIXED FUNCTION =====
function AttackState:CreateHitbox(owner, comboIndex)
	local skillName = self.SkillName or "BasicAttack"

	-- CLIENT ONLY NOTIFIES SERVER - DOES NOT DETECT HITS
	-- Server will handle all hit detection to prevent exploits
	CombatRemotes.CreateHitbox:FireServer(skillName, comboIndex)

	-- Optional: Create visual-only hitbox for client prediction/feedback
	-- This doesn't affect actual damage, just shows the player where they're swinging
	-- Uncomment if you want visual feedback:
	--[[
	local skill = SkillData:GetSkill(skillName)
	if skill then
		-- Visual hitbox only (no OnHit callback)
		if skill.Continuous then
			self.HitboxManager:CreateContinuous(owner.Character, {
				Duration = skill.Duration,
				Interval = skill.Interval or 0.07,
				Size = skill.HitboxSize,
				ForwardOffset = skill.HitboxOffset,
				OnHit = nil  -- No callback = visual only
			})
		else
			-- Just create visual representation, ignore hits
			self.HitboxManager:CreateSingle(owner.Character, owner.RootPart.CFrame, skill.HitboxSize)
		end
	end
	]]--
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
