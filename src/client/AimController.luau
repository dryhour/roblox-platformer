local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AimMath = require(Shared:WaitForChild("AimMath"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local MyMatch = require(script.Parent.MyMatch)

-- Aiming your launch. A short dotted arrow shows which way your ball will go; point where you
-- want it to go, then lock it in (the HUD's Lock Aim button works for everyone):
--   mouse     move to aim, click to lock
--   touch     drag to aim (as often as you like), then Lock Aim
--   gamepad   left stick to aim, A to lock
--   keyboard  W/S or Up/Down to aim higher or lower, Space or Enter to lock
-- If time runs out first, the server uses wherever you were aiming.
local AimController = {}

local SEND_EVERY = 0.1
local KEY_TURN_SPEED = math.rad(120) -- radians per second
local STICK_DEADZONE = 0.4
local ARROW_LENGTH = Config.BALL_SIZE * 1.5 -- just a little way past the ball's edge
local DOT_SIZE = 0.45
local DOT_GAP = 0.9
local HEAD_LENGTH = 1.3
local HEAD_ANGLE = math.rad(35)
local AIMING_COLOR = Color3.fromRGB(255, 255, 255)
local LOCKED_COLOR = Color3.fromRGB(90, 230, 110)

local angle = 0 -- radians from your ball's forward
local locked = false
local dirty = false
local lastSentAt = 0
local stick = Vector2.zero
local lineFolder: Folder
local dots: { Part } = {}
local head: { Part } = {}

-- True once you've locked your aim this round.
function AimController.isLocked(): boolean
	return locked
end

-- Your ball's core, its forward, and the arena's facing (the axis aims turn around), while
-- you're aiming.
local function aiming(): (BasePart?, Vector3?, Vector3?)
	if MyMatch.phase() ~= "Aim" then
		return nil, nil, nil
	end
	local ball = MyMatch.myBall()
	local core = ball and ball.PrimaryPart
	local forward = ball and ball:GetAttribute("Forward")
	local axis = ball and ball:GetAttribute("Facing")
	if core and typeof(forward) == "Vector3" and typeof(axis) == "Vector3" then
		return core, forward, axis
	end
	return nil, nil, nil
end

local function aimAtWorld(point: Vector3)
	local core, forward, axis = aiming()
	if not core or not forward or not axis or locked then
		return
	end
	local toward = AimMath.flatten(point - core.Position, axis)
	if toward.Magnitude > 0.5 then
		angle = math.clamp(AimMath.angle(forward, toward.Unit, axis), -Config.AIM_ARC, Config.AIM_ARC)
		dirty = true
	end
end

-- Aims at the spot in the arena under a point on the screen (viewport coordinates).
local function aimAtScreen(point: Vector2)
	local core, _, axis = aiming()
	if not core or not axis then
		return
	end
	local ray = workspace.CurrentCamera:ViewportPointToRay(point.X, point.Y)
	local along = ray.Direction:Dot(axis)
	if math.abs(along) < 0.001 then
		return
	end
	local distance = (core.Position - ray.Origin):Dot(axis) / along
	if distance > 0 then
		aimAtWorld(ray.Origin + ray.Direction * distance)
	end
end

local function send()
	local _, forward, axis = aiming()
	if forward and axis then
		Remotes.Aim:FireServer(AimMath.rotate(forward, angle, axis), locked)
		lastSentAt = os.clock()
		dirty = false
	end
end

local function lock()
	if aiming() and not locked then
		locked = true
		send()
	end
end

-- Locks in your aim, e.g. from the Lock Aim button.
AimController.lock = lock

local function linePart(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Parent = lineFolder
	return part
end

-- A row of dots from the edge of the ball, ending in an arrowhead. Hides it for nil.
local function drawArrow(core: BasePart?, direction: Vector3?, axis: Vector3?)
	local count = 0
	local color = if locked then LOCKED_COLOR else AIMING_COLOR
	local tip: Vector3? = nil
	if core and direction and axis then
		local radius = core.Size.X / 2
		local start = core.Position + direction * (radius + 0.6)
		count = math.floor(ARROW_LENGTH / DOT_GAP)
		for index = 1, count do
			local dot = dots[index] or linePart()
			dots[index] = dot
			dot.Shape = Enum.PartType.Ball
			dot.Size = Vector3.one * DOT_SIZE
			dot.Position = start + direction * (index - 1) * DOT_GAP
			dot.Color = color
			dot.Transparency = 0
		end
		tip = start + direction * (count - 1) * DOT_GAP + direction * HEAD_LENGTH
	end
	for index = count + 1, #dots do
		dots[index].Transparency = 1
	end
	for index, sign in { 1, -1 } do
		local arm = head[index] or linePart()
		head[index] = arm
		if tip and direction and axis then
			local back = tip - AimMath.rotate(direction, sign * HEAD_ANGLE, axis) * HEAD_LENGTH
			arm.Size = Vector3.new(DOT_SIZE, DOT_SIZE, HEAD_LENGTH + DOT_SIZE)
			arm.CFrame = CFrame.lookAt((tip + back) / 2, tip, axis)
			arm.Color = color
			arm.Transparency = 0
		else
			arm.Transparency = 1
		end
	end
end

function AimController.start()
	lineFolder = Instance.new("Folder")
	lineFolder.Name = "AimLine"
	lineFolder.Parent = workspace

	local lastPhase = ""
	RunService.RenderStepped:Connect(function(deltaTime)
		local phase = MyMatch.phase()
		if phase ~= lastPhase then
			lastPhase = phase
			if phase == "Aim" then
				angle, locked, dirty = 0, false, true
			end
		end

		local core, forward, axis = aiming()
		if not core or not forward or not axis then
			drawArrow(nil, nil, nil)
			return
		end

		if not locked then
			local lastInput = UserInputService:GetLastInputType()
			if lastInput == Enum.UserInputType.MouseMovement then
				aimAtScreen(UserInputService:GetMouseLocation())
			end
			if stick.Magnitude > STICK_DEADZONE then
				local camera = workspace.CurrentCamera.CFrame
				local right = AimMath.flatten(camera.RightVector, axis)
				local up = AimMath.flatten(camera.UpVector, axis)
				aimAtWorld(core.Position + right * stick.X + up * stick.Y)
			end
			local turn = 0
			if not UserInputService:GetFocusedTextBox() then
				if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
					turn += 1
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
					turn -= 1
				end
			end
			if turn ~= 0 then
				-- Turning one way raises a ball heading right but lowers one heading left.
				if axis:Cross(forward).Y < 0 then
					turn = -turn
				end
				angle = math.clamp(angle + turn * KEY_TURN_SPEED * deltaTime, -Config.AIM_ARC, Config.AIM_ARC)
				dirty = true
			end
			if dirty and os.clock() - lastSentAt >= SEND_EVERY then
				send()
			end
		end

		drawArrow(core, AimMath.rotate(forward, angle, axis), axis)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	local touchAiming: { [InputObject]: boolean } = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 then
			aimAtScreen(UserInputService:GetMouseLocation())
			lock()
		elseif kind == Enum.UserInputType.Touch then
			if aiming() then
				touchAiming[input] = true
				aimAtScreen(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset())
			end
		elseif
			input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Return
		then
			lock()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if touchAiming[input] then
			aimAtScreen(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset())
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		touchAiming[input] = nil
	end)
end

return AimController
