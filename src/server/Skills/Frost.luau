-- Frigo Camelo (the reference game's Frost Ball): hitting the other ball freezes it in a block of
-- ice for 1.5 seconds, slowing it to a crawl.
local Frost = {}

local SLOW = 0.25
local FREEZE_TIME = 1.5

function Frost.onEnemyHit(battle, ball, enemy)
	battle:addSpeedBuff(enemy, "Frost", SLOW, FREEZE_TIME)
	battle:effect("Frost", enemy.core.Position)

	local ice = Instance.new("Part")
	ice.Name = "Ice"
	ice.Shape = Enum.PartType.Ball
	ice.Size = Vector3.one * battle:radius(enemy) * 2.5
	ice.Color = Color3.fromRGB(170, 230, 255)
	ice.Material = Enum.Material.Ice
	ice.Transparency = 0.45
	ice.Anchored = true
	ice.CanCollide = false
	ice.CanQuery = false
	ice.CanTouch = false
	ice.Position = enemy.core.Position
	battle:own(ball, ice)
	table.insert(ball.state.ice, { part = ice, target = enemy, untilTime = os.clock() + FREEZE_TIME })
end

function Frost.onStart(_battle, ball)
	ball.state.ice = {}
end

function Frost.onTick(_battle, ball)
	local now = os.clock()
	local ice = ball.state.ice
	for index = #ice, 1, -1 do
		local block = ice[index]
		if now > block.untilTime or not block.target.alive then
			block.part:Destroy()
			table.remove(ice, index)
		else
			block.part.Position = block.target.core.Position
		end
	end
end

return Frost
