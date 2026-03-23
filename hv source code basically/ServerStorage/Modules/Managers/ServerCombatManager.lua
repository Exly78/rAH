-- ServerStorage.Modules.Managers.ServerCombatManager

local ServerCombatManager = {}
ServerCombatManager.__index = ServerCombatManager

local Players      = game:GetService("Players")
local CombatRemotes = require(game.ServerStorage.Modules.Remotes.CombatRemotes)
local SkillData    = require(game.ReplicatedStorage.Modules.Data.SkillData)
local WeaponData   = require(game.ReplicatedStorage.Modules.Data.WeaponData)
local TagManager   = require(game.ReplicatedStorage.Modules.Managers.TagManager)

-- ===== CONSTANTS =====
local COOLDOWN_CONFIG = {
	GLOBAL_SKILL    = 0.15,
	BASIC_ATTACK    = 0.08,
	CRITICAL_ATTACK = 1.0,
	DODGE           = 0.5,
}

local DAMAGE_CONFIG = {
	BASE_DAMAGE              = 10,
	BLOCK_REDUCTION          = 0.5,
	MIN_MULTIPLIER           = 0.5,
	DEFENSE_DOWN_MULTIPLIER  = 0.3,
	STRENGTH_UP_MULTIPLIER   = 1.5,
}

local VALIDATION_CONFIG = {
	MAX_HITBOX_TOLERANCE = 5,
	MAX_SKILL_SPAM_RATE  = 3,
	MAX_COMBO_COUNT      = 5,
}

-- ===== CONSTRUCTOR =====
function ServerCombatManager.new(healthManager, statusManager)
	local self = setmetatable({}, ServerCombatManager)

	self.HealthManager = healthManager
	self.StatusManager = statusManager  

	self.ActiveSkills          = {}
	self.SkillCooldowns        = {}
	self.SpamDetection         = {}
	self.ComboTracking         = {}
	self.InitializedCharacters = {}
	self.LastPostureDamage     = {}

	print("[ServerCombatManager] Initialized")

	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = tick()
			for character, _ in pairs(self.InitializedCharacters) do
				local lastHit = self.LastPostureDamage[character] or 0
				if now - lastHit >= 5 then
					local currentPosture = character:GetAttribute("Posture") or 0
					if currentPosture > 0 then
						character:SetAttribute("Posture", math.max(0, currentPosture - 5))
					end
				end
			end
		end
	end)

	return self
end

function ServerCombatManager:SetStatusManager(statusManager)
	self.StatusManager = statusManager
end

-- ===== CHARACTER INITIALIZATION =====
function ServerCombatManager:InitializeCharacter(character)
	if self.InitializedCharacters[character] then return end

	character:SetAttribute("EquippedWeapon",        nil)
	character:SetAttribute("CurrentWeapon",          nil)
	character:SetAttribute("IsEquipped",             false)
	character:SetAttribute("WeaponDamageMultiplier", 1.0)
	character:SetAttribute("Posture",                0)
	character:SetAttribute("MaxPosture",             100)

	if self.HealthManager then
		self.HealthManager:RegisterCharacter(character)
	end

	if self.StatusManager then
		self.StatusManager:RegisterCharacter(character)
	end

	TagManager.Initialize(character)
	self.InitializedCharacters[character] = true

	print("[ServerCombatManager] Initialized character: " .. character.Name)

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:CleanupCharacter(character)
		end
	end)
end

function ServerCombatManager:SetupPlayerListeners()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			character:SetAttribute("EquippedWeapon", nil)
			self:InitializeCharacter(character)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character:SetAttribute("EquippedWeapon", nil)
			self:InitializeCharacter(player.Character)
		end
	end
end

function ServerCombatManager:CleanupCharacter(character)
	TagManager.Cleanup(character)

	if self.HealthManager then
		self.HealthManager:CleanupCharacter(character)
	end

	if self.StatusManager then
		self.StatusManager:RemoveAll(character)
	end

	self.InitializedCharacters[character] = nil
	self.LastPostureDamage[character]     = nil

	print("[ServerCombatManager] Cleaned up character: " .. character.Name)
