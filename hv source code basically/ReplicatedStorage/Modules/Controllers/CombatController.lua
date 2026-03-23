-- ReplicatedStorage.Modules.Controllers.CombatController

local CombatController = {}
CombatController.__index = CombatController

local WeaponManager = require(game.ReplicatedStorage.Modules.Weapons.WeaponManager)
local HitboxManager = require(script.Parent.Parent.Managers.HitboxManager)
local CombatRemotes = require(game.ReplicatedStorage.Modules.Remotes.CombatRemotes)
local SkillData     = require(script.Parent.Parent.Data.SkillData)
local WeaponData    = require(game.ReplicatedStorage.Modules.Data.WeaponData)
local TagManager    = require(game.ReplicatedStorage.Modules.Managers.TagManager)

local DAMAGE_MULTIPLIERS = { UNARMED = 1.0, KATANA = 1.5 }
local COMBO_CONFIG       = { RESET_DELAY = 1.5, MAX_COUNT = 5 }

function CombatController.new(characterController)
	local self = setmetatable({}, CombatController)

	self.CC           = characterController
	self.Character    = characterController.Character
	self.WeaponManager = WeaponManager.new(self.Character)
	self.HitboxManager = HitboxManager.new()

	self.CurrentWeapon       = nil
	self.ComboCount          = 0
	self.ComboResetTimer     = 0
	self.QueuedAttack        = false
	self.CanQueueNextAttack  = false
	self._isEquipping        = false
	self._slideAttackTime    = 0
	self._runAttackTime      = 0
	self.IsRunAttacking      = false

	self.Character:SetAttribute("IsEquipped", false)
	self.Character:SetAttribute("WeaponDamageMultiplier", DAMAGE_MULTIPLIERS.UNARMED)

	self._remoteConnections = {}
	self:SetupRemoteListeners()

	return self
end

function CombatController:Update(dt)
	if self.ComboResetTimer > 0 then
		self.ComboResetTimer -= dt
		if self.ComboResetTimer <= 0 then
			self:ResetCombo()
		end
	end
end

-- ===== EQUIP / UNEQUIP =====
function CombatController:EquipWeapon(weaponName)
	weaponName = weaponName or "Katana"
	if self._isEquipping or self.Character:GetAttribute("IsEquipped") then return end

	local sm = self.CC.StateMachine
	local inIdle   = sm:IsInState("Idle")
	local inCrouch = sm:IsInState("Slide") and self.Character:GetAttribute("IsCrouching")
	if not (inIdle or inCrouch) then return end

	self._isEquipping = true

	local wasSprinting        = self.CC.MovementController.IsSprinting
	local wasSprintAnimPlaying = self.CC.MovementController._sprintAnimPlaying

	if wasSprintAnimPlaying then
		self.CC.MovementController:StopSprintAnimation()
	end

	self.CurrentWeapon = weaponName
	self.Character:SetAttribute("IsEquipped", true)
	self.Character:SetAttribute("WeaponDamageMultiplier", DAMAGE_MULTIPLIERS.KATANA)
	CombatRemotes.WeaponEquipped:FireServer(weaponName)

	self.CC.AnimationManager:Play(weaponName .. "_WeaponIdle", 0.15)
	local equipTracks = self.CC.AnimationManager:Play(weaponName .. "_Equip")

	if wasSprinting and self.CC.MovementController.IsMoving then
		task.wait(0.1)
		self.CC.MovementController._wasSprintingLastFrame = false
		self.CC.MovementController:StartSprintAnimation()
	end

	local keyframeHandled = false
	if equipTracks and equipTracks[1] then
		local track = equipTracks[1]
		local connection
		connection = track:GetMarkerReachedSignal("Weld"):Connect(function()
			if not keyframeHandled then
				keyframeHandled = true
				self.WeaponManager:WeldToHand()
				self._isEquipping = false
				connection:Disconnect()
			end
		end)
	else
		self._isEquipping = false
	end
end

