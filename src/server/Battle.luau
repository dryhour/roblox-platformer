local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimMath = require(ReplicatedStorage.Shared.AimMath)
local Bounce = require(ReplicatedStorage.Shared.Bounce)
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Looks = require(ReplicatedStorage.Shared.Looks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Arena = require(script.Parent.World.Arena)

-- One round's auto-battle. The server moves both balls itself (with the shared Bounce math, not
-- Roblox physics), so nobody can cheat their ball's movement and every bounce is exact. Once
-- launched, balls fly around the arena's upright box at their own speed, bounce off the walls
-- and each other, take damage, and trigger their abilities. Sudden death closes the walls in.
--
-- Clients draw the balls themselves for smooth motion. Each ball model's Pos, Vel and At
-- attributes say where it was, how fast it was going (in studs per second, world space) and
-- when (server time); they change only when its path does (a bounce, a hit, a speed change).
-- Its Health attribute is out of Config.BALL_HEALTH.
--
-- Health: every ball has Config.BALL_HEALTH (100). Damage and healing are given in raw points;
-- a ball's `health` stat says how many raw points its 100 is worth, so tougher balls lose less
-- per hit.
--
-- Abilities live in src/server/Skills. Each is a table of optional hooks, called with
-- (battle, ball, ...):
--   onStart()                      when the balls launch
--   onTick(deltaTime)              every frame
--   onWallHit(point, normal)       after bouncing off a wall
--   onEnemyHit(enemy, damage)      after hitting the other ball
--   onLowHealth()                  once, when health first drops below Config.LOW_HEALTH
-- Hooks aren't called while a ball's skills are disabled (skillsDisabledUntil).
local Battle = {}
Battle.__index = Battle

local HIT_COOLDOWN = 0.25
local WALL_COOLDOWN = 0.15
local SHRINK_SPEED = 10 -- studs per second the walls move during sudden death
local MAX_STEP = 1 / 120 -- longest movement step, so fast balls can't pass through each other
local STEER_PUBLISH_EVERY = 0.1 -- while a black hole bends a path, clients get it this often

export type Ball = {
	side: string,
	def: Brainrots.Brainrot,
	model: Model,
	core: BasePart, -- invisible, anchored; follows the ball so abilities can use its position
	forward: Vector3,
	position: Vector2, -- in the arena's flat space (see Bounce)
	direction: Vector2, -- unit
	hp: number, -- out of maxHp
	maxHp: number,
	alive: boolean,
	lastVelocity: Vector3, -- world space, studs per second
	buffs: { [string]: { multiplier: number, untilTime: number } },
	growth: number, -- size and mass multiplier
	damageStacks: number, -- each adds 5% to the next hit on the other ball
	skillsDisabledUntil: number,
	pullTarget: Vector3?, -- steered toward this until pullUntil
	pullUntil: number,
	lowHealthFired: boolean,
	lastWallHitAt: number,
	publishedSpeed: number,
	publishedAt: number,
	skill: { [string]: any },
	state: { [string]: any }, -- for the ability's own use
}

export type Battle = typeof(setmetatable(
	{} :: {
		arena: Arena.Arena,
		balls: { [string]: Ball },
		owned: { [Ball]: { Instance } },
		running: boolean,
		startedAt: number,
		lastHitAt: number,
		suddenDeath: boolean,
		targetHalfWidth: number,
		nextShrinkAt: number,
		connection: RBXScriptConnection?,
	},
	Battle
))

local skills: { [string]: { [string]: any } } = {}
for _, module in script.Parent.Skills:GetChildren() do
	if module:IsA("ModuleScript") then
		skills[module.Name] = require(module) :: any
	end
end

-- Turns any value into a unit direction in the arena's plane within the aim arc of `forward`.
Battle.clampAim = AimMath.clamp

-- Sets up a battle in `arena` with the picked brainrot for each side ("Left", "Right"). The
-- balls sit still at their spawn points until launch().
function Battle.new(arena: Arena.Arena, picks: { [string]: string }): Battle
	local self = setmetatable({
		arena = arena,
		balls = {},
		owned = {},
		running = false,
		startedAt = 0,
		lastHitAt = 0,
		suddenDeath = false,
		targetHalfWidth = arena.halfWidth(),
		nextShrinkAt = 0,
		connection = nil,
	}, Battle)
	for side, id in picks do
		self:spawnBall(side, id)
	end
	return self
