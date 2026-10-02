local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hud = require(script.Hud)

-- The on-screen UI. There's very little of it on purpose (see CLAUDE.md).
local UI = {}

-- Screens shorter than this (in pixels) shrink the UI to fit, e.g. phones in landscape.
local DESIGN_HEIGHT = 540

function UI.start()
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild("MatchState")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotUI"
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

	local hud = Hud.new(gui)
	state.AttributeChanged:Connect(hud.refresh)
	hud.refresh()
	RunService.RenderStepped:Connect(hud.tick)
end

return UI