function CombatController:UnequipWeapon()
	if self._isEquipping or not self.Character:GetAttribute("IsEquipped") then return end

	local sm = self.CC.StateMachine
	local inIdle   = sm:IsInState("Idle")
	local inCrouch = sm:IsInState("Slide") and self.Character:GetAttribute("IsCrouching")
	if not (inIdle or inCrouch) then return end

	self._isEquipping = true

	local wasSprinting        = self.CC.MovementController.IsSprinting
	local wasSprintAnimPlaying = self.CC.MovementController._sprintAnimPlaying

	if wasSprintAnimPlaying then
		self.CC.MovementController:StopSprintAnimation()
	end

	self.Character:SetAttribute("IsEquipped", false)
	self.Character:SetAttribute("WeaponDamageMultiplier", DAMAGE_MULTIPLIERS.UNARMED)
	CombatRemotes.WeaponUnequipped:FireServer()

	local weaponName   = self.CurrentWeapon
	local unequipTracks = self.CC.AnimationManager:Play(weaponName .. "_Unequip")

	if wasSprinting and self.CC.MovementController.IsMoving then
		task.wait(0.1)
		self.CC.MovementController._wasSprintingLastFrame = false
		self.CC.MovementController:StartSprintAnimation()
	end

	local keyframeFired = false
	local connection
	if unequipTracks and unequipTracks[1] then
		local track = unequipTracks[1]
		connection = track:GetMarkerReachedSignal("Weld"):Connect(function()
			if not keyframeFired then
				keyframeFired = true
				self.WeaponManager:WeldToBody()
				self.CC.AnimationManager:Stop(weaponName .. "_WeaponIdle")
				self.CC.AnimationManager:StopAll(0.2, false)
				self.CC.MovementController._sprintAnimPlaying = false
				self.CC.MovementController._wasSprintingLastFrame = false
				self.CurrentWeapon = nil
				self._isEquipping = false
				connection:Disconnect()
			end
		end)
	else
		self._isEquipping = false
	end

	task.delay(1.5, function()
		if not keyframeFired and self.CurrentWeapon == weaponName then
			if connection then connection:Disconnect() end
			self.WeaponManager:WeldToBody()
			self.CC.AnimationManager:Stop(weaponName .. "_WeaponIdle")
			self.CC.AnimationManager:StopAll(0.2, false)
			self.CC.MovementController._sprintAnimPlaying = false
			self.CC.MovementController._wasSprintingLastFrame = false
			self.CurrentWeapon = nil
			self._isEquipping = false
		end
	end)
end

-- ===== BASIC ATTACK =====
function CombatController:PerformBasicAttack()
	if not self.CurrentWeapon or not self.WeaponManager:IsWeaponEquipped() then return end

	local stateMachine = self.CC.StateMachine
	if stateMachine:IsInState("Hitstun") or stateMachine:IsInState("KnockedOut") then return end
	if self.IsRunAttacking then return end

	if stateMachine:IsInState("Attack") then
		if self.CanQueueNextAttack and not self.QueuedAttack then
			self.QueuedAttack = true
		end
		return
	end

	if not stateMachine:IsInState("Idle") then return end

	-- Run attack when sprinting
	if self.CC.MovementController.IsSprinting then
		self:PerformRunAttack()
		return
	end

	self:AdvanceCombo()
	local attackAnim  = "Attack" .. self.ComboCount
	local weapon      = self.CurrentWeapon
	local attackTracks = self.CC.AnimationManager:Play(weapon .. "_" .. attackAnim, 0.1, true)
	local attackTrack  = attackTracks and attackTracks[1] or nil

	stateMachine:SetState("Attack", {
		attackType = "BasicAttack",
		comboIndex = self.ComboCount,
		endlag     = 0.2,
		track      = attackTrack,
	})

	CombatRemotes.SkillRequest:FireServer("BasicAttack", self.ComboCount)
end

