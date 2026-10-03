local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimMath = require(ReplicatedStorage.Shared.AimMath)

-- Brr Brr Patapim (the doc's Spider Ball): each wall bounce stretches a vine back to its last
-- bounce point (up to 3, each lasting 6 seconds). The other ball rolling through a vine is
-- slowed by 60% and takes 40 damage a second.
--
-- Vines.make builds the same ability with other numbers and looks; Backrooms Mold's hazard tape
-- (Skills/Tape) uses it.
export type Options = {
	maxLines: number,
	lifetime: number,
	damagePerSecond: number, -- raw points
	slow: number, -- speed multiplier while touching a line
	slowTime: number,
	damageEvery: number, -- damage is added up and dealt in chunks this often
	thickness: number,
	colors: { Color3 }, -- more than one makes stripes
	material: Enum.Material,
}

-- Balls and lines all sit in the arena's plane, so plain 3D distance works.
local distanceToSegment = AimMath.distanceToSegment

local function make(options: Options)
	local skill = {}

	-- A line from `from` to `to`, made of stripes if there's more than one color.
	local function drawLine(battle, ball, from: Vector3, to: Vector3): { BasePart }
		local length = (to - from).Magnitude
		local stripes = if #options.colors > 1 then math.max(1, math.floor(length / 1.2)) else 1
		local parts = {}
		for index = 1, stripes do
			local a = from:Lerp(to, (index - 1) / stripes)
			local b = from:Lerp(to, index / stripes)
			local piece = Instance.new("Part")
			piece.Name = "Line"
			piece.Size = Vector3.new(options.thickness, options.thickness, (b - a).Magnitude)
			piece.CFrame = CFrame.lookAt((a + b) / 2, b, battle.arena.facing)
			piece.Color = options.colors[(index - 1) % #options.colors + 1]
			piece.Material = options.material
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			battle:own(ball, piece)
			table.insert(parts, piece)
		end
		return parts
	end

	function skill.onStart(_battle, ball)
		ball.state.lines = {}
		ball.state.lastPoint = nil
		ball.state.pending = {}
		ball.state.nextDamageAt = os.clock() + options.damageEvery
	end

	function skill.onWallHit(battle, ball, point: Vector3)
		local state = ball.state
		local last = state.lastPoint
		state.lastPoint = point
		if not last or (point - last).Magnitude < 2 then
			return
		end
		table.insert(state.lines, { parts = drawLine(battle, ball, last, point), from = last, to = point, madeAt = os.clock() })
		if #state.lines > options.maxLines then
			local oldest = table.remove(state.lines, 1)
			if oldest then
				for _, piece in oldest.parts do
					piece:Destroy()
				end
			end
		end
	end

	function skill.onTick(battle, ball, deltaTime: number)
		local state = ball.state
		local now = os.clock()
		for index = #state.lines, 1, -1 do
			local line = state.lines[index]
			if now - line.madeAt > options.lifetime then
				for _, piece in line.parts do
					piece:Destroy()
				end
				table.remove(state.lines, index)
			end
		end

		for _, enemy in battle:enemiesOf(ball) do
			for _, line in state.lines do
				if distanceToSegment(enemy.core.Position, line.from, line.to) < battle:radius(enemy) then
					battle:addSpeedBuff(enemy, "Lines", options.slow, options.slowTime)
					state.pending[enemy] = (state.pending[enemy] or 0) + options.damagePerSecond * deltaTime
					break
				end
			end
		end

		if now >= state.nextDamageAt then
			state.nextDamageAt = now + options.damageEvery
			for enemy, amount in state.pending do
				if amount >= 1 then
					battle:damage(enemy, amount, "vine")
				end
			end
			table.clear(state.pending)
		end
	end

	return skill
end

local Vines = make({
	maxLines = 3,
	lifetime = 6,
	damagePerSecond = 40,
	slow = 0.4,
	slowTime = 1.2,
	damageEvery = 0.5,
	thickness = 0.35,
	colors = { Color3.fromRGB(80, 220, 90) },
	material = Enum.Material.Neon,
})
Vines.make = make

return Vines
