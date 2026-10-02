local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AimMath = require(Shared:WaitForChild("AimMath"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local MyMatch = require(script.Parent.MyMatch)

-- Aiming your launch. A line shows where your ball will go, bouncing off the walls of the
-- upright arena; point at where you want it to go, then lock it in:
--   mouse     move to aim, click to lock
--   touch     drag to aim, let go to lock
--   gamepad   left stick to aim, A to lock
--   keyboard  W/S or Up/Down to aim higher or lower, Space or Enter to lock
-- If time runs out first, the server uses wherever you were aiming.
local AimController = {}

local SEND_EVERY = 0.1
local KEY_TURN_SPEED = math.rad(120) -- radians per second
local STICK_DEADZONE = 0.4
local LINE_BOUNCES = 3
local LINE_LENGTH = Config.ARENA_SIZE * 2.5
local LINE_THICKNESS = 0.3
local AIMING_COLOR = Color3.fromRGB(255, 255, 255)
local LOCKED_COLOR = Color3.fromRGB(90, 230, 110)

local angle = 0 -- radians from your ball's forward
local locked = false
local dirty = false
local lastSentAt = 0
local stick = Vector2.zero
local lineFolder: Folder
local lineParts: { Part } = {}

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

local function drawLine(points: { Vector3 }?)
	local count = if points then #points - 1 else 0
	for index = 1, math.max(count, #lineParts) do
		local part = lineParts[index]
		if index > count then
			if part then
				part.Transparency = 1
			end
			continue
		end
		if not part then
			part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Parent = lineFolder
			lineParts[index] = part
		end
		local from, to = (points :: { Vector3 })[index], (points :: { Vector3 })[index + 1]
		local length = (to - from).Magnitude
		part.Size = Vector3.new(LINE_THICKNESS, LINE_THICKNESS, math.max(length, 0.1))
		part.CFrame = CFrame.lookAt((from + to) / 2, to + Vector3.new(0, 0.001, 0))
		part.Color = if locked then LOCKED_COLOR else AIMING_COLOR
		-- Later bounces fade, so the first leg reads clearly.
		part.Transparency = 0.1 + 0.2 * (index - 1)
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
			drawLine(nil)
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

		local arena = MyMatch.arena()
		local walls = arena and arena:FindFirstChild("Walls")
		if walls then
			drawLine(AimMath.trace(core.Position, AimMath.rotate(forward, angle, axis), axis, walls, LINE_BOUNCES, LINE_LENGTH))
		end
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
		if touchAiming[input] then
			touchAiming[input] = nil
			lock()
		end
	end)
end

return AimController
