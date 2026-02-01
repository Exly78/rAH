local Players = game:GetService("Players")
local CombatRemotes = require(game.ServerStorage.Modules.Remotes.CombatRemotes)
local ServerCombatManager = require(game.ServerStorage.Modules.Managers.ServerCombatManager)
local SkillData = require(game.ReplicatedStorage.Modules.Data.SkillData)

local combatManager = ServerCombatManager.new()
combatManager:SetupPlayerListeners()


local AuthorizedSkills = {}  -- [player.UserId] = {skillName, timestamp, used}

-- ===== SKILL REQUEST LISTENER =====

CombatRemotes.SkillRequest.OnServerEvent:Connect(function(player, skillName)
	if not player or not player.Character then return end

	local skill = SkillData:GetSkill(skillName)
	if not skill then
		warn("[SERVER] Invalid skill: " .. skillName)
		return
	end

	local validation = combatManager:RequestSkill(player, skillName)
	if not validation.success then
		print("[SERVER] Skill rejected: " .. validation.reason)
		return
	end

	print("[SERVER] " .. player.Name .. " authorized to cast " .. skillName)

	AuthorizedSkills[player.UserId] = {
		skillName = skillName,
		timestamp = tick(),
		used = false
	}
end)

-- ===== HITBOX CREATION LISTENER =====
CombatRemotes.CreateHitbox.OnServerEvent:Connect(function(player, skillName, comboIndex)
	if not player or not player.Character then return end

	local attacker = player.Character
	local humanoid = attacker:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local auth = AuthorizedSkills[player.UserId]
	if not auth or auth.used then
		warn("[SERVER] Unauthorized hitbox creation from " .. player.Name)
		return
	end

	if tick() - auth.timestamp > 2 then
		warn("[SERVER] Expired hitbox authorization from " .. player.Name)
		AuthorizedSkills[player.UserId] = nil
		return
	end

	auth.used = true

	local skill = SkillData:GetSkill(skillName)
	if not skill then
		warn("[SERVER] Invalid skill in hitbox creation: " .. skillName)
		return
	end

	print("[SERVER] Processing hitbox for: " .. skillName .. " (Combo: " .. (comboIndex or 1) .. ")")

	-- ===== CREATE HITBOX =====
	local rootPart = attacker:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local hitboxPos = rootPart.Position + rootPart.CFrame.LookVector * skill.HitboxOffset
	local hitboxSize = skill.HitboxSize

	if comboIndex and comboIndex == 5 then
		hitboxSize = hitboxSize * 1.3  
	end

	local hitEntities = workspace:GetPartBoundsInRadius(hitboxPos, (hitboxSize/2).Magnitude)

	local targetsHit = {}
	local seenChars = {}  
	for _, part in ipairs(hitEntities) do
		local targetChar = part:FindFirstAncestorOfClass("Model")
		if targetChar and not seenChars[targetChar] then
			local targetHumanoid = targetChar:FindFirstChild("Humanoid")

			if targetHumanoid and targetChar ~= attacker and targetHumanoid.Health > 0 then
				if combatManager:ValidateHitbox(attacker, targetChar.HumanoidRootPart.Position, hitboxSize, skill.HitboxOffset) then
					seenChars[targetChar] = true
					table.insert(targetsHit, targetChar)
				end
			end
		end
	end

	-- ===== APPLY DAMAGE TO ALL TARGETS (once per character) =====
	local results = {Hits = 0, Blocked = 0, Dodged = 0, Parried = 0}

	local damageMultiplier = 1.0
	if comboIndex then
		damageMultiplier = 1.0 + (comboIndex - 1) * 0.15
	end

	for _, target in ipairs(targetsHit) do
		local result = combatManager:ApplyDamage(attacker, target, {}, {
			Damage = skill.Damage * damageMultiplier,
			HitstunDuration = skill.HitstunDuration,
			StatusEffects = skill.StatusEffects,
		})

		if result.hit then
			results.Hits = results.Hits + 1
			if result.hitType == "Blocked" then
				results.Blocked = results.Blocked + 1
			end
		elseif result.reason == "Dodge" then
			results.Dodged = results.Dodged + 1
		elseif result.reason == "Parry" then
			results.Parried = results.Parried + 1
		end
	end

	print("[SERVER] Hitbox results: " .. results.Hits .. " hits, " .. results.Blocked .. " blocked, " .. results.Dodged .. " dodged")

	task.delay(0.1, function()
		if AuthorizedSkills[player.UserId] == auth then
			AuthorizedSkills[player.UserId] = nil
		end
	end)
end)

-- ===== HANDLE PLAYER CLEANUP =====
Players.PlayerRemoving:Connect(function(player)
	AuthorizedSkills[player.UserId] = nil
	print("[SERVER] " .. player.Name .. " left")
end)

print("[SERVER] Combat system initialized")
