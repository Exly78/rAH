local ServerCombatManager = {}
ServerCombatManager.__index = ServerCombatManager

local Players = game:GetService("Players")
local CombatRemotes = require(game.ServerStorage.Modules.Remotes.CombatRemotes)
local SkillData = require(game.ReplicatedStorage.Modules.Data.SkillData)
local WeaponData = require(game.ReplicatedStorage.Modules.Data.WeaponData)
local TagManager = require(game.ReplicatedStorage.Modules.Managers.TagManager)

-- ===== CONSTANTS =====
local COOLDOWN_CONFIG = {
	GLOBAL_SKILL = 0.15,     -- Minimum time between any skills
	BASIC_ATTACK = 0.08,     -- Time between basic attacks (overridden by weapon SwingSpeed)
	CRITICAL_ATTACK = 1.0,   -- Critical attack cooldown
	DODGE = 0.5,             -- Dodge cooldown
}

local DAMAGE_CONFIG = {
	BASE_DAMAGE = 10,
	BLOCK_REDUCTION = 0.5,
	MIN_MULTIPLIER = 0.5,
	DEFENSE_DOWN_MULTIPLIER = 0.3,
	STRENGTH_UP_MULTIPLIER = 1.5,
}

local VALIDATION_CONFIG = {
	MAX_HITBOX_TOLERANCE = 5,  -- Extra studs allowed for latency
	MAX_SKILL_SPAM_RATE = 3,  -- Max skills per second before kick
	MAX_COMBO_COUNT = 5,       -- Maximum combo chain
}

-- ===== CONSTRUCTOR =====
function ServerCombatManager.new()
	local self = setmetatable({}, ServerCombatManager)

	-- Track active skills and cooldowns per player
	self.ActiveSkills = {}  -- [player.UserId] = {skillName, timestamp}
	self.SkillCooldowns = {}  -- [player.UserId] = {[skillName] = expiryTime}
	self.SpamDetection = {}  -- [player.UserId] = {count, windowStart}
	self.ComboTracking = {}  -- [player.UserId] = {comboCount, lastComboTime}

	-- Character initialization tracking
	self.InitializedCharacters = {}

	print("[ServerCombatManager] Initialized")

	return self
end

-- ===== CHARACTER INITIALIZATION =====
-- In ServerCombatManager, UPDATE this method:
function ServerCombatManager:InitializeCharacter(character)
	if self.InitializedCharacters[character] then
		return
	end

	character:SetAttribute("EquippedWeapon", nil)
	character:SetAttribute("CurrentWeapon", nil)
	character:SetAttribute("IsEquipped", false)
	character:SetAttribute("WeaponDamageMultiplier", 1.0)

	-- Then initialize TagManager
	TagManager.Initialize(character)
	self.InitializedCharacters[character] = true

	print("[ServerCombatManager] Initialized character: " .. character.Name)

	-- Cleanup on character removal
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

			-- Just initialize the ONE attribute that's causing issues
			character:SetAttribute("EquippedWeapon", nil)

			self:InitializeCharacter(character)
		end)
	end)

	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character:SetAttribute("EquippedWeapon", nil)
			self:InitializeCharacter(player.Character)
		end
	end
end
function ServerCombatManager:CleanupCharacter(character)
	TagManager.Cleanup(character)
	self.InitializedCharacters[character] = nil
	print("[ServerCombatManager] Cleaned up character: " .. character.Name)
end

