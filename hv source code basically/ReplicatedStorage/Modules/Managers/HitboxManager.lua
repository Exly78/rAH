-- ReplicatedStorage/Modules/Managers/HitboxManager.lua
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HitboxManager = {}
HitboxManager.__index = HitboxManager

function HitboxManager.new()
	local self = setmetatable({}, HitboxManager)
	self.Active = {} 
	return self
end

function HitboxManager:_scan(attacker, cframe, size, hitMap)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { attacker }

	local parts = Workspace:GetPartBoundsInBox(cframe, size, params)
	local results = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChild("Humanoid")

		if humanoid and not hitMap[model] then
			hitMap[model] = true
			table.insert(results, model)
			
		end
	end

	return results
end

function HitboxManager:CreateSingle(attacker, cframe, size)
	local hitMap = {}
	return self:_scan(attacker, cframe, size, hitMap)
end

function HitboxManager:CreateContinuous(attacker, config)
	if self.Active[attacker] then return end
	if not config or not config.Duration or not config.Size or not config.ForwardOffset then
		warn("[HitboxManager] Invalid config for CreateContinuous")
		return
	end

	local root = attacker:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local hitMap = {}
	local elapsed = 0
	local interval = config.Interval or 0.07

	self.Active[attacker] = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		if elapsed >= config.Duration then
			self:Stop(attacker)
			return
		end

		if (elapsed % interval) < dt then
			local boxCF = root.CFrame * CFrame.new(0, 0, -config.ForwardOffset)

			local hits = self:_scan(attacker, boxCF, config.Size, hitMap)
			for _, target in ipairs(hits) do
				if config.OnHit then
					config.OnHit(target)
				end
			end
		end
	end)
end

function HitboxManager:Stop(attacker)
	if self.Active[attacker] then
		self.Active[attacker]:Disconnect()
		self.Active[attacker] = nil
	end
end

function HitboxManager:Destroy()
	for attacker, conn in pairs(self.Active) do
		conn:Disconnect()
	end
	self.Active = {}
end

return HitboxManager
