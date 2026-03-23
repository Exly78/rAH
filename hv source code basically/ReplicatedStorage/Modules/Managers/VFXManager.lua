-- ReplicatedStorage.Modules.Managers.VFXManager
-- Client-side only. Require from LocalScripts or ModuleScripts loaded on the client.
--
-- ─────────────────────────────────────────────
--  QUICK USAGE
-- ─────────────────────────────────────────────
--
--  local VFXManager = require(game.ReplicatedStorage.Modules.Managers.VFXManager)
--
--  -- Burst particles at a world position
--  VFXManager:Play("HitSpark", Vector3.new(0, 5, 0))
--
--  -- Attach particles to a part/character rootpart
--  VFXManager:Play("HitSpark", character.HumanoidRootPart)
--
--  -- Pass overrides (any registered field can be overridden per-call)
--  VFXManager:Play("HitSpark", part, { EmitCount = 30, Color = Color3.fromRGB(255, 0, 0) })
--
--  -- Looping effects return a handle — call :Stop() when done
--  local trail = VFXManager:Play("SlashTrail", weaponPart)
--  task.wait(0.4)
--  trail:Stop()
--
--  -- Play a sound at a part
--  VFXManager:Play("ParrySound", character.HumanoidRootPart)
--
--  -- Flash a highlight on a character
--  VFXManager:Play("HitFlash", character)
--
-- ─────────────────────────────────────────────
--  REGISTERING YOUR OWN EFFECTS
-- ─────────────────────────────────────────────
--
--  VFXManager:Register("MyEffect", {
--      Type      = "Particles",                    -- see types below
--      Template  = "Assets/VFX/MyParticle",        -- path inside ReplicatedStorage
--      EmitCount = 20,                             -- burst count
--      Duration  = 1.5,                            -- seconds before auto-cleanup
--      Looping   = false,                          -- true = enable emitter, return handle
--  })
--
-- ─────────────────────────────────────────────
--  EFFECT TYPES
-- ─────────────────────────────────────────────
--
--  "Particles"  Template = path to a ParticleEmitter (or folder of them) in ReplicatedStorage.
--               EmitCount, Looping, Duration, Color (Color3), Size (number or NumberSequence).
--
--  "Sound"      SoundId (rbxassetid://...), Volume (0-1), PlaybackSpeed (0-1), Duration.
--               No Template needed.
--
--  "Highlight"  Adds a Roblox Highlight to a Model/Part. No Template needed.
--               FillColor, OutlineColor, FillTransparency, OutlineTransparency, Duration.
--
--  "Billboard"  Template = path to a BillboardGui in ReplicatedStorage.
--               Duration. Override Text via options.Text for damage numbers etc.
--
-- ─────────────────────────────────────────────

local VFXManager  = {}
VFXManager.__index = VFXManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")

VFXManager._effects = {}

-- ===== REGISTER =====
function VFXManager:Register(name, config)
	self._effects[name] = config
end

-- ===== PLAY =====
-- target : Vector3 | BasePart | Attachment | Model
-- options: table of per-call overrides (optional)
-- returns: handle with :Stop() — safe to call even on non-looping effects
function VFXManager:Play(name, target, options)
	local config = self._effects[name]
	if not config then
		warn("[VFXManager] Unknown effect:", name)
		return { Stop = function() end }
	end

	options = options or {}
	local effectType = config.Type or "Particles"

	if effectType == "Particles" then
		return self:_playParticles(config, target, options)
	elseif effectType == "Sound" then
		return self:_playSound(config, target, options)
	elseif effectType == "Highlight" then
		return self:_playHighlight(config, target, options)
	elseif effectType == "Billboard" then
		return self:_playBillboard(config, target, options)
	else
		warn("[VFXManager] Unknown effect type:", effectType)
		return { Stop = function() end }
	end
end

-- ===== INTERNAL: resolve template path =====
function VFXManager:_resolveTemplate(templatePath)
	if not templatePath then return nil end
	local parts = string.split(templatePath, "/")
	local current = ReplicatedStorage
	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part)
		if not current then return nil end
	end
	return current
end

-- ===== INTERNAL: get a BasePart/Attachment to parent effects onto =====
-- Returns (parent, isTemporary).
-- isTemporary = true means we created a temporary Attachment that should be cleaned up.
function VFXManager:_getParent(target)
	if typeof(target) == "Vector3" then
		local att = Instance.new("Attachment")
		att.WorldPosition = target
		att.Parent = workspace.Terrain
		return att, true
	elseif typeof(target) == "Instance" then
		if target:IsA("Attachment") then
			return target, false
		elseif target:IsA("BasePart") then
			return target, false
		elseif target:IsA("Model") then
			local root = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
			return root, false
		end
	end
	return nil, false
