-- Chimpanzini Bananini (the doc's Apple Ball): drops a banana every 3 seconds. Rolling over your
-- own banana heals 15%; when the other ball touches one, it explodes.
local Bananas = {}

local DROP_EVERY = 3
local MAX_BANANAS = 4
local LIFETIME = 10
local ARM_TIME = 1 -- so you don't pick up a banana the moment you drop it
local HEAL = 0.15
local BLAST_DAMAGE = 120
local BLAST_RADIUS = 10
local REACH = 1.5 -- how close a ball's surface has to get

local function makeBanana(position: Vector3): Part
	local banana = Instance.new("Part")
	banana.Name = "Banana"
	banana.Shape = Enum.PartType.Ball
	banana.Size = Vector3.one * 2.2
	banana.Position = position
	banana.Color = Color3.fromRGB(255, 220, 60)
	banana.Material = Enum.Material.Neon
	banana.Anchored = true
	banana.CanCollide = false
	banana.CanQuery = false
	banana.CanTouch = false

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(4, 4)
	sign.StudsOffset = Vector3.new(0, 2.5, 0)
	sign.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🍌"
	label.TextScaled = true
	label.Parent = sign
	sign.Parent = banana
	return banana
end

function Bananas.onStart(_battle, ball)
	ball.state.nextDropAt = os.clock() + DROP_EVERY
	ball.state.bananas = {}
end

function Bananas.onTick(battle, ball)
	local now = os.clock()
	local bananas = ball.state.bananas
	if now >= ball.state.nextDropAt then
		ball.state.nextDropAt = now + DROP_EVERY
		if #bananas < MAX_BANANAS then
			local part = makeBanana(ball.core.Position)
			battle:own(ball, part)
			table.insert(bananas, { part = part, droppedAt = now })
		end
	end

	local function touching(other, part: BasePart): boolean
		return (other.core.Position - part.Position).Magnitude < battle:radius(other) + REACH
	end

	for index = #bananas, 1, -1 do
		local banana = bananas[index]
		local age = now - banana.droppedAt
		local used = age > LIFETIME
		if not used and age > ARM_TIME then
			if touching(ball, banana.part) then
				battle:heal(ball, ball.maxHp * HEAL)
				used = true
			else
				for _, enemy in battle:enemiesOf(ball) do
					if touching(enemy, banana.part) then
						battle:effect("Explosion", banana.part.Position, 1)
						for _, victim in battle:enemiesOf(ball) do
							if (victim.core.Position - banana.part.Position).Magnitude < BLAST_RADIUS + battle:radius(victim) then
								battle:damage(victim, BLAST_DAMAGE, "blast")
							end
						end
						used = true
						break
					end
				end
			end
		end
		if used then
			banana.part:Destroy()
			table.remove(bananas, index)
		end
	end
end

return Bananas
