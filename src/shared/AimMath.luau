local Config = require(script.Parent.Config)

-- Aiming math shared by the server (to check aims) and clients (to draw the aim line).
local AimMath = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- The angle from `forward` to `direction` around the vertical axis, in radians.
function AimMath.angle(forward: Vector3, direction: Vector3): number
	return math.atan2(forward:Cross(direction).Y, forward:Dot(direction))
end

-- `forward` turned `angle` radians around the vertical axis.
function AimMath.rotate(forward: Vector3, angle: number): Vector3
	return CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(forward)
end

-- Turns any value into a flat unit direction within Config.AIM_ARC of `forward`.
function AimMath.clamp(direction: unknown, forward: Vector3): Vector3
	if typeof(direction) ~= "Vector3" then
		return forward
	end
	local aim = flat(direction)
	if not (aim.Magnitude > 0.001 and aim.Magnitude < math.huge) then
		return forward
	end
	local angle = math.clamp(AimMath.angle(forward, aim.Unit), -Config.AIM_ARC, Config.AIM_ARC)
	return AimMath.rotate(forward, angle)
end

-- The points a ball launched from `origin` along `direction` passes through as it bounces off
-- `walls`, up to `bounces` bounces or `length` studs in total.
function AimMath.trace(origin: Vector3, direction: Vector3, walls: Instance, bounces: number, length: number): { Vector3 }
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
		local normal = flat(hit.Normal)
		if left <= 0 or normal.Magnitude < 0.01 then
			break
		end
		normal = normal.Unit
		heading = heading - 2 * heading:Dot(normal) * normal
	end
	return points
end

return AimMath
