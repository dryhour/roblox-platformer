local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimMath = require(ReplicatedStorage.Shared.AimMath)
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Looks = require(ReplicatedStorage.Shared.Looks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Arena = require(script.Parent.World.Arena)

-- One round's auto-battle. The server owns and simulates both balls, so nobody can cheat their
-- ball's movement. Once launched, balls fly around the arena's upright box at their own speed
-- with no gravity, bounce off the walls and each other, take damage, and trigger their
-- abilities. Sudden death closes the walls in.
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

local BALL_VOLUME = 4 / 3 * math.pi * (Config.BALL_SIZE / 2) ^ 3
local HIT_COOLDOWN = 0.25
local WALL_COOLDOWN = 0.15
local SHRINK_SPEED = 10 -- studs per second the walls move during sudden death

export type Ball = {
	side: string,
	def: Brainrots.Brainrot,
	model: Model,
	core: BasePart,
	float: VectorForce, -- cancels gravity
	forward: Vector3,
	hp: number,
	maxHp: number,
	alive: boolean,
	lastVelocity: Vector3,
	buffs: { [string]: { multiplier: number, untilTime: number } },
	growth: number, -- size and mass multiplier
	damageStacks: number, -- each adds 5% to the next hit on the other ball
	skillsDisabledUntil: number,
	pullTarget: Vector3?, -- steered toward this until pullUntil
	pullUntil: number,
	lowHealthFired: boolean,
	lastWallHitAt: number,
	skill: { [string]: any },
	state: { [string]: any }, -- for the ability's own use
	healthText: TextLabel,
}

export type Battle = typeof(setmetatable(
	{} :: {
		arena: Arena.Arena,
		explosions: { [string]: string }, -- each side's knockout explosion (see Cosmetics)
		balls: { [string]: Ball },
		byCore: { [BasePart]: Ball },
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

local rng = Random.new()
local skills: { [string]: { [string]: any } } = {}
for _, module in script.Parent.Skills:GetChildren() do
	if module:IsA("ModuleScript") then
		skills[module.Name] = require(module) :: any
	end
end

-- Turns any value into a unit direction in the arena's plane within the aim arc of `forward`.
Battle.clampAim = AimMath.clamp

-- The ball's health as a big number over it, outlined in its side's color.
local function healthLabel(core: BasePart, color: Color3): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Health"
	billboard.Size = UDim2.fromScale(Config.BALL_SIZE * 1.2, Config.BALL_SIZE * 0.5)
	billboard.StudsOffset = Vector3.new(0, Config.BALL_SIZE * 0.8, 0)
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
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = text

	billboard.Parent = core
	return text
end

-- Sets up a battle in `arena` with the picked brainrot for each side ("Left", "Right"), and the
-- explosion each side shows when it knocks the other out. The balls sit frozen at their spawn
-- points until launch().
function Battle.new(arena: Arena.Arena, picks: { [string]: string }, explosions: { [string]: string }): Battle
	local self = setmetatable({
		arena = arena,
		explosions = explosions,
		balls = {},
		byCore = {},
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
	-- Slick and very bouncy. Heavier brainrots get denser balls.
	core.CustomPhysicalProperties = PhysicalProperties.new(def.stats.mass / BALL_VOLUME, 0.02, 0.96, 1, 1)
	core.Parent = model
	model.PrimaryPart = core

	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	local float = Instance.new("VectorForce")
	float.Name = "Float"
	float.Attachment0 = attachment
	float.RelativeTo = Enum.ActuatorRelativeTo.World
	float.ApplyAtCenterOfMass = true
	float.Parent = core

	local look = Looks.build(def.id)
	Looks.place(look, CFrame.lookAt(position, position + self.arena.facing))
	look.Parent = model

	local ball: Ball = {
		side = side,
		def = def,
		model = model,
		core = core,
		float = float,
		forward = forward,
		hp = def.stats.health,
		maxHp = def.stats.health,
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
		skill = skills[def.skill] or {},
		state = {},
		healthText = healthLabel(core, Config.SIDE_COLORS[side]),
	}
	self:refreshHealth(ball)
	self.balls[side] = ball
	self.byCore[core] = ball
	self.owned[ball] = {}

	core.Touched:Connect(function(hit)
		self:onTouched(ball, hit)
	end)
	CollectionService:AddTag(model, "Ball")
	model.Parent = self.arena.model
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
	ball.healthText.Text = tostring(math.max(0, math.ceil(ball.hp)))
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

-- Deals damage (more in sudden death) and returns how much was dealt. `kind` tells clients how
-- to show it: "hit", "wall", "shot", "vine" or "blast".
function Battle.damage(self: Battle, target: Ball, amount: number, kind: string): number
	if not target.alive or not self.running then
		return 0
	end
	if self.suddenDeath then
		amount *= Config.SUDDEN_DEATH_DAMAGE
	end
	amount = math.max(1, math.round(amount))
	target.hp -= amount
	self:refreshHealth(target)
	if kind ~= "wall" then
		self:effect("Damage", target.core.Position, amount)
	end
	if target.hp <= 0 then
		self:knockOut(target)
	elseif not target.lowHealthFired and target.hp <= target.maxHp * Config.LOW_HEALTH then
		target.lowHealthFired = true
		self:hook(target, "onLowHealth")
	end
	return amount
end

function Battle.heal(self: Battle, ball: Ball, amount: number)
	if not ball.alive then
		return
	end
	amount = math.round(math.min(amount, ball.maxHp - ball.hp))
	if amount <= 0 then
		return
	end
	ball.hp += amount
	self:refreshHealth(ball)
	self:effect("Heal", ball.core.Position, amount)
end

function Battle.clearOwned(self: Battle, ball: Ball)
	for _, instance in self.owned[ball] do
		instance:Destroy()
	end
	table.clear(self.owned[ball])
end

function Battle.knockOut(self: Battle, ball: Ball)
	ball.alive = false
	ball.hp = 0
	local winner = if ball.side == "Left" then "Right" else "Left"
	self:effect("KnockOut", ball.core.Position, ball.def.id, self.explosions[winner])
	self:clearOwned(ball)
	self.byCore[ball.core] = nil
	ball.model:Destroy()
end

function Battle.onTouched(self: Battle, ball: Ball, hit: BasePart)
	if not self.running or not ball.alive then
		return
	end
	local now = os.clock()
	if hit:GetAttribute("IsArenaWall") then
		if now - ball.lastWallHitAt < WALL_COOLDOWN then
			return
		end
		ball.lastWallHitAt = now
		local normal = hit:GetAttribute("Normal") :: Vector3
		local point = ball.core.Position - normal * self:radius(ball)
		self:effect("Wall", point)
		self:damage(ball, Config.WALL_DAMAGE, "wall")
		self:hook(ball, "onWallHit", point, normal)
		return
	end
	local other = self.byCore[hit]
	if other and other.alive and now - self.lastHitAt >= HIT_COOLDOWN then
		self.lastHitAt = now
		self:collide(ball, other)
	end
end

-- Both balls damage each other, using their velocities from just before they touched.
function Battle.collide(self: Battle, a: Ball, b: Ball)
	local relativeSpeed = (a.lastVelocity - b.lastVelocity).Magnitude
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

-- Keeps the ball moving at its speed in whatever direction it's going (bounces only change the
-- direction), steers it toward a black hole if one is pulling, and keeps it inside the walls and
-- in the box's plane. Works in the arena's own space: X across, Y up.
function Battle.keepRolling(self: Battle, ball: Ball, deltaTime: number, now: number)
	local core = ball.core
	local space = self.arena.cframe
	local velocity = space:VectorToObjectSpace(core.AssemblyLinearVelocity)
	local direction = Vector3.new(velocity.X, velocity.Y, 0)
	if direction.Magnitude > 0.5 then
		direction = direction.Unit
	else
		local angle = rng:NextNumber(0, math.pi * 2)
		direction = Vector3.new(math.cos(angle), math.sin(angle), 0)
	end

	local offset = space:PointToObjectSpace(core.Position)
	if ball.pullTarget and ball.pullUntil > now then
		local toward = space:PointToObjectSpace(ball.pullTarget) - offset
		toward = Vector3.new(toward.X, toward.Y, 0)
		if toward.Magnitude > 0.5 then
			local steered = direction:Lerp(toward.Unit, math.min(1, 6 * deltaTime))
			if steered.Magnitude > 0.01 then
				direction = steered.Unit
			end
		end
	end

	local limit = self.arena.halfWidth() - self:radius(ball)
	local x, y = offset.X, offset.Y
	if math.abs(x) > limit then
		x = math.sign(x) * limit
		if direction.X * x > 0 then
			direction = Vector3.new(-direction.X, direction.Y, 0)
		end
	end
	if math.abs(y) > limit then
		y = math.sign(y) * limit
		if direction.Y * y > 0 then
			direction = Vector3.new(direction.X, -direction.Y, 0)
		end
	end
	if x ~= offset.X or y ~= offset.Y or math.abs(offset.Z) > 0.05 then
		core.Position = space:PointToWorldSpace(Vector3.new(x, y, 0))
	end

	-- Gravity would curve every path downward. Mass changes as Charge balls grow.
	ball.float.Force = Vector3.new(0, core.AssemblyMass * workspace.Gravity, 0)
	local newVelocity = space:VectorToWorldSpace(direction * self:speedOf(ball, now))
	core.AssemblyLinearVelocity = newVelocity
	ball.lastVelocity = newVelocity
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

	for _, ball in self.balls do
		if ball.alive then
			self:keepRolling(ball, deltaTime, now)
			self:hook(ball, "onTick", deltaTime)
		end
	end
end

-- Launches each side's ball in its aimed direction (kept within the aim arc).
function Battle.launch(self: Battle, aims: { [string]: Vector3? })
	for side, ball in self.balls do
		local direction = Battle.clampAim(aims[side], ball.forward, self.arena.facing)
		ball.float.Force = Vector3.new(0, ball.core:GetMass() * workspace.Gravity, 0)
		ball.core.Anchored = false
		ball.core:SetNetworkOwner(nil)
		ball.core.AssemblyLinearVelocity = direction * ball.def.stats.speed
		ball.lastVelocity = ball.core.AssemblyLinearVelocity
	end
	self.running = true
	self.startedAt = os.clock()
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

-- The round's winning side: the only ball left, or the one with more of its health left.
-- nil for a draw.
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