end

-- ===== SKILL REQUEST VALIDATION =====
function ServerCombatManager:RequestSkill(player, skillName, comboIndex)
	if not self:CheckSpamRate(player) then
		warn("[SERVER] " .. player.Name .. " is spamming skills - potential exploit")
		player:Kick("Skill spam detected")
		return {success = false, reason = "RateLimited"}
	end

	local character = player.Character
	if not character then
		return {success = false, reason = "NoCharacter"}
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return {success = false, reason = "Dead"}
	end

	if self.HealthManager and self.HealthManager:IsDead(character) then
		return {success = false, reason = "Dead"}
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return {success = false, reason = "NoRootPart"}
	end

	self:InitializeCharacter(character)

	if not self:CanPerformSkill(character, skillName) then
		return {success = false, reason = "InvalidState"}
	end

	if skillName == "BasicAttack" then
		return self:ValidateBasicAttack(player, character, comboIndex)
	end

	local skill = SkillData:GetSkill(skillName)
	if not skill then
		warn("[SERVER] " .. player.Name .. " requested unknown skill: " .. tostring(skillName))
		return {success = false, reason = "SkillNotFound"}
	end

	if not self:CheckCooldown(player, skillName) then
		return {success = false, reason = "OnCooldown"}
	end

	if skill.Cost and skill.Cost > 0 then
		local currentResource = character:GetAttribute("Mana") or 0
		if currentResource < skill.Cost then
			return {success = false, reason = "InsufficientResources"}
		end
	end

	self:RecordSkillUsage(player, skillName)
	self:SetCooldown(player, skillName, skill.Cooldown)

	if skill.Cost and skill.Cost > 0 then
		local currentResource = character:GetAttribute("Mana") or 0
		character:SetAttribute("Mana", math.max(0, currentResource - skill.Cost))
	end

	print("[SERVER] " .. player.Name .. " cast " .. skillName)
	return {success = true, skill = skill}
end

-- ===== BASIC ATTACK VALIDATION =====
function ServerCombatManager:ValidateBasicAttack(player, character, comboIndex)
	local weaponName = character:GetAttribute("EquippedWeapon")
	print("[DEBUG SERVER] EquippedWeapon value:", weaponName)

	if not weaponName then
		warn("[SERVER] " .. player.Name .. " tried BasicAttack without weapon")
		return {success = false, reason = "NoWeapon"}
	end

	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then
		warn("[SERVER] Unknown weapon: " .. weaponName)
		return {success = false, reason = "InvalidWeapon"}
	end

	if comboIndex then
		if comboIndex < 1 or comboIndex > VALIDATION_CONFIG.MAX_COMBO_COUNT then
			warn("[SERVER] " .. player.Name .. " sent invalid combo index: " .. comboIndex)
			return {success = false, reason = "InvalidCombo"}
		end

		if not self:ValidateComboSequence(player, comboIndex) then
			warn("[SERVER] " .. player.Name .. " sent out-of-sequence combo: " .. comboIndex)
			return {success = false, reason = "ComboSequenceInvalid"}
		end
	end

	if not self:CheckCooldown(player, "BasicAttack") then
		return {success = false, reason = "OnCooldown"}
	end

	self:RecordSkillUsage(player, "BasicAttack")
	self:SetCooldown(player, "BasicAttack", COOLDOWN_CONFIG.BASIC_ATTACK)

	if comboIndex then
		self:UpdateComboTracking(player, comboIndex)
	end

	print("[SERVER] " .. player.Name .. " BasicAttack [" .. weaponName .. "] Combo " .. (comboIndex or "1"))
	return { success = true, weapon = weapon, comboIndex = comboIndex or 1 }
end

-- ===== COMBO TRACKING =====
function ServerCombatManager:ValidateComboSequence(player, comboIndex)
	local comboData = self.ComboTracking[player.UserId]

	if not comboData then
		return comboIndex == 1
	end

	if tick() - comboData.lastComboTime > 1.5 then
		return comboIndex == 1
	end

	local expectedNext = comboData.comboCount + 1
	if expectedNext > VALIDATION_CONFIG.MAX_COMBO_COUNT then
		expectedNext = 1
	end

	return comboIndex == expectedNext or comboIndex == 1