-- ===== SKILL REQUEST VALIDATION =====
function ServerCombatManager:RequestSkill(player, skillName, comboIndex)
	-- Anti-spam detection
	if not self:CheckSpamRate(player) then
		warn("[SERVER] " .. player.Name .. " is spamming skills - potential exploit")
		player:Kick("Skill spam detected")
		return {success = false, reason = "RateLimited"}
	end

	-- Basic validation
	local character = player.Character
	if not character then
		return {success = false, reason = "NoCharacter"}
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return {success = false, reason = "Dead"}
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return {success = false, reason = "NoRootPart"}
	end

	-- Initialize character if needed
	self:InitializeCharacter(character)

	-- Check if character is in valid state
	if not self:CanPerformSkill(character, skillName) then
		return {success = false, reason = "InvalidState"}
	end

	-- Handle BasicAttack with weapon data
	if skillName == "BasicAttack" then
		return self:ValidateBasicAttack(player, character, comboIndex)
	end

	-- Skill existence check
	local skill = SkillData:GetSkill(skillName)
	if not skill then
		warn("[SERVER] " .. player.Name .. " requested unknown skill: " .. tostring(skillName))
		return {success = false, reason = "SkillNotFound"}
	end

	-- Cooldown check
	if not self:CheckCooldown(player, skillName) then
		return {success = false, reason = "OnCooldown"}
	end

	-- Resource cost check (mana, stamina, etc.)
	if skill.Cost and skill.Cost > 0 then
		local currentResource = character:GetAttribute("Mana") or 0
		if currentResource < skill.Cost then
			return {success = false, reason = "InsufficientResources"}
		end
	end

	-- All checks passed - record the skill usage
	self:RecordSkillUsage(player, skillName)
	self:SetCooldown(player, skillName, skill.Cooldown)

	-- Deduct resource cost
	if skill.Cost and skill.Cost > 0 then
		local currentResource = character:GetAttribute("Mana") or 0
		character:SetAttribute("Mana", math.max(0, currentResource - skill.Cost))
	end

	print("[SERVER] " .. player.Name .. " cast " .. skillName)

	return {success = true, skill = skill}
end
-- Handle weapon equip
CombatRemotes.WeaponEquipped.OnServerEvent:Connect(function(player, weaponName)
	local character = player.Character
	if not character then return end

	-- Validate weapon exists
	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then
		warn("[SERVER] Invalid weapon:", weaponName)
		return
	end

	character:SetAttribute("EquippedWeapon", weaponName)
	print("[SERVER]", player.Name, "equipped", weaponName)
end)

-- Handle weapon unequip
CombatRemotes.WeaponUnequipped.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end

	character:SetAttribute("EquippedWeapon", nil)
	print("[SERVER]", player.Name, "unequipped weapon")
end)
-- ===== BASIC ATTACK VALIDATION =====
function ServerCombatManager:ValidateBasicAttack(player, character, comboIndex)
	local userId = player.UserId

	-- Get equipped weapon
	local weaponName = character:GetAttribute("EquippedWeapon")
	print("[DEBUG SERVER] EquippedWeapon value:", weaponName)

	if not weaponName then
		warn("[SERVER] " .. player.Name .. " tried BasicAttack without weapon")
		return {success = false, reason = "NoWeapon"}
	end

	-- ADD THIS LINE - Actually get the weapon data!
	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then
		warn("[SERVER] Unknown weapon: " .. weaponName)
		return {success = false, reason = "InvalidWeapon"}
	end

	-- Validate combo index
	if comboIndex then
		if comboIndex < 1 or comboIndex > VALIDATION_CONFIG.MAX_COMBO_COUNT then
			warn("[SERVER] " .. player.Name .. " sent invalid combo index: " .. comboIndex)
			return {success = false, reason = "InvalidCombo"}
		end

		-- Validate combo sequence
		if not self:ValidateComboSequence(player, comboIndex) then
			warn("[SERVER] " .. player.Name .. " sent out-of-sequence combo: " .. comboIndex)
			return {success = false, reason = "ComboSequenceInvalid"}
		end
	end

	-- Check weapon swing speed cooldown
	local cooldown = weapon.SwingSpeed or COOLDOWN_CONFIG.BASIC_ATTACK
	if not self:CheckCooldown(player, "BasicAttack") then
		return {success = false, reason = "OnCooldown"}
	end

	-- Record usage and set cooldown
	self:RecordSkillUsage(player, "BasicAttack")
	self:SetCooldown(player, "BasicAttack", cooldown)

	-- Update combo tracking
	if comboIndex then
		self:UpdateComboTracking(player, comboIndex)
	end

	print("[SERVER] " .. player.Name .. " BasicAttack [" .. weaponName .. "] Combo " .. (comboIndex or "1"))

	return {
		success = true, 
		weapon = weapon,
		comboIndex = comboIndex or 1
	}
end

