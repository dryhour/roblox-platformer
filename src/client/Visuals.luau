local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounce = require(Shared:WaitForChild("Bounce"))
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Camera = require(script.Parent.Camera)
local MyMatch = require(script.Parent.MyMatch)
local Profile = require(script.Parent.Profile)
local Sounds = require(script.Parent.Sounds)

-- What players see on top of the server's game:
--   * every ball, drawn smoothly every frame. The server only says where a ball was and how
--     fast it was going whenever its path changes (see Battle); in between, the client works
--     out where it is now with the same Bounce math, so wall bounces happen exactly in step.
--     When the server's word differs (balls hitting each other), the difference fades out over
--     a moment instead of snapping. Looks face the players, turn toward where they're going,
--     grow with Charge, and show their health in the middle. Faces react to health: worried
--     brows and a sweat drop below half, tiny pupils and trembling when nearly broken.
--   * effects the server sends: hits, damage and heal numbers, wall sparks, explosions,
--     abilities, knockouts, and the finisher: the beaten ball's energy (in the winner's explosion
--     style) curving into the losing player and blowing up on them, knocking them back and
--     shattering the heart they lose. Players in the match also get sounds and camera shake;
--     anyone close enough in the lobby sees the rest.
--   * the arrows on the lobby's treadmills, sliding along with the belts
local Visuals = {}

local TURN_SHARPNESS = 8
local TURN = 0.7 -- how far a look turns from facing the players toward its direction of travel
local WATCH_DISTANCE = 160 -- lobby players closer than this see other matches' effects
local CORRECTION_SHARPNESS = 12 -- how fast a difference from the server's path fades
local MAX_CORRECTION = 8 -- bigger differences than this snap instead
local MAX_PREDICT = 1 -- seconds ahead to work out a path without hearing from the server
local CROWN_GOLD = Color3.fromRGB(255, 200, 50)
local WORRIED_BELOW = 50
local SCARED_BELOW = 20
local SWEAT = Color3.fromRGB(120, 200, 255)

-- A brow or sweat drop added to a look's face, placed relative to one of its eyes.
type FaceExtra = { part: BasePart, kind: string, eye: CFrame, eyeSize: number }

type LookCache = {
	look: Instance,
	parts: { BasePart },
	offsets: { CFrame },
	sizes: { Vector3 },
	spins: { number },
	facing: Vector3,
	heading: Vector3, -- where the look's front points
	scale: number,
	at: number, -- the At of the path being followed
	shown: Vector3?, -- where the ball was drawn last frame
	correction: Vector3, -- added to the worked-out position, fading to nothing
	health: TextLabel,
	healthGui: BillboardGui,
	pupils: { number }, -- indexes into parts
	moodParts: { [string]: { number } }, -- parts shown only when calm, or only in a rage
	rage: boolean,
	extras: { FaceExtra },
	mood: string, -- "happy", "worried" or "scared"
}

local caches: { [Model]: LookCache } = {}

-- The ball's health as a big number in its middle, outlined in its side's color.
local function healthLabel(model: Model, body: BasePart): (TextLabel, BillboardGui)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Health"
	billboard.Adornee = body
	billboard.Size = UDim2.fromScale(Config.BALL_SIZE * 0.95, Config.BALL_SIZE * 0.5)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 250
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.SIDE_COLORS[model:GetAttribute("Side") :: string] or Color3.new(0, 0, 0)
	stroke.Thickness = 3
	stroke.Parent = text
	billboard.Parent = body
	return text, billboard
end

-- A short tapering trail behind a ball, in its color.
local function addTrail(body: BasePart, color: Color3)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, body.Size.Y * 0.3, 0)
	top.Parent = body
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -body.Size.Y * 0.3, 0)
	bottom.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.25
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 0.5
	trail.FaceCamera = true
	trail.Parent = body
end