end

function ServerCombatManager:UpdateComboTracking(player, comboIndex)
	self.ComboTracking[player.UserId] = {
		comboCount    = comboIndex,
		lastComboTime = tick(),
	}
end

-- ===== STATE VALIDATION =====
function ServerCombatManager:CanPerformSkill(character, skillName)
	if TagManager.HasTag(character, "Hitstunned") then return false end
	if TagManager.HasTag(character, "KnockedOut")  then return false end
	if TagManager.HasTag(character, "Stunned")     then return false end

	if skillName == "Dodge" then
		return not TagManager.HasTag(character, "DodgeDisabled")
	end

	return true
end

-- ===== COOLDOWN SYSTEM =====
function ServerCombatManager:CheckCooldown(player, skillName)
	local userId   = player.UserId
	local cooldowns = self.SkillCooldowns[userId]
	if not cooldowns then
		self.SkillCooldowns[userId] = {}
		return true
	end

	local now = tick()
	if cooldowns[skillName] and now < cooldowns[skillName] then return false end
	if cooldowns["__global"] and now < cooldowns["__global"] then return false end
	return true
end

function ServerCombatManager:SetCooldown(player, skillName, cooldownDuration)
	local userId = player.UserId
	if not self.SkillCooldowns[userId] then
		self.SkillCooldowns[userId] = {}
	end

	local now = tick()
	self.SkillCooldowns[userId][skillName]   = now + (cooldownDuration or COOLDOWN_CONFIG.GLOBAL_SKILL)
	self.SkillCooldowns[userId]["__global"]  = now + COOLDOWN_CONFIG.GLOBAL_SKILL
end

function ServerCombatManager:RecordSkillUsage(player, skillName)
	self.ActiveSkills[player.UserId] = { skillName = skillName, timestamp = tick() }
end

-- ===== SPAM DETECTION =====
function ServerCombatManager:CheckSpamRate(player)
	local userId      = player.UserId
	local currentTime = tick()
	local spamData    = self.SpamDetection[userId]

	if not spamData then
		self.SpamDetection[userId] = { count = 1, windowStart = currentTime }
		return true
	end

	if currentTime - spamData.windowStart >= 1.0 then
		spamData.count       = 1
		spamData.windowStart = currentTime
		return true
	end

	spamData.count += 1

	if spamData.count > VALIDATION_CONFIG.MAX_SKILL_SPAM_RATE then
		warn("[SERVER] " .. player.Name .. " exceeded spam rate limit!")
		return false
	end

	return true
end

-- ===== ATTACK TYPE RESOLUTION =====
-- Returns a table describing what defensive options are available for this attack.
-- All fields default to true (= allowed) unless the AttackType restricts them.
--   canParry  : parry window absorbs the hit
--   canBlock  : blocking reduces/nullifies damage
--   canDodge  : dodge invulnerability frames apply
--   blockBreak: attacking through a block/parry triggers an instant block-break
--   hitsAirborne  : attack connects against airborne targets (JumpOnly = false)
--   hitsGrounded  : attack connects against grounded targets (CrouchOnly = false when crouching)
local COUNTER_WINDOW_DEFAULT = 0.3  -- seconds from AttackStartTime that parry is valid

