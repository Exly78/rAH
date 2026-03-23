-- ServerStorage.Modules.Handlers.HitboxServer
-- Handles skill authorization and hitbox creation remote events.

local SkillData = require(game.ReplicatedStorage.Modules.Data.SkillData)

local HitboxServer = {}

function HitboxServer.Setup(managers, CombatRemotes)
	local healthManager   = managers.health
	local combatManager   = managers.combat
	local criticalManager = managers.critical
	local statusManager   = managers.status

	local AuthorizedSkills = {}

	-- ===== SKILL REQUEST =====
	CombatRemotes.SkillRequest.OnServerEvent:Connect(function(player, skillName)
		if not player or not player.Character then return end

		local skill = SkillData:GetSkill(skillName)
		if not skill then
			warn("[HitboxServer] Invalid skill:", skillName)
			return
		end

		local validation = combatManager:RequestSkill(player, skillName)
		if not validation.success then
			return
		end

		AuthorizedSkills[player.UserId] = {
			skillName = skillName,
			timestamp = tick(),
			used      = false,
		}
	end)

	-- ===== HITBOX CREATION =====
	CombatRemotes.CreateHitbox.OnServerEvent:Connect(function(player, skillName, comboIndex)
		if not player or not player.Character then return end

		local attacker = player.Character
		local humanoid = attacker:FindFirstChild("Humanoid")
		if not humanoid or healthManager:IsDead(attacker) then return end

		local auth = AuthorizedSkills[player.UserId]
		if not auth or auth.used then
			warn("[HitboxServer] Unauthorized hitbox from", player.Name)
			return
		end

		if tick() - auth.timestamp > 2 then
			warn("[HitboxServer] Expired hitbox auth from", player.Name)
			AuthorizedSkills[player.UserId] = nil
			return
		end

		auth.used = true

		local skill = SkillData:GetSkill(skillName)
		if not skill then
			warn("[HitboxServer] Invalid skill in hitbox:", skillName)
			return
		end

		statusManager:NotifyAction(attacker)

		-- Critical attacks are delegated to ServerCriticalManager
		if skill.IsCritical then
			criticalManager:HandleCritical(player, skill.CriticalPhase)
			task.delay(0.1, function()
				if AuthorizedSkills[player.UserId] == auth then
					AuthorizedSkills[player.UserId] = nil
				end
			end)
			return
		end

		-- Normal hitbox
		local rootPart = attacker:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		local hitboxPos  = rootPart.Position + rootPart.CFrame.LookVector * skill.HitboxOffset
		local hitboxSize = skill.HitboxSize

		if comboIndex and comboIndex == 5 then
			hitboxSize = hitboxSize * 1.3
		end

		local hitEntities = workspace:GetPartBoundsInRadius(hitboxPos, (hitboxSize / 2).Magnitude)
		local targetsHit  = {}
		local seenChars   = {}

		for _, part in ipairs(hitEntities) do
			local targetChar = part:FindFirstAncestorOfClass("Model")
			if targetChar and not seenChars[targetChar] then
				local targetHumanoid = targetChar:FindFirstChild("Humanoid")
				if targetHumanoid and targetChar ~= attacker then
					if not healthManager.HealthData[targetChar] then
						if not game.Players:GetPlayerFromCharacter(targetChar) then
							combatManager:InitializeCharacter(targetChar)
						end
					end
					if healthManager:IsAlive(targetChar) then
						local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
						if targetRoot and combatManager:ValidateHitbox(attacker, targetRoot.Position, hitboxSize, skill.HitboxOffset) then
							seenChars[targetChar] = true
							table.insert(targetsHit, targetChar)
						end
					end
				end
			end
		end

		local damageMultiplier = comboIndex and (1.0 + (comboIndex - 1) * 0.15) or 1.0

		local isJumpOnly = (skill.AttackType == "JumpOnly")

		for _, target in ipairs(targetsHit) do
			local dmgTable = {
				Damage                = skill.Damage * damageMultiplier,
				HitstunDuration       = skill.HitstunDuration,
				StatusEffects         = skill.StatusEffects,
				PostureDamage         = skill.PostureDamage,
				ChipDamage            = skill.ChipDamage,
				IsCriticalHit         = skill.IsCritical or false,
				AttackType            = skill.AttackType or "Default",
				BlockBreakDamage      = skill.BlockBreakDamage,
				AttackStartTime       = auth.timestamp,
				CounterWindowDuration = skill.CounterWindowDuration,
			}

			if isJumpOnly then
				-- Ping compensation: wait ~150ms then check airborne state.
				-- This catches players who jumped just before the server processed the hit.
				local capturedTarget = target
				task.spawn(function()
					task.wait(0.15)
					if healthManager:IsAlive(capturedTarget) and attacker.Parent then
						combatManager:ApplyDamage(attacker, capturedTarget, dmgTable)
					end
				end)
			else
				combatManager:ApplyDamage(attacker, target, dmgTable)
			end
		end

		task.delay(0.1, function()
			if AuthorizedSkills[player.UserId] == auth then
				AuthorizedSkills[player.UserId] = nil
			end
		end)
	end)

	-- Return AuthorizedSkills so CombatServer can clean up on PlayerRemoving
	return { AuthorizedSkills = AuthorizedSkills }
end

return HitboxServer