local function cacheFor(model: Model): LookCache?
	local look = model:FindFirstChild("Look")
	local body = look and look:FindFirstChild("Body")
	if not look or not body or not body:IsA("BasePart") then
		return nil
	end
	local cache = caches[model]
	if cache and cache.look == look then
		return cache
	end

	local parts, offsets, sizes, spins = {}, {}, {}, {}
	local pupils, extras = {}, {}
	local moodParts = { calm = {}, rage = {} }
	for _, part in look:GetChildren() do
		local offset = part:GetAttribute("Offset")
		if part:IsA("BasePart") and typeof(offset) == "CFrame" then
			table.insert(parts, part)
			table.insert(offsets, offset)
			table.insert(sizes, part.Size)
			table.insert(spins, part:GetAttribute("Spin") or 0)
			local role = part:GetAttribute("Role")
			if role == "calm" or role == "rage" then
				table.insert(moodParts[role], #parts)
				part.Transparency = if role == "rage" then 1 else 0
			elseif role == "pupil" then
				table.insert(pupils, #parts)
			elseif role == "eye" then
				-- A brow over each eye, and a sweat drop by the first, shown as health drops.
				local kinds = if #extras == 0 then { "brow", "sweat" } else { "brow" }
				for _, kind in kinds do
					local extra = Instance.new("Part")
					extra.Name = if kind == "brow" then "Brow" else "Sweat"
					extra.Shape = if kind == "brow" then Enum.PartType.Block else Enum.PartType.Ball
					extra.Color = if kind == "brow" then Color3.fromRGB(20, 20, 20) else SWEAT
					extra.Material = Enum.Material.SmoothPlastic
					extra.Anchored = true
					extra.CanCollide = false
					extra.CanQuery = false
					extra.CanTouch = false
					extra.CastShadow = false
					extra.Transparency = 1
					extra.Parent = look
					table.insert(extras, { part = extra, kind = kind, eye = offset, eyeSize = part.Size.X })
				end
			end
		end
	end
	local facing = model:GetAttribute("Facing")
	facing = if typeof(facing) == "Vector3" then facing else Vector3.zAxis
	local health, healthGui = healthLabel(model, body)
	addTrail(body, Brainrots.get(model:GetAttribute("Brainrot")).color)
	cache = {
		look = look,
		parts = parts,
		offsets = offsets,
		sizes = sizes,
		spins = spins,
		facing = facing,
		heading = facing,
		scale = 1,
		at = 0,
		shown = nil,
		correction = Vector3.zero,
		health = health,
		healthGui = healthGui,
		pupils = pupils,
		moodParts = moodParts,
		rage = false,
		extras = extras,
		mood = "happy",
	}
	caches[model] = cache
	return cache
end

-- Where a brow or sweat drop sits for a mood, relative to the look's center (before growth).
local function extraOffset(extra: FaceExtra, mood: string): CFrame
	local eye = extra.eye.Position
	local size = extra.eyeSize
	local side = if eye.X >= 0 then 1 else -1
	if extra.kind == "sweat" then
		return CFrame.new(eye + Vector3.new(side * size * 1.3, size * 0.5, size * 0.4))
	end
	-- Worried brows tilt up in the middle; scared ones shoot up high.
	local lift = if mood == "scared" then 1.05 else 0.75
	local tilt = if mood == "scared" then side * 12 else -side * 25
	return CFrame.new(eye + Vector3.new(0, size * lift, -size * 0.1)) * CFrame.Angles(0, 0, math.rad(tilt))
end

-- Changes a face to suit its health.
local function setMood(cache: LookCache, mood: string, scale: number)
	cache.mood = mood
	local pupilScale = if mood == "scared" then 0.45 elseif mood == "worried" then 0.8 else 1
	for _, index in cache.pupils do
		cache.parts[index].Size = cache.sizes[index] * scale * pupilScale
	end
	for _, extra in cache.extras do
		local shown = mood ~= "happy"
		extra.part.Transparency = if shown then 0 else 1
		if extra.kind == "brow" then
			extra.part.Size = Vector3.new(extra.eyeSize * 1.1, extra.eyeSize * 0.22, extra.eyeSize * 0.25) * scale
		else
			extra.part.Size = Vector3.one * extra.eyeSize * 0.55 * scale
		end
	end
end

-- Where a ball is now and how fast it's going, worked out from the server's last word on its
-- path and the arena's walls.
local function whereNow(model: Model, core: BasePart): (Vector3?, Vector3)
	local position = model:GetAttribute("Pos")
	local velocity = model:GetAttribute("Vel")
	local at = model:GetAttribute("At")
	local arena = model.Parent
	local center = arena and arena:GetAttribute("Center")
	local facing = arena and arena:GetAttribute("Facing")
	local half = arena and arena:GetAttribute("HalfWidth")
	if typeof(position) ~= "Vector3" or typeof(velocity) ~= "Vector3" or typeof(at) ~= "number" then
		return nil, Vector3.zero
	end
	local speed = velocity.Magnitude
	if speed < 0.01 or typeof(center) ~= "Vector3" or typeof(facing) ~= "Vector3" or typeof(half) ~= "number" then
		return position, velocity
	end
	local space = CFrame.lookAt(center, center - facing)
	local flatPosition = space:PointToObjectSpace(position)
	local flatVelocity = space:VectorToObjectSpace(velocity)
	local elapsed = math.clamp(workspace:GetServerTimeNow() - at, 0, MAX_PREDICT)
	local limit = half - core.Size.X / 2
	local newPosition, direction = Bounce.move(
		Vector2.new(flatPosition.X, flatPosition.Y),
		Vector2.new(flatVelocity.X, flatVelocity.Y).Unit,
		speed * elapsed,
		limit
	)
	return space:PointToWorldSpace(Vector3.new(newPosition.X, newPosition.Y, 0)),
		space:VectorToWorldSpace(Vector3.new(direction.X, direction.Y, 0)) * speed
end

-- Where a ball in `arena` was drawn this frame, by side.
local function drawnBall(arena: Instance, side: unknown): Vector3?
	local model = if typeof(side) == "string" then arena:FindFirstChild(side) else nil
	local cache = model and caches[model :: Model]
	return cache and cache.shown
end

-- Ability parts that ride on a ball (see Battle.follow), drawn on the ball as it's drawn here:
-- centered on it, circling it, or stretched between two balls.
local function updateFollowers()
	local now = workspace:GetServerTimeNow()
	for _, part in CollectionService:GetTagged("Follower") do
		local arena = part.Parent and part.Parent.Parent
		local facing = arena and arena:GetAttribute("Facing")
		local center = arena and drawnBall(arena, part:GetAttribute("FollowBall"))
		if not part:IsA("BasePart") or not center or typeof(facing) ~= "Vector3" then
			continue
		end
		local chainTo = part:GetAttribute("ChainTo")
		local index = part:GetAttribute("OrbitIndex")
		if chainTo then
			local other = drawnBall(arena :: Instance, chainTo)
			if other then
				part.Size = Vector3.new(part.Size.X, part.Size.Y, math.max((other - center).Magnitude, 0.1))
				part.CFrame = CFrame.lookAt((center + other) / 2, other, facing)
			end
		elseif typeof(index) == "number" then
			local count = part:GetAttribute("OrbitCount") or 1
			local radius = part:GetAttribute("OrbitRadius") or 2
			local spin = part:GetAttribute("OrbitSpin") or 0
			local space = CFrame.lookAt(center, center - facing)
			local angle = now * spin + (index - 1) * 2 * math.pi / count
			local outward = space.RightVector * math.cos(angle) + space.UpVector * math.sin(angle)
			local position = center + outward * radius
			part.CFrame = CFrame.lookAt(position, position + outward, facing)
		else
			part.CFrame = part.CFrame.Rotation + center
		end
	end
end

local function updateLooks(deltaTime: number)
	local allParts: { BasePart } = {}
	local allCFrames: { CFrame } = {}
	local now = os.clock()
	local fade = math.exp(-CORRECTION_SHARPNESS * deltaTime)
	for _, model in CollectionService:GetTagged("Ball") do
		local core = model:IsA("Model") and model.PrimaryPart
		local cache = core and cacheFor(model)
		if not core or not cache then
			continue
		end

		-- Balls that grow (Charge) scale their look to match.
		local scale = core.Size.X / Config.BALL_SIZE
		local health = tonumber(model:GetAttribute("Health")) or Config.BALL_HEALTH
		local mood = if health < SCARED_BELOW then "scared" elseif health < WORRIED_BELOW then "worried" else "happy"
		if math.abs(scale - cache.scale) > 0.01 then
			cache.scale = scale
			for index, part in cache.parts do
				part.Size = cache.sizes[index] * scale
			end
			setMood(cache, mood, scale)
			cache.healthGui.Size = UDim2.fromScale(Config.BALL_SIZE * 0.95 * scale, Config.BALL_SIZE * 0.5 * scale)
		elseif mood ~= cache.mood then
			setMood(cache, mood, scale)
		end
		-- Balls with a rage face (Pure Brainrot Smile) swap faces when the server says so.
		local rage = model:GetAttribute("Rage") == true
		if rage ~= cache.rage then
			cache.rage = rage
			for _, index in cache.moodParts.calm do
				cache.parts[index].Transparency = if rage then 1 else 0
			end
			for _, index in cache.moodParts.rage do
				cache.parts[index].Transparency = if rage then 0 else 1
			end
		end

		local predicted, velocity = whereNow(model, core)
		predicted = predicted or core.Position
		-- A new path from the server: start from where the ball was drawn, and fade the
		-- difference out.
		local at = model:GetAttribute("At")
		if typeof(at) == "number" and at ~= cache.at then
			cache.at = at
			local gap = if cache.shown then cache.shown - predicted else Vector3.zero
			cache.correction = if gap.Magnitude < MAX_CORRECTION then gap else Vector3.zero
		end
		cache.correction *= fade
		local position = predicted + cache.correction
		cache.shown = position

		local goal = cache.facing
		if velocity.Magnitude > 2 then
			goal = (goal + velocity.Unit * TURN).Unit
		end
		local turned = cache.heading:Lerp(goal, 1 - math.exp(-TURN_SHARPNESS * deltaTime))
		if turned.Magnitude > 0.01 then
			cache.heading = turned.Unit
		end
		local center = CFrame.lookAt(position, position + cache.heading)
		if mood == "scared" then
			local t = now * 40
			center += Vector3.new(math.noise(t, 1), math.noise(t, 2), 0) * 0.15
		end
		for _, extra in cache.extras do
			local offset = extraOffset(extra, mood)
			table.insert(allParts, extra.part)
			table.insert(allCFrames, center * (CFrame.new(offset.Position * scale) * offset.Rotation))
		end
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
		cache.health.Text = tostring(model:GetAttribute("Health") or "")
	end
	if #allParts > 0 then
		workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	updateFollowers()
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

	-- Punches out to 1.5x, settles back, and floats up while fading over half a second.
	local punch = TweenService:Create(billboard, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(size * 1.5, size * 0.48),
	})
	punch.Completed:Connect(function()
		TweenService:Create(billboard, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(size, size * 0.32),
		}):Play()
	end)
	punch:Play()
	local rise = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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