function ServerCombatManager:ResolveAttackType(damageData)
	local attackType = damageData.AttackType or "Default"
	local now        = tick()

	-- Default: everything allowed
	local opts = {
		canParry       = true,
		canBlock       = true,
		canDodge       = true,
		blockBreak     = false,
		hitsAirborne   = true,
		hitsCrouching  = true,
	}

	if attackType == "Default" then
		

	elseif attackType == "BlockBreak" then
		opts.canParry   = false
		opts.canBlock   = false
		opts.blockBreak = true

	elseif attackType == "Unparryable" then
		opts.canParry = false

	elseif attackType == "ParryOnly" then
		opts.canBlock = false
		opts.canDodge = false

	elseif attackType == "DodgeOnly" then
		opts.canParry = false
		opts.canBlock = false

	elseif attackType == "BlockOnly" then
		opts.canParry = false
		opts.canDodge = false

	elseif attackType == "HitboxOnly" then
	
		opts.canParry = false
		opts.canBlock = false
		opts.canDodge = false

	elseif attackType == "CrouchOnly" then
		opts.hitsCrouching = false

	elseif attackType == "JumpOnly" then
		opts.hitsAirborne = false

	elseif attackType == "CounterWindow" then
		local startTime      = damageData.AttackStartTime or now
		local windowDuration = damageData.CounterWindowDuration or COUNTER_WINDOW_DEFAULT
		local elapsed        = now - startTime

		if elapsed <= windowDuration then
			opts.canBlock = false
			opts.canDodge = false
		else
			opts.canParry = false
			opts.canBlock = false
			opts.canDodge = false
		end
	end

	return opts
end

function ServerCombatManager:ApplyBlockBreak(attacker, target, damageData)
	local baseDamage      = damageData.Damage or DAMAGE_CONFIG.BASE_DAMAGE
	local breakBonus      = damageData.BlockBreakDamage or 0
	local totalDamage     = baseDamage + breakBonus
	local multiplier      = self:GetDamageMultiplier(attacker, target)
	local finalDamage     = math.floor(totalDamage * multiplier)

	TagManager.RemoveTag(target, "IsBlocking")
	TagManager.RemoveTag(target, "Blocking")
	TagManager.RemoveTag(target, "CanParry")
	TagManager.RemoveTag(target, "Parrying")

	TagManager.AddTag(target, "BlockBroken", 2.0)
	TagManager.AddTag(target, "Hitstunned",  2.0)

	local maxPosture = target:GetAttribute("MaxPosture") or 100
	target:SetAttribute("Posture", maxPosture)
	TagManager.AddTag(target, "PostureBroken", 2.0)
	self.LastPostureDamage[target] = tick()

	local dmgResult = self.HealthManager:TakeDamage(target, finalDamage)

	print("[SERVER] " .. target.Name .. " BLOCK BROKEN by " .. attacker.Name .. " for " .. finalDamage)
	CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "BlockBroken", finalDamage)

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer then
		CombatRemotes.ApplyHitstun:FireClient(targetPlayer, target, 2.0)
		CombatRemotes.BlockBroken:FireClient(targetPlayer, target)
	end

	return {hit = true, hitType = "BlockBroken", damage = finalDamage, died = dmgResult.died}
end

local function IsAirborne(target)
	local humanoid = target:FindFirstChild("Humanoid")
	if not humanoid then return false end
	return humanoid.FloorMaterial == Enum.Material.Air
end

local function IsCrouching(target)
	return TagManager.HasTag(target, "Crouching") or (target:GetAttribute("IsCrouching") == true)
end

