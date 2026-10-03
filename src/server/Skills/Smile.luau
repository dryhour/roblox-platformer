-- Pure Brainrot Smile (the reference game's Verity Ball): every wall bounce makes it a little
-- faster (+4%, up to +60%). Below 40 health it flies into a rage: the screen flashes, its smile
-- turns into a terrifying grin, and every hit after that deals 60% more.
local Smile = {}

local SPEED_PER_BOUNCE = 0.04
local MAX_SPEED_BONUS = 0.6
local RAGE_BELOW = 40
local RAGE_STACKS = 12 -- each damage stack adds 5% to the next hit
local FOREVER = 1e6

function Smile.onStart(_battle, ball)
	ball.state.bonus = 0
	ball.state.rage = false
end

function Smile.onWallHit(battle, ball)
	ball.state.bonus = math.min(MAX_SPEED_BONUS, ball.state.bonus + SPEED_PER_BOUNCE)
	battle:addSpeedBuff(ball, "Smile", 1 + ball.state.bonus, FOREVER)
end

function Smile.onTick(battle, ball)
	if not ball.state.rage and ball.hp < RAGE_BELOW then
		ball.state.rage = true
		ball.damageStacks = math.max(ball.damageStacks, RAGE_STACKS)
		ball.model:SetAttribute("Rage", true)
		battle:effect("Rage", ball.core.Position)
	end
end

-- Hits use up damage stacks, so a raging smile tops them back up after every hit.
function Smile.onEnemyHit(_battle, ball)
	if ball.state.rage then
		ball.damageStacks = math.max(ball.damageStacks, RAGE_STACKS)
	end
end

return Smile
