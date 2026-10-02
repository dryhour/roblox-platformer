local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimMath = require(ReplicatedStorage.Shared.AimMath)
local Config = require(ReplicatedStorage.Shared.Config)

-- Trippi Troppi (the reference game's Laser Ball): every 3 seconds it fires a laser straight
-- ahead that bounces off the walls twice. If the laser crosses the other ball, it deals 70.
local Laser = {}

local FIRE_EVERY = 3
local DAMAGE = 70
local BOUNCES = 2
local LENGTH = Config.ARENA_SIZE * 3
local SHOW_FOR = 0.35
local COLOR = Color3.fromRGB(150, 230, 255)

function Laser.onStart(_battle, ball)
	ball.state.nextShotAt = os.clock() + FIRE_EVERY
end

function Laser.onTick(battle, ball)
	local now = os.clock()
	if now < ball.state.nextShotAt then
		return
	end
	ball.state.nextShotAt = now + FIRE_EVERY
	local heading = ball.lastVelocity
	if heading.Magnitude < 0.1 then
		return
	end

	local points = AimMath.trace(ball.core.Position, heading.Unit, battle.arena.facing, battle.arena.walls, BOUNCES, LENGTH)
	local hit = {}
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local length = (to - from).Magnitude
		if length > 0.05 then
			local beam = Instance.new("Part")
			beam.Name = "Laser"
			beam.Size = Vector3.new(0.4, 0.4, length)
			beam.CFrame = CFrame.lookAt((from + to) / 2, to, battle.arena.facing)
			beam.Color = COLOR
			beam.Material = Enum.Material.Neon
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanQuery = false
			beam.CanTouch = false
			battle:own(ball, beam)
			task.delay(SHOW_FOR, beam.Destroy, beam)
		end
		for _, enemy in battle:enemiesOf(ball) do
			if AimMath.distanceToSegment(enemy.core.Position, from, to) < battle:radius(enemy) then
				hit[enemy] = true
			end
		end
	end
	for enemy in hit do
		battle:damage(enemy, DAMAGE, "shot")
		battle:effect("Explosion", enemy.core.Position, 0.4)
	end
end

return Laser
