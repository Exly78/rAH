-- ServerScriptService.CombatServer

local Players               = game:GetService("Players")
local CombatRemotes         = require(game.ServerStorage.Modules.Remotes.CombatRemotes)
local ServerCombatManager   = require(game.ServerStorage.Modules.Managers.ServerCombatManager)
local ServerHealthManager   = require(game.ServerStorage.Modules.Managers.ServerHealthManager)
local ServerStatusManager   = require(game.ServerStorage.Modules.Managers.ServerStatusManager)
local ServerCriticalManager = require(game.ServerStorage.Modules.Managers.ServerCriticalManager)
local ServerWeaponManager   = require(game.ServerStorage.Modules.Weapons.ServerWeaponManager)
local SkillData             = require(game.ReplicatedStorage.Modules.Data.SkillData)
local WeaponData            = require(game.ReplicatedStorage.Modules.Data.WeaponData)
local TagManager            = require(game.ReplicatedStorage.Modules.Managers.TagManager)

-- ===== MANAGER INIT =====
local healthManager   = ServerHealthManager.new()
local statusManager   = ServerStatusManager.new(healthManager, CombatRemotes)
local combatManager   = ServerCombatManager.new(healthManager, statusManager)
local weaponManager   = ServerWeaponManager.new()
local criticalManager = ServerCriticalManager.new(healthManager, combatManager, weaponManager)
combatManager:SetupPlayerListeners()

local AuthorizedSkills = {}

-- Anti-spam tracking
local DodgeCooldowns = {}
local DODGE_COOLDOWN     = 0.5
local MAX_DODGE_DURATION = 0.6

local BlockCooldowns = {}
local BLOCK_COOLDOWN     = 0.1
local MAX_PARRY_WINDOW   = 0.3
local MAX_BLOCK_DURATION = 10.0

-- ========================================================
-- WEAPON MODEL MANAGEMENT
-- ========================================================

CombatRemotes.AddWeapon.OnServerEvent:Connect(function(player, weaponName)
	if not player or not player.Character then return end
	if type(weaponName) ~= "string" then return end

	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then
		warn("[SERVER] Invalid weapon requested:", weaponName)
		return
	end

	weaponManager:AddWeaponToCharacter(player.Character, weaponName)
	print("[SERVER]", player.Name, "spawned weapon:", weaponName)
end)

CombatRemotes.RemoveWeapon.OnServerEvent:Connect(function(player)
	if not player or not player.Character then return end
	weaponManager:RemoveWeaponFromCharacter(player.Character)
end)

CombatRemotes.WeaponEquipped.OnServerEvent:Connect(function(player, weaponName)
	if not player or not player.Character then return end

	local weapon = WeaponData:GetWeapon(weaponName)
	if not weapon then
		warn("[SERVER] Invalid weapon:", weaponName)
		return
	end

	local character = player.Character

	-- If AddWeapon was never called (e.g. Sword:Equip skips it), create the weapon now
	if not weaponManager.CharacterWeapons[character] then
		weaponManager:AddWeaponToCharacter(character, weaponName)
	end

	character:SetAttribute("EquippedWeapon", weaponName)
	character:SetAttribute("IsEquipped", true)
	print("[SERVER]", player.Name, "equipped", weaponName)
end)

CombatRemotes.WeaponUnequipped.OnServerEvent:Connect(function(player)
	if not player or not player.Character then return end

	player.Character:SetAttribute("EquippedWeapon", nil)
	player.Character:SetAttribute("IsEquipped", false)
	print("[SERVER]", player.Name, "unequipped weapon")
end)

CombatRemotes.WeaponWeldToHand.OnServerEvent:Connect(function(player)
	if not player or not player.Character then return end
	weaponManager:WeldToHand(player.Character)
end)

CombatRemotes.WeaponWeldToBody.OnServerEvent:Connect(function(player)
	if not player or not player.Character then return end
	weaponManager:WeldToBody(player.Character)
end)

-- ========================================================
-- DODGE / BLOCK / PARRY STATE
-- ========================================================

CombatRemotes.DodgeStarted.OnServerEvent:Connect(function(player, dodgeDuration)
	if not player or not player.Character then return end

	local character = player.Character
	local humanoid  = character:FindFirstChild("Humanoid")
	if not humanoid or healthManager:IsDead(character) then return end

	dodgeDuration = math.min(tonumber(dodgeDuration) or 0.45, MAX_DODGE_DURATION)
	if dodgeDuration <= 0 then return end

	local userId = player.UserId
	local now    = tick()
	if DodgeCooldowns[userId] and (now - DodgeCooldowns[userId]) < DODGE_COOLDOWN then return end
	DodgeCooldowns[userId] = now

	if TagManager.HasTag(character, "Hitstunned") or TagManager.HasTag(character, "KnockedOut") then return end

	TagManager.Initialize(character)
	TagManager.AddTag(character, "Invulnerable", dodgeDuration)
	TagManager.AddTag(character, "Dodging",      dodgeDuration)

	print("[SERVER]", player.Name, "dodge started (" .. dodgeDuration .. "s)")
end)

