local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MyMatch = require(script.Parent.MyMatch)

-- In the lobby, the normal Roblox camera follows your avatar. In a match, the camera looks down
-- into your arena: it frames the arena while drafting and aiming, then follows the midpoint of
-- the two balls, pulling back as they spread apart. Big hits shake it.
local Camera = {}

local DIRECTION = Vector3.new(0, 1, 0.5).Unit -- from what it looks at, toward the camera
local MIN_DISTANCE = 72
local SPREAD = 1.3 -- distance per stud between the balls
local SHARPNESS = 5
local FIELD_OF_VIEW = 70

local trauma = 0 -- 0 to 1; shake strength is its square

-- Adds shake, e.g. 0.2 for a bump or 0.6 for a knockout.
function Camera.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

function Camera.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local inArena = false
	local focus = Vector3.zero
	local distance = MIN_DISTANCE

	RunService:BindToRenderStep("ArenaCamera", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		local arena = MyMatch.arena()
		local center = arena and arena:GetAttribute("Center")
		if not arena or typeof(center) ~= "Vector3" then
			if inArena then
				inArena = false
				camera.CameraType = Enum.CameraType.Custom
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraSubject = humanoid
				end
			end
			return
		end

		local goalFocus, spread = center, 0
		local phase = MyMatch.phase()
		if phase == "Battle" or phase == "Resolve" then
			local positions = {}
			for _, ball in MyMatch.balls() do
				if ball.PrimaryPart then
					table.insert(positions, ball.PrimaryPart.Position)
				end
			end
			if #positions > 0 then
				local sum = Vector3.zero
				for _, position in positions do
					sum += position
				end
				goalFocus = Vector3.new(sum.X / #positions, center.Y, sum.Z / #positions)
				if #positions >= 2 then
					spread = (positions[1] - positions[2]).Magnitude
				end
			end
		end

		local alpha = 1 - math.exp(-SHARPNESS * deltaTime)
		if not inArena then
			inArena = true
			focus, distance = goalFocus, MIN_DISTANCE
		else
			focus = focus:Lerp(goalFocus, alpha)
			distance += (math.max(MIN_DISTANCE, spread * SPREAD) - distance) * alpha
		end

		trauma = math.max(0, trauma - deltaTime * 1.5)
		local shake = trauma * trauma
		local t = os.clock() * 25
		local wobble = CFrame.Angles(
			math.noise(t, 1) * 0.04 * shake,
			math.noise(t, 2) * 0.04 * shake,
			math.noise(t, 3) * 0.03 * shake
		)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FIELD_OF_VIEW
		camera.CFrame = CFrame.lookAt(focus + DIRECTION * distance, focus) * wobble
	end)
end

return Camera
