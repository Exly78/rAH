-- ReplicatedStorage.Modules.Data.ClassData
-- Defines the full class tree: Base → Subclass → Ascension, and Base → True Class.
-- All checks are done server-side in ProgressionService, this is pure data.

local ClassData = {}

-- ===== CLASS TIERS =====
ClassData.Tier = {
	Base      = "Base",
	Subclass  = "Subclass",
	Ascension = "Ascension",
	TrueClass = "TrueClass",
}

-- ===== CLASS DEFINITIONS =====
-- StatRequirements: { StatName = minimumPoints }
-- ParentClass: must currently hold this class to unlock (nil = Base classes, anyone can pick)
-- Lives awarded on unlock
ClassData.Classes = {

	-- ============================
	-- BASE CLASSES
	-- ============================

	Warrior = {
		DisplayName  = "Warrior",
		Tier         = "Base",
		Description  = "A master of brute force. Excels with heavy weapons and raw physical power.",
		ParentClass  = nil,
		StatRequirements = { Strength = 10 },
		LivesOnUnlock = 0,
		StartingWeaponTypes = { "Medium", "Heavy" },
		PassiveBonus = { BonusDamage = 3 },
	},

	Rogue = {
		DisplayName  = "Rogue",
		Tier         = "Base",
		Description  = "Swift and lethal. Excels with light weapons and exploiting openings.",
		ParentClass  = nil,
		StatRequirements = { Agility = 10 },
		LivesOnUnlock = 0,
		StartingWeaponTypes = { "Light", "Medium" },
		PassiveBonus = { CritChance = 0.05 },
	},

	Scholar = {
		DisplayName  = "Scholar",
		Tier         = "Base",
		Description  = "Unlocks the power of the Veil through study. Excels with intelligence-based magic.",
		ParentClass  = nil,
		StatRequirements = { Intelligence = 10 },
		LivesOnUnlock = 0,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { VeilDamageBonus = 0.08 },
	},

	Cleric = {
		DisplayName  = "Cleric",
		Tier         = "Base",
		Description  = "Channels holy or cursed power. Buffs, debuffs, and Veil manipulation.",
		ParentClass  = nil,
		StatRequirements = { Faith = 10 },
		LivesOnUnlock = 0,
		StartingWeaponTypes = { "Light", "Medium" },
		PassiveBonus = { SanityResistance = 0.06 },
	},

	Hunter = {
		DisplayName  = "Hunter",
		Tier         = "Base",
		Description  = "Precise and adaptive. Excels with ranged and hybrid weapons.",
		ParentClass  = nil,
		StatRequirements = { Dexterity = 10 },
		LivesOnUnlock = 0,
		StartingWeaponTypes = { "Light", "Medium", "Ranged" },
		PassiveBonus = { RangedDamageBonus = 0.08 },
	},

	Warden = {
		DisplayName  = "Warden",
		Tier         = "Base",
		Description  = "Unbreakable endurance. Excels in sustained combat and damage absorption.",
		ParentClass  = nil,
		StatRequirements = { Endurance = 10 },
		LivesOnUnlock = 0,
		StartingWeaponTypes = { "Medium", "Heavy" },
		PassiveBonus = { DamageResistance = 0.05 },
	},

	-- ============================
	-- SUBCLASSES
	-- ============================

	Knight = {
		DisplayName  = "Knight",
		Tier         = "Subclass",
		Description  = "A disciplined warrior clad in endurance. Specializes in defense and heavy weapon mastery.",
		ParentClass  = "Warrior",
		StatRequirements = { Strength = 30, Endurance = 25 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Medium", "Heavy" },
		PassiveBonus = { DamageResistance = 0.07, BonusDamage = 5 },
	},

	Berserker = {
		DisplayName  = "Berserker",
		Tier         = "Subclass",
		Description  = "Reckless and devastating. Trades defense for overwhelming offensive power.",
		ParentClass  = "Warrior",
		StatRequirements = { Strength = 35, Agility = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Medium", "Heavy" },
		PassiveBonus = { BonusDamage = 10, CritChance = 0.04 },
	},

	Assassin = {
		DisplayName  = "Assassin",
		Tier         = "Subclass",
		Description  = "Precision killer. Maximizes critical damage and exploits enemy weaknesses.",
		ParentClass  = "Rogue",
		StatRequirements = { Agility = 30, Dexterity = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { CritChance = 0.08, BonusDamage = 4 },
	},

	Shadowblade = {
		DisplayName  = "Shadowblade",
		Tier         = "Subclass",
		Description  = "Melds stealth and Veil energy into lethal hybrid attacks.",
		ParentClass  = "Rogue",
		StatRequirements = { Agility = 25, Intelligence = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light", "Medium" },
		PassiveBonus = { CritChance = 0.05, VeilDamageBonus = 0.06 },
	},

	Arcanist = {
		DisplayName  = "Arcanist",
		Tier         = "Subclass",
		Description  = "Deep Veil mastery. Devastating spell damage and mana efficiency.",
		ParentClass  = "Scholar",
		StatRequirements = { Intelligence = 35, Faith = 15 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { VeilDamageBonus = 0.12, SanityResistance = -0.03 }, -- power at a cost
	},

	VeilWarden = {
		DisplayName  = "Veil Warden",
		Tier         = "Subclass",
		Description  = "Uses the Veil as both weapon and shield. Hybrid Veil offense and defense.",
		ParentClass  = "Scholar",
		StatRequirements = { Intelligence = 25, Endurance = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light", "Medium" },
		PassiveBonus = { VeilDamageBonus = 0.08, DamageResistance = 0.04 },
	},

	Inquisitor = {
		DisplayName  = "Inquisitor",
		Tier         = "Subclass",
		Description  = "Offensive holy power. Burns enemies with divine judgement.",
		ParentClass  = "Cleric",
		StatRequirements = { Faith = 30, Strength = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light", "Medium" },
		PassiveBonus = { BonusDamage = 6, SanityResistance = 0.04 },
	},

	Oracle = {
		DisplayName  = "Oracle",
		Tier         = "Subclass",
		Description  = "Foresight and manipulation. Debuffs, sanity attacks, and Veil reading.",
		ParentClass  = "Cleric",
		StatRequirements = { Faith = 25, Intelligence = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { SanityResistance = 0.08, VeilDamageBonus = 0.05 },
	},

	Ranger = {
		DisplayName  = "Ranger",
		Tier         = "Subclass",
		Description  = "Sustained ranged dominance. Traps, tracking, and deadly precision.",
		ParentClass  = "Hunter",
		StatRequirements = { Dexterity = 30, Agility = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light", "Medium", "Ranged" },
		PassiveBonus = { RangedDamageBonus = 0.10, CritChance = 0.04 },
	},

	Ironclad = {
		DisplayName  = "Ironclad",
		Tier         = "Subclass",
		Description  = "Living fortress. Maximum endurance and posture, punishes aggression.",
		ParentClass  = "Warden",
		StatRequirements = { Endurance = 35, Strength = 20 },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Medium", "Heavy" },
		PassiveBonus = { DamageResistance = 0.10, PostureBonus = 20 },
	},

	-- ============================
	-- ASCENSIONS (peak of a subclass)
	-- ============================

	Crusader = {
		DisplayName  = "Crusader",
		Tier         = "Ascension",
		Description  = "The pinnacle of the Knight. Holy-infused armor and divine heavy weapon mastery.",
		ParentClass  = "Knight",
		StatRequirements = { Strength = 55, Endurance = 45, Faith = 25 },
		MilestoneRequirements = { "Complete the Trial of Iron" }, -- future quest check
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Medium", "Heavy" },
		PassiveBonus = { BonusDamage = 12, DamageResistance = 0.10, SanityResistance = 0.05 },
	},

	Wraith = {
		DisplayName  = "Wraith",
		Tier         = "Ascension",
		Description  = "Transcends physical limits. Phasing strikes, near-invisible critical attacks.",
		ParentClass  = "Assassin",
		StatRequirements = { Agility = 55, Dexterity = 40, Intelligence = 20 },
		MilestoneRequirements = { "Complete the Trial of Shadows" },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { CritChance = 0.12, DodgeSpeedBonus = 0.08, BonusDamage = 8 },
	},

	VeilbreakArcanist = {
		DisplayName  = "Veilbreaker",
		Tier         = "Ascension",
		Description  = "Has broken through the Veil entirely. Reality-warping spell power at sanity's cost.",
		ParentClass  = "Arcanist",
		StatRequirements = { Intelligence = 60, Faith = 30 },
		MilestoneRequirements = { "Enter the Veil Realm" },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { VeilDamageBonus = 0.20, SanityResistance = -0.10 },
	},

	-- ============================
	-- TRUE CLASSES (alternate pinnacle, branches from Base)
	-- ============================

	Juggernaut = {
		DisplayName  = "Juggernaut",
		Tier         = "TrueClass",
		Description  = "Pure Warrior mastery. Unstoppable force — sacrifices all finesse for overwhelming power.",
		ParentClass  = "Warrior",
		StatRequirements = { Strength = 70 },
		-- Also requires base class to be nearly Ascension-ready
		BaseClassPointsRequired = 60,  -- total points must be >= this before unlocking
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Heavy" },
		PassiveBonus = { BonusDamage = 20, DamageResistance = 0.05, DodgeSpeedBonus = -0.10 },
	},

	Phantom = {
		DisplayName  = "Phantom",
		Tier         = "TrueClass",
		Description  = "Pure Rogue mastery. Exists between strikes — untouchable, inevitable.",
		ParentClass  = "Rogue",
		StatRequirements = { Agility = 70 },
		BaseClassPointsRequired = 60,
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { CritChance = 0.15, DodgeSpeedBonus = 0.12, BonusDamage = 6 },
	},

	VeilboundSelf = {
		DisplayName  = "Veilbound",
		Tier         = "TrueClass",
		Description  = "Gave everything to the Veil. No longer fully human. Power beyond reckoning.",
		ParentClass  = "Scholar",
		StatRequirements = { Intelligence = 65, Faith = 20 },
		BaseClassPointsRequired = 60,
		MilestoneRequirements   = { "Achieve Veil-Touched status", "Survive 10 Veil Realm minutes" },
		LivesOnUnlock = 1,
		StartingWeaponTypes = { "Light" },
		PassiveBonus = { VeilDamageBonus = 0.25, SanityResistance = -0.15, BonusDamage = 10 },
	},
}

-- ===== HELPERS =====

function ClassData:GetClass(className)
	return self.Classes[className]
end

-- Returns all classes at a given tier
function ClassData:GetClassesByTier(tier)
	local result = {}
	for name, def in pairs(self.Classes) do
		if def.Tier == tier then
			result[name] = def
		end
	end
	return result
end

-- Returns all subclasses/ascensions/trueclasses that branch from a given parent
function ClassData:GetChildClasses(parentClassName)
	local result = {}
	for name, def in pairs(self.Classes) do
		if def.ParentClass == parentClassName then
			result[name] = def
		end
	end
	return result
end

-- Checks whether a player's current stats and class meet requirements for a target class.
-- playerData = { CurrentClass = "Warrior", Stats = { Strength = 35, ... }, TotalPointsSpent = 60 }
-- Returns: canUnlock (bool), failReason (string or nil)
function ClassData:CanUnlockClass(targetClassName, playerData)
	local classDef = self.Classes[targetClassName]
	if not classDef then
		return false, "Class does not exist: " .. tostring(targetClassName)
	end

	local stats        = playerData.Stats or {}
	local currentClass = playerData.CurrentClass
	local totalSpent   = playerData.TotalPointsSpent or 0

	-- 1. Parent class check
	if classDef.ParentClass then
		if currentClass ~= classDef.ParentClass then
			return false, "Requires " .. classDef.ParentClass .. " as current class (you have: " .. tostring(currentClass) .. ")"
		end
	end

	-- 2. Stat threshold checks
	for statName, required in pairs(classDef.StatRequirements or {}) do
		local current = stats[statName] or 0
		if current < required then
			return false, "Requires " .. required .. " " .. statName .. " (you have " .. current .. ")"
		end
	end

	-- 3. True class base points check
	if classDef.BaseClassPointsRequired then
		if totalSpent < classDef.BaseClassPointsRequired then
			return false, "Requires " .. classDef.BaseClassPointsRequired .. " total points spent (you have " .. totalSpent .. ")"
		end
	end

	-- 4. Milestone requirements (future — checked by server against playerData.CompletedMilestones)
	if classDef.MilestoneRequirements then
		local completed = playerData.CompletedMilestones or {}
		for _, milestone in ipairs(classDef.MilestoneRequirements) do
			if not completed[milestone] then
				return false, "Requires milestone: " .. milestone
			end
		end
	end

	return true, nil
end

return ClassData