-- ===== COMBO TRACKING =====
function ServerCombatManager:ValidateComboSequence(player, comboIndex)
	local userId = player.UserId
	local comboData = self.ComboTracking[userId]

	if not comboData then
		-- First attack must be combo 1
		return comboIndex == 1
	end

	-- Check if combo expired (1.5 second window)
	if tick() - comboData.lastComboTime > 1.5 then
		-- Combo expired, must restart at 1
		return comboIndex == 1
	end

	-- Must be next in sequence or restart at 1
	local expectedNext = comboData.comboCount + 1
	if expectedNext > VALIDATION_CONFIG.MAX_COMBO_COUNT then
		expectedNext = 1
	end

	return comboIndex == expectedNext or comboIndex == 1
end

function ServerCombatManager:UpdateComboTracking(player, comboIndex)
	local userId = player.UserId

	self.ComboTracking[userId] = {
		comboCount = comboIndex,
		lastComboTime = tick()
	}
end

-- ===== STATE VALIDATION =====
function ServerCombatManager:CanPerformSkill(character, skillName)
	-- Check if character is hitstunned
	if TagManager.HasTag(character, "Hitstunned") then
		return false
	end

	-- Check if character is knocked out
	if TagManager.HasTag(character, "KnockedOut") then
		return false
	end

	-- Check if character is stunned
	if TagManager.HasTag(character, "Stunned") then
		return false
	end

	-- Allow dodge even during some states
	if skillName == "Dodge" then
		return not TagManager.HasTag(character, "DodgeDisabled")
	end

	return true
end

-- ===== COOLDOWN SYSTEM =====
function ServerCombatManager:CheckCooldown(player, skillName)
	local userId = player.UserId

	if not self.SkillCooldowns[userId] then
		self.SkillCooldowns[userId] = {}
		return true
	end

	local cooldowns = self.SkillCooldowns[userId]
	local currentTime = tick()

	-- Check skill-specific cooldown
	if cooldowns[skillName] and currentTime < cooldowns[skillName] then
		return false
	end

	-- Check global cooldown
	if cooldowns["__global"] and currentTime < cooldowns["__global"] then
		return false
	end

	return true
end

function ServerCombatManager:SetCooldown(player, skillName, cooldownDuration)
	local userId = player.UserId

	if not self.SkillCooldowns[userId] then
		self.SkillCooldowns[userId] = {}
	end

	local cooldowns = self.SkillCooldowns[userId]
	local currentTime = tick()

	-- Set skill-specific cooldown
	local skillCooldown = cooldownDuration or COOLDOWN_CONFIG.GLOBAL_SKILL
	cooldowns[skillName] = currentTime + skillCooldown

	-- Set global cooldown (shorter than skill-specific)
	cooldowns["__global"] = currentTime + COOLDOWN_CONFIG.GLOBAL_SKILL
end

function ServerCombatManager:RecordSkillUsage(player, skillName)
	self.ActiveSkills[player.UserId] = {
		skillName = skillName, 
		timestamp = tick()
	}
end

-- ===== SPAM DETECTION =====
function ServerCombatManager:CheckSpamRate(player)
	local userId = player.UserId
	local currentTime = tick()

	if not self.SpamDetection[userId] then
		self.SpamDetection[userId] = {
			count = 1,
			windowStart = currentTime
		}
		return true
	end

	local spamData = self.SpamDetection[userId]

	-- Reset window if 1 second has passed
	if currentTime - spamData.windowStart >= 1.0 then
		spamData.count = 1
		spamData.windowStart = currentTime
		return true
	end

	-- Increment count
	spamData.count = spamData.count + 1

	-- Check if exceeds limit
	if spamData.count > VALIDATION_CONFIG.MAX_SKILL_SPAM_RATE then
		warn("[SERVER] " .. player.Name .. " exceeded spam rate limit!")
		return false
	end

	return true
end