-- A bright red flash and blur across your screen, fading out fast.
local function flashScreen()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Brightness = 0.4
	tint.TintColor = Color3.fromRGB(255, 140, 140)
	tint.Parent = game:GetService("Lighting")
	local blur = Instance.new("BlurEffect")
	blur.Size = 18
	blur.Parent = game:GetService("Lighting")
	local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(tint, fade, { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	TweenService:Create(blur, fade, { Size = 0 }):Play()
	Debris:AddItem(tint, 0.5)
	Debris:AddItem(blur, 0.5)
end

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

-- A burst in an explosion cosmetic's style: its particles, colors and motion. `size` scales it.
local function styledBurst(position: Vector3, explosion: Cosmetics.Explosion, size: number)
	local part = holder(position, explosion.lifetime + 0.5)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = explosion.texture
	local keypoints = {}
	for index, color in explosion.colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(#explosion.colors - 1, 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, explosion.colors[1]))
	end
	emitter.Color = ColorSequence.new(keypoints)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(explosion.speed * 0.4 * size, explosion.speed * size)
	emitter.Lifetime = NumberRange.new(explosion.lifetime * 0.6, explosion.lifetime)
	emitter.Acceleration = Vector3.new(0, explosion.rise, 0)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(math.round(60 * size))
end

-- Knocks an avatar back away from `from` and lets it settle, for this player's eyes only.
local function knockBack(body: Instance?, from: Vector3)
	local root = body and body:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local rest = root.CFrame
	local away = Vector3.new(rest.Position.X - from.X, 0, rest.Position.Z - from.Z)
	away = if away.Magnitude > 0.1 then away.Unit else -rest.LookVector
	local axis = away:Cross(Vector3.yAxis)
	local hit = CFrame.new(away * 1.6) * rest * CFrame.fromAxisAngle(rest:VectorToObjectSpace(axis), math.rad(-25))
	local out = TweenService:Create(root, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = hit })
	out.Completed:Connect(function()
		TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = rest }):Play()
	end)
	out:Play()
