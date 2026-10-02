local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MyMatch = require(script.Parent.MyMatch)
local Profile = require(script.Parent.Profile)

-- In the lobby, the normal Roblox camera follows your avatar. In a match, the camera glides to
-- face your arena head on, framing the box and both players floating beside it, and your
-- avatar's controls switch off (on touch screens that hides the thumbstick and jump button,
-- leaving the screen free for aiming). Big hits shake it.
local Camera = {}

local HALF_WIDTH = Config.ARENA_SIZE / 2 + 10 -- the box plus the players beside it
local HALF_HEIGHT = Config.ARENA_SIZE / 2 + 4
local LIFT = 2 -- look a little above the middle, leaving room for the HUD at the top
local FIELD_OF_VIEW = 50
local LOBBY_FIELD_OF_VIEW = 70
local SHARPNESS = 5

local trauma = 0 -- 0 to 1; shake strength is its square

-- Adds shake, e.g. 0.2 for a bump or 0.6 for a knockout, unless it's turned off in Settings.
function Camera.shake(amount: number)
	if Profile.setting("shake") then
		trauma = math.min(1, trauma + amount)
	end
end

-- Where the camera goes to see the whole arena on this screen.
local function arenaView(center: Vector3, facing: Vector3, viewport: Vector2): CFrame
	local tangent = math.tan(math.rad(FIELD_OF_VIEW / 2))
	local aspect = viewport.X / math.max(viewport.Y, 1)
	local distance = math.max(HALF_HEIGHT / tangent, HALF_WIDTH / (tangent * aspect))
	local target = center + Vector3.new(0, LIFT, 0)
	return CFrame.lookAt(target + facing * distance, target)
end

function Camera.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local inArena = false
	local view = CFrame.identity

	local controls = nil
	task.spawn(function()
		local ok, playerModule = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
		end)
		if ok then
			controls = playerModule:GetControls()
		end
	end)

	RunService:BindToRenderStep("ArenaCamera", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		local center, facing = MyMatch.frame()
		if not center or not facing then
			if inArena then
				inArena = false
				camera.CameraType = Enum.CameraType.Custom
				camera.FieldOfView = LOBBY_FIELD_OF_VIEW
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraSubject = humanoid
				end
				if controls then
					controls:Enable()
				end
			end
			return
		end

		if not inArena then
			inArena = true
			view = camera.CFrame
			if controls then
				controls:Disable()
			end
		end
		local goal = arenaView(center, facing, camera.ViewportSize)
		view = view:Lerp(goal, 1 - math.exp(-SHARPNESS * deltaTime))

		trauma = math.max(0, trauma - deltaTime * 1.5)
		local shake = trauma * trauma
		local t = os.clock() * 25
		local wobble = CFrame.Angles(
			math.noise(t, 1) * 0.03 * shake,
			math.noise(t, 2) * 0.03 * shake,
			math.noise(t, 3) * 0.02 * shake
		)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FIELD_OF_VIEW
		camera.CFrame = view * wobble
	end)
end

return Camera