-- ===== DAMAGE APPLICATION =====
function ServerCombatManager:ApplyDamage(attacker, target, damageData)
	local targetHumanoid = target:FindFirstChild("Humanoid")
	if not targetHumanoid then
		return {hit = false, reason = "TargetDead"}
	end

	if self.HealthManager and self.HealthManager:IsDead(target) then
		return {hit = false, reason = "TargetDead"}
	end

	damageData = damageData or {}
	local baseDamage = damageData.Damage or DAMAGE_CONFIG.BASE_DAMAGE

	-- ===== RESOLVE ATTACK TYPE =====
	local attackOpts = self:ResolveAttackType(damageData)
	local attackType = damageData.AttackType or "Default"

	-- ===== POSITIONAL MISS CHECKS (CrouchOnly / JumpOnly) =====
	if not attackOpts.hitsCrouching and IsCrouching(target) then
		print("[SERVER] " .. target.Name .. " avoided CrouchOnly attack by crouching!")
		CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Missed", 0)
		return {hit = false, reason = "Missed"}
	end

	if not attackOpts.hitsAirborne and IsAirborne(target) then
		print("[SERVER] " .. target.Name .. " avoided JumpOnly attack by being airborne!")
		CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Missed", 0)
		return {hit = false, reason = "Missed"}
	end

	-- ===== INVULNERABILITY / DODGE CHECK =====
	if TagManager.HasTag(target, "Invulnerable") or TagManager.HasTag(target, "Dodging") then
		if attackOpts.canDodge then
			print("[SERVER] " .. target.Name .. " is invulnerable (dodging)")
			CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Dodged", 0)

			local currentPosture = target:GetAttribute("Posture") or 0
			if currentPosture > 0 then
				target:SetAttribute("Posture", math.max(0, currentPosture - 15))
			end

			local dodgerPlayer = Players:GetPlayerFromCharacter(target)
			if dodgerPlayer then
				CombatRemotes.DodgeSuccess:FireClient(dodgerPlayer, target)
			end

			return {hit = false, reason = "Dodged"}
		else

			print("[SERVER] " .. target.Name .. " dodge ignored by attack type: " .. attackType)
		end
	end

	-- ===== DIRECTIONAL CHECK =====
	local isFacingAttacker = true
	local attackerHRP = attacker:FindFirstChild("HumanoidRootPart")
	local targetHRP   = target:FindFirstChild("HumanoidRootPart")

	if attackerHRP and targetHRP then
		local attackerFlat = Vector3.new(attackerHRP.Position.X, 0, attackerHRP.Position.Z)
		local targetFlat   = Vector3.new(targetHRP.Position.X,   0, targetHRP.Position.Z)

		if (attackerFlat - targetFlat).Magnitude > 0.001 then
			local toAttacker = (attackerFlat - targetFlat).Unit
			local lookFlat   = Vector3.new(targetHRP.CFrame.LookVector.X, 0, targetHRP.CFrame.LookVector.Z).Unit
			if lookFlat:Dot(toAttacker) < 0 then
				isFacingAttacker = false
			end
		end
	end

	-- ===== PARRY CHECK =====
	if TagManager.HasTag(target, "CanParry") and isFacingAttacker then
		if attackOpts.blockBreak then
			print("[SERVER] " .. target.Name .. " parry BROKEN by BlockBreak attack!")
			return self:ApplyBlockBreak(attacker, target, damageData)

		elseif attackOpts.canParry then
			print("[SERVER] " .. target.Name .. " PARRIED the attack!")
			CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Parried", 0)

			TagManager.AddTag(attacker, "Hitstunned", 1.0)

			local currentTargetPosture = target:GetAttribute("Posture") or 0
			if currentTargetPosture > 0 then
				target:SetAttribute("Posture", math.max(0, currentTargetPosture - 25))
			end

			local attackerPosture    = attacker:GetAttribute("Posture") or 0
			local attackerMaxPosture = attacker:GetAttribute("MaxPosture") or 100
			local newAttackerPosture = math.min(attackerMaxPosture, attackerPosture + 25)
			attacker:SetAttribute("Posture", newAttackerPosture)
			self.LastPostureDamage[attacker] = tick()

			if newAttackerPosture >= attackerMaxPosture then
				print("[SERVER] " .. attacker.Name .. " posture broken by parry!")
				TagManager.AddTag(attacker, "PostureBroken", 2.0)
			end

			local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
			if attackerPlayer then
				CombatRemotes.ApplyHitstun:FireClient(attackerPlayer, attacker, 1.0)
				CombatRemotes.GotParried:FireClient(attackerPlayer, attacker)
			end

			local defenderPlayer = Players:GetPlayerFromCharacter(target)
			if defenderPlayer then
				CombatRemotes.ParrySuccess:FireClient(defenderPlayer, target)
			end

			return {hit = false, reason = "Parried"}
		end
	end

	-- ===== BLOCK CHECK =====
	if TagManager.HasTag(target, "IsBlocking") and isFacingAttacker then
		if attackOpts.blockBreak then
			print("[SERVER] " .. target.Name .. " block BROKEN by BlockBreak attack!")
			return self:ApplyBlockBreak(attacker, target, damageData)

		elseif attackOpts.canBlock then
			local finalDamage    = damageData.ChipDamage or 0
			local blockDmgResult = {died = false}

			if finalDamage > 0 then
				blockDmgResult = self.HealthManager:TakeDamage(target, finalDamage)
			end

			print("[SERVER] " .. target.Name .. " blocked! Chip: " .. finalDamage)
			CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Blocked", finalDamage)

			if damageData.PostureDamage then
				local currentPosture = target:GetAttribute("Posture") or 0
				local maxPosture     = target:GetAttribute("MaxPosture") or 100
				local newPosture     = math.min(maxPosture, currentPosture + damageData.PostureDamage)
				target:SetAttribute("Posture", newPosture)
				self.LastPostureDamage[target] = tick()

				if newPosture >= maxPosture then
					print("[SERVER] " .. target.Name .. " posture broken while blocking!")
					TagManager.AddTag(target, "PostureBroken", 2.0)
					TagManager.RemoveTag(target, "IsBlocking")
				end
			end

			local blockHitstun = 0.2
			TagManager.AddTag(target, "Hitstunned", blockHitstun)

			local targetPlayer = Players:GetPlayerFromCharacter(target)
			if targetPlayer then
				CombatRemotes.ApplyHitstun:FireClient(targetPlayer, target, blockHitstun)
				CombatRemotes.BlockImpact:FireClient(targetPlayer, target)
			end

			return {hit = true, hitType = "Blocked", damage = finalDamage, died = blockDmgResult.died}
		end
	end

	-- ===== NORMAL HIT =====
	local multiplier = self:GetDamageMultiplier(attacker, target)

	if self.StatusManager then
		local hitResults = self.StatusManager:NotifyHit(target, { BaseDamage = baseDamage })
		if hitResults["Fracture"] then
			multiplier = multiplier * (hitResults["Fracture"].DamageMultiplier or 1)
		end
	end

	local finalDamage = math.floor(baseDamage * multiplier)
	local dmgResult   = self.HealthManager:TakeDamage(target, finalDamage)
	print("[SERVER] " .. attacker.Name .. " hit " .. target.Name .. " for " .. finalDamage .. " damage!")

	-- ===== HITSTUN =====
	local hitstunDuration = damageData.HitstunDuration or self:CalculateWeaponHitstun(attacker)
	TagManager.AddTag(target, "Hitstunned", hitstunDuration)

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer then
		CombatRemotes.ApplyHitstun:FireClient(targetPlayer, target, hitstunDuration)
	end

	-- ===== POSTURE DAMAGE =====
	if damageData.PostureDamage then
		local currentPosture = target:GetAttribute("Posture") or 0
		local maxPosture     = target:GetAttribute("MaxPosture") or 100
		local newPosture     = math.min(maxPosture, currentPosture + damageData.PostureDamage)
		target:SetAttribute("Posture", newPosture)
		self.LastPostureDamage[target] = tick()

		if newPosture >= maxPosture then
			print("[SERVER] " .. target.Name .. " posture broken!")
			TagManager.AddTag(target, "PostureBroken", 2.0)
		end
	end

	-- ===== APPLY STATUS EFFECTS via StatusManager =====
	if damageData.StatusEffects and self.StatusManager then
		for effectName, effectData in pairs(damageData.StatusEffects) do
			if effectData.Stacks or effectData.Count then
				self.StatusManager:Apply(target, effectName, {
					Stacks = effectData.Stacks or 0,
					Count  = effectData.Count  or 0,
				})
				print("[SERVER] Applied status " .. effectName .. " to " .. target.Name
					.. " (Stacks:" .. (effectData.Stacks or 0)
					.. " Count:"  .. (effectData.Count  or 0) .. ")")
			end
		end
	end

	if self.StatusManager then
		self.StatusManager:NotifyAction(attacker)
	end

	-- ===== KNOCKBACK =====
	if damageData.Knockback and damageData.Knockback > 0 then
		self:ApplyKnockback(attacker, target, damageData.Knockback)
	end

	-- ===== HIT CONFIRM =====
	CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Hit", finalDamage)

	return {
		hit             = true,
		hitType         = "Normal",
		damage          = finalDamage,
		hitstunDuration = hitstunDuration,
		died            = dmgResult.died,
	}
