-- Modules/Managers/CombatManager.lua
local CombatManager = {}
CombatManager.__index = CombatManager

function CombatManager.new()
	local self = setmetatable({}, CombatManager)
	self.DamageLog = {}
	return self
end

function CombatManager:ApplyDamage(attacker, hitbox, damageData)
	damageData = damageData or {}

	local baseDamage = damageData.Damage or 10
	local result = {
		Hits = {},
		Blocked = {},
		Parried = {},
		Dodged = {},
	}

	local hitEntities = hitbox.EntitiesHit

	for character, _ in pairs(hitEntities) do
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 then

			if character:GetAttribute("IsInvulnerable") then
				table.insert(result.Dodged, character)
				print(character.Name .. " dodged!")
				continue
			end

			if character:GetAttribute("IsBlocking") then
				-- for now i keep it like this
				local blockReduction = 0.5  
				local finalDamage = baseDamage * blockReduction
				humanoid:TakeDamage(finalDamage)
				table.insert(result.Blocked, character)
				print(character.Name .. " blocked for " .. finalDamage .. " damage!")
				continue
			end

			if character:GetAttribute("CanParry") then
				-- Parry negates damage and might stun attacker
				table.insert(result.Parried, character)
				print(character.Name .. " parried!")
				continue
			end

			-- Normal hit
			humanoid:TakeDamage(baseDamage)
			table.insert(result.Hits, character)
			print(character.Name .. " took " .. baseDamage .. " damage!")

			if character:FindFirstChild("CharacterController") then
				local hitstunDuration = math.min(damageData.HitstunDuration or 0.5, 2)
				character:SetAttribute("NeedsHitstun", hitstunDuration)
			end

			if damageData.StatusEffects then
				for effectName, effectData in pairs(damageData.StatusEffects) do
					character:SetAttribute("Apply" .. effectName, true)
					if effectData.Duration then
						character:SetAttribute(effectName .. "Duration", effectData.Duration)
					end
					if effectData.Potency then
						character:SetAttribute(effectName .. "Potency", effectData.Potency)
					end
				end
			end
		end
	end

	return result
end

function CombatManager:GetDamageMultiplier(target)
	local multiplier = 1
	local defenseDown = target:GetAttribute("DefenseDown") or 0
	multiplier = multiplier + (defenseDown * 0.3)  
	return multiplier
end

return CombatManager
