local Sword = {}
Sword.__index = Sword

function Sword.new(character)
	local self = setmetatable({}, Sword)
	self.Character = character
	self.Controller = character:FindFirstChild("CharacterController")
	self.IsEquipped = false
	return self
end

function Sword:Equip()
	if self.IsEquipped then return end

	local controller = self.Controller
	controller.MovementState.IsEquipped = true
	controller.MovementState.CurrentWeapon = "Sword"
	controller.Humanoid.WalkSpeed = 14  
	controller:SetAttribute("WeaponDamageMultiplier", 1.5)
	controller:PlayAnimation("SwordEquip")
	self.IsEquipped = true

	print("Sword equipped!")
end

function Sword:Unequip()
	if not self.IsEquipped then return end

	local controller = self.Controller
	controller.MovementState.IsEquipped = false
	controller:PlayAnimation("SwordUnequip")
	controller.MovementState.CurrentWeapon = nil

	controller.Humanoid.WalkSpeed = 16 
	controller:SetAttribute("WeaponDamageMultiplier", 1.0)

	self.IsEquipped = false

	print("Sword unequipped!")
end

function Sword:GetSkills()
	return {
		"SwordSlash",
		"SwordThrust",
		"HeavyOverhead"
	}
end

return Sword
