local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Input = require(script.Parent.Input)
local Sounds = require(script.Parent.Sounds)

-- Drives the local player's ball. The player's client simulates their own ball (the server
-- gives it network ownership), so all of this responds instantly:
--   * rolling: a force toward where the player steers, relative to the camera, up to the
--     class's top speed, which grows the longer you roll straight (momentum)
--   * jump, boost, brake, and the Slam ability's dive
--   * knockback the server sends after collisions, bumpers and slams
local BallController = {}

local player = Players.LocalPlayer
local balls = workspace:WaitForChild("Balls")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local momentum = 0 -- 0 to 1
local boostMeter = 100
local force: VectorForce? = nil
local forceCore: BasePart? = nil

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.FilterDescendantsInstances = { balls }

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- The local player's ball, if they have one right now.
function BallController.myBall(): Model?
	for _, model in balls:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("UserId") == player.UserId then
			return model
		end
	end
	return nil
end

-- 0 to 100. Each boost costs Config.BOOST_COST.
function BallController.boostMeter(): number
	return boostMeter
end

local function myCore(): BasePart?
	local ball = BallController.myBall()
	local core = ball and ball.PrimaryPart
	if core and not core.Anchored then
		return core
	end
	return nil
end

local function onGround(core: BasePart): boolean
	return workspace:Raycast(core.Position, Vector3.new(0, -(Config.BALL_SIZE / 2 + 0.8), 0), groundParams) ~= nil
end

-- Where the player is steering, in world space. The camera never turns, but this keeps "up the
-- screen" correct if it ever does.
local function wishDirection(): Vector3
	local move = Input.move()
	local camera = workspace.CurrentCamera.CFrame
	local forward = flat(camera.LookVector)
	local right = flat(camera.RightVector)
	if forward.Magnitude < 0.001 or right.Magnitude < 0.001 then
		return Vector3.new(move.X, 0, -move.Y)
	end
	return right.Unit * move.X + forward.Unit * move.Y
end

local function controlForce(core: BasePart): VectorForce
	if force and forceCore == core and force.Parent then
		return force
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Control"
	attachment.Parent = core
	local newForce = Instance.new("VectorForce")
	newForce.Attachment0 = attachment
	newForce.RelativeTo = Enum.ActuatorRelativeTo.World
	newForce.ApplyAtCenterOfMass = true
	newForce.Force = Vector3.zero
	newForce.Parent = core
	force, forceCore = newForce, core
	momentum = 0
	return newForce
end

local function step(deltaTime: number)
	boostMeter = math.min(100, boostMeter + Config.BOOST_REGEN * deltaTime)

	local ball = BallController.myBall()
	local core = ball and ball.PrimaryPart
	if not ball or not core then
		return
	end
	local push = controlForce(core)
	if core.Anchored then
		push.Force = Vector3.zero
		momentum = 0
		return
	end

	local class = Brainrots.classOf(ball:GetAttribute("Brainrot"))
	local mass = core.AssemblyMass
	local wish = wishDirection()
	local velocity = flat(core.AssemblyLinearVelocity)
	local speed = velocity.Magnitude
	local heading = if speed > 1 then velocity.Unit else Vector3.zero
	local grounded = onGround(core)
	local steering = wish.Magnitude > 0.3

	-- Momentum builds while rolling fast and straight on the ground, and bleeds away on sharp
	-- turns or when you ease off.
	if grounded and steering and speed > class.topSpeed * 0.8 and heading:Dot(wish.Unit) > 0.9 then
		momentum += deltaTime / Config.MOMENTUM_BUILD_TIME
	elseif steering and speed > 10 and heading:Dot(wish.Unit) < 0.3 then
		momentum -= deltaTime * 1.5
	else
		momentum -= deltaTime * 0.5
	end
	momentum = math.clamp(momentum, 0, 1)
	local cap = class.topSpeed * (1 + Config.MOMENTUM_BONUS * momentum)

	local total = Vector3.zero
	if wish.Magnitude > 0.05 then
		local change = wish * cap - velocity
		-- Going faster than you could roll (after a boost or a hit): steer, but don't brake.
		if speed > cap then
			local along = change:Dot(heading)
			if along < 0 then
				change -= heading * along
			end
		end
		local accel = class.accel * (if grounded then 1 else Config.AIR_CONTROL)
		if change.Magnitude > 0.01 then
			total += change.Unit * math.min(accel, change.Magnitude * 10) * mass
		end
	elseif grounded then
		total -= velocity * Config.IDLE_DAMPING * mass
	end
	if grounded and Input.brakeHeld() then
		total -= velocity * Config.BRAKE_STRENGTH * mass
		momentum = 0
	end
	push.Force = total
end

local function jump()
	local core = myCore()
	if not core or not onGround(core) then
		return
	end
	local velocity = core.AssemblyLinearVelocity
	core.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, 0) + Config.JUMP_SPEED, velocity.Z)
	Sounds.play("Jump")
end

local function boost()
	local core = myCore()
	if not core or boostMeter < Config.BOOST_COST then
		return
	end
	local direction = wishDirection()
	if direction.Magnitude < 0.3 then
		direction = flat(core.AssemblyLinearVelocity)
	end
	if direction.Magnitude < 0.3 then
		direction = flat(workspace.CurrentCamera.CFrame.LookVector)
	end
	boostMeter -= Config.BOOST_COST
	core.AssemblyLinearVelocity += direction.Unit * Config.BOOST_SPEED
	remotes.Boost:FireServer()
	Sounds.play("Boost")
end

local function ability()
	local core = myCore()
	if not core or workspace:GetServerTimeNow() < (player:GetAttribute("AbilityReadyAt") or 0) then
		return
	end
	remotes.Ability:FireServer()
	-- In the air, dive into the ground first; the server waits for the landing to slam.
	if not onGround(core) then
		local velocity = core.AssemblyLinearVelocity
		core.AssemblyLinearVelocity = Vector3.new(velocity.X, -Config.SLAM_DIVE_SPEED, velocity.Z)
	end
end

function BallController.start()
	RunService.PreSimulation:Connect(step)
	Input.onAction("Jump", jump)
	Input.onAction("Boost", boost)
	Input.onAction("Ability", ability)

	remotes.Knockback.OnClientEvent:Connect(function(change: Vector3)
		local core = myCore()
		if core then
			core.AssemblyLinearVelocity += change
			momentum = 0
		end
	end)
end

return BallController
