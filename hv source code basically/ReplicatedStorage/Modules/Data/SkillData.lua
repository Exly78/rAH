-- ReplicatedStorage.Modules.Data.SkillData
-- StatusEffects format:
--   { EffectName = { Stacks = n, Count = n } }
--   Stacks = potency per trigger
--   Count  = number of times the effect triggers before expiring

local SkillData = {}

-- ===== ATTACK TYPES =====
-- Defines what defensive options can counter this attack.
--
--   Default       : parryable, blockable, dodgeable (standard behaviour)
--   BlockBreak    : bypasses parry AND block (both trigger instant block-break + extra damage),
--                   only dodge or physically leaving the hitbox saves the target
--   Unparryable   : blockable + dodgeable, parry does nothing (treated as a normal hit)
--   ParryOnly     : only a parry saves you; block and dodge fail
--   DodgeOnly     : only a dodge saves you; parry and block fail
--   BlockOnly     : only a block saves you; parry and dodge fail
--   HitboxOnly    : no defensive input works — physically leave the hitbox or take the hit
--   CrouchOnly    : misses crouching targets, hits everyone else
--   JumpOnly      : misses airborne targets, hits grounded targets
--   CounterWindow : parryable during the early CounterWindowDuration (seconds from AttackStartTime),
--                   fully unblockable/undodgeable after the window closes
--
-- Set BlockBreakDamage on the skill/weapon to add bonus damage on top of the normal hit
-- when a block or parry is broken by a BlockBreak attack.
-- Set CounterWindowDuration to override the default 0.3s counter window.

SkillData.AttackTypes = {
	Default       = "Default",
	BlockBreak    = "BlockBreak",
	Unparryable   = "Unparryable",
	ParryOnly     = "ParryOnly",
	DodgeOnly     = "DodgeOnly",
	BlockOnly     = "BlockOnly",
	HitboxOnly    = "HitboxOnly",
	CrouchOnly    = "CrouchOnly",
	JumpOnly      = "JumpOnly",
	CounterWindow = "CounterWindow",
}

SkillData.Skills = {

	["BasicAttack"] = {
		Name            = "Basic Attack",
		Damage          = 15,
		PostureDamage   = 10,
		Cost            = 0,
		Cooldown        = 0.5,
		HitstunDuration = 0.4,
		HitboxSize      = Vector3.new(5, 5, 5),
		HitboxOffset    = 5,
		Animation       = "BasicAttack",
		Duration        = 0.6,
		StatusEffects   = {
			-- BasicAttack applies a small bleed: 2 stacks potency, 3 charges
			Bleed = { Stacks = 2, Count = 3 },
		},
		Priority        = 1,
		Continuous      = false,
		AttackType      = "CrouchOnly",
	},

	["HeavyAttack"] = {
		Name            = "Heavy Attack",
		Damage          = 30,
		PostureDamage   = 35,
		Cost            = 20,
		Cooldown        = 1.5,
		HitstunDuration = 1.0,
		HitboxSize      = Vector3.new(10, 10, 10),
		HitboxOffset    = 6,
		Animation       = "HeavyAttack",
		Duration        = 1.2,
		StatusEffects   = {
			-- HeavyAttack applies Fracture: 5 stacks, 4 charges (amplifies incoming hits)
			Fracture = { Stacks = 5, Count = 4 },
		},
		Priority        = 2,
		Continuous      = false,
		AttackType      = "Default",
	},

	["PowerSlash"] = {
		Name            = "Power Slash",
		Damage          = 25,
		PostureDamage   = 25,
		Cost            = 15,
		Cooldown        = 1.0,
		HitstunDuration = 0.7,
		HitboxSize      = Vector3.new(8, 8, 12),
		HitboxOffset    = 7,
		Animation       = "PowerSlash",
		Duration        = 0.8,
		StatusEffects   = {
			-- PowerSlash applies a heavy bleed and a Sunder (ticking damage over time)
			Bleed  = { Stacks = 5, Count = 6 },
			Sunder = { Stacks = 3, Count = 8 },
		},
		Priority        = 3,
		Continuous      = true,
		AttackType      = "Default",
	},

	-- ===== KATANA CRITICALS =====
	-- Phase 1: wide swing at 1.25x base damage. If it lands, marks targets
	-- and unlocks Phase 2 (AltCrit) for a short window.
	["KatanaCritical"] = {
		Name            = "Katana Critical",
		Damage          = 15 * 1.25,   -- 1.25x base katana damage
		PostureDamage   = 20,
		Cost            = 0,
		Cooldown        = 5,           -- full cooldown if nobody hit
		HitstunDuration = 0.6,
		HitboxSize      = Vector3.new(8, 8, 8),
		HitboxOffset    = 5,
		Animation       = "KatanaCritical",
		Duration        = 1.0,
		StatusEffects   = {},
		IsCritical      = true,
		CriticalPhase   = 1,
		WeaponType      = "Katana",
		AttackType      = "Default",
	},

	-- Phase 2: no new hitbox — hits the same marked targets 5 times rapidly.
	-- Only available after Phase 1 lands (AltCrit attribute set on attacker).
	["KatanaCriticalAlt"] = {
		Name             = "Katana Critical Alt",
		Damage           = 15 * 1.25,  -- same 1.25x per hit, 5 hits total
		PostureDamage    = 10,
		Cost             = 0,
		Cooldown         = 0.5,
		HitstunDuration  = 0.3,
		HitboxSize       = Vector3.new(0, 0, 0), -- unused — targets pre-marked
		HitboxOffset     = 0,
		Animation        = "KatanaCriticalAlt",
		Duration         = 1.2,
		StatusEffects    = {},
		IsCritical       = true,
		CriticalPhase    = 2,
		WeaponType       = "Katana",
		RapidHits        = 5,
		RapidHitInterval = 0.065,
		AttackType       = "Default",
	},

	["SlideAttack"] = {
		Name            = "Slide Attack",
		Damage          = 20,
		PostureDamage   = 15,
		Cost            = 0,
		Cooldown        = 1.0,
		HitstunDuration = 0.5,
		HitboxSize      = Vector3.new(7, 4, 8),
		HitboxOffset    = 6,
		Animation       = "SlideAttack",
		Duration        = 0.8,
		StatusEffects   = {},
		Priority        = 2,
		Continuous      = false,
		AttackType      = "JumpOnly",
	},

	["TestSkill"] = {
		Name            = "Test Skill",
		Damage          = 20,
		PostureDamage   = 15,
		Cost            = 10,
		Cooldown        = 0.8,
		HitstunDuration = 0.6,
		HitboxSize      = Vector3.new(8, 8, 8),
		HitboxOffset    = 5,
		Animation       = "TestSkill",
		Duration        = 0.7,
		StatusEffects   = {},
		Priority        = 1,
		Continuous      = false,
		AttackType      = "Default",
	},

}

function SkillData:GetSkill(skillName)
	return self.Skills[skillName]
end

function SkillData:GetAllSkills()
	return self.Skills
end

function SkillData:AddSkill(skillName, skillConfig)
	self.Skills[skillName] = skillConfig
	print("Skill added: " .. skillName)
end

function SkillData:RemoveSkill(skillName)
	self.Skills[skillName] = nil
	print("Skill removed: " .. skillName)
end

return SkillData