end

-- ===== DAMAGE CALCULATION =====
function ServerCombatManager:GetDamageMultiplier(attacker, target)
	local multiplier = 1.0

	multiplier = multiplier * (attacker:GetAttribute("WeaponDamageMultiplier") or 1.0)
	multiplier = multiplier * (target:GetAttribute("DefenseMultiplier") or 1.0)

	if TagManager.HasTag(target,   "DefenseDown") then multiplier = multiplier * (1.0 + DAMAGE_CONFIG.DEFENSE_DOWN_MULTIPLIER) end
	if TagManager.HasTag(attacker, "StrengthUp")  then multiplier = multiplier * DAMAGE_CONFIG.STRENGTH_UP_MULTIPLIER end

	return math.max(multiplier, DAMAGE_CONFIG.MIN_MULTIPLIER)
end

function ServerCombatManager:CalculateWeaponHitstun(attacker)
	local weaponName = attacker:GetAttribute("EquippedWeapon")
	if not weaponName then return 0.5 end
	local weapon = WeaponData:GetWeapon(weaponName)
	return (weapon and weapon.HitStunDuration) or 0.5
end

-- ===== KNOCKBACK =====
function ServerCombatManager:ApplyKnockback(attacker, target, knockbackForce)
	local targetRoot   = target:FindFirstChild("HumanoidRootPart")
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not attackerRoot then return end

	local direction    = (targetRoot.Position - attackerRoot.Position).Unit
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(50000, 0, 50000)
	bodyVelocity.Velocity = direction * knockbackForce
	bodyVelocity.Parent   = targetRoot

	task.delay(0.1, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)

	print("[SERVER] Applied knockback to " .. target.Name)
