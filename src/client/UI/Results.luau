local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModeInfo = require(Shared:WaitForChild("ModeInfo"))
local Text = require(Shared:WaitForChild("Text"))
local Widgets = require(script.Parent.Widgets)

-- The scoreboard after each game and the winner screen at the end of the match.
local Results = {}

local CENTER = Enum.TextXAlignment.Center
local RIGHT = Enum.TextXAlignment.Right

local function score(player: Player): number
	return (player:GetAttribute("Score") :: number?) or 0
end

function Results.new(gui: ScreenGui)
	local localPlayer = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild("MatchState")

	local panel = Widgets.panel({
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 0),
		Parent = gui,
	})
	local heading = Widgets.label("", 30, { LayoutOrder = 1, TextColor3 = Widgets.ACCENT, TextXAlignment = CENTER, Parent = panel })
	local subheading = Widgets.label("", 16, { LayoutOrder = 2, TextColor3 = Widgets.MUTED, TextXAlignment = CENTER, Parent = panel })
	local rows = Widgets.stack({ LayoutOrder = 3, Parent = panel }, 4)
	local footer = Widgets.label("", 14, { LayoutOrder = 4, TextColor3 = Widgets.MUTED, TextXAlignment = CENTER, Parent = panel })

	local function addRow(order: number, place: number, player: Player, showGame: boolean)
		local frame = Widgets.create("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Widgets.TEXT,
			BackgroundTransparency = if player == localPlayer then 0.9 else 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = rows,
		}, {
			Widgets.corner(6),
			Widgets.create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		})
		local function cell(text: string, size: number, x: number, width: number, props: { [string]: any }?)
			local cellProps: { [string]: any } = {
				Position = UDim2.new(x, 0, 0, 0),
				Size = UDim2.new(width, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.None,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = frame,
			}
			if props then
				for key, value in props do
					cellProps[key] = value
				end
			end
			Widgets.label(text, size, cellProps)
		end

		local color = Config.PLAYER_COLORS[player:GetAttribute("ColorIndex") or 1]
		cell(Text.ordinal(place), 16, 0, 0.08, { TextColor3 = Widgets.MUTED })
		Widgets.swatch(color, 14, { Position = UDim2.new(0.08, 0, 0.5, -7), Parent = frame })
		cell(player.DisplayName, 16, 0.08, 0.34, { Position = UDim2.new(0.08, 22, 0, 0), Size = UDim2.new(0.34, -22, 1, 0) })
		if showGame then
			cell((player:GetAttribute("LastDetail") :: string?) or "", 13, 0.43, 0.33, { Font = Widgets.FONT_REGULAR, TextColor3 = Widgets.MUTED })
			cell(`+{player:GetAttribute("LastPoints") or 0}`, 16, 0.76, 0.11, { TextColor3 = Widgets.GOOD, TextXAlignment = RIGHT })
		end
		cell(tostring(score(player)), 18, 0.87, 0.13, { TextXAlignment = RIGHT })
	end

	local function refresh()
		local phase = state:GetAttribute("Phase")
		panel.Visible = phase == "Scoreboard" or phase == "Final"
		if not panel.Visible then
			return
		end

		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			return score(a) > score(b)
		end)

		if phase == "Final" then
			local winners = {}
			for _, player in players do
				if score(player) == score(players[1]) then
					table.insert(winners, player.DisplayName)
				end
			end
			heading.Text = if #winners == 1
				then `{winners[1]} wins!`
				elseif #winners > 1 then `{table.concat(winners, " & ")} tie!`
				else "Match over"
			subheading.Text = "Final standings"
		else
			local info = ModeInfo.byId[state:GetAttribute("ModeId") or ""]
			heading.Text = if info then `{info.name} results` else "Results"
			subheading.Text = `Game {state:GetAttribute("GameNumber") or 1} of {state:GetAttribute("GameCount") or 1}`
		end

		Widgets.clear(rows)
		for order, player in players do
			-- Tied players share a place.
			local place = 1
			for _, other in players do
				if score(other) > score(player) then
					place += 1
				end
			end
			addRow(order, place, player, phase == "Scoreboard")
		end
	end

	local function tick()
		if not panel.Visible then
			return
		end
		local left = math.max(0, math.ceil((state:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()))
		if state:GetAttribute("Phase") == "Final" then
			footer.Text = `Back to the lobby in {left}`
		elseif state:GetAttribute("GameNumber") == state:GetAttribute("GameCount") then
			footer.Text = `Final results in {left}`
		else
			footer.Text = `Next game in {left}`
		end
	end

	return { refresh = refresh, tick = tick }
end

return Results