-- ===== DAMAGE APPLICATION =====
function ServerCombatManager:ApplyDamage(attacker, target, damageData)
	-- Validate target
	local targetHumanoid = target:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return {hit = false, reason = "TargetDead"}
	end

	-- Validate attacker
	if not attacker or not attacker:FindFirstChild("Humanoid") then
		return {hit = false, reason = "InvalidAttacker"}
	end

	-- Initialize target if needed
	self:InitializeCharacter(target)

	-- Setup damage data
	damageData = damageData or {}
	local baseDamage = damageData.Damage or DAMAGE_CONFIG.BASE_DAMAGE

	-- ===== INVULNERABILITY CHECK =====
	if TagManager.HasTag(target, "Invulnerable") then
		print("[SERVER] " .. target.Name .. " is invulnerable (dodging)")
		CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Dodged", 0)
		return {hit = false, reason = "Invulnerable"}
	end

	-- ===== BLOCK CHECK =====
	if target:GetAttribute("IsBlocking") then
		local blockReduction = DAMAGE_CONFIG.BLOCK_REDUCTION
		local finalDamage = math.floor(baseDamage * blockReduction)
		targetHumanoid:TakeDamage(finalDamage)

		print("[SERVER] " .. target.Name .. " blocked! Damage reduced to " .. finalDamage)
		CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Blocked", finalDamage)
		CombatRemotes.UpdateHealth:FireAllClients(target.Name, targetHumanoid.Health, targetHumanoid.MaxHealth)

		-- Apply minimal hitstun on block
		local blockHitstun = 0.2
		TagManager.AddTag(target, "Hitstunned", blockHitstun)

		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer then
			CombatRemotes.ApplyHitstun:FireClient(targetPlayer, target, blockHitstun)
		end

		return {hit = true, hitType = "Blocked", damage = finalDamage}
	end

	-- ===== PARRY CHECK =====
	if target:GetAttribute("CanParry") then
		print("[SERVER] " .. target.Name .. " parried the attack!")
		CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Parried", 0)

		-- Apply hitstun to attacker instead (parry punishment)
		TagManager.AddTag(attacker, "Hitstunned", 1.0)

		local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
		if attackerPlayer then
			CombatRemotes.ApplyHitstun:FireClient(attackerPlayer, attacker, 1.0)
		end

		return {hit = false, reason = "Parried"}
	end

	-- ===== NORMAL HIT =====
	local multiplier = self:GetDamageMultiplier(attacker, target)
	local finalDamage = math.floor(baseDamage * multiplier)

	-- Apply damage
	targetHumanoid:TakeDamage(finalDamage)
	print("[SERVER] " .. attacker.Name .. " hit " .. target.Name .. " for " .. finalDamage .. " damage!")

	-- ===== APPLY HITSTUN =====
	local hitstunDuration = damageData.HitstunDuration or self:CalculateWeaponHitstun(attacker)
	TagManager.AddTag(target, "Hitstunned", hitstunDuration)

	-- Notify target player
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer then
		CombatRemotes.ApplyHitstun:FireClient(targetPlayer, target, hitstunDuration)
	end

	-- ===== APPLY POSTURE DAMAGE (if using posture system) =====
	if damageData.PostureDamage then
		local currentPosture = target:GetAttribute("Posture") or 0
		local maxPosture = target:GetAttribute("MaxPosture") or 100
		local newPosture = math.min(maxPosture, currentPosture + damageData.PostureDamage)
		target:SetAttribute("Posture", newPosture)

		-- Break posture if full
		if newPosture >= maxPosture then
			print("[SERVER] " .. target.Name .. " posture broken!")
			TagManager.AddTag(target, "PostureBroken", 2.0)
		end
	end

	-- ===== APPLY STATUS EFFECTS =====
	if damageData.StatusEffects then
		for effectName, effectData in pairs(damageData.StatusEffects) do
			local duration = effectData.Duration or 1
			TagManager.AddTag(target, effectName, duration)
			print("[SERVER] Applied " .. effectName .. " to " .. target.Name .. " for " .. duration .. "s")
		end
	end

	-- ===== KNOCKBACK =====
	if damageData.Knockback and damageData.Knockback > 0 then
		self:ApplyKnockback(attacker, target, damageData.Knockback)
	end

	-- ===== FIRE HIT CONFIRM =====
	CombatRemotes.HitConfirm:FireAllClients(attacker.Name, target.Name, "Hit", finalDamage)
	CombatRemotes.UpdateHealth:FireAllClients(target.Name, targetHumanoid.Health, targetHumanoid.MaxHealth)

	return {
		hit = true, 
		hitType = "Normal", 
		damage = finalDamage,
		hitstunDuration = hitstunDuration
	}