end

-- From the arena's flat space to the world, and back.
function Battle.toWorld(self: Battle, point: Vector2): Vector3
	return self.arena.cframe:PointToWorldSpace(Vector3.new(point.X, point.Y, 0))
end

function Battle.vectorToWorld(self: Battle, vector: Vector2): Vector3
	return self.arena.cframe:VectorToWorldSpace(Vector3.new(vector.X, vector.Y, 0))
end

function Battle.toFlat(self: Battle, point: Vector3): Vector2
	local offset = self.arena.cframe:PointToObjectSpace(point)
	return Vector2.new(offset.X, offset.Y)
end

function Battle.vectorToFlat(self: Battle, vector: Vector3): Vector2
	local offset = self.arena.cframe:VectorToObjectSpace(vector)
	return Vector2.new(offset.X, offset.Y)
end

function Battle.spawnBall(self: Battle, side: string, id: string)
	local def = Brainrots.get(id)
	local position, forward = self.arena.spawn(side)

	local model = Instance.new("Model")
	model.Name = side
	model:SetAttribute("Side", side)
	model:SetAttribute("Brainrot", def.id)
	model:SetAttribute("Forward", forward)
	model:SetAttribute("Facing", self.arena.facing)

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * Config.BALL_SIZE
	core.Transparency = 1
	core.Position = position
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Parent = model
	model.PrimaryPart = core

	local look = Looks.build(def.id)
	Looks.place(look, CFrame.lookAt(position, position + self.arena.facing))
	look.Parent = model

	local ball: Ball = {
		side = side,
		def = def,
		model = model,
		core = core,
		forward = forward,
		position = self:toFlat(position),
		direction = self:vectorToFlat(forward).Unit,
		hp = Config.BALL_HEALTH,
		maxHp = Config.BALL_HEALTH,
		alive = true,
		lastVelocity = Vector3.zero,
		buffs = {},
		growth = 1,
		damageStacks = 0,
		skillsDisabledUntil = 0,
		pullTarget = nil,
		pullUntil = 0,
		lowHealthFired = false,
		lastWallHitAt = 0,
		publishedSpeed = 0,
		publishedAt = 0,
		skill = skills[def.skill] or {},
		state = {},
	}
	self:refreshHealth(ball)
	self.balls[side] = ball
	self.owned[ball] = {}
	-- Standing still until launch.
	model:SetAttribute("Pos", position)
	model:SetAttribute("Vel", Vector3.zero)
	model:SetAttribute("At", workspace:GetServerTimeNow())

	CollectionService:AddTag(model, "Ball")
	model.Parent = self.arena.model
end

-- Turns a ball to head along `direction` (in the arena's flat space), e.g. an ability dashing
-- at the other ball. Clients hear about it on the next step.
function Battle.redirect(_self: Battle, ball: Ball, direction: Vector2)
	if direction.Magnitude > 0.01 then
		ball.direction = Bounce.steepen(direction.Unit, ball.position)
		ball.publishedSpeed = -1
	end
end

-- Tells clients the ball's current path. At goes last, so it arrives with the rest.
function Battle.publish(self: Battle, ball: Ball, speed: number)
	ball.publishedSpeed = speed
	ball.publishedAt = os.clock()
	ball.model:SetAttribute("Pos", self:toWorld(ball.position))
	ball.model:SetAttribute("Vel", self:vectorToWorld(ball.direction * speed))
	ball.model:SetAttribute("At", workspace:GetServerTimeNow())
end

-- Sends a visual effect to every client: the players in this match, and anyone in the lobby
-- close enough to watch.
function Battle.effect(_self: Battle, kind: string, ...: any)
	Remotes.Effect:FireAllClients(kind, ...)
end

-- Puts an ability's part in the arena and removes it when the ball is knocked out or the round
-- ends.
function Battle.own(self: Battle, ball: Ball, instance: Instance)
	table.insert(self.owned[ball], instance)
	instance.Parent = self.arena.effects
end

-- Marks a part as riding on `target`'s ball, so clients draw it there smoothly (the server
-- still moves it, for abilities to use). `extra` adds how: OrbitIndex, OrbitCount, OrbitRadius
-- and OrbitSpin to circle it, or ChainTo (a side) to stretch between two balls.
function Battle.follow(_self: Battle, part: BasePart, target: Ball, extra: { [string]: any }?)
	part:SetAttribute("FollowBall", target.side)
	if extra then
		for name, value in extra do
			part:SetAttribute(name, value)
		end
	end
	CollectionService:AddTag(part, "Follower")
