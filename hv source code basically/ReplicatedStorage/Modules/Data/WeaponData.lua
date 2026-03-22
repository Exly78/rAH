-- ReplicatedStorage.Modules.Data.WeaponData

local WeaponData = {}

local Ranges = {
	Katana = 8,
	Scythe = 10,
	Dagger = 7,
	Sueno  = 12,
	Fist   = 7,
}

local function createWeapon(name, props)
	return {
		Name            = name,
		WeaponType      = props.WeaponType      or "Medium",
		Damage          = props.Damage          or 5,
		SwingSpeed      = props.SwingSpeed      or 1,
		StunDuration    = props.StunDuration    or 0.25,
		HitStunDuration = props.HitStunDuration or 0.5,
		PostureDamage   = props.PostureDamage   or 1,
		Range           = props.Range           or Ranges[name] or 5,
		Endlag          = props.Endlag          or 0.25,
		HitType         = props.HitType         or "Slash",
		Timing          = props.Timing          or 0.2,
		Length          = props.Length          or 0.5,
		HitboxProperties = props.HitboxProperties or {
			Swing = {
				Height    = 8,
				Width     = 8,
				Range     = Ranges[name] or 5,
				Offset    = CFrame.new(0, 0, -3),
				Predict   = 0.05,
				Visualize = 0.05,
			}
		},
		Animations = props.Animations or {
			Equip     = "equip",
			Unequip   = "unequip",
			Attack1   = "swing1",
			Attack2   = "swing2",
			Attack3   = "swing3",
			Attack4   = "swing4",
			Attack5   = "swing5",
			Critical  = "critical",
			Block     = "blocking",
			WeaponIdle = "weaponidle",
			Sprint    = "Sprint",
		},

		-- Critical attack definition for this weapon.
		-- Phase1 = the opening strike; if it lands, Phase2 unlocks.
		-- Phase2 = the follow-up executed on the marked targets.
		Critical = props.Critical or nil,
	}
end

WeaponData.Weapons = {

	Katana = createWeapon("Katana", {
		Damage      = 6,
		WeaponType  = "Medium",
		SwingSpeed  = 1.05,

		-- Critical block.
		-- If Phases has only one entry = single hit crit.
		-- If Phases has two entries = two-stage crit (Phase1 marks, Phase2 follows up).
		Critical = {
			AltCritWindow = 8,  -- only relevant if Phases has 2 entries
			Phases = {
				[1] = {
					DamageMultiplier = 1.25,
					PostureDamage    = 20,
					HitstunDuration  = 0.6,
					HitboxSize       = Vector3.new(8, 8, 8),
					HitboxOffset     = 5,
					Cooldown         = 5,
					Animation        = "KatanaCritical",
				},
				[2] = {
					DamageMultiplier = 1.25,
					PostureDamage    = 10,
					HitstunDuration  = 0.3,
					RapidHits        = 5,
					RapidHitInterval = 0.065,
					Cooldown         = 3,
					Animation        = "KatanaCriticalAlt",
				},
			},
		},
	}),

	Dagger = createWeapon("Dagger", {
		Damage          = 3,
		WeaponType      = "Light",
		SwingSpeed      = 0.92,
		Endlag          = 0.1,
		HitStunDuration = 0.05,
		-- Dagger crit: no Phase2 yet, define when ready
		Critical = nil,
	}),

	Scythe = createWeapon("Scythe", {
		Damage          = 8,
		WeaponType      = "Heavy",
		SwingSpeed      = 1.05,
		HitStunDuration = 0.6,
		Critical        = nil,
	}),

	Sueno = createWeapon("Sueno", {
		Damage       = 7,
		WeaponType   = "Heavy",
		SwingSpeed   = 1,
		Length       = 1,
		Range        = 10,
		HitboxProperties = {
			Swing = {
				Height    = 8,
				Width     = 5,
				Range     = 10,
				Offset    = CFrame.new(0, 0, -5.5),
				Predict   = 0.05,
				Visualize = 0.05,
			}
		},
		Critical = nil,
	}),

	Fist = createWeapon("Fist", {
		Damage     = 4,
		WeaponType = "Light",
		SwingSpeed = 1,
		Critical   = nil,
	}),
}

function WeaponData:GetWeapon(name)
	return self.Weapons[name]
end

function WeaponData:GetAnimationKey(weaponName, animName)
	local weapon = self:GetWeapon(weaponName)
	if not weapon then return nil end
	return weapon.Animations[animName]
end

-- Returns the Critical definition for a weapon, or nil if it has none
function WeaponData:GetCritical(weaponName)
	local weapon = self:GetWeapon(weaponName)
	return weapon and weapon.Critical or nil
end

return WeaponData
