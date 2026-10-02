local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModeInfo = require(Shared:WaitForChild("ModeInfo"))
local Widgets = require(script.Parent.Widgets)

-- The lobby: on the left, who's here, color choice and the ready button; on the right, the
-- match settings, which only the host can change.
local Lobby = {}

local PANEL_WIDTH = 300

function Lobby.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild("MatchState")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local function isHost(): boolean
		return state:GetAttribute("HostUserId") == player.UserId
	end

	-- Left panel

	local roster = Widgets.panel({
		Name = "Roster",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		Parent = gui,
	})
	Widgets.label("PARTY PLATFORMER", 24, { LayoutOrder = 1, TextColor3 = Widgets.ACCENT, Parent = roster })
	local status = Widgets.label("", 15, {
		LayoutOrder = 2,
		Font = Widgets.FONT_REGULAR,
		TextColor3 = Widgets.MUTED,
		Parent = roster,
	})
	local playerRows = Widgets.stack({ LayoutOrder = 3, Parent = roster }, 4)
	Widgets.label("YOUR COLOR", 13, { LayoutOrder = 4, TextColor3 = Widgets.MUTED, Parent = roster })

	local swatchRow = Widgets.stack({
		LayoutOrder = 5,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = roster,
	}, 8, Enum.FillDirection.Horizontal)
	local swatchStrokes: { UIStroke } = {}
	local swatchButtons: { TextButton } = {}
	for index, color in Config.PLAYER_COLORS do
		local stroke = Widgets.create("UIStroke", {
			Thickness = 3,
			Color = Widgets.TEXT,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
		swatchStrokes[index] = stroke
		swatchButtons[index] = Widgets.button("", function()
			remotes.ChooseColor:FireServer(index)
		end, {
			LayoutOrder = index,
			BackgroundColor3 = color,
			Size = UDim2.fromOffset(34, 34),
			Parent = swatchRow,
		})
		stroke.Parent = swatchButtons[index]
	end

	local readyButton = Widgets.button("", function()
		remotes.SetReady:FireServer(not player:GetAttribute("Ready"))
	end, {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 48),
		TextSize = 22,
		Parent = roster,
	})

	-- Right panel

	local settings = Widgets.panel({
		Name = "Settings",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		Parent = gui,
	})
	Widgets.label("MATCH SETTINGS", 20, { LayoutOrder = 1, Parent = settings })
	local hostNote = Widgets.label("", 13, {
		LayoutOrder = 2,
		Font = Widgets.FONT_REGULAR,
		TextColor3 = Widgets.MUTED,
		Parent = settings,
	})

	local updaters: { (host: boolean) -> () } = {}
	local order = 2

	local function row(title: string): Frame
		order += 1
		local frame = Widgets.create("Frame", {
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = settings,
		})
		Widgets.label(title, 15, {
			Font = Widgets.FONT_REGULAR,
			Size = UDim2.new(0.55, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			Parent = frame,
		})
		return frame
	end

	local function stepper(title: string, name: string, format: (number) -> string)
		local setting = Config.Settings[name]
		local frame = row(title)
		local function change(direction: number)
			if isHost() then
				remotes.ChangeSetting:FireServer(name, (state:GetAttribute(name) or setting.default) + direction * setting.step)
			end
		end
		local minus = Widgets.button("-", function()
			change(-1)
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 0), Parent = frame })
		local value = Widgets.label("", 16, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -34, 0, 0),
			Size = UDim2.new(0, 60, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
		local plus = Widgets.button("+", function()
			change(1)
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = frame })
		table.insert(updaters, function(host)
			local current = state:GetAttribute(name) or setting.default
			value.Text = format(current)
			minus.Visible = host and current > setting.min
			plus.Visible = host and current < setting.max
		end)
	end

	-- A button showing the current value; the host clicks it to change it.
	local function choice(frame: Frame, width: number, onClick: () -> ()): TextButton
		return Widgets.button("", function()
			if isHost() then
				onClick()
			end
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(width, 30),
			TextSize = 14,
			Parent = frame,
		})
	end

	stepper("Games", "Games", tostring)
	stepper("Time per game", "GameTime", function(seconds)
		return `{seconds}s`
	end)
	stepper("Score multiplier", "Multiplier", function(multiplier)
		return `{multiplier}x`
	end)

	do
		local options = Config.RANDOMIZATION_OPTIONS
		local button = choice(row("Game order"), 126, function()
			local index = table.find(options, state:GetAttribute("Randomization")) or 1
			remotes.ChangeSetting:FireServer("Randomization", options[index % #options + 1])
		end)
		table.insert(updaters, function(host)
			button.Text = Config.RANDOMIZATION_LABELS[state:GetAttribute("Randomization")] or ""
			button.AutoButtonColor = host
		end)
	end

	order += 1
	Widgets.label("GAMES IN THE MIX", 13, { LayoutOrder = order, TextColor3 = Widgets.MUTED, Parent = settings })
	for _, info in ModeInfo.list do
		local attribute = "Mode_" .. info.id
		local minPlayers = if Config.TESTING then 1 else info.minPlayers
		local button = choice(row(`{info.name} ({minPlayers}+)`), 60, function()
			remotes.ChangeSetting:FireServer(attribute, not state:GetAttribute(attribute))
		end)
		table.insert(updaters, function(host)
			local enabled = state:GetAttribute(attribute) == true
			button.Text = if enabled then "ON" else "OFF"
			button.BackgroundColor3 = if enabled then Widgets.GOOD else Widgets.BUTTON
			button.AutoButtonColor = host
		end)
	end

	local function lobbyStatus(): string
		local left = (state:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			return `Starting in {math.ceil(left)}...`
		end
		local players = Players:GetPlayers()
		local needed = state:GetAttribute("MinPlayers") or Config.MIN_PLAYERS
		if #players < needed then
			return `Waiting for players ({#players}/{needed})`
		end
		local ready = 0
		for _, other in players do
			if other:GetAttribute("Ready") then
				ready += 1
			end
		end
		return `{ready}/{#players} ready. The match starts when everyone is.`
	end

	local function refresh()
		local visible = state:GetAttribute("Phase") == "Lobby"
		roster.Visible = visible
		settings.Visible = visible
		if not visible then
			return
		end

		local host = isHost()
		hostNote.Text = if host then "You're the host." else "Only the host can change these."
		for _, update in updaters do
			update(host)
		end

		Widgets.clear(playerRows)
		local hostId = state:GetAttribute("HostUserId")
		for index, other in Players:GetPlayers() do
			local color = Config.PLAYER_COLORS[other:GetAttribute("ColorIndex") or 1]
			local ready = other:GetAttribute("Ready") == true
			local frame = Widgets.create("Frame", {
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				Parent = playerRows,
			})
			Widgets.swatch(color, 14, { Position = UDim2.new(0, 0, 0.5, -7), Parent = frame })
			Widgets.label(other.DisplayName .. (if other.UserId == hostId then "  (host)" else ""), 16, {
				Position = UDim2.fromOffset(22, 0),
				Size = UDim2.new(1, -110, 1, 0),
				AutomaticSize = Enum.AutomaticSize.None,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = frame,
			})
			Widgets.label(if ready then "READY" else "NOT READY", 13, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 90, 1, 0),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if ready then Widgets.GOOD else Widgets.MUTED,
				Parent = frame,
			})
		end

		for index, button in swatchButtons do
			local owner = nil
			for _, other in Players:GetPlayers() do
				if other:GetAttribute("ColorIndex") == index then
					owner = other
				end
			end
			swatchStrokes[index].Enabled = owner == player
			button.BackgroundTransparency = if owner and owner ~= player then 0.75 else 0
		end

		local ready = player:GetAttribute("Ready") == true
		readyButton.Text = if ready then "READY! (CLICK TO UNDO)" else "READY UP"
		readyButton.TextSize = if ready then 16 else 22
		readyButton.BackgroundColor3 = if ready then Widgets.GOOD else Widgets.ACCENT
		readyButton.TextColor3 = Widgets.DARK_TEXT
	end

	local function tick()
		if roster.Visible then
			status.Text = lobbyStatus()
		end
	end

	return { refresh = refresh, tick = tick }
end

return Lobby
