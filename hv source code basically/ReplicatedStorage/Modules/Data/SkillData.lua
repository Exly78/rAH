local SkillData = {}

SkillData.Skills = {
	["BasicAttack"] = {
		Name = "Basic Attack",
		Damage = 15,
		Cost = 0,
		Cooldown = 0.5,
		HitstunDuration = 0.4,
		HitboxSize = Vector3.new(5, 5, 5),
		HitboxOffset = 5,
		Animation = "BasicAttack",
		Duration = 0.6,
		StatusEffects = {},
		Priority = 1,
		Continuous = false, -- single-hit
	},

	["HeavyAttack"] = {
		Name = "Heavy Attack",
		Damage = 30,
		Cost = 20,
		Cooldown = 1.5,
		HitstunDuration = 1.0,
		HitboxSize = Vector3.new(10, 10, 10),
		HitboxOffset = 6,
		Animation = "HeavyAttack",
		Duration = 1.2,
		StatusEffects = {
			Weighted = {Duration = 3, Potency = 0.5}
		},
		Priority = 2,
		Continuous = false,
	},

	["PowerSlash"] = {
		Name = "Power Slash",
		Damage = 25,
		Cost = 15,
		Cooldown = 1.0,
		HitstunDuration = 0.7,
		HitboxSize = Vector3.new(8, 8, 12),
		HitboxOffset = 7,
		Animation = "PowerSlash",
		Duration = 0.8,
		StatusEffects = {
			Burn = {Duration = 5, Potency = 0.3}
		},
		Priority = 3,
		Continuous = true, -- continuous hitboxes
	},

	["TestSkill"] = {
		Name = "Test Skill",
		Damage = 20,
		Cost = 10,
		Cooldown = 0.8,
		HitstunDuration = 0.6,
		HitboxSize = Vector3.new(8, 8, 8),
		HitboxOffset = 5,
		Animation = "TestSkill",
		Duration = 0.7,
		StatusEffects = {},
		Priority = 1,
		Continuous = false,
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
