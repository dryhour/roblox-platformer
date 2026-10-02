-- Ballerina Cappuccina (the reference game's Dice Ball): every wall bounce rolls a die (at most
-- once a second). 1-2 heals 40, 3-4 gives a burst of speed, and 5-6 doubles its next hit.
local Dice = {}

local COOLDOWN = 1
local HEAL = 40
local SPEED_BOOST = 1.4
local BOOST_TIME = 2
local DOUBLE_STACKS = 20 -- each damage stack adds 5% to the next hit, so 20 doubles it

local rng = Random.new()

function Dice.onStart(_battle, ball)
	ball.state.nextRollAt = 0
end

function Dice.onWallHit(battle, ball)
	local now = os.clock()
	if now < ball.state.nextRollAt then
		return
	end
	ball.state.nextRollAt = now + COOLDOWN
	local roll = rng:NextInteger(1, 6)
	if roll <= 2 then
		battle:heal(ball, HEAL)
	elseif roll <= 4 then
		battle:addSpeedBuff(ball, "Dice", SPEED_BOOST, BOOST_TIME)
	else
		ball.damageStacks = math.max(ball.damageStacks, DOUBLE_STACKS)
	end
	battle:effect("Dice", ball.core.Position, roll)
end

return Dice
