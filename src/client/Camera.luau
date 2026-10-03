local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MyMatch = require(script.Parent.MyMatch)
local Profile = require(script.Parent.Profile)

-- In the lobby, the normal Roblox camera follows your avatar. Once you join a station (and
-- through the match), the camera glides over 0.8 seconds to face your arena dead on, framing
-- the box and both players beside it. A narrow field of view keeps it nearly flat, so the
-- box's side walls don't show; the box sits a little high, leaving room for buttons below. When
-- a round is won, the camera slides a little toward the losing player, following the finisher's
-- energy as it flies at them, and zooms in slightly; at the end of the match it leans toward
-- the winner the same way. Your avatar's
-- controls switch off meanwhile (on touch screens that hides the thumbstick and jump button,
-- leaving the screen free for aiming). Big hits shake it side to side.
local Camera = {}

local BOX_HALF = Config.ARENA_SIZE / 2 + 2 -- to the outside of the box's frame
local HALF_WIDTH = BOX_HALF + 8 -- the box plus the players beside it
local HALF_HEIGHT = BOX_HALF + 5.5
local LIFT = -1.5 -- look a little below the middle, so the box sits high and buttons fit below
local FIELD_OF_VIEW = 25
local LOBBY_FIELD_OF_VIEW = 70
local GLIDE = 0.8 -- seconds, easing out
local LEAN = 0.45 -- how far toward a player the camera slides, as a share of the way
local MAX_LEAN = 7 -- studs
local LEAN_ZOOM = 0.85 -- how much closer it comes while leaning
local SHAKE = 0.9 -- studs at full strength

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

local following: Vector3? = nil

-- Something the camera should lean toward while it leans (the finisher's flying energy), or nil.
function Camera.follow(point: Vector3?)
	following = point
end

-- The arena view, slid sideways toward `point` and brought a little closer.
local function lean(view: CFrame, center: Vector3, point: Vector3): CFrame
	local across = math.clamp((point - center):Dot(view.RightVector) * LEAN, -MAX_LEAN, MAX_LEAN)
	local distance = (view.Position - center).Magnitude
	return view + view.RightVector * across + view.LookVector * distance * (1 - LEAN_ZOOM)
end

-- What the camera should show: "arena", or the arena leaning toward one side (the loser during
-- the finisher, the winner when the match is over). Returns its name and where to be.
local function shotFor(center: Vector3, facing: Vector3, viewport: Vector2): (string, CFrame)
	local state = MyMatch.state()
	local phase = MyMatch.phase()
	local focus: string? = nil
	if state then
		local roundWinner = state:GetAttribute("RoundWinner")
		local matchWinner = state:GetAttribute("MatchWinnerSide")
		if (phase == "Finish" or phase == "Resolve") and (roundWinner == "Left" or roundWinner == "Right") then
			focus = if roundWinner == "Left" then "Right" else "Left"
		elseif phase == "Over" and (matchWinner == "Left" or matchWinner == "Right") then
			focus = matchWinner
		end
	end
	local view = arenaView(center, facing, viewport)
	local chest = if state and focus then state:GetAttribute(`{focus}Avatar`) else nil
	if focus and typeof(chest) == "Vector3" then
		-- Follows the energy while it flies, then rests on the player.
		local point = if following and phase == "Finish" then following else chest
		return `lean{focus}`, lean(view, center, point)
	end
	return "arena", view
end

function Camera.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local inArena = false
	local shot = "" -- the shot being shown
	local from = CFrame.identity -- where the glide to it started
	local fromFieldOfView = LOBBY_FIELD_OF_VIEW
	local glideStart = 0

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
			shot = ""
			if controls then
				controls:Disable()
			end
		end
		local name, goal = shotFor(center, facing, camera.ViewportSize)
		if name ~= shot then
			-- A new shot: glide there from wherever the camera is now.
			shot = name
			from = camera.CFrame
			fromFieldOfView = camera.FieldOfView
			glideStart = os.clock()
		end
		local t = math.clamp((os.clock() - glideStart) / GLIDE, 0, 1)
		local eased = 1 - (1 - t) ^ 3
		local view = from:Lerp(goal, eased)
		camera.FieldOfView = fromFieldOfView + (FIELD_OF_VIEW - fromFieldOfView) * eased

		-- Shake: quick random nudges up, down and sideways that die away fast.
		trauma = math.max(0, trauma - deltaTime * 2.5)
		local shake = trauma * trauma * SHAKE
		local noise = os.clock() * 30
		local nudge = view.RightVector * math.noise(noise, 1) * shake + view.UpVector * math.noise(noise, 2) * shake
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = view + nudge
	end)
end

return Camera