-- ===== RUN ATTACK =====
function CombatController:PerformRunAttack()
	if tick() < self._runAttackTime then return end
	self._runAttackTime = tick() + 1.0

	local rootPart = self.CC.RootPart
	local weapon   = self.CurrentWeapon

	-- Lock onto the direction the character is currently facing
	local look   = rootPart.CFrame.LookVector
	local runDir = Vector3.new(look.X, 0, look.Z).Unit
	local startSpeed = self.CC.MovementController.Humanoid.WalkSpeed

	-- Stop sprint so MovementController doesn't fight the locked direction
	self.CC.MovementController:ForceStopSprintAnimation()
	self.CC.MovementController.IsSprinting = false
	self.CC.InputController:ResetSprint()

	self.IsRunAttacking = true
	self.CC.Humanoid.AutoRotate = false

	local tracks = self.CC.AnimationManager:Play(weapon .. "_RunAttack", 0.05, true)
	local track  = tracks and tracks[1] or nil
	local attackDuration = (track and track.Length) or 0.7

	CombatRemotes.SkillRequest:FireServer("RunAttack")

	-- Initial lunge burst
	local LUNGE_BOOST = 15
	local curVel = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(
		runDir.X * (startSpeed + LUNGE_BOOST),
		curVel.Y,
		runDir.Z * (startSpeed + LUNGE_BOOST)
	)

	-- Decelerate from boosted speed to 0 over the attack duration
	local boostedSpeed = startSpeed + LUNGE_BOOST
	local elapsed = 0
	local RunService = game:GetService("RunService")
	local momentumConn
	momentumConn = RunService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt
		local t = math.min(elapsed / attackDuration, 1)
		local speed = boostedSpeed * (1 - t)
		local vel   = runDir * speed
		local cv    = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, cv.Y, vel.Z)
		if t >= 1 then
			momentumConn:Disconnect()
			momentumConn = nil
		end
	end)

	-- Hitbox
	local hitFired = false
	if track then
		local conn
		conn = track:GetMarkerReachedSignal("Hit"):Connect(function()
			if not hitFired then
				hitFired = true
				CombatRemotes.CreateHitbox:FireServer("RunAttack", 1)
				conn:Disconnect()
			end
		end)
		task.delay(attackDuration * 0.9, function()
			if not hitFired then
				hitFired = true
				CombatRemotes.CreateHitbox:FireServer("RunAttack", 1)
			end
		end)
	else
		task.delay(0.3, function()
			if not hitFired then
				hitFired = true
				CombatRemotes.CreateHitbox:FireServer("RunAttack", 1)
			end
		end)
	end

	task.delay(attackDuration, function()
		self.IsRunAttacking = false
		self.CC.Humanoid.AutoRotate = true
		if momentumConn then
			momentumConn:Disconnect()
			momentumConn = nil
		end
	end)
end

-- ===== SLIDE ATTACK =====
function CombatController:PerformSlideAttack()
	if not self.CurrentWeapon or not self.WeaponManager:IsWeaponEquipped() then return end

	local stateMachine = self.CC.StateMachine
	if not stateMachine:IsInState("Slide") then return end

	local slideState = stateMachine.States["Slide"]
	if not slideState or not slideState.IsSliding then return end

	if TagManager.HasTag(self.Character, "Hitstunned") or TagManager.HasTag(self.Character, "KnockedOut") then return end

	if tick() < self._slideAttackTime then return end
	self._slideAttackTime = tick() + 1.0

	-- Lock slide so it doesn't end mid-attack
	slideState:SetAttacking(true)

	local weapon = self.CurrentWeapon
	local tracks = self.CC.AnimationManager:Play(weapon .. "_SlideAttack", 0.05, true)
	local track  = tracks and tracks[1] or nil

	CombatRemotes.SkillRequest:FireServer("SlideAttack")

	local attackDuration = (track and track.Length) or 0.8

	local hitFired = false
	if track then
		local conn
		conn = track:GetMarkerReachedSignal("Hit"):Connect(function()
			if not hitFired then
				hitFired = true
				CombatRemotes.CreateHitbox:FireServer("SlideAttack", 1)
				conn:Disconnect()
			end
		end)
		task.delay(attackDuration * 0.9, function()
			if not hitFired then
				hitFired = true
				CombatRemotes.CreateHitbox:FireServer("SlideAttack", 1)
			end
		end)
	else
		task.delay(0.3, function()
			if not hitFired then
				hitFired = true
				CombatRemotes.CreateHitbox:FireServer("SlideAttack", 1)
			end
		end)
	end

	-- Release the slide lock when the animation finishes
	task.delay(attackDuration, function()
		slideState:SetAttacking(false)
	end)
end