end

-- ===== DAMAGE CALCULATION =====
function ServerCombatManager:GetDamageMultiplier(attacker, target)
	local multiplier = 1.0

	local weaponMultiplier = attacker:GetAttribute("WeaponDamageMultiplier") or 1.0
	multiplier = multiplier * weaponMultiplier

	local defenseMultiplier = target:GetAttribute("DefenseMultiplier") or 1.0
	multiplier = multiplier * defenseMultiplier

	if TagManager.HasTag(target, "DefenseDown") then
		multiplier = multiplier * (1.0 + DAMAGE_CONFIG.DEFENSE_DOWN_MULTIPLIER)
	end

	if TagManager.HasTag(attacker, "StrengthUp") then
		multiplier = multiplier * DAMAGE_CONFIG.STRENGTH_UP_MULTIPLIER
	end
	return math.max(multiplier, DAMAGE_CONFIG.MIN_MULTIPLIER)
end

function ServerCombatManager:CalculateWeaponHitstun(attacker)
	local weaponName = attacker:GetAttribute("EquippedWeapon")
	if not weaponName then
		return 0.5 -- Default hitstun
	end

	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then
		return 0.5
	end

	return weapon.HitStunDuration or 0.5
end

-- ===== KNOCKBACK =====
function ServerCombatManager:ApplyKnockback(attacker, target, knockbackForce)
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")

	if not targetRoot or not attackerRoot then return end

	-- Calculate knockback direction
	local direction = (targetRoot.Position - attackerRoot.Position).Unit
	local knockbackVector = direction * knockbackForce

	-- Apply velocity
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(50000, 0, 50000)
	bodyVelocity.Velocity = knockbackVector
	bodyVelocity.Parent = targetRoot

	-- Remove after short duration
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
	local attackerPos = attackerRoot.Position

	-- Calculate hitbox position
	local hitboxPos = attackerPos + attackerRoot.CFrame.LookVector * hitboxOffset

	-- Calculate distance to target
	local distance = (targetPosition - hitboxPos).Magnitude
	local hitboxRadius = (hitboxSize / 2).Magnitude

	-- Allow some tolerance for latency
	local maxDistance = hitboxRadius + VALIDATION_CONFIG.MAX_HITBOX_TOLERANCE

	if distance > maxDistance then
		warn("[SERVER] Suspicious hit rejected - Distance: " .. math.floor(distance) .. " studs (max: " .. math.floor(maxDistance) .. ")")
		return false
	end

	return true
end

-- ===== WEAPON DAMAGE DATA =====
function ServerCombatManager:GetWeaponDamageData(weaponName, comboIndex)
	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then
		return nil
	end

	return {
		Damage = weapon.Damage,
		HitstunDuration = weapon.HitStunDuration,
		PostureDamage = weapon.PostureDamage,
		StunDuration = weapon.StunDuration,
		HitboxSize = Vector3.new(
			weapon.HitboxProperties.Swing.Width,
			weapon.HitboxProperties.Swing.Height,
			weapon.HitboxProperties.Swing.Range
		),
		HitboxOffset = weapon.Range,
		Knockback = weapon.WeaponType == "Heavy" and 20 or 5,
	}
end

-- ===== CLEANUP =====
function ServerCombatManager:Cleanup(player)
	local userId = player.UserId

	self.ActiveSkills[userId] = nil
	self.SkillCooldowns[userId] = nil
	self.SpamDetection[userId] = nil
	self.ComboTracking[userId] = nil

	print("[ServerCombatManager] Cleaned up data for " .. player.Name)
end

function ServerCombatManager:Destroy()
	-- Cleanup all tracked data
	self.ActiveSkills = {}
	self.SkillCooldowns = {}
	self.SpamDetection = {}
	self.ComboTracking = {}
	self.InitializedCharacters = {}

	print("[ServerCombatManager] Destroyed")
end

return ServerCombatManager