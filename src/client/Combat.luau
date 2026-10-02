local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Movement = require(script.Parent.Movement)

-- Beam Attack input. While you're the Attacker, clicking fires toward the mouse. F, a gamepad's
-- X or R2, or the touch button fire the way you're pushing, or else the way you're facing.
local Combat = {}

local ACTION = "FireBeam"

function Combat.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local state = ReplicatedStorage:WaitForChild("MatchState")
	local fireBeam = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireBeam") :: RemoteEvent
	local lastFireAt = -math.huge
	local bound = false

	local function aim(input: InputObject): Vector3?
		local root = player.Character and player.Character.PrimaryPart
		if not root then
			return nil
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Where the mouse ray crosses the Z = 0 play plane.
			local mouse = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			if math.abs(ray.Direction.Z) > 1e-3 then
				local point = ray.Origin + ray.Direction * (-ray.Origin.Z / ray.Direction.Z)
				local direction = Vector3.new(point.X - root.Position.X, point.Y - root.Position.Y, 0)
				if direction.Magnitude > 0.1 then
					return direction.Unit
				end
			end
		end
		local move = Movement.getMoveVector()
		local stick = Vector3.new(move.X, -move.Z, 0)
		if stick.Magnitude > 0.3 then
			return stick.Unit
		end
		return Vector3.new(if root.CFrame.LookVector.X < 0 then -1 else 1, 0, 0)
	end

	local function onFire(_: string, inputState: Enum.UserInputState, input: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if os.clock() - lastFireAt >= Config.BEAM_COOLDOWN then
			local direction = aim(input)
			if direction then
				lastFireAt = os.clock()
				fireBeam:FireServer(direction)
			end
		end
		return Enum.ContextActionResult.Sink
	end

	local function update()
		local shouldBind = player:GetAttribute("Role") == "Attacker" and state:GetAttribute("Phase") == "Playing"
		if shouldBind and not bound then
			ContextActionService:BindAction(
				ACTION,
				onFire,
				true,
				Enum.UserInputType.MouseButton1,
				Enum.KeyCode.F,
				Enum.KeyCode.ButtonX,
				Enum.KeyCode.ButtonR2
			)
			ContextActionService:SetTitle(ACTION, "Beam")
		elseif bound and not shouldBind then
			ContextActionService:UnbindAction(ACTION)
		end
		bound = shouldBind
	end

	player:GetAttributeChangedSignal("Role"):Connect(update)
	state:GetAttributeChangedSignal("Phase"):Connect(update)
	update()
end

return Combat
