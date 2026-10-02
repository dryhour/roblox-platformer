-- Brr Brr Patapim (the doc's Spider Ball): each wall bounce stretches a vine back to its last
-- bounce point (up to 3, each lasting 6 seconds). The other ball rolling through a vine is
-- slowed by 60% and takes 40 damage a second.
local Vines = {}

local MAX_VINES = 3
local LIFETIME = 6
local DAMAGE_PER_SECOND = 40
local SLOW = 0.4
local SLOW_TIME = 1.2
local DAMAGE_EVERY = 0.5 -- vine damage is added up and dealt in chunks

local function flatDistanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local p = Vector2.new(point.X, point.Z)
	local start = Vector2.new(a.X, a.Z)
	local segment = Vector2.new(b.X, b.Z) - start
	local t = math.clamp((p - start):Dot(segment) / math.max(segment:Dot(segment), 0.001), 0, 1)
	return (start + segment * t - p).Magnitude
end

function Vines.onStart(_battle, ball)
	ball.state.vines = {}
	ball.state.lastPoint = nil
	ball.state.pending = {}
	ball.state.nextDamageAt = os.clock() + DAMAGE_EVERY
end

function Vines.onWallHit(battle, ball, point: Vector3)
	local state = ball.state
	local last = state.lastPoint
	state.lastPoint = point
	if not last or (point - last).Magnitude < 4 then
		return
	end

	local vine = Instance.new("Part")
	vine.Name = "Vine"
	vine.Size = Vector3.new(0.6, 0.6, (point - last).Magnitude)
	vine.CFrame = CFrame.lookAt((point + last) / 2, point)
	vine.Color = Color3.fromRGB(80, 220, 90)
	vine.Material = Enum.Material.Neon
	vine.Anchored = true
	vine.CanCollide = false
	vine.CanQuery = false
	vine.CanTouch = false
	battle:own(ball, vine)
	table.insert(state.vines, { part = vine, from = last, to = point, madeAt = os.clock() })
	if #state.vines > MAX_VINES then
		local oldest = table.remove(state.vines, 1)
		if oldest then
			oldest.part:Destroy()
		end
	end
end

function Vines.onTick(battle, ball, deltaTime: number)
	local state = ball.state
	local now = os.clock()
	for index = #state.vines, 1, -1 do
		local vine = state.vines[index]
		if now - vine.madeAt > LIFETIME then
			vine.part:Destroy()
			table.remove(state.vines, index)
		end
	end

	for _, enemy in battle:enemiesOf(ball) do
		for _, vine in state.vines do
			if flatDistanceToSegment(enemy.core.Position, vine.from, vine.to) < battle:radius(enemy) then
				battle:addSpeedBuff(enemy, "Vines", SLOW, SLOW_TIME)
				state.pending[enemy] = (state.pending[enemy] or 0) + DAMAGE_PER_SECOND * deltaTime
				break
			end
		end
	end

	if now >= state.nextDamageAt then
		state.nextDamageAt = now + DAMAGE_EVERY
		for enemy, amount in state.pending do
			if amount >= 1 then
				battle:damage(enemy, amount, "vine")
			end
		end
		table.clear(state.pending)
	end
end

return Vines
