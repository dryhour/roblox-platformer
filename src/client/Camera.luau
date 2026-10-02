local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Side-on camera. It copies the current map's CameraPart; if the part has a Follow attribute,
-- it instead slides sideways (and up) to keep the local character in view.
local Camera = {}

-- A narrow field of view from far away flattens the perspective so the map reads as 2D.
local FIELD_OF_VIEW = 30
-- How quickly a following camera catches up with the character. Higher is snappier.
local FOLLOW_SHARPNESS = 6
-- How far above the character a following camera aims, unless the part sets OffsetY.
local DEFAULT_OFFSET_Y = 6

function Camera.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local followPart: BasePart? = nil
	local followPosition = Vector3.zero

	-- The default camera scripts reset CameraType when the character respawns, so it's
	-- reapplied every frame.
	RunService:BindToRenderStep("Camera2D", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FIELD_OF_VIEW

		local map = workspace:FindFirstChild("Map")
		local cameraPart = map and map:FindFirstChild("CameraPart")
		if not cameraPart or not cameraPart:IsA("BasePart") then
			return
		end
		if not cameraPart:GetAttribute("Follow") then
			camera.CFrame = cameraPart.CFrame
			return
		end

		-- Follow: keep the part's distance and angle, move it to track the character within
		-- MinX..MaxX, and never lower than the part itself or higher than MaxY.
		local base = cameraPart.Position
		local isNewMap = followPart ~= cameraPart
		local target = if isNewMap then base else followPosition
		local root = player.Character and player.Character.PrimaryPart
		if root then
			local x = math.clamp(
				root.Position.X,
				cameraPart:GetAttribute("MinX") or -math.huge,
				cameraPart:GetAttribute("MaxX") or math.huge
			)
			local y = math.clamp(
				root.Position.Y + (cameraPart:GetAttribute("OffsetY") or DEFAULT_OFFSET_Y),
				base.Y,
				cameraPart:GetAttribute("MaxY") or math.huge
			)
			target = Vector3.new(x, y, base.Z)
		end

		if isNewMap then
			followPart = cameraPart
			followPosition = target
		else
			followPosition = followPosition:Lerp(target, 1 - math.exp(-FOLLOW_SHARPNESS * deltaTime))
		end
		camera.CFrame = cameraPart.CFrame.Rotation + followPosition
	end)
end

return Camera
