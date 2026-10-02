local RunService = game:GetService("RunService")

local BallController = require(script.Parent.BallController)

-- A fixed-angle camera above and behind your ball, so up on the screen is always forward and
-- nobody has to learn camera controls. It widens as you speed up and shakes on big hits.
-- Without a ball (knocked out, or joined mid-round) it follows someone still playing.
local Camera = {}

local OFFSET = Vector3.new(0, 48, 40)
local FOLLOW_SHARPNESS = 10
local FOV_REST = 60
local FOV_FAST = 78
local FAST_SPEED = 90
local SNAP_DISTANCE = 150 -- farther than this (a teleport), cut instead of gliding

local trauma = 0 -- 0 to 1; shake strength is its square

-- Adds shake, e.g. 0.2 for a bump or 0.6 for a big slam.
function Camera.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

local function target(): BasePart?
	local mine = BallController.myBall()
	if mine and mine.PrimaryPart then
		return mine.PrimaryPart
	end
	for _, model in workspace:WaitForChild("Balls"):GetChildren() do
		if model:IsA("Model") and model.PrimaryPart then
			return model.PrimaryPart
		end
	end
	return nil
end

function Camera.start()
	local camera = workspace.CurrentCamera
	local focus = Vector3.zero
	local fov = FOV_REST

	RunService:BindToRenderStep("BallCamera", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		camera.CameraType = Enum.CameraType.Scriptable

		local core = target()
		local speed = 0
		if core then
			local goal = core.Position
			if (goal - focus).Magnitude > SNAP_DISTANCE then
				focus = goal
			else
				focus = focus:Lerp(goal, 1 - math.exp(-FOLLOW_SHARPNESS * deltaTime))
			end
			local velocity = core.AssemblyLinearVelocity
			speed = Vector2.new(velocity.X, velocity.Z).Magnitude
		end

		local goalFov = FOV_REST + (FOV_FAST - FOV_REST) * math.clamp(speed / FAST_SPEED, 0, 1)
		fov += (goalFov - fov) * (1 - math.exp(-4 * deltaTime))
		camera.FieldOfView = fov

		trauma = math.max(0, trauma - deltaTime * 1.5)
		local shake = trauma * trauma
		local t = os.clock() * 25
		local wobble = CFrame.Angles(
			math.noise(t, 1) * 0.04 * shake,
			math.noise(t, 2) * 0.04 * shake,
			math.noise(t, 3) * 0.03 * shake
		)
		camera.CFrame = CFrame.lookAt(focus + OFFSET, focus) * wobble
	end)
end

return Camera
