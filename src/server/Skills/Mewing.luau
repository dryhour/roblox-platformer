-- Sigma Mewing (the reference game's Charge Ball): every 5 seconds it slows to a crawl and
-- charges up in a cyan glow for 1.2 seconds, then dashes straight at the other ball at 4x speed
-- for a second, its next hit dealing double.
local Mewing = {}

local CYCLE = 5
local CHARGE_TIME = 1.2
local DASH_TIME = 1
local CHARGE_SPEED = 0.1
local DASH_SPEED = 4
local DASH_STACKS = 20 -- each damage stack adds 5% to the next hit, so 20 doubles it

function Mewing.onStart(_battle, ball)
	ball.state.nextChargeAt = os.clock() + CYCLE
	ball.state.dashAt = nil
end

local function makeAura(battle, ball): BasePart
	local aura = Instance.new("Part")
	aura.Name = "Aura"
	aura.Shape = Enum.PartType.Ball
	aura.Size = Vector3.one * battle:radius(ball) * 3
	aura.Color = Color3.fromRGB(90, 230, 255)
	aura.Material = Enum.Material.ForceField
	aura.Anchored = true
	aura.CanCollide = false
	aura.CanQuery = false
	aura.CanTouch = false
	aura.Position = ball.core.Position
	battle:own(ball, aura)
	battle:follow(aura, ball)
	return aura
end

function Mewing.onTick(battle, ball)
	local now = os.clock()
	local state = ball.state
	if not state.dashAt and now >= state.nextChargeAt then
		-- Start charging.
		state.dashAt = now + CHARGE_TIME
		state.aura = makeAura(battle, ball)
		battle:addSpeedBuff(ball, "Mewing", CHARGE_SPEED, CHARGE_TIME)
	elseif state.dashAt and now >= state.dashAt then
		-- Dash at the other ball.
		state.dashAt = nil
		state.nextChargeAt = now + CYCLE
		if state.aura then
			state.aura:Destroy()
			state.aura = nil
		end
		local target = battle:enemiesOf(ball)[1]
		if target then
			battle:redirect(ball, target.position - ball.position)
		end
		battle:addSpeedBuff(ball, "Mewing", DASH_SPEED, DASH_TIME)
		ball.damageStacks = math.max(ball.damageStacks, DASH_STACKS)
		battle:effect("Impact", ball.core.Position, ball.def.id, 0)
	end
end

return Mewing
