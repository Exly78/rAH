-- ReplicatedStorage.Modules.Data.PerkData
-- Defines all available perks in the pool.
-- At each milestone 5 are drawn at random and player picks 1.
-- Effects are applied by ProgressionService on the server.

local PerkData = {}

-- Rarity affects draw weight — Common drawn more often than Rare
PerkData.Rarity = {
	Common   = { Name = "Common",   Weight = 60, Color = Color3.fromRGB(200, 200, 200) },
	Uncommon = { Name = "Uncommon", Weight = 30, Color = Color3.fromRGB(80, 200, 120)  },
	Rare     = { Name = "Rare",     Weight = 10, Color = Color3.fromRGB(100, 140, 240) },
}

-- Category used for UI grouping and filtering
PerkData.Category = {
	Stat        = "Stat",
	Weapon      = "Weapon",
	Ability     = "Ability",
	Survival    = "Survival",
	Veil        = "Veil",
}

-- ===== PERK POOL =====
-- Effect table is applied additively to playerData.DerivedStats.
-- Keys must match derived stat names from StatData:CalculateDerived().
PerkData.Perks = {

	-- ============================
	-- STAT BOOSTS
	-- ============================

	QuickReflexes = {
		DisplayName = "Quick Reflexes",
		Category    = "Stat",
		Rarity      = "Common",
		Description = "+5 Agility — you move like you were born for this.",
		Effect = {
			StatBonus = { Agility = 5 },
		},
	},

	IronBackbone = {
		DisplayName = "Iron Backbone",
		Category    = "Stat",
		Rarity      = "Common",
		Description = "+10 Endurance — built to last.",
		Effect = {
			StatBonus = { Endurance = 10 },
		},
	},

	BrightMind = {
		DisplayName = "Bright Mind",
		Category    = "Stat",
		Rarity      = "Common",
		Description = "+5 Intelligence — the Veil speaks more clearly now.",
		Effect = {
			StatBonus = { Intelligence = 5 },
		},
	},

	SteadyFaith = {
		DisplayName = "Steady Faith",
		Category    = "Stat",
		Rarity      = "Common",
		Description = "+5 Faith — an unshakeable conviction.",
		Effect = {
			StatBonus = { Faith = 5 },
		},
	},

	SteelGrip = {
		DisplayName = "Steel Grip",
		Category    = "Stat",
		Rarity      = "Common",
		Description = "+5 Strength — your strikes hit harder.",
		Effect = {
			StatBonus = { Strength = 5 },
		},
	},

	HawkEye = {
		DisplayName = "Hawk Eye",
		Category    = "Stat",
		Rarity      = "Common",
		Description = "+5 Dexterity — precision comes naturally.",
		Effect = {
			StatBonus = { Dexterity = 5 },
		},
	},

	-- ============================
	-- WEAPON ENHANCEMENTS
	-- ============================

	SharpenedEdge = {
		DisplayName = "Sharpened Edge",
		Category    = "Weapon",
		Rarity      = "Uncommon",
		Description = "+10% light weapon damage. Every cut goes deeper.",
		Effect = {
			LightWeaponDamageBonus = 0.10,
		},
	},

	HeavyImpact = {
		DisplayName = "Heavy Impact",
		Category    = "Weapon",
		Rarity      = "Uncommon",
		Description = "+10% heavy weapon damage. The earth shakes when you swing.",
		Effect = {
			HeavyWeaponDamageBonus = 0.10,
		},
	},

	CriticalEdge = {
		DisplayName = "Critical Edge",
		Category    = "Weapon",
		Rarity      = "Uncommon",
		Description = "+8% critical hit chance.",
		Effect = {
			CritChance = 0.08,
		},
	},

	ComboMaster = {
		DisplayName = "Combo Master",
		Category    = "Weapon",
		Rarity      = "Rare",
		Description = "Melee combo hits deal +15% damage on hit 3 and beyond.",
		Effect = {
			ComboScalingBonus = 0.15,
		},
	},

	PoisedStriker = {
		DisplayName = "Poised Striker",
		Category    = "Weapon",
		Rarity      = "Uncommon",
		Description = "Attacks deal +20% posture damage.",
		Effect = {
			PostureDamageBonus = 0.20,
		},
	},

	GuardBreaker = {
		DisplayName = "Guard Breaker",
		Category    = "Weapon",
		Rarity      = "Rare",
		Description = "When you break an enemy's posture, deal +25% damage for 3 seconds.",
		Effect = {
			GuardBreakDamageBonus = 0.25,
			GuardBreakDuration    = 3,
		},
	},

	-- ============================
	-- ABILITY MODIFIERS
	-- ============================

	VeilChanneler = {
		DisplayName = "Veil Channeler",
		Category    = "Ability",
		Rarity      = "Uncommon",
		Description = "Veil abilities cost 10% less mana.",
		Effect = {
			ManaCostReduction = 0.10,
		},
	},

	ExtendedReach = {
		DisplayName = "Extended Reach",
		Category    = "Ability",
		Rarity      = "Common",
		Description = "Hitbox range on all melee attacks +10%.",
		Effect = {
			HitboxRangeBonus = 0.10,
		},
	},

	BleedingEdge = {
		DisplayName = "Bleeding Edge",
		Category    = "Ability",
		Rarity      = "Uncommon",
		Description = "Bleed status effect stacks are applied at +2 extra.",
		Effect = {
			BleedStackBonus = 2,
		},
	},

	-- ============================
	-- SURVIVABILITY / MOBILITY
	-- ============================

	Fleetfooted = {
		DisplayName = "Fleetfooted",
		Category    = "Survival",
		Rarity      = "Uncommon",
		Description = "+15% dodge speed. Barely there.",
		Effect = {
			DodgeSpeedBonus = 0.15,
		},
	},

	StoneSkin = {
		DisplayName = "Stone Skin",
		Category    = "Survival",
		Rarity      = "Uncommon",
		Description = "-5% all damage taken.",
		Effect = {
			DamageResistance = 0.05,
		},
	},

	LastStand = {
		DisplayName = "Last Stand",
		Category    = "Survival",
		Rarity      = "Rare",
		Description = "Below 20% HP, gain +20% damage and +10% damage resistance.",
		Effect = {
			LastStandDamageBonus     = 0.20,
			LastStandResistanceBonus = 0.10,
			LastStandThreshold       = 0.20,
		},
	},

	Tenacious = {
		DisplayName = "Tenacious",
		Category    = "Survival",
		Rarity      = "Rare",
		Description = "Once per life, survive a lethal hit with 1 HP.",
		Effect = {
			CanSurviveLethalhit = true,
		},
		MaxStack = 1, -- can only have this once
	},

	-- ============================
	-- VEIL-SPECIFIC
	-- ============================

	VeilResilience = {
		DisplayName = "Veil Resilience",
		Category    = "Veil",
		Rarity      = "Uncommon",
		Description = "Corruption and Veil damage effects reduced by 20%.",
		Effect = {
			VeilCorruptionResistance = 0.20,
		},
	},

	VeilHunger = {
		DisplayName = "Veil Hunger",
		Category    = "Veil",
		Rarity      = "Uncommon",
		Description = "+15% damage while in a Veil-exposed zone.",
		Effect = {
			VeilZoneDamageBonus = 0.15,
		},
	},

	VeilAwareness = {
		DisplayName = "Veil Awareness",
		Category    = "Veil",
		Rarity      = "Rare",
		Description = "Sanity drain from Veil Hotspots is halved.",
		Effect = {
			VeilSanityDrainReduction = 0.50,
		},
	},

	SanityTether = {
		DisplayName = "Sanity Tether",
		Category    = "Veil",
		Rarity      = "Rare",
		Description = "When sanity would drop below 25, it stabilizes at 25 once per life.",
		Effect = {
			SanityFloor = 25,
		},
		MaxStack = 1,
	},

	VoidtouchedStrike = {
		DisplayName = "Voidtouched Strike",
		Category    = "Veil",
		Rarity      = "Rare",
		Description = "Attacks deal +5% bonus damage as Veil damage, bypassing physical resistance.",
		Effect = {
			VeilDamageOnHit = 0.05,
		},
	},
}

