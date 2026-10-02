local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Text = require(ReplicatedStorage.Shared.Text)
local Characters = require(script.Parent.Parent.Characters)
local Maps = require(script.Parent.Parent.Maps)
local Types = require(script.Parent.Parent.Types)

-- Beam Attack: one player is the Attacker and fires beams at everyone else. Survivors who are
-- hit are out until the next game. The game ends when time runs out or no Survivors are left.
local BeamAttack = {}
BeamAttack.map = "BeamArena"

-- Both roles can earn up to 100 points (more for the Attacker with quick eliminations).
local ELIMINATION_POINTS = 80 -- split evenly across all the Survivors
local ALL_ELIMINATED_BONUS = 20
local QUICK_KILL_BONUS = 10 -- for each elimination within QUICK_KILL_WINDOW seconds of the last
local QUICK_KILL_WINDOW = 3
local SURVIVAL_POINTS = 80 -- times the fraction of the game survived
local SURVIVED_BONUS = 20 -- for lasting the whole game

-- The beam shows as a thin warning line for CHARGE_TIME, then fires along that same line.
local CHARGE_TIME = 0.45
local ACTIVE_TIME = 0.25
local RANGE = 160
local WIDTH = 3
local HIT_RADIUS = WIDTH / 2 + 2 -- the beam's radius plus about half a character
local WARNING_COLOR = Color3.fromRGB(255, 90, 90)
local BEAM_COLOR = Color3.fromRGB(255, 40, 70)

type Round = {
	ctx: Types.Context,
	attacker: Player,
	survivors: { Player },
	outAt: { [Player]: number }, -- when each eliminated Survivor went out (server time)
	active: boolean,
	startedAt: number,
	eliminations: number,
	quickKills: number,
	lastKillAt: number,
	nextFireAt: number,
}

local round: Round? = nil

