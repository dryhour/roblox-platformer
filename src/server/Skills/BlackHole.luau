-- Cappuccino Assassino (the doc's Black Hole Ball): the first time its health drops below 25%,
-- it opens a black hole around itself for 3 seconds that pulls the other ball in and switches
-- off its ability.
local BlackHole = {}

local RADIUS = 7
local DURATION = 3

function BlackHole.onLowHealth(battle, ball)
	local now = os.clock()
	ball.state.activeUntil = now + DURATION

	local field = Instance.new("Part")
	field.Name = "BlackHole"
	field.Shape = Enum.PartType.Ball
	field.Size = Vector3.one * RADIUS * 2
	field.Position = ball.core.Position
	field.Color = Color3.fromRGB(120, 40, 200)
	field.Material = Enum.Material.ForceField
	field.Anchored = true
	field.CanCollide = false
	field.CanQuery = false
	field.CanTouch = false
	battle:own(ball, field)
	ball.state.field = field

	for _, enemy in battle:enemiesOf(ball) do
		enemy.skillsDisabledUntil = now + DURATION
	end
	battle:effect("BlackHole", ball.core.Position)
end

function BlackHole.onTick(battle, ball)
	local field = ball.state.field
	if not field then
		return
	end
	local now = os.clock()
	if now > ball.state.activeUntil then
		field:Destroy()
		ball.state.field = nil
		return
	end
	field.Position = ball.core.Position
	for _, enemy in battle:enemiesOf(ball) do
		if (enemy.core.Position - ball.core.Position).Magnitude < RADIUS then
			enemy.pullTarget = ball.core.Position
			enemy.pullUntil = now + 0.1
		end
	end
end

return BlackHole