end

function Battle.enemiesOf(self: Battle, ball: Ball): { Ball }
	local enemies = {}
	for _, other in self.balls do
		if other ~= ball and other.alive then
			table.insert(enemies, other)
		end
	end
	return enemies
end

function Battle.radius(_self: Battle, ball: Ball): number
	return ball.core.Size.X / 2
end

-- Multiplies the ball's speed by `multiplier` for `duration` seconds. Buffs with the same key
-- replace each other; different keys stack.
function Battle.addSpeedBuff(_self: Battle, ball: Ball, key: string, multiplier: number, duration: number)
	ball.buffs[key] = { multiplier = multiplier, untilTime = os.clock() + duration }
end

function Battle.refreshHealth(_self: Battle, ball: Ball)
	ball.model:SetAttribute("Health", math.max(0, math.ceil(ball.hp)))
end

function Battle.hook(self: Battle, ball: Ball, name: string, ...: any)
	local hook = ball.skill[name]
	if hook and ball.alive and os.clock() >= ball.skillsDisabledUntil then
		local ok, err = pcall(hook, self, ball, ...)
		if not ok then
			warn(`{ball.def.skill}.{name} failed: {err}`)
		end
	end
end

-- Raw points as a share of a ball's 100 health.
local function toHealth(ball: Ball, amount: number): number
	return amount / ball.def.stats.health * ball.maxHp
end

-- Deals `amount` raw damage (more in sudden death) and returns the raw amount dealt. `kind`
-- tells clients how to show it: "hit", "wall", "shot", "vine" or "blast".
function Battle.damage(self: Battle, target: Ball, amount: number, kind: string): number
	if not target.alive or not self.running then
		return 0
	end
	if self.suddenDeath then
		amount *= Config.SUDDEN_DEATH_DAMAGE
	end
	local lost = toHealth(target, amount)
	target.hp -= lost
	self:refreshHealth(target)
	if kind ~= "wall" then
		self:effect("Damage", target.core.Position, math.max(1, math.round(lost)))
	end
	if target.hp <= 0 then
		self:knockOut(target)
	elseif not target.lowHealthFired and target.hp <= target.maxHp * Config.LOW_HEALTH then
		target.lowHealthFired = true
		self:hook(target, "onLowHealth")
	end
	return amount
end

-- Heals `amount` raw points, up to full health.
function Battle.heal(self: Battle, ball: Ball, amount: number)
	if not ball.alive then
		return
	end
	local gained = math.min(toHealth(ball, amount), ball.maxHp - ball.hp)
	if gained <= 0 then
		return
	end
	ball.hp += gained
	self:refreshHealth(ball)
	self:effect("Heal", ball.core.Position, math.max(1, math.round(gained)))
end

function Battle.clearOwned(self: Battle, ball: Ball)
	for _, instance in self.owned[ball] do
		instance:Destroy()
	end
	table.clear(self.owned[ball])
end

-- A knocked-out ball stops dead where it is, waiting for the finisher (see disperse).
function Battle.knockOut(self: Battle, ball: Ball)
	ball.alive = false
	ball.hp = 0
	self:effect("KnockOut", ball.core.Position, ball.def.id)
	self:clearOwned(ball)
	self:publish(ball, 0)
end

-- Slows every ball still going to a fifth of its speed for `duration`, right after a knockout.
function Battle.slowMotion(self: Battle, duration: number)
	for _, ball in self.balls do
		if ball.alive then
			self:addSpeedBuff(ball, "SlowMotion", 0.2, duration)
		end
	end
end

-- Stops the round: nothing moves or takes damage any more.
function Battle.freeze(self: Battle)
	self.running = false
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	for _, ball in self.balls do
		if ball.alive then
			self:clearOwned(ball)
			self:publish(ball, 0)
		end
	end
end

-- Removes a side's ball as it bursts into energy for the finisher. Returns where it was.
function Battle.disperse(self: Battle, side: string): Vector3?
	local ball = self.balls[side]
	if not ball or not ball.model.Parent then
		return nil
	end
	local position = ball.core.Position
	ball.alive = false
	self:clearOwned(ball)
	ball.model:Destroy()
	return position
end

