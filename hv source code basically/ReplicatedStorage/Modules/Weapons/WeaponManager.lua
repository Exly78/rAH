--ReplicatedStorage.Modules.Weapons.WeaponManager
-- CLIENT-SIDE: No longer clones weapon models.
-- Server creates/parents the model; this just finds it and fires remotes for weld swaps.

local WeaponManager = {}
WeaponManager.__index = WeaponManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)
local CombatRemotes = require(ReplicatedStorage.Modules.Remotes.CombatRemotes)

function WeaponManager.new(character)
	local self = setmetatable({}, WeaponManager)

	self.Character = character
	self.Humanoid = character:FindFirstChild("Humanoid")
	self.RootPart = character:FindFirstChild("HumanoidRootPart")
	self.RightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	self.Torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")

	self.CurrentWeapon = nil
	self.WeaponModel = nil
	self.IsEquipped = false

	return self
end

function WeaponManager:RegisterWeaponSkills()
	local swordSkills = {
		["SwordSlash"] = {
			Name = "Sword Slash",
			Damage = 25,
			HitstunDuration = 0.5,
			HitboxSize = Vector3.new(6, 6, 8),
			HitboxOffset = 6,
			Animation = "SwordSlash",
			Duration = 0.7,
			StatusEffects = {},
		},
		["SwordThrust"] = {
			Name = "Sword Thrust",
			Damage = 20,
			HitstunDuration = 0.6,
			HitboxSize = Vector3.new(4, 4, 12),
			HitboxOffset = 8,
			Animation = "SwordThrust",
			Duration = 0.8,
			StatusEffects = {
				Bleed = {Duration = 4, Potency = 0.2}
			},
		},
		["HeavyOverhead"] = {
			Name = "Heavy Overhead",
			Damage = 45,
			Cost = 25,
			Cooldown = 2.0,
			HitstunDuration = 1.2,
			HitboxSize = Vector3.new(12, 12, 12),
			HitboxOffset = 4,
			Animation = "HeavyOverhead",
			Duration = 1.5,
			StatusEffects = {
				Stun = {Duration = 1.5}
			},
		}
	}

	for skillName, skillData in pairs(swordSkills) do
		SkillData:AddSkill(skillName, skillData)
	end

	print("[WeaponManager] Registered weapon skills")
end

-- ===== ADD WEAPON (waits for server-created model) =====
function WeaponManager:AddWeaponToCharacter(weaponName)
	-- Tell server to create the weapon model
	CombatRemotes.AddWeapon:FireServer(weaponName)

	-- Wait for the server-created model to appear on the character
	local weaponModel = self.Character:WaitForChild("Weapon", 5)
	if not weaponModel then
		warn("[WeaponManager] Timed out waiting for server weapon model:", weaponName)
		return false
	end

	self.WeaponModel = weaponModel
	self.CurrentWeapon = weaponName
	self.IsEquipped = false

	self.Character:SetAttribute("CurrentWeapon", weaponName)

	print("[WeaponManager] Found server weapon model:", weaponName)
	return true
end

-- ===== WELD TO HAND (fires remote, server does the actual weld) =====
function WeaponManager:WeldToHand()
	if not self.WeaponModel then
		warn("[WeaponManager] Cannot weld to hand - no weapon model")
		return
	end

	CombatRemotes.WeaponWeldToHand:FireServer()
	self.IsEquipped = true
	self.Character:SetAttribute("EquippedWeapon", self.CurrentWeapon)

	print("[WeaponManager] Requested weld to hand")
end

-- ===== WELD TO BODY (fires remote, server does the actual weld) =====
function WeaponManager:WeldToBody()
	if not self.WeaponModel then
		warn("[WeaponManager] No weapon to weld to body")
		return
	end

	CombatRemotes.WeaponWeldToBody:FireServer()
	self.IsEquipped = false

	print("[WeaponManager] Requested weld to body")
end

-- ===== REMOVE WEAPON =====
function WeaponManager:RemoveWeaponFromCharacter()
	-- Tell server to destroy the model
	CombatRemotes.RemoveWeapon:FireServer()

	self.WeaponModel = nil
	self.CurrentWeapon = nil
	self.IsEquipped = false

	self.Character:SetAttribute("CurrentWeapon", nil)
	self.Character:SetAttribute("EquippedWeapon", nil)

	print("[WeaponManager] Requested weapon removal")
end

-- ===== QUERIES (unchanged) =====
function WeaponManager:GetWeaponModel()
	return self.WeaponModel
end

function WeaponManager:GetCurrentWeapon()
	return self.CurrentWeapon
end

function WeaponManager:IsWeaponEquipped()
	return self.IsEquipped
end

function WeaponManager:Destroy()
	-- Don't fire remove on destroy — character is probably being cleaned up anyway
	self.WeaponModel = nil
	self.CurrentWeapon = nil
	self.IsEquipped = false
end

return WeaponManager
