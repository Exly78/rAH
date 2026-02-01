local CombatController = {}
CombatController.__index = CombatController

local WeaponManager = require(game.ReplicatedStorage.Modules.Weapons.WeaponManager)
local HitboxManager = require(script.Parent.Parent.Managers.HitboxManager) -- Adjust path
local CombatRemotes = require(game.ReplicatedStorage.Modules.Remotes.CombatRemotes)
local SkillData = require(script.Parent.Parent.Data.SkillData) -- Adjust path
local TagManager = require(game.ReplicatedStorage.Modules.Managers.TagManager)

local DAMAGE_MULTIPLIERS = { UNARMED = 1.0, KATANA = 1.5 }
local COMBO_CONFIG = { RESET_DELAY = 1.5, MAX_COUNT = 5 }

function CombatController.new(characterController)
	local self = setmetatable({}, CombatController)

	self.CC = characterController
	self.Character = characterController.Character
	self.WeaponManager = WeaponManager.new(self.Character)
	self.HitboxManager = HitboxManager.new()

	self.CurrentWeapon = nil
	self.ComboCount = 0
	self.ComboResetTimer = 0
	self.QueuedAttack = false
	self.CanQueueNextAttack = false

	self.Character:SetAttribute("IsEquipped", false)
	self.Character:SetAttribute("WeaponDamageMultiplier", DAMAGE_MULTIPLIERS.UNARMED)

	self:SetupRemoteListeners()

	return self
end

function CombatController:Update(dt)
	if self.ComboResetTimer > 0 then
		self.ComboResetTimer = self.ComboResetTimer - dt
		if self.ComboResetTimer <= 0 then
			self:ResetCombo()
		end
	end
end

-- ===== WEAPON MANAGEMENT =====
function CombatController:EquipWeapon(weaponName)
	weaponName = weaponName or "Katana"
	if self.Character:GetAttribute("IsEquipped") then return end

	self.CurrentWeapon = weaponName
	self.Character:SetAttribute("IsEquipped", true)
	self.Character:SetAttribute("WeaponDamageMultiplier", DAMAGE_MULTIPLIERS.KATANA)
	CombatRemotes.WeaponEquipped:FireServer(weaponName)

	self.CC.AnimationManager:Play("Katana_WeaponIdle", 0)
	self.CC.AnimationManager:Play("Katana_Equip")

	task.delay(0.05, function()
		self.CC:ConnectWeldKeyframe("Weld", function()
			self.WeaponManager:WeldToHand()
		end)
	end)
end

function CombatController:UnequipWeapon()
	if not self.Character:GetAttribute("IsEquipped") then return end

	self.Character:SetAttribute("IsEquipped", false)
	self.Character:SetAttribute("WeaponDamageMultiplier", DAMAGE_MULTIPLIERS.UNARMED)
	CombatRemotes.WeaponUnequipped:FireServer()

	local weaponName = self.CurrentWeapon
	self.CC:PlayAnimation("Unequip")

	local keyframeFired = false
	self.CC.AnimationManager:OnKeyframe("Weld", function()
		self.WeaponManager:WeldToBody()
		keyframeFired = true
		self.CC.AnimationManager:Stop(weaponName .. "_WeaponIdle")
		self.CC.AnimationManager:StopAll(0.2, true)
		self.CurrentWeapon = nil
	end)

	-- Fallback if animation fails/cancels
	task.delay(1.5, function()
		if not keyframeFired and self.CurrentWeapon == weaponName then
			self.WeaponManager:WeldToBody()
			self.CC.AnimationManager:StopAll(0.2, true)
			self.CurrentWeapon = nil
		end
	end)
end

-- ===== COMBAT ACTIONS =====
function CombatController:PerformBasicAttack()
	if not self.CurrentWeapon or not self.WeaponManager:IsWeaponEquipped() then return end

	-- Check State
	local stateMachine = self.CC.StateMachine
	if stateMachine:IsInState("Hitstun") or stateMachine:IsInState("KnockedOut") then return end

	if stateMachine:IsInState("Attack") then
		if self.CanQueueNextAttack and not self.QueuedAttack then
			self.QueuedAttack = true
		end
		return
	end

	if not stateMachine:IsInState("Idle") then return end

	self:AdvanceCombo()
	local attackAnim = "Attack" .. self.ComboCount
	self.CC:PlayAnimation(attackAnim, 0)

	stateMachine:SetState("Attack", {
		attackType = "BasicAttack",
		comboIndex = self.ComboCount,
		endlag = 0.2,
	})

	CombatRemotes.SkillRequest:FireServer("BasicAttack", self.ComboCount)
end

function CombatController:PerformCriticalAttack()
	if not self.CurrentWeapon or not self.CC.StateMachine:IsInState("Idle") then return end

	self.CC:PlayAnimation("Critical")
	self.CC.StateMachine:SetState("Attack", { attackType = "CriticalAttack", endlag = 0.4 })
	CombatRemotes.SkillRequest:FireServer("CriticalAttack")
end

-- ===== COMBO LOGIC =====
function CombatController:ResetCombo()
	self.ComboCount = 0
	self.CanQueueNextAttack = false
	self.QueuedAttack = false
end

function CombatController:AdvanceCombo()
	self.ComboCount = self.ComboCount + 1
	if self.ComboCount > COMBO_CONFIG.MAX_COUNT then self.ComboCount = 1 end
	self.ComboResetTimer = COMBO_CONFIG.RESET_DELAY
	self.CanQueueNextAttack = false
	self.QueuedAttack = false
end

-- ===== STATUS EFFECTS =====
function CombatController:ApplyHitstun(duration)
	if self.CC:IsInvulnerable() then return end

	TagManager.AddTag(self.Character, "Hitstunned", duration)
	self.CC:PlayAnimation("Hitstun")

	if not self.CC.StateMachine:IsInState("Hitstun") then
		self.CC.StateMachine:SetState("Hitstun", { duration = duration })
	end
end

function CombatController:SetupRemoteListeners()
	CombatRemotes.ApplyHitstun.OnClientEvent:Connect(function(target, duration)
		if target == self.Character then self:ApplyHitstun(duration) end
	end)
	-- Add other remotes here
end

function CombatController:Destroy()
	self.WeaponManager:Destroy()
	self.HitboxManager:Destroy()
end

return CombatController