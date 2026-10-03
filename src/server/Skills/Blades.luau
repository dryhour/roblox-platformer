-- Lirilì Larilà (the reference game's Blade Ball): cactus spikes orbit it, one more after every
-- wall bounce (up to 6). A spike touching the other ball deals 25 damage, at most once a second
-- per spike.
local Blades = {}

local MAX_SPIKES = 6
local DAMAGE = 25
local COOLDOWN = 1
local SPIN = 4 -- radians per second
local REACH = 0.5 -- how close a spike has to get to the other ball's surface

-- Spikes go around on the server's clock, so clients can draw them in step.
local function angleOf(index: number, count: number): number
	return workspace:GetServerTimeNow() * SPIN + (index - 1) * 2 * math.pi / count
end

local function addSpike(battle, ball)
	local spike = Instance.new("Part")
	spike.Name = "Spike"
	spike.Size = Vector3.new(0.35, 0.35, 1.6)
	spike.Color = Color3.fromRGB(235, 245, 225)
	spike.Material = Enum.Material.SmoothPlastic
	spike.Anchored = true
	spike.CanCollide = false
	spike.CanQuery = false
	spike.CanTouch = false
	spike.CFrame = ball.core.CFrame
	battle:own(ball, spike)
	table.insert(ball.state.spikes, { part = spike, readyAt = 0 })
	local count = #ball.state.spikes
	for index, entry in ball.state.spikes do
		battle:follow(entry.part, ball, {
			OrbitIndex = index,
			OrbitCount = count,
			OrbitRadius = battle:radius(ball) + 1,
			OrbitSpin = SPIN,
		})
	end
end

function Blades.onStart(battle, ball)
	ball.state.spikes = {}
	addSpike(battle, ball)
end

function Blades.onWallHit(battle, ball)
	if #ball.state.spikes < MAX_SPIKES then
		addSpike(battle, ball)
	end
end

function Blades.onTick(battle, ball)
	local now = os.clock()
	local space = battle.arena.cframe
	local center = ball.core.Position
	local orbit = battle:radius(ball) + 1
	local spikes = ball.state.spikes
	for index, spike in spikes do
		local angle = angleOf(index, #spikes)
		local outward = space.RightVector * math.cos(angle) + space.UpVector * math.sin(angle)
		local position = center + outward * orbit
		spike.part.CFrame = CFrame.lookAt(position, position + outward, battle.arena.facing)
		if now < spike.readyAt then
			continue
		end
		for _, enemy in battle:enemiesOf(ball) do
			if (enemy.core.Position - position).Magnitude < battle:radius(enemy) + REACH then
				spike.readyAt = now + COOLDOWN
				battle:damage(enemy, DAMAGE, "shot")
				battle:effect("Wall", position)
			end
		end
	end
end

return Blades
