-- How balls move inside an arena box, shared so it matches exactly: the server runs it, and
-- clients use it to draw each ball smoothly between the server's updates.
--
-- Works in the arena's own flat space: X across, Y up, measured from the middle of the box.
-- Balls go straight at a steady speed and bounce off the walls at +/- `limit` (the box's half
-- width minus the ball's radius).
local Bounce = {}

-- Every bounce leaves at least this far from the walls' directions, so balls never get stuck
-- going straight back and forth or sliding along a wall.
Bounce.MIN_ANGLE = math.rad(20)

local MAX_BOUNCES_PER_MOVE = 8

export type Hit = { point: Vector2, normal: Vector2 } -- the normal points back into the box

-- The sign to use for a part of a direction, picking toward the middle of the box if it's zero.
local function sideOf(value: number, position: number): number
	if math.abs(value) > 1e-4 then
		return math.sign(value)
	end
	return if position > 0 then -1 else 1
end

-- Turns `direction` so it's at least MIN_ANGLE away from flat across and straight up and down,
-- keeping which way it goes.
function Bounce.steepen(direction: Vector2, position: Vector2): Vector2
	local minimum = math.sin(Bounce.MIN_ANGLE)
	local rest = math.sqrt(1 - minimum * minimum)
	local x, y = direction.X, direction.Y
	if math.abs(y) < minimum then
		return Vector2.new(sideOf(x, position.X) * rest, sideOf(y, position.Y) * minimum)
	elseif math.abs(x) < minimum then
		return Vector2.new(sideOf(x, position.X) * minimum, sideOf(y, position.Y) * rest)
	end
	return direction
end

local function reflect(direction: Vector2, normal: Vector2, position: Vector2): Vector2
	return Bounce.steepen(direction - 2 * direction:Dot(normal) * normal, position)
end

-- Puts a ball back inside the walls if it's outside them (the walls moved in, or it grew), and
-- turns it to head back in. Returns the new position and direction, and the hit if there was one.
function Bounce.contain(position: Vector2, direction: Vector2, limit: number): (Vector2, Vector2, Hit?)
	local x, y = position.X, position.Y
	local normal = nil
	if math.abs(x) > limit then
		x = math.sign(x) * limit
		if direction.X * x > 0 then
			normal = Vector2.new(-math.sign(x), 0)
		end
	end
	if math.abs(y) > limit then
		y = math.sign(y) * limit
		if direction.Y * y > 0 then
			normal = Vector2.new(0, -math.sign(y))
		end
	end
	position = Vector2.new(x, y)
	if not normal then
		return position, direction, nil
	end
	return position, reflect(direction, normal, position), { point = position, normal = normal }
end

-- Moves a ball `distance` along `direction`, bouncing off the walls on the way. Returns the new
-- position and direction, and each wall it hit.
function Bounce.move(position: Vector2, direction: Vector2, distance: number, limit: number): (Vector2, Vector2, { Hit })
	local hits = {}
	local remaining = distance
	for _ = 1, MAX_BOUNCES_PER_MOVE do
		-- How far until it reaches each wall it's heading toward.
		local nearest, normal = math.huge, nil
		if direction.X > 1e-6 then
			nearest, normal = (limit - position.X) / direction.X, Vector2.new(-1, 0)
		elseif direction.X < -1e-6 then
			nearest, normal = (-limit - position.X) / direction.X, Vector2.new(1, 0)
		end
		local toY = math.huge
		if direction.Y > 1e-6 then
			toY = (limit - position.Y) / direction.Y
		elseif direction.Y < -1e-6 then
			toY = (-limit - position.Y) / direction.Y
		end
		if toY < nearest then
			nearest, normal = toY, Vector2.new(0, -math.sign(direction.Y))
		end
		if not normal or remaining <= nearest then
			position += direction * remaining
			break
		end
		nearest = math.max(nearest, 0)
		position += direction * nearest
		remaining -= nearest
		direction = reflect(direction, normal, position)
		table.insert(hits, { point = position, normal = normal })
	end
	return position, direction, hits
end

return Bounce
