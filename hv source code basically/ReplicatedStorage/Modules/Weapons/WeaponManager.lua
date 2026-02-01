local WeaponManager = {}
WeaponManager.__index = WeaponManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local WeaponsFolder = Assets:WaitForChild("Weapons")
local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)

local WELD_DATA = {
	Katana = {
		BodyAttach = CFrame.new(0, 0.05, 1.25) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		Sheathe = CFrame.new(-1.157, -1.244, -0.254) * CFrame.Angles(math.rad(15.181), math.rad(180), math.rad(180)),
		HandAttach = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
	},
	Greatsword = {
		BodyAttach = CFrame.new(-0.742, 0, -1.3) * CFrame.Angles(0, math.rad(90), math.rad(145)),
		HandAttach = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
	},
}

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

	self.BodyWeld = nil
	self.HandWeld = nil
	self.SheathWeld = nil

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

function WeaponManager:AddWeaponToCharacter(weaponName)
	if self.WeaponModel then
		self:RemoveWeaponFromCharacter()
	end

	local weaponTemplate = WeaponsFolder:FindFirstChild(weaponName)
	if not weaponTemplate then
		warn("[WeaponManager] Weapon not found:", weaponName)
		return false
	end

	self.WeaponModel = weaponTemplate:Clone()
	self.WeaponModel.Name = "Weapon"
	self.CurrentWeapon = weaponName

	for _, part in ipairs(self.WeaponModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end

	self.WeaponModel.Parent = self.Character

	local weldData = WELD_DATA[weaponName]
	if not weldData then
		warn("[WeaponManager] No weld data for:", weaponName)
		return false
	end

	local bodyAttach = self.WeaponModel:FindFirstChild("BodyAttach")
	if bodyAttach then
		self.BodyWeld = Instance.new("Motor6D")
		self.BodyWeld.Name = "TorsoWeld"
		self.BodyWeld.Parent = bodyAttach

		local sheathAttach = self.WeaponModel:FindFirstChild("Sheath") and self.WeaponModel.Sheath:FindFirstChild("BodyAttach")

		if sheathAttach then
			self.BodyWeld.Part0 = sheathAttach
		else
			self.BodyWeld.Part0 = self.Torso
		end

		self.BodyWeld.Part1 = bodyAttach
		self.BodyWeld.C0 = weldData.BodyAttach
	end

	local sheath = self.WeaponModel:FindFirstChild("Sheath")
	if sheath and weldData.Sheathe then
		local sheathAttach = sheath:FindFirstChild("BodyAttach")
		if sheathAttach then
			self.SheathWeld = Instance.new("Motor6D")
			self.SheathWeld.Name = "SheathWeld"
			self.SheathWeld.Parent = sheath
			self.SheathWeld.Part0 = self.Torso
			self.SheathWeld.Part1 = sheathAttach
			self.SheathWeld.C0 = weldData.Sheathe
		end
	end

	self.IsEquipped = false

	self.Character:SetAttribute("CurrentWeapon", weaponName)

	print("[WeaponManager] Added weapon to character:", weaponName, "- Welded to torso")
	return true
end

function WeaponManager:WeldToHand()
	if not self.WeaponModel or not self.RightArm then
		warn("[WeaponManager] Cannot weld to hand - missing weapon or arm")
		return
	end

	local bodyAttach = self.WeaponModel:FindFirstChild("BodyAttach")
	if not bodyAttach then
		warn("[WeaponManager] BodyAttach not found on weapon")
		return
	end

	if self.BodyWeld then
		self.BodyWeld:Destroy()
		self.BodyWeld = nil
	end

	self.HandWeld = Instance.new("Motor6D")
	self.HandWeld.Name = "HandWeld"
	self.HandWeld.Parent = bodyAttach
	self.HandWeld.Part0 = self.RightArm
	self.HandWeld.Part1 = bodyAttach

	local weldData = WELD_DATA[self.CurrentWeapon]
	if weldData and weldData.HandAttach then
		self.HandWeld.C0 = weldData.HandAttach
	else
		self.HandWeld.C0 = CFrame.new()
	end

	self.IsEquipped = true

	self.Character:SetAttribute("EquippedWeapon", self.CurrentWeapon)

	print("[WeaponManager] Weapon welded to hand")
end

function WeaponManager:WeldToBody()
	print("[DEBUG] Unequipping - HandWeld exists:", self.HandWeld ~= nil)
	print("[DEBUG] Current weapon:", self.CurrentWeapon)
	print("[DEBUG] Weld data:", WELD_DATA[self.CurrentWeapon])

	if not self.WeaponModel then
		warn("[WeaponManager] No weapon to weld to body")
		return
	end

	local bodyAttach = self.WeaponModel:FindFirstChild("BodyAttach")
	if not bodyAttach then
		warn("[WeaponManager] BodyAttach not found on weapon")
		return
	end

	if self.HandWeld then
		self.HandWeld:Destroy()
		self.HandWeld = nil
	end

	bodyAttach.CFrame = CFrame.new()

	self.BodyWeld = Instance.new("Motor6D")
	self.BodyWeld.Name = "TorsoWeld"
	self.BodyWeld.Parent = bodyAttach

	local sheath = self.WeaponModel:FindFirstChild("Sheath")
	local sheathAttach = sheath and sheath:FindFirstChild("BodyAttach")

	if sheathAttach then
		self.BodyWeld.Part0 = sheathAttach
	else
		self.BodyWeld.Part0 = self.Torso
	end

	self.BodyWeld.Part1 = bodyAttach

	local weldData = WELD_DATA[self.CurrentWeapon]
	if weldData then
		self.BodyWeld.C0 = weldData.BodyAttach
		self.BodyWeld.C1 = CFrame.new() 
	end

	self.IsEquipped = false

	print("[WeaponManager] Weapon welded to body")
end

function WeaponManager:RemoveWeaponFromCharacter()
	if self.WeaponModel then
		self.WeaponModel:Destroy()
		self.WeaponModel = nil
	end

	self.CurrentWeapon = nil
	self.IsEquipped = false
	self.BodyWeld = nil
	self.HandWeld = nil
	self.SheathWeld = nil

	self.Character:SetAttribute("CurrentWeapon", nil)
	self.Character:SetAttribute("EquippedWeapon", nil)

	print("[WeaponManager] Removed weapon from character")
end

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
	self:RemoveWeaponFromCharacter()
end

return WeaponManager