-- Prefers players who have been the Attacker the fewest times this match.
local function pickAttacker(ctx: Types.Context): Player
	local counts = ctx.match.attackerCounts
	local fewest = math.huge
	local candidates = {}
	for _, player in ctx.players do
		local count = counts[player.UserId] or 0
		if count < fewest then
			fewest = count
			candidates = { player }
		elseif count == fewest then
			table.insert(candidates, player)
		end
	end
	local attacker = candidates[math.random(#candidates)]
	counts[attacker.UserId] = fewest + 1
	return attacker
end

local function spawnAttacker(r: Round)
	r.ctx.spawn(r.attacker, Maps.spawnPoints(r.ctx.map, "AttackerSpawn")[1])
	local character = r.attacker.Character
	if character then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = BEAM_COLOR
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = BEAM_COLOR
		highlight.Parent = character
	end
end

local function survivorsLeft(r: Round): number
	local count = 0
	for _, survivor in r.survivors do
		if not r.outAt[survivor] and r.ctx.isIn(survivor) then
			count += 1
		end
	end
	return count
end

-- Takes a Survivor out of the game. Only beam hits count toward the Attacker's score.
local function knockOut(r: Round, survivor: Player, byBeam: boolean)
	if r.outAt[survivor] or not table.find(r.survivors, survivor) then
		return
	end
	local now = workspace:GetServerTimeNow()
	r.outAt[survivor] = now
	survivor:SetAttribute("Role", "Eliminated")
	survivor:SetAttribute("Status", "")
	if byBeam then
		r.eliminations += 1
		if now - r.lastKillAt <= QUICK_KILL_WINDOW then
			r.quickKills += 1
		end
		r.lastKillAt = now
		r.attacker:SetAttribute("Status", `Eliminations: {r.eliminations}`)
	end
	r.ctx.announce(`{survivor.DisplayName} is out! {survivorsLeft(r)} left`)
	Characters.kill(survivor)
end

local function beamPart(map: Model, origin: Vector3, direction: Vector3, length: number, width: number, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = "Beam"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -length / 2)
	part.Parent = map
	return part
end

local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local t = math.clamp((point - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (a + ab * t - point).Magnitude
end

local function fire(r: Round, origin: Vector3, direction: Vector3)
	-- The beam stops at the first wall or platform in its way.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { r.ctx.map }
	local hit = workspace:Raycast(origin, direction * RANGE, params)
	local length = if hit then math.max(hit.Distance, 0.5) else RANGE
	local finish = origin + direction * length

	local warning = beamPart(r.ctx.map, origin, direction, length, 0.5, WARNING_COLOR, 0.4)
	task.wait(CHARGE_TIME)
	warning:Destroy()
	if round ~= r or not r.active then
		return
	end

	local beam = beamPart(r.ctx.map, origin, direction, length, WIDTH, BEAM_COLOR, 0)
	local stopAt = os.clock() + ACTIVE_TIME
	while os.clock() < stopAt and round == r and r.active do
		for _, survivor in r.survivors do
			local root = if r.outAt[survivor] then nil else Characters.root(survivor)
			if root and distanceToSegment(root.Position, origin, finish) <= HIT_RADIUS then
				knockOut(r, survivor, true)
			end
		end
		RunService.Heartbeat:Wait()
	end
	beam:Destroy()
end

ReplicatedStorage.Remotes.FireBeam.OnServerEvent:Connect(function(player: Player, direction: unknown)
	local r = round
	if not r or not r.active or player ~= r.attacker or typeof(direction) ~= "Vector3" then
		return
	end
	-- Aim only within the play plane, and reject zero, NaN and infinite vectors.
	local aim = Vector3.new(direction.X, direction.Y, 0)
	local magnitude = aim.Magnitude
	if not (magnitude > 0.01 and magnitude < math.huge) then
		return
	end
	local now = os.clock()
	if now < r.nextFireAt then
		return
	end
	local root = Characters.root(player)
	if not root then
		return
	end
	-- Allow the next shot slightly early so network jitter doesn't eat it.
	r.nextFireAt = now + Config.BEAM_COOLDOWN - 0.15
	task.spawn(fire, r, Vector3.new(root.Position.X, root.Position.Y, 0), aim.Unit)
end)

function BeamAttack.setup(ctx: Types.Context)
	local attacker = pickAttacker(ctx)
	local survivors = {}
	for _, player in ctx.players do
		if player ~= attacker then
			table.insert(survivors, player)
		end
	end

	local r: Round = {
		ctx = ctx,
		attacker = attacker,
		survivors = survivors,
		outAt = {},
		active = false,
		startedAt = 0,
		eliminations = 0,
		quickKills = 0,
		lastKillAt = -math.huge,
		nextFireAt = 0,
	}
	round = r

	attacker:SetAttribute("Role", "Attacker")
	attacker:SetAttribute("Status", "Eliminations: 0")
	spawnAttacker(r)

	local spawns = Maps.spawnPoints(ctx.map, "Spawn")
	for i, survivor in survivors do
		survivor:SetAttribute("Role", "Survivor")
		survivor:SetAttribute("Status", "Stay out of the beams!")
		ctx.spawn(survivor, spawns[(i - 1) % #spawns + 1])
	end
end

function BeamAttack.run(ctx: Types.Context): { [Player]: Types.Result }
	local r = assert(round, "BeamAttack.run called before setup")
	r.startedAt = workspace:GetServerTimeNow()
	r.active = true
	ctx.waitUntilOver(function()
		-- With nobody to hunt (testing alone in Studio), play on until the timer runs out.
		return not ctx.isIn(r.attacker) or (#r.survivors > 0 and survivorsLeft(r) == 0)
	end)
	r.active = false
	round = nil

	local endedAt = workspace:GetServerTimeNow()
	local results: { [Player]: Types.Result } = {}
	for _, survivor in r.survivors do
		local outAt = r.outAt[survivor]
		local survived = (outAt or endedAt) - r.startedAt
		local points = math.round(SURVIVAL_POINTS * math.clamp(survived / ctx.duration, 0, 1))
		if not outAt then
			points += SURVIVED_BONUS
		end
		results[survivor] = {
			points = points,
			detail = if outAt then `Survived {math.floor(survived)}s` else "Survived the whole game!",
		}
	end

	local survivorCount = #r.survivors
	local attackerPoints = math.round(ELIMINATION_POINTS * r.eliminations / math.max(survivorCount, 1))
		+ r.quickKills * QUICK_KILL_BONUS
	if survivorCount > 0 and r.eliminations == survivorCount then
		attackerPoints += ALL_ELIMINATED_BONUS
	end
	results[r.attacker] = {
		points = attackerPoints,
		detail = `Attacker: {Text.count(r.eliminations, "elimination")}`,
	}
	return results
end

function BeamAttack.onDied(ctx: Types.Context, player: Player)
	local r = round
	if not r then
		return
	end
	if player == r.attacker then
		ctx.respawnLater(player, function()
			spawnAttacker(r)
		end)
	else
		-- Falling or lava also counts as being out, but doesn't score for the Attacker.
		knockOut(r, player, false)
	end
end

return BeamAttack