-- Both balls damage each other, based on how fast they were closing in.
function Battle.collide(self: Battle, a: Ball, b: Ball, relativeSpeed: number)
	if relativeSpeed < Config.MIN_IMPACT_SPEED then
		return
	end
	local midpoint = (a.core.Position + b.core.Position) / 2
	local faster = if a.lastVelocity.Magnitude >= b.lastVelocity.Magnitude then a else b
	self:effect("Impact", midpoint, faster.def.id, relativeSpeed)

	local function strike(attacker: Ball, victim: Ball)
		local massRatio = math.clamp(
			(attacker.def.stats.mass * attacker.growth) / (victim.def.stats.mass * victim.growth),
			0.5,
			2
		)
		local amount = (relativeSpeed * attacker.def.stats.impactPower * massRatio * Config.DAMAGE_SCALE + Config.FLAT_DAMAGE)
			* (1 + 0.05 * attacker.damageStacks)
		attacker.damageStacks = 0
		local dealt = self:damage(victim, amount, "hit")
		self:hook(attacker, "onEnemyHit", victim, dealt)
	end
	strike(a, b)
	strike(b, a)
end

function Battle.speedOf(_self: Battle, ball: Ball, now: number): number
	local multiplier = 1
	for key, buff in ball.buffs do
		if buff.untilTime > now then
			multiplier *= buff.multiplier
		else
			ball.buffs[key] = nil
		end
	end
	return ball.def.stats.speed * multiplier
end

function Battle.onWallHit(self: Battle, ball: Ball, hit: Bounce.Hit)
	local now = os.clock()
	local point = self:toWorld(hit.point - hit.normal * self:radius(ball))
	local normal = self:vectorToWorld(hit.normal)
	self:effect("Wall", point)
	if now - ball.lastWallHitAt >= WALL_COOLDOWN then
		ball.lastWallHitAt = now
		self:damage(ball, Config.WALL_DAMAGE, "wall")
	end
	self:hook(ball, "onWallHit", point, normal)
end

-- Moves a ball `deltaTime` along its path, bending it toward a black hole if one is pulling and
-- bouncing it off the walls. Returns whether its path changed.
function Battle.advance(self: Battle, ball: Ball, deltaTime: number, now: number): boolean
	local changed = false
	if ball.pullTarget and ball.pullUntil > now then
		local toward = self:toFlat(ball.pullTarget) - ball.position
		if toward.Magnitude > 0.5 then
			local steered = ball.direction:Lerp(toward.Unit, math.min(1, 6 * deltaTime))
			if steered.Magnitude > 0.01 then
				ball.direction = steered.Unit
			end
		end
	end

	local limit = self.arena.halfWidth() - self:radius(ball)
	local position, direction, pushed = Bounce.contain(ball.position, ball.direction, limit)
	local hits
	position, direction, hits = Bounce.move(position, direction, self:speedOf(ball, now) * deltaTime, limit)
	ball.position, ball.direction = position, direction
	if pushed then
		table.insert(hits, 1, pushed)
	end
	for _, hit in hits do
		changed = true
		self:onWallHit(ball, hit)
		if not ball.alive then
			break
		end
	end
	return changed
end

-- Bounces two overlapping balls off each other like billiard balls (heavier ones push harder),
-- then each keeps its own speed. Returns whether they hit.
function Battle.separate(self: Battle, a: Ball, b: Ball, now: number): boolean
	local offset = b.position - a.position
	local distance = offset.Magnitude
	local reach = self:radius(a) + self:radius(b)
	if distance >= reach or distance < 1e-4 then
		return false
	end
	local normal = offset / distance
	local massA, massB = a.def.stats.mass * a.growth, b.def.stats.mass * b.growth
	local overlap = reach - distance
	a.position -= normal * overlap * massB / (massA + massB)
	b.position += normal * overlap * massA / (massA + massB)

	local velocityA = a.direction * self:speedOf(a, now)
	local velocityB = b.direction * self:speedOf(b, now)
	local closing = (velocityA - velocityB):Dot(normal)
	if closing <= 0 then
		return true
	end
	local impulse = 2 * closing / (massA + massB)
	local newA = velocityA - normal * impulse * massB
	local newB = velocityB + normal * impulse * massA
	a.direction = Bounce.steepen(if newA.Magnitude > 0.01 then newA.Unit else -normal, a.position)
	b.direction = Bounce.steepen(if newB.Magnitude > 0.01 then newB.Unit else normal, b.position)

	if now - self.lastHitAt >= HIT_COOLDOWN then
		self.lastHitAt = now
		self:collide(a, b, (velocityA - velocityB).Magnitude)
	end
	return true
