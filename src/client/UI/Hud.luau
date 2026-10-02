local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Text"))
local AimController = require(script.Parent.Parent.AimController)
local MyMatch = require(script.Parent.Parent.MyMatch)
local Sounds = require(script.Parent.Parent.Sounds)
local Widgets = require(script.Parent.Widgets)

-- The match HUD: both sides' hearts and names, the phase and its timer, a pointing hand while
-- you aim, the round result and the match winner, and a red tint in sudden death. Icons and
-- numbers, as few words as possible (see CLAUDE.md). Nothing shows in the lobby.
local Hud = {}

local PHASE_ICONS = { Draft = "🃏", Aim = "🎯", Battle = "⚔️" }
local SUDDEN_DEATH_TINT = Color3.fromRGB(255, 170, 170)

local CENTER = Enum.TextXAlignment.Center

local function bigLabel(size: number, props: { [string]: any }): TextLabel
	local label = Widgets.label("", size, {
		Font = Enum.Font.GothamBlack,
		TextXAlignment = CENTER,
		TextStrokeTransparency = 0,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function Hud.new(gui: ScreenGui)
	local root = Widgets.create("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	-- One card per side, top left and top right: hearts over the name.
	local function sideCard(side: string): (Frame, TextLabel, TextLabel, UIStroke)
		local isLeft = side == "Left"
		local card = Widgets.panel({
			AnchorPoint = Vector2.new(if isLeft then 0 else 1, 0),
			Position = UDim2.new(if isLeft then 0 else 1, if isLeft then 12 else -12, 0, 8),
			Size = UDim2.fromOffset(190, 0),
			Parent = root,
		})
		local stroke = Widgets.create("UIStroke", { Color = Config.SIDE_COLORS[side], Thickness = 3, Parent = card })
		local hearts = bigLabel(26, { LayoutOrder = 1, TextStrokeTransparency = 1, Parent = card })
		local name = bigLabel(16, {
			LayoutOrder = 2,
			TextColor3 = Config.SIDE_COLORS[side],
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		return card, hearts, name, stroke
	end
	local _, leftHearts, leftName, leftStroke = sideCard("Left")
	local _, rightHearts, rightName, rightStroke = sideCard("Right")

	local timer = bigLabel(40, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(260, 0),
		Parent = root,
	})

	local banner = Widgets.stack({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(700, 0),
		Parent = root,
	}, 4)
	local bannerIcon = bigLabel(120, { LayoutOrder = 1, TextStrokeTransparency = 1, Parent = banner })
	local bannerText = bigLabel(44, { LayoutOrder = 2, TextColor3 = Widgets.ACCENT, Parent = banner })

	local hint = bigLabel(64, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(120, 0),
		TextStrokeTransparency = 1,
		Parent = root,
	})

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "SuddenDeathTint"
	tint.Enabled = false
	tint.TintColor = SUDDEN_DEATH_TINT
	tint.Parent = Lighting

	local lastBeep = 0

	local function hearts(count: number): string
		count = math.clamp(count, 0, Config.HEARTS)
		return string.rep("❤️", count) .. string.rep("🖤", Config.HEARTS - count)
	end

	local function refresh()
		local state = MyMatch.state()
		root.Visible = state ~= nil
		tint.Enabled = state ~= nil and state:GetAttribute("SuddenDeath") == true
		if not state then
			return
		end
		local mySide = MyMatch.side()
		leftHearts.Text = hearts(state:GetAttribute("LeftHearts") or 0)
		rightHearts.Text = hearts(state:GetAttribute("RightHearts") or 0)
		leftName.Text = (if mySide == "Left" then "▶ " else "") .. tostring(state:GetAttribute("LeftName") or "")
		rightName.Text = tostring(state:GetAttribute("RightName") or "") .. (if mySide == "Right" then " ◀" else "")
		leftStroke.Thickness = if mySide == "Left" then 5 else 2
		rightStroke.Thickness = if mySide == "Right" then 5 else 2

		local phase = MyMatch.phase()
		if phase == "Resolve" then
			local winner = state:GetAttribute("RoundWinner")
			bannerIcon.Text = if winner == mySide then "🏆" elseif winner == "Draw" then "🤝" else "💔"
			bannerText.Text = ""
		elseif phase == "Over" then
			bannerIcon.Text = "👑"
			bannerText.Text = tostring(state:GetAttribute("MatchWinner") or "")
		end
		banner.Visible = phase == "Resolve" or phase == "Over"
	end

	local function tick()
		if not root.Visible then
			return
		end
		local phase = MyMatch.phase()
		local left = MyMatch.timeLeft()
		local icon = PHASE_ICONS[phase]
		local state = MyMatch.state()
		local suddenDeath = state and state:GetAttribute("SuddenDeath") == true
		if icon then
			local seconds = if phase == "Battle" then Text.clock(left) else tostring(math.max(0, math.ceil(left)))
			timer.Text = `{if suddenDeath then "⚠️" else icon} {seconds}`
			timer.TextColor3 = if suddenDeath or left <= 3 then Widgets.BAD else Widgets.TEXT
		end
		timer.Visible = icon ~= nil

		-- Beep through the last 3 seconds of drafting and aiming.
		local whole = math.ceil(left)
		if (phase == "Draft" or phase == "Aim") and whole <= 3 and whole >= 1 and whole ~= lastBeep then
			lastBeep = whole
			Sounds.play("Beep")
		elseif whole > 3 then
			lastBeep = 0
		end

		-- A bobbing hand while you aim, a check once you've locked in.
		hint.Visible = phase == "Aim"
		hint.Text = if AimController.isLocked() then "✅" else "👆"
		hint.Position = UDim2.new(0.5, 0, 1, -30 - math.abs(math.sin(os.clock() * 4)) * 12)
	end

	return { refresh = refresh, tick = tick }
end

return Hud
