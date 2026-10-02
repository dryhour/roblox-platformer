local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Camera = require(script.Parent.Camera)
local Sounds = require(script.Parent.Sounds)

-- What players see on top of the physics:
--   * every ball's brainrot look, moved each frame to follow its sphere (the server only places
--     it once), facing the way it rolls and growing with it
--   * effects the server sends: hits, damage and heal numbers, wall sparks, explosions and
--     knockouts
local Visuals = {}

local TURN_SHARPNESS = 12
local MAX_LEAN = math.rad(12)

type LookCache = {
	look: Instance,
	parts: { BasePart },
	offsets: { CFrame },
	sizes: { Vector3 },
	spins: { number },
	yaw: number,
	scale: number,
}

local caches: { [Model]: LookCache } = {}

local function angleLerp(from: number, to: number, alpha: number): number
	local difference = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + difference * alpha
end

local function yawOf(direction: Vector3): number
	-- The yaw that points a look's front (-Z) along `direction`.
	return math.atan2(-direction.X, -direction.Z)
end

local function cacheFor(model: Model): LookCache?
	local look = model:FindFirstChild("Look")
	if not look then
		return nil
	end
	local cache = caches[model]
	if cache and cache.look == look then
		return cache
	end

	local parts, offsets, sizes, spins = {}, {}, {}, {}
	for _, part in look:GetChildren() do
		local offset = part:GetAttribute("Offset")
		if part:IsA("BasePart") and typeof(offset) == "CFrame" then
			table.insert(parts, part)
			table.insert(offsets, offset)
			table.insert(sizes, part.Size)
			table.insert(spins, part:GetAttribute("Spin") or 0)
		end
	end
	local forward = model:GetAttribute("Forward")
	cache = {
		look = look,
		parts = parts,
		offsets = offsets,
		sizes = sizes,
		spins = spins,
		yaw = if typeof(forward) == "Vector3" then yawOf(forward) else 0,
		scale = 1,
	}
	caches[model] = cache
	return cache
end

local function updateLooks(deltaTime: number)
	local allParts: { BasePart } = {}
	local allCFrames: { CFrame } = {}
	local now = os.clock()
	for _, model in CollectionService:GetTagged("Ball") do
		local core = model:IsA("Model") and model.PrimaryPart
		local cache = core and cacheFor(model)
		if not core or not cache then
			continue
		end

		-- Balls that grow (Charge) scale their look to match.
		local scale = core.Size.X / Config.BALL_SIZE
		if math.abs(scale - cache.scale) > 0.01 then
			cache.scale = scale
			for index, part in cache.parts do
				part.Size = cache.sizes[index] * scale
			end
		end

		local velocity = core.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		if speed > 2 then
			cache.yaw = angleLerp(cache.yaw, yawOf(flat), 1 - math.exp(-TURN_SHARPNESS * deltaTime))
		end
		local lean = CFrame.Angles(-MAX_LEAN * math.clamp(speed / 60, 0, 1), 0, 0)
		local center = CFrame.new(core.Position) * CFrame.Angles(0, cache.yaw, 0) * lean
		for index, part in cache.parts do
			local offset = cache.offsets[index]
			offset = CFrame.new(offset.Position * scale) * offset.Rotation
			local spin = cache.spins[index]
			if spin ~= 0 then
				offset *= CFrame.Angles(0, 0, now * spin)
			end
			table.insert(allParts, part)
			table.insert(allCFrames, center * offset)
		end
	end
	if #allParts > 0 then
		workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for model in caches do
		if not model.Parent then
			caches[model] = nil
		end
	end
end

-- Effects

local function holder(position: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = workspace
	Debris:AddItem(part, lifetime)
	return part
end

local function burst(position: Vector3, colors: { Color3 }, count: number, speed: number)
	local part = holder(position, 2)
	for _, color in colors do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 0.4
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
		emitter.Speed = NumberRange.new(speed * 0.5, speed)
		emitter.Lifetime = NumberRange.new(0.4, 0.9)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 3
		emitter.Acceleration = Vector3.new(0, -40, 0)
		emitter.Rate = 0
		emitter.Parent = part
		emitter:Emit(math.ceil(count / #colors))
	end
end

-- Text that pops up over a spot and floats away: comic words and damage numbers.
local function pop(position: Vector3, text: string, color: Color3, size: number)
	local part = holder(position, 1)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(size * 0.4, size * 0.13)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	billboard.Parent = part

	local grow = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(billboard, grow, { Size = UDim2.fromScale(size, size * 0.32) }):Play()
	local rise = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(billboard, rise, { StudsOffset = Vector3.new(0, 10, 0) }):Play()
	TweenService:Create(label, rise, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function ring(position: Vector3, radius: number, color: Color3)
	local part = holder(position, 0.6)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 2, 2)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.2
	TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
end

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 230, 110)
local ORANGE = Color3.fromRGB(255, 150, 40)
local PURPLE = Color3.fromRGB(150, 70, 230)

local function onEffect(kind: string, position: Vector3, data: any, amount: any)
	if kind == "Impact" then
		local brainrot = Brainrots.get(data)
		burst(position, { brainrot.color, Color3.new(1, 1, 1) }, 20, 40)
		pop(position + Vector3.new(0, 3, 0), brainrot.word, brainrot.color, 16)
		Sounds.play("Hit")
		Camera.shake(math.clamp((tonumber(amount) or 0) / 150, 0.15, 0.6))
	elseif kind == "Damage" then
		pop(position, `-{data}`, RED, 9)
	elseif kind == "Heal" then
		pop(position, `+{data}`, GREEN, 9)
	elseif kind == "Wall" then
		burst(position, { Color3.fromRGB(120, 220, 255) }, 6, 20)
	elseif kind == "Explosion" then
		local size = tonumber(data) or 1
		burst(position, { ORANGE, Color3.fromRGB(255, 230, 120) }, math.round(30 * size), 45 * size)
		ring(position, 10 * size, ORANGE)
		Sounds.play("Boom")
		Camera.shake(0.25 * size)
	elseif kind == "Leech" then
		burst(position, { RED }, 15, 25)
	elseif kind == "BlackHole" then
		ring(position, 18, PURPLE)
		burst(position, { PURPLE }, 40, 50)
		pop(position + Vector3.new(0, 4, 0), "🌀", PURPLE, 16)
		Camera.shake(0.5)
	elseif kind == "KnockOut" then
		local brainrot = Brainrots.get(data)
		burst(position, { brainrot.color, Color3.new(1, 1, 1), ORANGE }, 70, 70)
		ring(position, 20, brainrot.color)
		pop(position + Vector3.new(0, 4, 0), "💥", brainrot.color, 22)
		Sounds.play("KnockOut")
		Camera.shake(0.8)
	elseif kind == "Launch" then
		Sounds.play("Launch")
	end
end

function Visuals.start()
	RunService:BindToRenderStep("BrainrotLooks", Enum.RenderPriority.Camera.Value - 1, updateLooks)
	Remotes.Effect.OnClientEvent:Connect(onEffect)
end

return Visuals
