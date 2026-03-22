-- ReplicatedStorage.Modules.Data.StatusEffectData
-- ============================================================
-- Define all status effects here. Each effect is registered
-- with its caps, trigger type, and tick behaviour.
--
-- TRIGGER TYPES:
--   "OnTime"   – consumes 1 count every [Interval] seconds
--   "OnAction" – consumes 1 count when the affected character attacks or moves
--   "OnHit"    – consumes 1 count each time the affected character takes a hit
--
-- STACKS  = potency (how hard each tick hits)
-- COUNT   = charges (how many times the effect can trigger before expiring)
-- ============================================================

local StatusEffectData = {}

-- ===== HELPERS =====
-- OnTrigger signature:
--   function(character, stacks, managers)
--     managers.Health   → ServerHealthManager instance
--     managers.Status   → ServerStatusManager instance (for cross-effect interactions)
--   end

-- ===== EFFECT DEFINITIONS =====

StatusEffectData.Effects = {

	-- ----------------------------------------------------------
	-- BLEED
	-- Applied by slashing moves. Each tick deals stacks damage
	-- when the target moves or attacks.
	-- ----------------------------------------------------------
	Bleed = {
		DisplayName  = "Bleed",
		TriggerType  = "OnAction",
		MaxStacks    = 20,
		MaxCount     = 15,
		Color        = Color3.fromRGB(200, 40, 40),

		PassiveDecay         = 1,   -- count lost per interval
		PassiveDecayInterval = 1,   -- seconds between each decay tick

		OnTrigger = function(character, stacks, managers)
			managers.Health:TakeDamage(character, stacks)
		end,
		OnApplied = function(character, stacks, count, managers) end,
		OnExpired = function(character, managers) end,
	},

	-- ----------------------------------------------------------
	-- FRACTURE (example "OnHit" effect)
	-- Each hit the target receives consumes 1 count and amplifies
	-- that hit's damage by a percentage based on stacks.
	-- Pairs nicely with heavy weapons.
	-- ----------------------------------------------------------
	Fracture = {
		DisplayName  = "Fracture",
		TriggerType  = "OnHit",
		MaxStacks    = 10,
		MaxCount     = 10,
		Color        = Color3.fromRGB(160, 130, 90),

		-- Returns a damage multiplier consumed externally by the hit pipeline.
		-- The manager will call this and forward the result to whoever dealt the hit.
		OnTrigger = function(character, stacks, managers)
			-- Each Fracture stack adds 3% bonus damage on the incoming hit
			local bonusMultiplier = 1 + (stacks * 0.03)
			return { DamageMultiplier = bonusMultiplier }
		end,

		OnApplied = function(character, stacks, count, managers) end,
		OnExpired = function(character, managers) end,
	},

	-- ----------------------------------------------------------
	-- SUNDER (example "OnTime" effect)
	-- A lingering debuff that ticks every second, reducing the
	-- target's effective defense (implemented as periodic damage
	-- here; swap out for a defense stat modifier if you add stats).
	-- ----------------------------------------------------------
	Sunder = {
		DisplayName  = "Sunder",
		TriggerType  = "OnTime",
		Interval     = 1,            -- seconds between ticks
		MaxStacks    = 15,
		MaxCount     = 20,
		Color        = Color3.fromRGB(100, 100, 220),

		OnTrigger = function(character, stacks, managers)
			managers.Health:TakeDamage(character, stacks * 0.5)
		end,

		OnApplied  = function(character, stacks, count, managers) end,
		OnExpired  = function(character, managers) end,
	},

}

-- ===== LOOKUP =====
function StatusEffectData.Get(effectName)
	return StatusEffectData.Effects[effectName]
end

function StatusEffectData.GetAll()
	return StatusEffectData.Effects
end

return StatusEffectData
