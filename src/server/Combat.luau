local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Balls = require(script.Parent.Balls)

-- Everything that pushes balls around: ball-on-ball collisions, bumpers, boosts and the Slam
-- ability. The server decides every push, then tells the ball's owner to apply it, since each
-- client simulates its own ball.
local Combat = {}

local remotes = ReplicatedStorage.Remotes
local RADIUS = Config.BALL_SIZE / 2
local PAIR_COOLDOWN = 0.3
local BUMPER_COOLDOWN = 0.4
-- How many recent velocity samples to keep per ball (see recentSpeedToward).
local HISTORY = 4

local boostedUntil: { [Player]: number } = {}
local lastBoostAt: { [Player]: number } = {}
local readyAt: { [string]: number } = {} -- cooldowns for ball pairs and ball/bumper pairs
local history: { [Player]: { Vector3 } } = {}

local function effect(kind: string, position: Vector3, ...: any)
	remotes.Effect:FireAllClients(kind, position, ...)
end

local function brainrotOf(player: Player): string
	local model = Balls.get(player)
	return Brainrots.get(model and model:GetAttribute("Brainrot")).id
end

local function weight(player: Player): number
	return Brainrots.classOf(brainrotOf(player)).density
end

-- Heavier balls push harder and get pushed less.
local function weightRatio(attacker: Player, victim: Player): number
	return math.clamp(math.sqrt(weight(attacker) / weight(victim)), 0.5, 2)
end

local function boostOf(player: Player): number
	return if (boostedUntil[player] or 0) > os.clock() then Config.BOOST_KNOCKBACK else 1
end

-- Changes the velocity of the player's ball by `change`.
function Combat.knock(player: Player, change: Vector3)
	if change.Magnitude > Config.MAX_KNOCKBACK then
		change = change.Unit * Config.MAX_KNOCKBACK
	end
	remotes.Knockback:FireClient(player, change)
end

-- The fastest the ball has recently moved toward `direction`. Positions reach the server a
-- little late, so by the time two balls look close enough to touch they may already be
-- bouncing apart; recent samples still show how hard they came together.
local function recentSpeedToward(player: Player, direction: Vector3): number
	local fastest = 0
	local samples = history[player]
	if samples then
		for _, velocity in samples do
			fastest = math.max(fastest, velocity:Dot(direction))
		end
	end
	return fastest
end

local function cooldownReady(key: string, seconds: number): boolean
	local now = os.clock()
	if (readyAt[key] or 0) > now then
		return false
	end
	readyAt[key] = now + seconds
	return true
end

local function collide(a: Player, coreA: BasePart, b: Player, coreB: BasePart)
	local offset = coreB.Position - coreA.Position
	local distance = offset.Magnitude
	if distance > RADIUS * 2 + 1 or distance < 0.001 then
		return
	end
	local normal = offset / distance
	local aToward = recentSpeedToward(a, normal)
	local bToward = recentSpeedToward(b, -normal)
	local impact = aToward + bToward
	if impact < Config.MIN_IMPACT_SPEED then
		return
	end
	local key = if a.UserId < b.UserId then `{a.UserId}:{b.UserId}` else `{b.UserId}:{a.UserId}`
	if not cooldownReady(key, PAIR_COOLDOWN) then
		return
	end

	-- Each ball is knocked away by how fast the other came at it, plus a share of the impact.
	local function push(ownSpeed: number): number
		return Config.KNOCKBACK_SCALE * (ownSpeed + 0.3 * impact) + Config.KNOCKBACK_BASE
	end
	local lift = Vector3.yAxis * Config.KNOCKBACK_LIFT
	Combat.knock(b, (normal + lift).Unit * push(aToward) * weightRatio(a, b) * boostOf(a))
	Combat.knock(a, (-normal + lift).Unit * push(bToward) * weightRatio(b, a) * boostOf(b))

	local hitter = if aToward >= bToward then a else b
	effect("Impact", coreA.Position + normal * RADIUS, brainrotOf(hitter), impact)
end

local function bounceOffBumpers(player: Player, core: BasePart)
	for _, bumper in CollectionService:GetTagged("Bumper") do
		local radius = bumper:GetAttribute("Radius")
		local height = bumper:GetAttribute("Height")
		if not bumper:IsA("BasePart") or not bumper.Anchored or typeof(radius) ~= "number" or typeof(height) ~= "number" then
			continue
		end
		local offset = core.Position - bumper.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > radius + RADIUS + 0.5 or flat.Magnitude < 0.001 or math.abs(offset.Y) > height / 2 + RADIUS then
			continue
		end
		if not cooldownReady(`{player.UserId}:{bumper:GetFullName()}`, BUMPER_COOLDOWN) then
			continue
		end
		-- Cancel the speed going into the bumper and send the ball away at a fixed speed.
		local away = flat.Unit
		local inward = recentSpeedToward(player, -away)
		Combat.knock(player, away * (Config.BUMPER_PUSH + inward) + Vector3.yAxis * 15)
		effect("Bumper", bumper.Position + away * radius)
	end
end

local function slam(player: Player)
	local core = Balls.core(player)
	if not core then
		return
	end
	-- Used in the air, the ball dives first (on its client) and the shockwave waits for landing.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:WaitForChild("Balls") }
	local waitUntil = os.clock() + 1
	while os.clock() < waitUntil and core.Parent do
		if workspace:Raycast(core.Position, Vector3.new(0, -(RADIUS + 1.5), 0), params) then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if not core.Parent then
		return
	end

	for other, model in Balls.all() do
		local otherCore = model.PrimaryPart
		if other == player or not otherCore or otherCore.Anchored then
			continue
		end
		local offset = otherCore.Position - core.Position
		local distance = offset.Magnitude
		if distance > Config.SLAM_RADIUS then
			continue
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local away = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
		local falloff = 1 - 0.5 * distance / Config.SLAM_RADIUS
		Combat.knock(
			other,
			away * Config.SLAM_PUSH * falloff * weightRatio(player, other) + Vector3.yAxis * Config.SLAM_LIFT
		)
	end
	effect("Shockwave", core.Position, brainrotOf(player))
end

remotes.Boost.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastBoostAt[player] or 0) < 0.25 then
		return
	end
	lastBoostAt[player] = now
	boostedUntil[player] = now + Config.BOOST_TIME
end)

remotes.Ability.OnServerEvent:Connect(function(player: Player)
	local core = Balls.core(player)
	local now = workspace:GetServerTimeNow()
	if not core or core.Anchored or now < (player:GetAttribute("AbilityReadyAt") or 0) then
		return
	end
	player:SetAttribute("AbilityReadyAt", now + Config.SLAM_COOLDOWN)
	slam(player)
end)

Players.PlayerRemoving:Connect(function(player)
	boostedUntil[player] = nil
	lastBoostAt[player] = nil
	history[player] = nil
end)

RunService.Heartbeat:Connect(function()
	local active: { { player: Player, core: BasePart } } = {}
	for player, model in Balls.all() do
		local core = model.PrimaryPart
		if core and not core.Anchored then
			table.insert(active, { player = player, core = core })
			local samples = history[player] or {}
			table.insert(samples, core.AssemblyLinearVelocity)
			if #samples > HISTORY then
				table.remove(samples, 1)
			end
			history[player] = samples
		else
			history[player] = nil
		end
	end

	for i = 1, #active do
		for j = i + 1, #active do
			collide(active[i].player, active[i].core, active[j].player, active[j].core)
		end
		bounceOffBumpers(active[i].player, active[i].core)
	end
end)

return Combat