end

-- Makes the heart an avatar is about to lose swell up, flash white and shatter.
local function shatterHeart(body: Instance?)
	local head = body and body:FindFirstChild("Head")
	local hearts = head and head:FindFirstChild("MatchHearts")
	if not hearts then
		return
	end
	local heart: TextLabel? = nil
	for index = 1, Config.HEARTS do
		local candidate = hearts:FindFirstChild(`Heart{index}`)
		if candidate and candidate:IsA("TextLabel") and candidate.Visible then
			heart = candidate
		end
	end
	if not heart then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Parent = heart
	local flash = Instance.new("Frame")
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Position = UDim2.fromScale(0.5, 0.5)
	flash.Size = UDim2.fromScale(0.8, 0.8)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Parent = heart
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = flash
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.5 }):Play()
	TweenService:Create(flash, TweenInfo.new(0.15), { BackgroundTransparency = 0.1 }):Play()
	task.delay(0.2, function()
		heart.TextTransparency = 1
		flash.BackgroundTransparency = 1
		-- Pieces fly out and fade.
		for piece = 1, 7 do
			local shard = Instance.new("Frame")
			shard.AnchorPoint = Vector2.new(0.5, 0.5)
			shard.Position = UDim2.fromScale(0.5, 0.5)
			shard.Size = UDim2.fromScale(0.22, 0.22)
			shard.Rotation = math.random(0, 90)
			shard.BackgroundColor3 = if piece % 2 == 0 then Color3.fromRGB(255, 70, 90) else Color3.fromRGB(255, 140, 150)
			shard.BorderSizePixel = 0
			shard.Parent = heart
			local angle = piece / 7 * math.pi * 2
			TweenService:Create(shard, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5 + math.cos(angle) * 1.4, 0.5 + math.sin(angle) * 1.4),
				Rotation = shard.Rotation + 180,
				BackgroundTransparency = 1,
			}):Play()
			Debris:AddItem(shard, 0.5)
		end
	end)