-- ===== CRITICAL ATTACK =====
-- R key calls this. It checks the AltCrit attribute to decide which phase to execute.
-- Phase 1 is the opener — plays Phase1 animation, fires Phase 1 to server.
-- Phase 2 is the follow-up — only available if Phase 1 landed (AltCrit = true).
function CombatController:PerformCriticalAttack()
	if not self.CurrentWeapon or not self.WeaponManager:IsWeaponEquipped() then return end

	local stateMachine = self.CC.StateMachine
	if stateMachine:IsInState("Hitstun") or stateMachine:IsInState("KnockedOut") then return end
	if not stateMachine:IsInState("Idle") then return end

	local weapon   = self.CurrentWeapon
	local critData = WeaponData:GetCritical(weapon)
	if not critData then
		warn("[CombatController] No critical defined for weapon:", weapon)
		return
	end

	local isMultiPhase = #critData.Phases > 1
	local hasAltCrit   = self.Character:GetAttribute("AltCrit") == true

	-- Determine which phase to execute
	-- animKey action must match a key in WEAPON_ANIMATION_PATHS
	local phase     = 1
	local animKey   = weapon .. "_Critical"
	local skillName = weapon .. "Critical"  -- e.g. "KatanaCritical"

	if isMultiPhase and hasAltCrit then
		phase     = 2
		animKey   = weapon .. "_CriticalAlt"
		skillName = weapon .. "CriticalAlt"  -- e.g. "KatanaCriticalAlt"
	end

	-- Play the animation
	local critTracks = self.CC.AnimationManager:Play(animKey, 0, true)
	local critTrack  = critTracks and critTracks[1] or nil

	-- Enter attack state — pass skillName so AttackState:CreateHitbox sends the right remote
	stateMachine:SetState("Attack", {
		attackType    = "CriticalAttack",
		skillName     = skillName,
		criticalPhase = phase,
		endlag        = 0.4,
		track         = critTrack,
	})

	CombatRemotes.SkillRequest:FireServer(skillName)
end

-- ===== COMBO LOGIC =====
function CombatController:ResetCombo()
	self.ComboCount         = 0
	self.CanQueueNextAttack = false
	self.QueuedAttack       = false
end

function CombatController:AdvanceCombo()
	self.ComboCount = self.ComboCount + 1
	if self.ComboCount > COMBO_CONFIG.MAX_COUNT then self.ComboCount = 1 end
	self.ComboResetTimer    = COMBO_CONFIG.RESET_DELAY
	self.CanQueueNextAttack = false
	self.QueuedAttack       = false
end

-- ===== STATUS EFFECTS =====
function CombatController:ApplyHitstun(duration)
	if self.CC:IsInvulnerable() then return end

	TagManager.AddTag(self.Character, "Hitstunned", duration)

	-- If blocking, stay in Block state — BlockImpact handles the reaction visually
	if self.CC.StateMachine:IsInState("Block") then return end

	self.CC:PlayAnimation("Hitstun")

	if not self.CC.StateMachine:IsInState("Hitstun") then
		self.CC.StateMachine:SetState("Hitstun", { duration = duration })
	end
end

-- ===== REMOTE LISTENERS =====
function CombatController:SetupRemoteListeners()
	local hitstunConn = CombatRemotes.ApplyHitstun.OnClientEvent:Connect(function(target, duration)
		if target == self.Character then
			self:ApplyHitstun(duration)
		end
	end)
	table.insert(self._remoteConnections, hitstunConn)

	local dodgeConn = CombatRemotes.DodgeSuccess.OnClientEvent:Connect(function(target)
		if target ~= self.Character then return end
		if not self.CC.StateMachine:IsInState("Dodge") then return end

		local dodgeState = self.CC.StateMachine.States["Dodge"]
		if dodgeState and dodgeState.OnDodgeSuccess then
			dodgeState:OnDodgeSuccess()
		end
	end)
	table.insert(self._remoteConnections, dodgeConn)

	local parryConn = CombatRemotes.ParrySuccess.OnClientEvent:Connect(function(target)
		if target ~= self.Character then return end
		if not self.CC.StateMachine:IsInState("Block") then return end

		local blockState = self.CC.StateMachine.States["Block"]
		if blockState and blockState.OnParrySuccess then
			blockState:OnParrySuccess()
		end
	end)
	table.insert(self._remoteConnections, parryConn)

	local gotParriedConn = CombatRemotes.GotParried.OnClientEvent:Connect(function(target)
		if target ~= self.Character then return end

		self.CC.AnimationManager:StopAll(0.05, false)

		local weapon = self.CurrentWeapon
		if weapon and self.Character:GetAttribute("IsEquipped") then
			self.CC.AnimationManager:Play(weapon .. "_Parried", 0.05)
		end
	end)
	table.insert(self._remoteConnections, gotParriedConn)
end

function CombatController:Destroy()
	for _, conn in ipairs(self._remoteConnections) do
		conn:Disconnect()
	end
	self._remoteConnections = {}

	self.WeaponManager:Destroy()
	self.HitboxManager:Destroy()
end

return CombatController