end

-- ===== HITBOX VALIDATION =====
function ServerCombatManager:ValidateHitbox(attacker, targetPosition, hitboxSize, hitboxOffset)
	if not attacker or not attacker:FindFirstChild("HumanoidRootPart") then
		warn("[SERVER] Invalid attacker in hitbox validation")
		return false
	end

	local attackerRoot = attacker.HumanoidRootPart
	local hitboxPos    = attackerRoot.Position + attackerRoot.CFrame.LookVector * hitboxOffset
	local distance     = (targetPosition - hitboxPos).Magnitude
	local maxDistance  = (hitboxSize / 2).Magnitude + VALIDATION_CONFIG.MAX_HITBOX_TOLERANCE

	if distance > maxDistance then
		warn("[SERVER] Suspicious hit rejected - Distance: " .. math.floor(distance) .. " (max: " .. math.floor(maxDistance) .. ")")
		return false
	end

	return true
end

-- ===== WEAPON DAMAGE DATA =====
function ServerCombatManager:GetWeaponDamageData(weaponName)
	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then return nil end

	return {
		Damage          = weapon.Damage,
		HitstunDuration = weapon.HitStunDuration,
		PostureDamage   = weapon.PostureDamage,
		StunDuration    = weapon.StunDuration,
		HitboxSize      = Vector3.new(
			weapon.HitboxProperties.Swing.Width,
			weapon.HitboxProperties.Swing.Height,
			weapon.HitboxProperties.Swing.Range
		),
		HitboxOffset = weapon.Range,
		Knockback    = weapon.WeaponType == "Heavy" and 20 or 5,
	}
end

-- ===== CLEANUP =====
function ServerCombatManager:Cleanup(player)
	local userId = player.UserId
	self.ActiveSkills[userId]   = nil
	self.SkillCooldowns[userId] = nil
	self.SpamDetection[userId]  = nil
	self.ComboTracking[userId]  = nil
	print("[ServerCombatManager] Cleaned up data for " .. player.Name)
end

function ServerCombatManager:Destroy()
	self.ActiveSkills          = {}
	self.SkillCooldowns        = {}
	self.SpamDetection         = {}
	self.ComboTracking         = {}
	self.InitializedCharacters = {}
	self.LastPostureDamage     = {}
	print("[ServerCombatManager] Destroyed")
end

return ServerCombatManager
