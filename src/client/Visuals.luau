local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local BallController = require(script.Parent.BallController)
local Camera = require(script.Parent.Camera)
local Sounds = require(script.Parent.Sounds)

-- What players see on top of the physics:
--   * every ball's brainrot look, moved each frame to follow its sphere, facing the way it rolls
--     and leaning into speed (the server only places it once)
--   * an arrow over your own ball
--   * effects the server sends: hits, slams, bumpers, knockouts, picks and confetti
local Visuals = {}

local TURN_SHARPNESS = 12
local MAX_LEAN = math.rad(12)
-- Effects within this distance of your ball shake your camera.
local SHAKE_DISTANCE = 45

type LookCache = {
	look: Instance,
	parts: { BasePart },
	offsets: { CFrame },
	spins: { number },
	yaw: number,
}

local player = Players.LocalPlayer
local balls = workspace:WaitForChild("Balls")
local caches: { [Model]: LookCache } = {}

local function angleLerp(from: number, to: number, alpha: number): number
	local difference = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + difference * alpha
end

local function addArrow(body: BasePart)
	if body:FindFirstChild("YouArrow") then
		return
	end
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "YouArrow"
	arrow.Size = UDim2.fromOffset(40, 40)
	arrow.StudsOffset = Vector3.new(0, Config.BALL_SIZE * 1.25, 0)
	arrow.AlwaysOnTop = true
	arrow.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "▼"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = arrow
	arrow.Parent = body
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

	local parts, offsets, spins = {}, {}, {}
	for _, part in look:GetChildren() do
		local offset = part:GetAttribute("Offset")
		if part:IsA("BasePart") and typeof(offset) == "CFrame" then
			table.insert(parts, part)
			table.insert(offsets, offset)
			table.insert(spins, part:GetAttribute("Spin") or 0)
		end
	end
	local body = look:FindFirstChild("Body")
	if body and body:IsA("BasePart") and model:GetAttribute("UserId") == player.UserId then
		addArrow(body)
	end

	-- Keep facing the same way when the look changes (picking a new brainrot).
	cache = { look = look, parts = parts, offsets = offsets, spins = spins, yaw = if cache then cache.yaw else 0 }
	caches[model] = cache
	return cache
end

local function updateLooks(deltaTime: number)
	local allParts: { BasePart } = {}
	local allCFrames: { CFrame } = {}
	local now = os.clock()
	for _, model in balls:GetChildren() do
		local core = model:IsA("Model") and model.PrimaryPart
		local cache = core and cacheFor(model)
		if not core or not cache then
			continue
		end
		local velocity = core.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		if speed > 2 then
			-- Yaw that points the look's front (-Z) along the velocity.
			local goal = math.atan2(-flat.X, -flat.Z)
			cache.yaw = angleLerp(cache.yaw, goal, 1 - math.exp(-TURN_SHARPNESS * deltaTime))
		end
		local lean = CFrame.Angles(-MAX_LEAN * math.clamp(speed / 80, 0, 1), 0, 0)
		local center = CFrame.new(core.Position) * CFrame.Angles(0, cache.yaw, 0) * lean
		for index, part in cache.parts do
			local offset = cache.offsets[index]
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
		if model.Parent ~= balls then
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

-- A comic word ("BONK!") that pops up and floats away.
local function pop(position: Vector3, text: string, color: Color3)
	local part = holder(position, 1)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(6, 2)
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
	TweenService:Create(billboard, grow, { Size = UDim2.fromScale(16, 5) }):Play()
	local rise = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(billboard, rise, { StudsOffset = Vector3.new(0, 9, 0) }):Play()
	TweenService:Create(label, rise, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

-- A flat ring that spreads out along the ground.
local function ring(position: Vector3, radius: number, color: Color3)
	local part = holder(position - Vector3.new(0, Config.BALL_SIZE / 2 - 0.3, 0), 0.6)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 2, 2)
	part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, 0, math.pi / 2)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.2
	TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
end

local function shakeNear(position: Vector3, amount: number)
	local mine = BallController.myBall()
	local core = mine and mine.PrimaryPart
	if core then
		local distance = (core.Position - position).Magnitude
		if distance < SHAKE_DISTANCE then
			Camera.shake(amount * (1 - distance / SHAKE_DISTANCE))
		end
	end
end

local CONFETTI = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(220, 100, 255),
}

local function onEffect(kind: string, position: Vector3, data: any, strength: any)
	if kind == "Impact" then
		local brainrot = Brainrots.get(data)
		local power = math.clamp((tonumber(strength) or 0) / 120, 0.15, 0.7)
		burst(position, { brainrot.color, Color3.new(1, 1, 1) }, 20, 40)
		pop(position, brainrot.word, brainrot.color)
		Sounds.play("Impact")
		shakeNear(position, power)
	elseif kind == "Shockwave" then
		local brainrot = Brainrots.get(data)
		ring(position, Config.SLAM_RADIUS, brainrot.color)
		burst(position, { brainrot.color }, 30, 50)
		pop(position, brainrot.word, brainrot.color)
		Sounds.play("Slam")
		shakeNear(position, 0.6)
	elseif kind == "Bumper" then
		burst(position, { Color3.fromRGB(255, 70, 200) }, 12, 30)
		pop(position, "BOING!", Color3.fromRGB(255, 120, 220))
		Sounds.play("Impact")
		shakeNear(position, 0.2)
	elseif kind == "Eliminated" then
		local brainrot = Brainrots.get(data)
		burst(position, { brainrot.color, Color3.new(1, 1, 1) }, 50, 60)
		pop(position, "💥", brainrot.color)
		Sounds.play("Eliminated")
	elseif kind == "Select" then
		local brainrot = Brainrots.get(data)
		burst(position, { brainrot.color }, 25, 35)
		pop(position, brainrot.emoji, brainrot.color)
		Sounds.play("Boost")
	elseif kind == "Confetti" then
		burst(position + Vector3.new(0, 6, 0), CONFETTI, 80, 55)
	end
end

function Visuals.start()
	RunService:BindToRenderStep("BrainrotLooks", Enum.RenderPriority.Camera.Value - 1, updateLooks)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effect").OnClientEvent:Connect(onEffect)
end

return Visuals
