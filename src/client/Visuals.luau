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
local MyMatch = require(script.Parent.MyMatch)
local Sounds = require(script.Parent.Sounds)

-- What players see on top of the physics:
--   * every ball's brainrot look, moved each frame to follow its sphere (the server only places
--     it once), facing out of the arena toward the players, turning toward where it's going,
--     and growing with it
--   * effects the server sends: hits, damage and heal numbers, wall sparks, explosions and
--     knockouts. Players in the match also get sounds and camera shake; anyone close enough in
--     the lobby sees the rest.
--   * the arrows on the lobby floor, pulsing toward the stations
local Visuals = {}

local TURN_SHARPNESS = 8
local TURN = 0.7 -- how far a look turns from facing the players toward its direction of travel
local WATCH_DISTANCE = 160 -- lobby players closer than this see other matches' effects

type LookCache = {
	look: Instance,
	parts: { BasePart },
	offsets: { CFrame },
	sizes: { Vector3 },
	spins: { number },
	facing: Vector3,
	heading: Vector3, -- where the look's front points
	scale: number,
}

local caches: { [Model]: LookCache } = {}

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
	local facing = model:GetAttribute("Facing")
	facing = if typeof(facing) == "Vector3" then facing else Vector3.zAxis
	cache = {
		look = look,
		parts = parts,
		offsets = offsets,
		sizes = sizes,
		spins = spins,
		facing = facing,
		heading = facing,
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
		local goal = cache.facing
		if velocity.Magnitude > 2 then
			goal = (goal + velocity.Unit * TURN).Unit
		end
		local turned = cache.heading:Lerp(goal, 1 - math.exp(-TURN_SHARPNESS * deltaTime))
		if turned.Magnitude > 0.01 then
			cache.heading = turned.Unit
		end
		local center = CFrame.lookAt(core.Position, core.Position + cache.heading)
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
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		emitter.Speed = NumberRange.new(speed * 0.5, speed)
		emitter.Lifetime = NumberRange.new(0.4, 0.9)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 3
		emitter.Acceleration = Vector3.new(0, -15, 0)
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
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
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
	TweenService:Create(billboard, rise, { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, rise, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function ring(position: Vector3, facing: Vector3, radius: number, color: Color3)
	local part = holder(position, 0.6)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, 1, 1)
	-- Flat against the arena, so it reads from the front.
	part.CFrame = CFrame.lookAt(position, position + facing) * CFrame.Angles(0, math.pi / 2, 0)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.2
	TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
end

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 230, 110)
local ORANGE = Color3.fromRGB(255, 150, 40)
local PURPLE = Color3.fromRGB(150, 70, 230)

-- The arena an effect happened in: your own, or the nearest one.
local function arenaNear(position: Vector3): (boolean, Vector3)
	local center, facing = MyMatch.frame()
	if center and facing and (position - center).Magnitude < Config.ARENA_SIZE then
		return true, facing
	end
	local nearest, best = nil, math.huge
	local arenas = workspace:FindFirstChild("Arenas")
	local all = if arenas then arenas:GetChildren() else {}
	for _, arena in all do
		local spot = arena:GetAttribute("Center")
		if typeof(spot) == "Vector3" and (spot - position).Magnitude < best then
			nearest, best = arena, (spot - position).Magnitude
		end
	end
	local nearestFacing = nearest and nearest:GetAttribute("Facing")
	return false, if typeof(nearestFacing) == "Vector3" then nearestFacing else Vector3.zAxis
end

local function onEffect(kind: string, position: Vector3, data: any, amount: any)
	local mine, facing = arenaNear(position)
	if not mine and (workspace.CurrentCamera.CFrame.Position - position).Magnitude > WATCH_DISTANCE then
		return
	end
	local function sound(name: string)
		if mine then
			Sounds.play(name)
		end
	end
	local function shake(amount: number)
		if mine then
			Camera.shake(amount)
		end
	end

	if kind == "Impact" then
		local brainrot = Brainrots.get(data)
		burst(position, { brainrot.color, Color3.new(1, 1, 1) }, 20, 18)
		pop(position + Vector3.new(0, 1.5, 0), brainrot.word, brainrot.color, 8)
		sound("Hit")
		shake(math.clamp((tonumber(amount) or 0) / 60, 0.15, 0.6))
	elseif kind == "Damage" then
		pop(position, `-{data}`, RED, 4.5)
	elseif kind == "Heal" then
		pop(position, `+{data}`, GREEN, 4.5)
	elseif kind == "Wall" then
		burst(position, { Color3.fromRGB(120, 220, 255) }, 6, 9)
	elseif kind == "Explosion" then
		local size = tonumber(data) or 1
		burst(position, { ORANGE, Color3.fromRGB(255, 230, 120) }, math.round(30 * size), 20 * size)
		ring(position, facing, 5 * size, ORANGE)
		sound("Boom")
		shake(0.25 * size)
	elseif kind == "Leech" then
		burst(position, { RED }, 15, 12)
	elseif kind == "BlackHole" then
		ring(position, facing, 8, PURPLE)
		burst(position, { PURPLE }, 40, 22)
		pop(position + Vector3.new(0, 2, 0), "🌀", PURPLE, 8)
		shake(0.5)
	elseif kind == "KnockOut" then
		local brainrot = Brainrots.get(data)
		burst(position, { brainrot.color, Color3.new(1, 1, 1), ORANGE }, 70, 30)
		ring(position, facing, 10, brainrot.color)
		pop(position + Vector3.new(0, 2, 0), "💥", brainrot.color, 11)
		sound("KnockOut")
		shake(0.8)
	elseif kind == "Launch" then
		sound("Launch")
	end
end

-- Arrows on the lobby floor light up one after another, leading away from the spawn.
local function pulseArrows()
	local lobby = workspace:WaitForChild("Lobby")
	local folder = lobby:WaitForChild("Chevrons")
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, arrow in folder:GetChildren() do
			local order = arrow:GetAttribute("Order")
			if arrow:IsA("BasePart") and typeof(order) == "number" then
				local glow = (math.sin(now * 5 - order * 0.7) + 1) / 2
				arrow.Transparency = 0.75 - glow * 0.65
			end
		end
	end)
end

function Visuals.start()
	RunService:BindToRenderStep("BrainrotLooks", Enum.RenderPriority.Camera.Value - 1, updateLooks)
	Remotes.Effect.OnClientEvent:Connect(onEffect)
	task.spawn(pulseArrows)
end

return Visuals
