local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Tung Tung Tung Sahur (the doc's Charge Ball): grows bigger and heavier every second, and
-- each wall bounce charges up the next hit on the other ball (+5% per bounce, up to 10).
local Charge = {}

local GROWTH_PER_SECOND = 0.02
local MAX_GROWTH = 1.6
local MAX_STACKS = 10

function Charge.onTick(_battle, ball, deltaTime: number)
	ball.growth = math.min(MAX_GROWTH, ball.growth + GROWTH_PER_SECOND * deltaTime)
	local size = Config.BALL_SIZE * ball.growth
	if math.abs(ball.core.Size.X - size) > 0.15 then
		ball.core.Size = Vector3.one * size
	end
end

function Charge.onWallHit(_battle, ball)
	ball.damageStacks = math.min(MAX_STACKS, ball.damageStacks + 1)
end

return Charge