end

-- ===== PARTICLES =====
function VFXManager:_playParticles(config, target, options)
	local templatePath = options.Template or config.Template
	local template = self:_resolveTemplate(templatePath)
	if not template then
		warn("[VFXManager] Particle template not found:", templatePath)
		return { Stop = function() end }
	end

	local parent, isTemp = self:_getParent(target)
	if not parent then return { Stop = function() end } end

	-- Template can be a single ParticleEmitter or a folder containing several
	local clones = {}
	if template:IsA("ParticleEmitter") then
		table.insert(clones, template:Clone())
	else
		for _, child in ipairs(template:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				table.insert(clones, child:Clone())
			end
		end
	end

	if #clones == 0 then
		warn("[VFXManager] No ParticleEmitters found in template:", templatePath)
		return { Stop = function() end }
	end

	-- Apply colour/size overrides and parent
	for _, emitter in ipairs(clones) do
		if options.Color then
			emitter.Color = ColorSequence.new(options.Color)
		end
		if options.Size then
			emitter.Size = typeof(options.Size) == "number"
				and NumberSequence.new(options.Size)
				or options.Size
		end
		emitter.Parent = parent
	end

	local looping    = options.Looping   ~= nil and options.Looping   or config.Looping   or false
	local emitCount  = options.EmitCount ~= nil and options.EmitCount or config.EmitCount or 20
	local duration   = options.Duration  ~= nil and options.Duration  or config.Duration  or 2

	local function cleanup()
		for _, e in ipairs(clones) do
			if e and e.Parent then e:Destroy() end
		end
		if isTemp and parent and parent.Parent then
			parent:Destroy()
		end
	end

	if looping then
		for _, e in ipairs(clones) do e.Enabled = true end

		local stopped = false
		return {
			Stop = function()
				if stopped then return end
				stopped = true
				for _, e in ipairs(clones) do
					if e and e.Parent then e.Enabled = false end
				end
				-- wait for existing particles to die before destroying
				task.delay(duration, cleanup)
			end
		}
	else
		-- Burst emit then auto-cleanup
		for _, e in ipairs(clones) do
			e.Enabled = false
			e:Emit(emitCount)
		end
		task.delay(duration, cleanup)
		return { Stop = cleanup }
	end
end

-- ===== SOUND =====
function VFXManager:_playSound(config, target, options)
	local parent, isTemp = self:_getParent(target)

	local sound = Instance.new("Sound")
	sound.SoundId            = options.SoundId       or config.SoundId       or ""
	sound.Volume             = options.Volume        or config.Volume        or 0.5
	sound.PlaybackSpeed      = options.PlaybackSpeed or config.PlaybackSpeed or 1
	sound.RollOffMaxDistance = config.RollOffMaxDistance or 60
	sound.Parent             = parent or workspace

	sound:Play()

	local function cleanup()
		if sound and sound.Parent then sound:Destroy() end
		if isTemp and parent and parent.Parent then parent:Destroy() end
	end

	local duration = options.Duration or config.Duration
	if duration then
		task.delay(duration + 0.1, cleanup)
	else
		sound.Ended:Once(cleanup)
	end

	return { Stop = function() if sound and sound.Parent then sound:Stop() end cleanup() end }
end

-- ===== HIGHLIGHT =====
function VFXManager:_playHighlight(config, target, options)
	-- Highlights need a Model or BasePart as adornee
	local adornee
	if typeof(target) == "Instance" then
		if target:IsA("Model") then
			adornee = target
		elseif target:IsA("BasePart") then
			adornee = (target.Parent and target.Parent:IsA("Model")) and target.Parent or target
		end
	end
	if not adornee then return { Stop = function() end } end

	local hl = Instance.new("Highlight")
	hl.FillColor             = options.FillColor             or config.FillColor             or Color3.fromRGB(255, 255, 255)
	hl.OutlineColor          = options.OutlineColor          or config.OutlineColor          or Color3.fromRGB(255, 255, 255)
	hl.FillTransparency      = options.FillTransparency      or config.FillTransparency      or 0.5
	hl.OutlineTransparency   = options.OutlineTransparency   or config.OutlineTransparency   or 0
	hl.Adornee               = adornee
	hl.Parent                = adornee

	local duration = options.Duration or config.Duration
	if duration then
		task.delay(duration, function()
			if hl and hl.Parent then hl:Destroy() end
		end)
	end

	return { Stop = function() if hl and hl.Parent then hl:Destroy() end end }
end

-- ===== BILLBOARD =====
function VFXManager:_playBillboard(config, target, options)
	local templatePath = options.Template or config.Template
	local template = self:_resolveTemplate(templatePath)
	if not template then
		warn("[VFXManager] Billboard template not found:", templatePath)
		return { Stop = function() end }
	end

	local parent, isTemp = self:_getParent(target)
	if not parent then return { Stop = function() end } end

	local clone = template:Clone()

	-- Allow text override for damage numbers
	if options.Text then
		local label = clone:FindFirstChildWhichIsA("TextLabel", true)
		if label then label.Text = tostring(options.Text) end
	end

	-- Allow colour override on the label
	if options.Color then
		local label = clone:FindFirstChildWhichIsA("TextLabel", true)
		if label then label.TextColor3 = options.Color end
	end

	clone.Parent = parent

	local duration = options.Duration or config.Duration or 1
	task.delay(duration, function()
		if clone and clone.Parent then clone:Destroy() end
		if isTemp and parent and parent.Parent then parent:Destroy() end
	end)

	return { Stop = function() if clone and clone.Parent then clone:Destroy() end end }
end

-- ═══════════════════════════════════════════════
--  BUILT-IN EFFECT DEFINITIONS
--  Swap Template paths to match your asset tree.
--  All particle templates live in:
--    ReplicatedStorage/Assets/VFX/<Name>
--  Each should be a ParticleEmitter or a Folder of ParticleEmitters.
-- ═══════════════════════════════════════════════

-- Hit sparks when an attack connects
VFXManager:Register("HitSpark", {
	Type      = "Particles",
	Template  = "Assets/VFX/HitSpark",
	EmitCount = 15,
	Duration  = 1.5,
})

-- Larger impact flash when a heavy/crit hit lands
VFXManager:Register("HeavyHitSpark", {
	Type      = "Particles",
	Template  = "Assets/VFX/HitSpark",
	EmitCount = 35,
	Duration  = 2.0,
})

-- Particles on the weapon during a swing (looping, stopped by AttackState)
VFXManager:Register("SlashTrail", {
	Type     = "Particles",
	Template = "Assets/VFX/SlashTrail",
	Looping  = true,
	Duration = 0.25,   -- fade time after Stop()
})

-- Particles on the character during a slide attack
VFXManager:Register("SlideAttackTrail", {
	Type     = "Particles",
	Template = "Assets/VFX/SlashTrail",
	Looping  = true,
	Duration = 0.2,
})

-- Block/parry impact burst
VFXManager:Register("BlockImpact", {
	Type      = "Particles",
	Template  = "Assets/VFX/BlockImpact",
	EmitCount = 12,
	Duration  = 1.0,
})

-- Dodge trail that follows the character
VFXManager:Register("DodgeTrail", {
	Type     = "Particles",
	Template = "Assets/VFX/DodgeTrail",
	Looping  = true,
	Duration = 0.3,
})

-- Flash the character red on a normal hit
VFXManager:Register("HitFlash", {
	Type               = "Highlight",
	FillColor          = Color3.fromRGB(220, 40, 40),
	OutlineColor       = Color3.fromRGB(255, 0, 0),
	FillTransparency   = 0.35,
	OutlineTransparency = 0,
	Duration           = 0.12,
})

-- Flash the character gold on a successful parry
VFXManager:Register("ParryFlash", {
	Type               = "Highlight",
	FillColor          = Color3.fromRGB(255, 210, 30),
	OutlineColor       = Color3.fromRGB(255, 255, 100),
	FillTransparency   = 0.2,
	OutlineTransparency = 0,
	Duration           = 0.2,
})

-- Flash the attacker white when they get parried
VFXManager:Register("GotParriedFlash", {
	Type               = "Highlight",
	FillColor          = Color3.fromRGB(255, 255, 255),
	OutlineColor       = Color3.fromRGB(200, 200, 200),
	FillTransparency   = 0.1,
	OutlineTransparency = 0,
	Duration           = 0.25,
})

-- Floating damage number (requires a BillboardGui template)
VFXManager:Register("DamageNumber", {
	Type     = "Billboard",
	Template = "Assets/VFX/DamageNumber",  -- BillboardGui with a TextLabel inside
	Duration = 0.9,
})

return VFXManager
