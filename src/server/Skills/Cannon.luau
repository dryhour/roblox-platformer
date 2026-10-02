-- Bombardiro Crocodilo (the doc's Cannon Ball): bouncing off a wall plants a turret there (up
-- to 3). Turrets fire a homing shot at the other ball every 1.5 seconds.
local Cannon = {}

local MAX_TURRETS = 3
local FIRE_EVERY = 1.5
local SHOT_DAMAGE = 65
local SHOT_SPEED = 45

function Cannon.onStart(_battle, ball)
	ball.state.turrets = {}
	ball.state.shots = {}
end

function Cannon.onWallHit(battle, ball, point: Vector3, normal: Vector3)
	local turrets = ball.state.turrets
	if #turrets >= MAX_TURRETS then
		return
	end
	local position = point + normal * 0.8
	local turret = Instance.new("Part")
	turret.Name = "Turret"
	turret.Size = Vector3.new(1.6, 1.6, 1.6)
	-- Walls can face up or down, so keep the turret upright relative to the arena's front.
	turret.CFrame = CFrame.lookAt(position, position + normal, battle.arena.facing)
	turret.Color = Color3.fromRGB(70, 75, 85)
	turret.Material = Enum.Material.Metal
	turret.Anchored = true
	turret.CanCollide = false
	turret.CanQuery = false
	turret.CanTouch = false

	local light = Instance.new("Part")
	light.Name = "Barrel"
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.one * 0.8
	light.CFrame = turret.CFrame * CFrame.new(0, 0, -0.9)
	light.Color = ball.def.color
	light.Material = Enum.Material.Neon
	light.Anchored = true
	light.CanCollide = false
	light.CanQuery = false
	light.CanTouch = false

	battle:own(ball, turret)
	battle:own(ball, light)
	table.insert(turrets, { position = light.Position, nextFireAt = os.clock() + 0.5 })
end

function Cannon.onTick(battle, ball, deltaTime: number)
	local now = os.clock()
	local enemies = battle:enemiesOf(ball)
	for _, turret in ball.state.turrets do
		local target = enemies[1]
		if target and now >= turret.nextFireAt then
			turret.nextFireAt = now + FIRE_EVERY
			local shot = Instance.new("Part")
			shot.Name = "Shot"
			shot.Shape = Enum.PartType.Ball
			shot.Size = Vector3.one * 0.8
			shot.Position = turret.position
			shot.Color = Color3.fromRGB(255, 150, 40)
			shot.Material = Enum.Material.Neon
			shot.Anchored = true
			shot.CanCollide = false
			shot.CanQuery = false
			shot.CanTouch = false
			battle:own(ball, shot)
			table.insert(ball.state.shots, { part = shot, target = target })
		end
	end

	local shots = ball.state.shots
	for index = #shots, 1, -1 do
		local shot = shots[index]
		local target = shot.target
		local toward = if target.alive then target.core.Position - shot.part.Position else nil
		if not toward then
			shot.part:Destroy()
			table.remove(shots, index)
		elseif toward.Magnitude <= SHOT_SPEED * deltaTime + battle:radius(target) then
			battle:damage(target, SHOT_DAMAGE, "shot")
			battle:effect("Explosion", shot.part.Position, 0.5)
			shot.part:Destroy()
			table.remove(shots, index)
		else
			shot.part.Position += toward.Unit * SHOT_SPEED * deltaTime
		end
	end
end

return Cannon