CombatRemotes.BlockStarted.OnServerEvent:Connect(function(player, parryWindow)
	if not player or not player.Character then return end

	local character = player.Character
	local humanoid  = character:FindFirstChild("Humanoid")
	if not humanoid or healthManager:IsDead(character) then return end

	parryWindow = math.min(tonumber(parryWindow) or 0.20, MAX_PARRY_WINDOW)
	if parryWindow <= 0 then return end

	local userId = player.UserId
	local now    = tick()
	if BlockCooldowns[userId] and (now - BlockCooldowns[userId]) < BLOCK_COOLDOWN then return end
	BlockCooldowns[userId] = now

	if TagManager.HasTag(character, "Hitstunned") or TagManager.HasTag(character, "KnockedOut") then return end

	TagManager.Initialize(character)
	TagManager.AddTag(character, "CanParry", parryWindow)
	TagManager.AddTag(character, "Parrying", parryWindow)

	task.delay(parryWindow, function()
		if character and character.Parent then
			if not TagManager.HasTag(character, "CanParry") then
				TagManager.AddTag(character, "IsBlocking", MAX_BLOCK_DURATION)
				TagManager.AddTag(character, "Blocking",   MAX_BLOCK_DURATION)
			end
		end
	end)

	print("[SERVER]", player.Name, "block started (parry: " .. parryWindow .. "s)")
end)

CombatRemotes.BlockEnded.OnServerEvent:Connect(function(player)
	if not player or not player.Character then return end

	local character = player.Character
	TagManager.RemoveTag(character, "CanParry")
	TagManager.RemoveTag(character, "Parrying")
	TagManager.RemoveTag(character, "IsBlocking")
	TagManager.RemoveTag(character, "Blocking")

	print("[SERVER]", player.Name, "block ended")
end)

-- ========================================================
-- SKILL REQUEST
-- ========================================================

CombatRemotes.SkillRequest.OnServerEvent:Connect(function(player, skillName)
	if not player or not player.Character then return end

	local skill = SkillData:GetSkill(skillName)
	if not skill then
		-- StarterPlayer.StarterPlayerScripts.MainScript

		local RunService = game:GetService("RunService")
		local Players    = game:GetService("Players")
		local UIS        = game:GetService("UserInputService")

		local player    = Players.LocalPlayer
		if not player then return end

		local character = player.Character or player.CharacterAdded:Wait()

		local Modules           = game.ReplicatedStorage:WaitForChild("Modules")
		local CharacterController = require(Modules.Controllers:WaitForChild("CharacterController"))
		local Store             = require(Modules.Controllers:WaitForChild("ControllerStore"))

		local controller = CharacterController.new(character, {})
		Store.Controller = controller

		local humanoid = controller.Humanoid
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

		print("=== COMBAT SYSTEM READY ===")

		controller.WantsDodge    = false
		controller.WantsBlock    = false
		controller.IsHoldingBlock = false

		-- ===== INPUT HANDLING =====
		UIS.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			local state = humanoid:GetState()

			-- Jump
			if input.KeyCode == Enum.KeyCode.Space then
				if state ~= Enum.HumanoidStateType.Freefall then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end

			-- Dodge (Q)
			if input.KeyCode == Enum.KeyCode.Q then
				controller.WantsDodge = true
			end

			-- Block / Parry (F)
			if input.KeyCode == Enum.KeyCode.F then
				if controller.StateMachine:IsInState("Block") then
					controller.IsHoldingBlock = true
					local blockState = controller.StateMachine.CurrentState
					if blockState and blockState.SetHolding then
						blockState:SetHolding(true)
					end
				else
					controller.WantsBlock    = true
					controller.IsHoldingBlock = true
				end
			end

			-- Equip / Unequip (E)
			if input.KeyCode == Enum.KeyCode.E then
				if character:GetAttribute("IsEquipped") then
					controller.CombatController:UnequipWeapon()
					print("[CONTROLS] Unequipped")
				else
					controller.CombatController:EquipWeapon("Katana")
					print("[CONTROLS] Equipped")
				end
			end

			-- Critical Attack (R)
			-- Phase is determined inside PerformCriticalAttack based on AltCrit attribute
			if input.KeyCode == Enum.KeyCode.R then
				if character:GetAttribute("IsEquipped") then
					controller.CombatController:PerformCriticalAttack()
				end
			end

			-- Basic Attack (Left Click)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if character:GetAttribute("IsEquipped") then
					controller.CombatController:PerformBasicAttack()
				end
			end
		end)

		UIS.InputEnded:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			if input.KeyCode == Enum.KeyCode.Q then
				controller.WantsDodge = false
			end

			if input.KeyCode == Enum.KeyCode.F then
				controller.IsHoldingBlock = false

				if controller.StateMachine:IsInState("Block") then
					local blockState = controller.StateMachine.CurrentState
					if blockState and blockState.SetHolding then
						blockState:SetHolding(false)
					end
				end

				controller.WantsBlock = false
			end
		end)

		-- ===== MAIN LOOP =====
		RunService.Heartbeat:Connect(function(dt)
			local success, err = pcall(function()
				controller:Update(dt)
			end)
			if not success then
				warn("Controller update error:", err)
			end
		end)		warn("[SERVER] Invalid skill:", skillName)
		return
	end

	local validation = combatManager:RequestSkill(player, skillName)
	if not validation.success then
		print("[SERVER] Skill rejected:", validation.reason)
		return
	end

	print("[SERVER]", player.Name, "authorized to cast", skillName)

	AuthorizedSkills[player.UserId] = {
		skillName = skillName,
		timestamp = tick(),
		used      = false,
	}
