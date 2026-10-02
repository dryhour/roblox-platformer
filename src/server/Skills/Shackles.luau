-- La Vaca Saturno Saturnita (the reference game's Shackles Ball): hitting the other ball chains
-- it for 2 seconds, dragging it in and dealing 20 damage a second. Then the chain needs 4
-- seconds to recharge.
local Shackles = {}

local CHAIN_TIME = 2
local RECHARGE = 4
local DAMAGE_PER_SECOND = 20
local COLOR = Color3.fromRGB(255, 200, 90)

function Shackles.onStart(_battle, ball)
	ball.state.readyAt = 0
end

function Shackles.onEnemyHit(battle, ball, enemy)
	local now = os.clock()
	if now < ball.state.readyAt then
		return
	end
	ball.state.readyAt = now + CHAIN_TIME + RECHARGE

	local chain = Instance.new("Part")
	chain.Name = "Chain"
	chain.Color = COLOR
	chain.Material = Enum.Material.Neon
	chain.Anchored = true
	chain.CanCollide = false
	chain.CanQuery = false
	chain.CanTouch = false
	battle:own(ball, chain)
	ball.state.chain = { part = chain, target = enemy, untilTime = now + CHAIN_TIME, owed = 0 }
end

function Shackles.onTick(battle, ball, deltaTime: number)
	local chain = ball.state.chain
	if not chain then
		return
	end
	local now = os.clock()
	if now > chain.untilTime or not chain.target.alive then
		chain.part:Destroy()
		ball.state.chain = nil
		return
	end
	local from, to = ball.core.Position, chain.target.core.Position
	chain.part.Size = Vector3.new(0.3, 0.3, math.max((to - from).Magnitude, 0.1))
	chain.part.CFrame = CFrame.lookAt((from + to) / 2, to, battle.arena.facing)
	chain.target.pullTarget = from
	chain.target.pullUntil = now + 0.1
	-- Damage is added up and dealt in whole points.
	chain.owed += DAMAGE_PER_SECOND * deltaTime
	if chain.owed >= 10 then
		battle:damage(chain.target, chain.owed, "vine")
		chain.owed = 0
	end
end

return Shackles
