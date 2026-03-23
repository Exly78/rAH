-- ServerStorage.Modules.Handlers.WeaponServer
-- Handles all weapon model and equip-state remote events.

local WeaponData = require(game.ReplicatedStorage.Modules.Data.WeaponData)

local WeaponServer = {}

function WeaponServer.Setup(managers, CombatRemotes)
	local weaponManager = managers.weapon

	CombatRemotes.AddWeapon.OnServerEvent:Connect(function(player, weaponName)
		if not player or not player.Character then return end
		if type(weaponName) ~= "string" then return end

		local weapon = WeaponData:GetWeapon(weaponName)
		if not weapon then
			warn("[WeaponServer] Invalid weapon requested:", weaponName)
			return
		end

		weaponManager:AddWeaponToCharacter(player.Character, weaponName)
	end)

	CombatRemotes.RemoveWeapon.OnServerEvent:Connect(function(player)
		if not player or not player.Character then return end
		weaponManager:RemoveWeaponFromCharacter(player.Character)
	end)

	CombatRemotes.WeaponEquipped.OnServerEvent:Connect(function(player, weaponName)
		if not player or not player.Character then return end

		local weapon = WeaponData:GetWeapon(weaponName)
		if not weapon then
			warn("[WeaponServer] Invalid weapon:", weaponName)
			return
		end

		local character = player.Character

		if not weaponManager.CharacterWeapons[character] then
			weaponManager:AddWeaponToCharacter(character, weaponName)
		end

		character:SetAttribute("EquippedWeapon", weaponName)
		character:SetAttribute("IsEquipped", true)
	end)

	CombatRemotes.WeaponUnequipped.OnServerEvent:Connect(function(player)
		if not player or not player.Character then return end

		player.Character:SetAttribute("EquippedWeapon", nil)
		player.Character:SetAttribute("IsEquipped", false)
	end)

	CombatRemotes.WeaponWeldToHand.OnServerEvent:Connect(function(player)
		if not player or not player.Character then return end
		weaponManager:WeldToHand(player.Character)
	end)

	CombatRemotes.WeaponWeldToBody.OnServerEvent:Connect(function(player)
		if not player or not player.Character then return end
		weaponManager:WeldToBody(player.Character)
	end)
end

return WeaponServer
