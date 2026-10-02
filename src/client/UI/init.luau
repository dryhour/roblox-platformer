local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hud = require(script.Hud)
local Lobby = require(script.Lobby)
local Results = require(script.Results)

-- All the on-screen UI. Each screen has refresh(), run when match or player attributes change,
-- and tick(), run every frame for countdowns.
local UI = {}

-- Screens shorter than this (in pixels) shrink the whole UI to fit, e.g. phones in landscape.
local DESIGN_HEIGHT = 540

type Screen = { refresh: () -> (), tick: () -> () }

function UI.start()
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild("MatchState")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PartyUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local camera = workspace.CurrentCamera
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function fit()
		scale.Scale = math.min(1, camera.ViewportSize.Y / DESIGN_HEIGHT)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	local screens: { Screen } = { Lobby.new(gui), Hud.new(gui), Results.new(gui) }

	-- Many attributes can change in one frame; refresh once, after all of them.
	local queued = false
	local function refresh()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			for _, screen in screens do
				screen.refresh()
			end
		end)
	end

	local function watch(other: Player)
		other.AttributeChanged:Connect(refresh)
		refresh()
	end
	state.AttributeChanged:Connect(refresh)
	Players.PlayerAdded:Connect(watch)
	-- ChildRemoved fires after the player is gone from GetPlayers(); PlayerRemoving fires before.
	Players.ChildRemoved:Connect(refresh)
	for _, other in Players:GetPlayers() do
		watch(other)
	end

	RunService.RenderStepped:Connect(function()
		for _, screen in screens do
			screen.tick()
		end
	end)
end

return UI