end

function Battle.startSuddenDeath(self: Battle)
	self.suddenDeath = true
	self.targetHalfWidth = self.arena.halfWidth()
	self.nextShrinkAt = os.clock()
	self.arena.setDanger(true)
	self.arena.state:SetAttribute("SuddenDeath", true)
	self:effect("SuddenDeath", self.arena.center)
end

function Battle.step(self: Battle, deltaTime: number)
	local now = os.clock()
	if not self.suddenDeath and now - self.startedAt >= Config.SUDDEN_DEATH_AT then
		self:startSuddenDeath()
	end
	if self.suddenDeath then
		if now >= self.nextShrinkAt then
			self.nextShrinkAt = now + Config.SHRINK_EVERY
			self.targetHalfWidth = math.max(Config.MIN_ARENA_HALF_WIDTH, self.targetHalfWidth * Config.SHRINK_FACTOR)
		end
		local half = self.arena.halfWidth()
		if half > self.targetHalfWidth then
			self.arena.setHalfWidth(math.max(self.targetHalfWidth, half - SHRINK_SPEED * deltaTime))
		end
	end

	local changed: { [Ball]: boolean } = {}
	local steps = math.max(1, math.ceil(deltaTime / MAX_STEP))
	local step = deltaTime / steps
	local left, right = self.balls.Left, self.balls.Right
	for _ = 1, steps do
		for _, ball in self.balls do
			if ball.alive and self:advance(ball, step, now) then
				changed[ball] = true
			end
		end
		if left and right and left.alive and right.alive and self:separate(left, right, now) then
			changed[left] = true
			changed[right] = true
		end
	end

	for _, ball in self.balls do
		if not ball.alive then
			continue
		end
		local speed = self:speedOf(ball, now)
		ball.core.CFrame = CFrame.new(self:toWorld(ball.position))
		ball.lastVelocity = self:vectorToWorld(ball.direction * speed)
		local steering = ball.pullTarget ~= nil and ball.pullUntil > now
		if
			changed[ball]
			or math.abs(speed - ball.publishedSpeed) > 0.01
			or (steering and now - ball.publishedAt >= STEER_PUBLISH_EVERY)
		then
			self:publish(ball, speed)
		end
		self:hook(ball, "onTick", deltaTime)
	end
end

-- Launches each side's ball in its aimed direction (kept within the aim arc).
function Battle.launch(self: Battle, aims: { [string]: Vector3? })
	local now = os.clock()
	for side, ball in self.balls do
		local direction = Battle.clampAim(aims[side], ball.forward, self.arena.facing)
		ball.direction = self:vectorToFlat(direction).Unit
		local speed = self:speedOf(ball, now)
		ball.lastVelocity = direction * speed
		self:publish(ball, speed)
	end
	self.running = true
	self.startedAt = now
	self:effect("Launch", self.arena.center)
	for _, ball in self.balls do
		self:hook(ball, "onStart")
	end
	self.connection = RunService.Heartbeat:Connect(function(deltaTime)
		self:step(deltaTime)
	end)
end

-- Sides whose balls are still in play.
function Battle.aliveSides(self: Battle): { string }
	local sides = {}
	for side, ball in self.balls do
		if ball.alive then
			table.insert(sides, side)
		end
	end
	return sides
end

-- The round's winning side: the only ball left, or the one with more health left. nil for a
-- draw.
function Battle.winner(self: Battle): string?
	local left, right = self.balls.Left, self.balls.Right
	local leftShare = if left and left.alive then left.hp / left.maxHp else 0
	local rightShare = if right and right.alive then right.hp / right.maxHp else 0
	if leftShare > rightShare then
		return "Left"
	elseif rightShare > leftShare then
		return "Right"
	end
	return nil
end

function Battle.destroy(self: Battle)
	self.running = false
	if self.connection then
		self.connection:Disconnect()
	end
	for _, ball in self.balls do
		self:clearOwned(ball)
		ball.model:Destroy()
	end
	self.arena.setHalfWidth(Config.ARENA_SIZE / 2)
	self.arena.setDanger(false)
	self.arena.state:SetAttribute("SuddenDeath", false)
end

return Battle
