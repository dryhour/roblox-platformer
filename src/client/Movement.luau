local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- The local character's movement: left/right only, facing, variable jump height and dashing,
-- plus the launches and speed boosts that map pads trigger.
local Movement = {}

local FACE_RIGHT = CFrame.lookAt(Vector3.zero, Vector3.xAxis)
local FACE_LEFT = CFrame.lookAt(Vector3.zero, -Vector3.xAxis)

-- Letting go of jump while still rising cuts the upward speed, so a tap is a short hop
-- and holding gives the full jump.
local JUMP_CUT_MULTIPLIER = 0.45

-- Dash: a short burst of sideways speed, toward where you're pushing or else where you face.
local DASH_SPEED = 85
local DASH_TIME = 0.14
local DASH_COOLDOWN = 0.9

local player = Players.LocalPlayer
local controls = nil
local jumpCut = false
local launchedAt = -math.huge
local lastDashAt = -math.huge
local boostToken = 0

local function livingCharacter(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character.PrimaryPart
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root
	end
	return nil, nil
end

local function isJumpHeld(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.Up)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

-- The stick or keys' direction from the default controls: X is right, -Z is up.
function Movement.getMoveVector(): Vector3
	return if controls then controls:GetMoveVector() else Vector3.zero
end

-- Throws the character upward at `power` studs per second.
function Movement.launch(power: number)
	local humanoid, root = livingCharacter()
	if not humanoid or not root then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, power, 0)
	-- A launch isn't a jump, so letting go of jump shouldn't cut it short.
	jumpCut = true
	launchedAt = os.clock()
end

-- Sets walk speed to `speed` for `duration` seconds.
function Movement.boost(speed: number, duration: number)
	local humanoid = livingCharacter()
	if not humanoid then
		return
	end
	local baseSpeed = humanoid:GetAttribute("BaseWalkSpeed")
	if not baseSpeed then
		baseSpeed = humanoid.WalkSpeed
		humanoid:SetAttribute("BaseWalkSpeed", baseSpeed)
	end
	humanoid.WalkSpeed = speed
	boostToken += 1
	local token = boostToken
	task.delay(duration, function()
		if token == boostToken and humanoid.Parent then
			humanoid.WalkSpeed = baseSpeed
		end
	end)
end

local function dash()
	local humanoid, root = livingCharacter()
	local attachment = root and root:FindFirstChild("Attachment2D")
	if not humanoid or not root or not attachment or root.Anchored then
		return
	end
	if os.clock() - lastDashAt < DASH_COOLDOWN then
		return
	end
	lastDashAt = os.clock()

	local moveX = Movement.getMoveVector().X
	local direction = if math.abs(moveX) > 0.1 then math.sign(moveX) elseif root.CFrame.LookVector.X < 0 then -1 else 1

	local push = Instance.new("LinearVelocity")
	push.Name = "Dash"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	push.LineDirection = Vector3.xAxis
	push.LineVelocity = direction * DASH_SPEED
	push.MaxForce = 1e6
	push.Parent = root
	task.delay(DASH_TIME, function()
		push:Destroy()
	end)
end

function Movement.start()
	-- Let the default controls read input (keyboard, gamepad, touch), then keep only left/right.
	controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

	-- Runs right after the default controls so this Move call wins.
	RunService:BindToRenderStep("Movement2D", Enum.RenderPriority.Input.Value + 1, function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then
			return
		end

		-- The camera faces -Z, so screen-right is world +X.
		local moveVector = Movement.getMoveVector()
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
			-- Right after a launch the character can still be touching the pad.
			if os.clock() - launchedAt > 0.25 then
				jumpCut = false
			end
		elseif not jumpCut and not isJumpHeld() and root.AssemblyLinearVelocity.Y > 0 then
			jumpCut = true
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y * JUMP_CUT_MULTIPLIER, velocity.Z)
		end
	end)

	ContextActionService:BindAction("Dash", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			dash()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("Dash", "Dash")
end

return Movement
