local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Draft = require(script.Draft)
local Gifts = require(script.Gifts)
local Hud = require(script.Hud)
local Inventory = require(script.Inventory)
local LobbyHud = require(script.LobbyHud)
local ProfileWindow = require(script.ProfileWindow)
local RewardPopups = require(script.RewardPopups)
local Settings = require(script.Settings)
local Stickers = require(script.Stickers)
local Store = require(script.Store)
local Toast = require(script.Toast)
local Trade = require(script.Trade)
local Widgets = require(script.Widgets)
local Windows = require(script.Windows)

-- All the on-screen UI: the lobby HUD and its windows, the waiting and match HUD, the draft,
-- stickers, trading, and reward popups.
local UI = {}

-- The UI is laid out for a screen this tall (in pixels) and scales to fit others.
local DESIGN_HEIGHT = 760
local MIN_SCALE = 0.45
local MAX_SCALE = 1.3
local REFRESH_EVERY = 0.1

function UI.start()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "GameUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local camera = workspace.CurrentCamera
	local function fit()
		Widgets.setFitScale(math.clamp(camera.ViewportSize.Y / DESIGN_HEIGHT, MIN_SCALE, MAX_SCALE))
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	-- Later screens draw on top of earlier ones.
	local screens = {
		LobbyHud.new(gui),
		Hud.new(gui),
		Stickers.new(gui),
		Draft.new(gui),
		Store.new(gui),
		Inventory.new(gui),
		Gifts.new(gui),
		Settings.new(gui),
		ProfileWindow.new(gui),
		Trade.new(gui),
		RewardPopups.new(gui),
	}
	Toast.attach(gui)

	-- Prompts in the world can open windows, like the gumball machine opening the Store.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local window = prompt:GetAttribute("OpensWindow")
		if typeof(window) == "string" then
			Windows.open(window)
		end
	end)

	-- Match state lives on whichever arena you're in, so poll it rather than wiring up signals
	-- for every arena.
	local sinceRefresh = math.huge
	RunService.RenderStepped:Connect(function(deltaTime)
		sinceRefresh += deltaTime
		local refreshing = sinceRefresh >= REFRESH_EVERY
		if refreshing then
			sinceRefresh = 0
			-- Windows belong to the lobby; close any that's open when a match starts.
			local open = Windows.current()
			local matchId = player:GetAttribute("MatchId")
			if open and open ~= "Trade" and typeof(matchId) == "string" and matchId ~= "" then
				Windows.close()
			end
		end
		for _, screen in screens do
			if refreshing then
				screen.refresh()
			end
			screen.tick()
		end
	end)
end

return UI