end

-- The finisher: the beaten ball bursts into an orb of energy in the winner's explosion style,
-- which curves from `from` into the loser's chest at `to` and blows up on them.
local function finisher(from: Vector3, to: Vector3, explosionId: unknown, brainrotId: unknown, body: Instance?, flight: number, mine: boolean)
	local explosion = Cosmetics.explosion(explosionId)
	local brainrot = Brainrots.get(brainrotId)
	burst(from, { brainrot.color, explosion.colors[1], Color3.new(1, 1, 1) }, 40, 16)

	local orb = Instance.new("Part")
	orb.Name = "Energy"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 1.8
	orb.Color = explosion.colors[1]
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.Position = from
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.7, 0)
	top.Parent = orb
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.7, 0)
	bottom.Parent = orb
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.35
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Color = ColorSequence.new(explosion.colors[1], explosion.colors[#explosion.colors])
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = orb
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = explosion.texture
	sparks.Color = ColorSequence.new(explosion.colors[1], explosion.colors[#explosion.colors])
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.9, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 120
	sparks.Parent = orb
	orb.Parent = workspace

	local control = (from + to) / 2 + Vector3.new(0, 7, 0)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / math.max(flight, 0.05), 1)
		orb.Position = (1 - t) ^ 2 * from + 2 * (1 - t) * t * control + t ^ 2 * to
		if mine then
			Camera.follow(orb.Position)
		end
		if t < 1 then
			return
		end
		connection:Disconnect()
		orb:Destroy()
		if mine then
			Camera.follow(nil)
		end
		-- The blast on the avatar.
		styledBurst(to, explosion, 1.6)
		burst(to, explosion.colors, 50, 24)
		ring(to, -workspace.CurrentCamera.CFrame.LookVector, 7, explosion.colors[1])
		pop(to + Vector3.new(0, 2.5, 0), explosion.emoji, explosion.colors[1], 9)
		knockBack(body, from)
		shatterHeart(body)
		if mine then
			Sounds.play("KnockOut")
			Camera.shake(0.9)
			flashScreen()
		end
	end)
end

local function onEffect(kind: string, position: Vector3, ...: any)
	local data, amount = ...
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
		if Profile.setting("numbers") then
			pop(position, `-{data}`, RED, 4.5)
		end
	elseif kind == "Heal" then
		if Profile.setting("numbers") then
			pop(position, `+{data}`, GREEN, 4.5)
		end
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
		-- The final hit. The big explosion comes with the finisher.
		local brainrot = Brainrots.get(data)
		burst(position, { brainrot.color, Color3.new(1, 1, 1) }, 30, 16)
		pop(position + Vector3.new(0, 2, 0), "💥", brainrot.color, 7)
		sound("Hit")
		shake(0.5)
	elseif kind == "Finisher" then
		local to, explosionId, brainrotId, body, flight = ...
		if typeof(to) == "Vector3" then
			finisher(position, to, explosionId, brainrotId, body, tonumber(flight) or 0.8, mine)
		end
	elseif kind == "Crown" then
		burst(position, { CROWN_GOLD, Color3.new(1, 1, 1) }, 60, 20)
		pop(position + Vector3.new(0, 3, 0), "👑", CROWN_GOLD, 10)
		sound("Reward")
	elseif kind == "Frost" then
		burst(position, { Color3.fromRGB(170, 230, 255), Color3.new(1, 1, 1) }, 25, 14)
		pop(position + Vector3.new(0, 1.5, 0), "❄️", Color3.fromRGB(170, 230, 255), 5)
	elseif kind == "Lightning" then
		burst(position, { Color3.fromRGB(255, 245, 140), Color3.new(1, 1, 1) }, 30, 20)
		sound("Boom")
		shake(0.3)
	elseif kind == "Rage" then
		burst(position, { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 230, 60) }, 50, 26)
		pop(position + Vector3.new(0, 2, 0), "😈", Color3.fromRGB(255, 60, 60), 9)
		sound("Boom")
		shake(0.7)
		if mine then
			flashScreen()
		end
	elseif kind == "Dice" then
		pop(position + Vector3.new(0, 1.5, 0), `🎲{data}`, Color3.fromRGB(255, 220, 90), 5)
	elseif kind == "Sticker" then
		if (workspace.CurrentCamera.CFrame.Position - position).Magnitude < 60 then
			Sounds.play("Pop")
		end
	elseif kind == "Launch" then
		sound("Launch")
	end
end

type TreadmillArrow = { part: BasePart, base: CFrame, along: number, treadmill: Instance }

-- Slides the arrows on the lobby's treadmills along with the belts, wrapping around at the end.
local function slideArrows()
	local folder = workspace:WaitForChild("Lobby"):WaitForChild("Treadmills")
	local arrows: { TreadmillArrow } = {}
	local function add(treadmill: Instance)
		for _, part in treadmill:GetChildren() do
			local along = part:GetAttribute("Along")
			if part:IsA("BasePart") and typeof(along) == "number" then
				table.insert(arrows, { part = part, base = part.CFrame, along = along, treadmill = treadmill })
			end
		end
	end
	for _, treadmill in folder:GetChildren() do
		add(treadmill)
	end
	folder.ChildAdded:Connect(add)

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local parts, cframes = {}, {}
		for _, arrow in arrows do
			local speed = arrow.treadmill:GetAttribute("Speed")
			local length = arrow.treadmill:GetAttribute("Length")
			if typeof(speed) == "number" and typeof(length) == "number" and length > 0 then
				local shift = (arrow.along + now * speed) % length - arrow.along
				table.insert(parts, arrow.part)
				table.insert(cframes, arrow.base + Vector3.new(0, 0, shift))
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

function Visuals.start()
	RunService:BindToRenderStep("BrainrotLooks", Enum.RenderPriority.Camera.Value - 1, updateLooks)
	Remotes.Effect.OnClientEvent:Connect(onEffect)
	task.spawn(slideArrows)
end

return Visuals
