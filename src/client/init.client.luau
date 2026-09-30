local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- A narrow field of view from far away flattens the perspective so the map reads as 2D.
local FIELD_OF_VIEW = 30

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local cameraPart = workspace:WaitForChild("Map"):WaitForChild("CameraPart") :: BasePart

-- Fixed camera: copy CameraPart every frame. The default camera scripts reset
-- CameraType when the character respawns, so it's reapplied here too.
RunService:BindToRenderStep("Camera2D", Enum.RenderPriority.Camera.Value + 1, function()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FIELD_OF_VIEW
	camera.CFrame = cameraPart.CFrame
end)

-- Movement: let the default controls read input (keyboard, gamepad, touch), then keep
-- only left/right. Runs right after the default controls so this Move call wins.
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local FACE_RIGHT = CFrame.lookAt(Vector3.zero, Vector3.xAxis)
local FACE_LEFT = CFrame.lookAt(Vector3.zero, -Vector3.xAxis)

-- Letting go of jump while still rising cuts the upward speed, so a tap is a short hop
-- and holding gives the full jump.
local JUMP_CUT_MULTIPLIER = 0.45
local jumpCut = false

local function isJumpHeld(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.Up)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

RunService:BindToRenderStep("Movement2D", Enum.RenderPriority.Input.Value + 1, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- The camera faces -Z, so screen-right is world +X.
	local moveVector = controls:GetMoveVector()
	humanoid:Move(Vector3.new(moveVector.X, 0, 0), false)

	-- Snap to face the last direction moved (the server creates the Facing constraint).
	local facing = character:FindFirstChild("Facing", true) :: AlignOrientation?
	if facing and moveVector.X > 0.1 then
		facing.CFrame = FACE_RIGHT
	elseif facing and moveVector.X < -0.1 then
		facing.CFrame = FACE_LEFT
	end

	-- W / Up arrow jump as well as Space.
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		humanoid.Jump = true
	end

	local root = character.PrimaryPart
	if not root then
		return
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		jumpCut = false
	elseif not jumpCut and not isJumpHeld() and root.AssemblyLinearVelocity.Y > 0 then
		jumpCut = true
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y * JUMP_CUT_MULTIPLIER, velocity.Z)
	end
end)