-- ===== HELPERS =====

function PerkData:GetPerk(perkName)
	return self.Perks[perkName]
end

function PerkData:GetAllPerkNames()
	local names = {}
	for name in pairs(self.Perks) do
		table.insert(names, name)
	end
	return names
end

-- Draws N unique random perks from the pool, weighted by rarity.
-- excludeOwned = list of perk names the player already has (avoids offering MaxStack=1 duplicates)
function PerkData:DrawPerks(count, excludeOwned)
	excludeOwned = excludeOwned or {}
	local ownedSet = {}
	for _, name in ipairs(excludeOwned) do ownedSet[name] = true end

	-- Build weighted pool
	local pool = {}
	for perkName, perkDef in pairs(self.Perks) do
		local skip = false
		if ownedSet[perkName] and perkDef.MaxStack == 1 then skip = true end
		if not skip then
			local rarityDef = self.Rarity[perkDef.Rarity]
			local weight = rarityDef and rarityDef.Weight or 30
			for _ = 1, weight do
				table.insert(pool, perkName)
			end
		end
	end

	-- Shuffle and pick unique
	local shuffled = {}
	local usedKeys = {}
	for i = #pool, 1, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local result = {}
	for _, name in ipairs(pool) do
		if not usedKeys[name] then
			usedKeys[name] = true
			table.insert(result, name)
			if #result >= count then break end
		end
	end

	return result
end

return PerkData
