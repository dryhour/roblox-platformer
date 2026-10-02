local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Draft = require(script.Draft)
local Hud = require(script.Hud)
local Widgets = require(script.Widgets)

-- The on-screen UI, shown only in matches and while waiting at a station. There's very little of
-- it on purpose (see CLAUDE.md).
local UI = {}

-- Screens shorter than this (in pixels) shrink the UI to fit, e.g. phones in landscape.
local DESIGN_HEIGHT = 600
local REFRESH_EVERY = 0.1

function UI.start()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "MatchUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local camera = workspace.CurrentCamera
	local function fit()
		Widgets.setFitScale(math.min(1, camera.ViewportSize.Y / DESIGN_HEIGHT))
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	local screens = { Hud.new(gui), Draft.new(gui) }
	-- Match state lives on whichever arena you're in, so poll it rather than wiring up signals
	-- for every arena.
	local sinceRefresh = math.huge
	RunService.RenderStepped:Connect(function(deltaTime)
		sinceRefresh += deltaTime
		for _, screen in screens do
			if sinceRefresh >= REFRESH_EVERY then
				screen.refresh()
			end
			screen.tick()
		end
		if sinceRefresh >= REFRESH_EVERY then
			sinceRefresh = 0
		end
	end)
end

return UI
