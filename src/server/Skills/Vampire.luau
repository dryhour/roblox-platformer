-- Tralalero Tralala (the doc's Vampire Ball): heals for part of every hit it lands, and speeds
-- up for a moment afterward.
local Vampire = {}

local LEECH = 0.35
local SPEED_BOOST = 1.15
local BOOST_TIME = 2

function Vampire.onEnemyHit(battle, ball, _enemy, damage: number)
	battle:heal(ball, damage * LEECH)
	battle:addSpeedBuff(ball, "Leech", SPEED_BOOST, BOOST_TIME)
	battle:effect("Leech", ball.core.Position)
end

return Vampire