end)

-- ========================================================
-- HITBOX CREATION
-- ========================================================

CombatRemotes.CreateHitbox.OnServerEvent:Connect(function(player, skillName, comboIndex)
	if not player or not player.Character then return end

	local attacker = player.Character
	local humanoid = attacker:FindFirstChild("Humanoid")
	if not humanoid or healthManager:IsDead(attacker) then return end

	local auth = AuthorizedSkills[player.UserId]
	if not auth or auth.used then
		warn("[SERVER] Unauthorized hitbox from", player.Name)
		return
	end

	if tick() - auth.timestamp > 2 then
		warn("[SERVER] Expired hitbox auth from", player.Name)
		AuthorizedSkills[player.UserId] = nil
		return
	end

	auth.used = true

	local skill = SkillData:GetSkill(skillName)
	if not skill then
		warn("[SERVER] Invalid skill in hitbox:", skillName)
		return
	end

	-- Attacker is acting — tick their own OnAction status effects
	statusManager:NotifyAction(attacker)

	-- ============================================================
	-- CRITICAL ATTACKS — delegated entirely to ServerCriticalManager
	-- ============================================================
	if skill.IsCritical then
		criticalManager:HandleCritical(player, skill.CriticalPhase)
		task.delay(0.1, function()
			if AuthorizedSkills[player.UserId] == auth then
				AuthorizedSkills[player.UserId] = nil
			end
		end)
		return
	end

	-- ============================================================
	-- NORMAL HITBOX
	-- ============================================================
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

	local damageMultiplier = 1.0
	if comboIndex then
		damageMultiplier = 1.0 + (comboIndex - 1) * 0.15
	end

	local results = { Hits = 0, Blocked = 0, Dodged = 0, Parried = 0, BlockBroken = 0, Missed = 0 }

	for _, target in ipairs(targetsHit) do
		local result = combatManager:ApplyDamage(attacker, target, {
			Damage                = skill.Damage * damageMultiplier,
			HitstunDuration       = skill.HitstunDuration,
			StatusEffects         = skill.StatusEffects,
			PostureDamage         = skill.PostureDamage,
			ChipDamage            = skill.ChipDamage,
			IsCriticalHit         = skill.IsCritical or false,
			AttackType            = skill.AttackType or "Default",
			BlockBreakDamage      = skill.BlockBreakDamage,
			AttackStartTime       = skill.AttackStartTime,
			CounterWindowDuration = skill.CounterWindowDuration,
		})

		if result.hit then
			results.Hits += 1
			if result.hitType == "Blocked"     then results.Blocked     += 1 end
			if result.hitType == "BlockBroken" then results.BlockBroken += 1 end
		elseif result.reason == "Dodged"  then results.Dodged  += 1
		elseif result.reason == "Parried" then results.Parried += 1
		elseif result.reason == "Missed"  then results.Missed  += 1
		end
	end

	print("[SERVER] Hitbox:", results.Hits, "hits,", results.Blocked, "blocked,",
		results.Dodged, "dodged,", results.Parried, "parried,",
		results.BlockBroken, "block broken,", results.Missed, "missed")

	task.delay(0.1, function()
		if AuthorizedSkills[player.UserId] == auth then
			AuthorizedSkills[player.UserId] = nil
		end
	end)
end)

-- ========================================================
-- PLAYER CLEANUP
-- ========================================================

Players.PlayerRemoving:Connect(function(player)
	AuthorizedSkills[player.UserId] = nil
	DodgeCooldowns[player.UserId]   = nil
	BlockCooldowns[player.UserId]   = nil
	criticalManager:CleanupPlayer(player)

	if player.Character then
		statusManager:RemoveAll(player.Character)
		weaponManager:CleanupCharacter(player.Character)
	end
end)

print("[SERVER] Combat system initialized (weapons + health + status effects + dodge/block/parry)")
