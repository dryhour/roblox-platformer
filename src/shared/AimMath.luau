local Config = require(script.Parent.Config)

-- Aiming math shared by the server (to check aims) and clients (to draw the aim line). Balls move
-- in the arena's upright plane; `axis` is that plane's normal (the arena's Facing attribute).
local AimMath = {}

-- `vector` with its part along `axis` removed, so it lies in the arena's plane.
function AimMath.flatten(vector: Vector3, axis: Vector3): Vector3
	return vector - axis * vector:Dot(axis)
end

-- The angle from `forward` to `direction`, turning around `axis`, in radians.
function AimMath.angle(forward: Vector3, direction: Vector3, axis: Vector3): number
	return math.atan2(forward:Cross(direction):Dot(axis), forward:Dot(direction))
end

-- `forward` turned `angle` radians around `axis`.
function AimMath.rotate(forward: Vector3, angle: number, axis: Vector3): Vector3
	return CFrame.fromAxisAngle(axis, angle):VectorToWorldSpace(forward)
end

-- Turns any value into a unit direction in the arena's plane within Config.AIM_ARC of `forward`.
function AimMath.clamp(direction: unknown, forward: Vector3, axis: Vector3): Vector3
	if typeof(direction) ~= "Vector3" then
		return forward
	end
	local aim = AimMath.flatten(direction, axis)
	if not (aim.Magnitude > 0.001 and aim.Magnitude < math.huge) then
		return forward
	end
	local angle = math.clamp(AimMath.angle(forward, aim.Unit, axis), -Config.AIM_ARC, Config.AIM_ARC)
	return AimMath.rotate(forward, angle, axis)
end

-- How far `point` is from the segment between `a` and `b`.
function AimMath.distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local segment = b - a
	local t = math.clamp((point - a):Dot(segment) / math.max(segment:Dot(segment), 0.001), 0, 1)
	return (a + segment * t - point).Magnitude
end

-- The points a ball launched from `origin` along `direction` passes through as it bounces off
-- `walls`, up to `bounces` bounces or `length` studs in total.
function AimMath.trace(
	origin: Vector3,
	direction: Vector3,
	axis: Vector3,
	walls: Instance,
	bounces: number,
	length: number
): { Vector3 }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { walls }
	local radius = Config.BALL_SIZE / 2

	local points = { origin }
	local position, heading, left = origin, direction, length
	for _ = 0, bounces do
		local hit = workspace:Raycast(position, heading * left, params)
		if not hit then
			table.insert(points, position + heading * left)
			break
		end
		-- Stop where the ball's surface, not its center, meets the wall.
		local travel = math.max(hit.Distance - radius, 0)
		position += heading * travel
		left -= travel
		table.insert(points, position)
		local normal = AimMath.flatten(hit.Normal, axis)
		if left <= 0 or normal.Magnitude < 0.01 then
			break
		end
		normal = normal.Unit
		heading = heading - 2 * heading:Dot(normal) * normal
	end
	return points
end

return AimMath
