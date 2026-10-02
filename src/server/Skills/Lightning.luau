-- Boneca Ambalabu (the reference game's Lightning Ball): every 4 seconds, lightning strikes the
-- other ball from the top of the arena for 70 damage.
local Lightning = {}

local STRIKE_EVERY = 4
local DAMAGE = 70
local ZIGS = 5
local SHOW_FOR = 0.3
local COLOR = Color3.fromRGB(255, 245, 140)

local rng = Random.new()

function Lightning.onStart(_battle, ball)
	ball.state.nextStrikeAt = os.clock() + STRIKE_EVERY
end

function Lightning.onTick(battle, ball)
	local now = os.clock()
	if now < ball.state.nextStrikeAt then
		return
	end
	ball.state.nextStrikeAt = now + STRIKE_EVERY
	local target = battle:enemiesOf(ball)[1]
	if not target then
		return
	end

	-- A zigzag bolt from the top wall down to the target, in the arena's plane.
	local space = battle.arena.cframe
	local bottom = target.core.Position
	local top = bottom + space.UpVector * (battle.arena.halfWidth() - space:PointToObjectSpace(bottom).Y)
	local previous = top
	for step = 1, ZIGS do
		local point = top:Lerp(bottom, step / ZIGS)
		if step < ZIGS then
			point += space.RightVector * rng:NextNumber(-1.5, 1.5)
		end
		local bolt = Instance.new("Part")
		bolt.Name = "Lightning"
		bolt.Size = Vector3.new(0.35, 0.35, (point - previous).Magnitude)
		bolt.CFrame = CFrame.lookAt((previous + point) / 2, point, battle.arena.facing)
		bolt.Color = COLOR
		bolt.Material = Enum.Material.Neon
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false
		battle:own(ball, bolt)
		task.delay(SHOW_FOR, bolt.Destroy, bolt)
		previous = point
	end
	battle:damage(target, DAMAGE, "shot")
	battle:effect("Lightning", bottom)
end

return Lightning
