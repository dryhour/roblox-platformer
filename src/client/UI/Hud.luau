local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Text"))
local AimController = require(script.Parent.Parent.AimController)
local MyMatch = require(script.Parent.Parent.MyMatch)
local Sounds = require(script.Parent.Parent.Sounds)
local BallIcon = require(script.Parent.BallIcon)
local Widgets = require(script.Parent.Widgets)

-- The match HUD, laid out like a fighting game: each side's card in its top corner (face, name,
-- hearts, and the ball it's playing), the phase and its timer at the top, a pointing hand while
-- you aim, the round result and match winner, and a red tint in sudden death. While you wait in
-- a station square, your card shows on your side, a "?" on the other, and an ✉️ button invites
-- friends. Icons and numbers, as few words as possible (see CLAUDE.md). Nothing shows otherwise.
local Hud = {}

local PHASE_ICONS = { Aim = "🎯", Battle = "⚔️" } -- the draft shows its own countdown
local SUDDEN_DEATH_TINT = Color3.fromRGB(255, 170, 170)
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local FACE_SIZE = 84
local FACE_BACK = Color3.fromRGB(25, 30, 58)
local INVITE = Color3.fromRGB(70, 120, 255)

local CENTER = Enum.TextXAlignment.Center

type Card = {
	face: ImageLabel,
	faceText: TextLabel,
	ring: UIStroke,
	name: TextLabel,
	hearts: TextLabel,
	ball: BallIcon.BallIcon,
}

type CardInfo = {
	userId: number?, -- 0 for the bot
	name: string?,
	hearts: number?,
	pick: string?,
	you: boolean?,
	mystery: boolean?, -- nobody yet: shows a "?"
}

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

local function hearts(count: number): string
	count = math.clamp(count, 0, Config.HEARTS)
	return string.rep("❤️", count) .. string.rep("🖤", Config.HEARTS - count)
end

-- A side's card, pinned to its top corner and mirrored on the right.
local function makeCard(parent: GuiObject, side: string): Card
	local isLeft = side == "Left"
	local color = Config.SIDE_COLORS[side]
	local root = Widgets.create("Frame", {
		Name = `{side}Card`,
		AnchorPoint = Vector2.new(if isLeft then 0 else 1, 0),
		Position = UDim2.new(if isLeft then 0 else 1, if isLeft then 16 else -16, 0, 12),
		Size = UDim2.fromOffset(300, 180),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Widgets.fit(root)

	-- Places a child `x` pixels in from this card's outer edge.
	local function slot(x: number, y: number, width: number, height: number): { [string]: any }
		return {
			AnchorPoint = Vector2.new(if isLeft then 0 else 1, 0),
			Position = UDim2.new(if isLeft then 0 else 1, if isLeft then x else -x, 0, y),
			Size = UDim2.fromOffset(width, height),
		}
	end
	local align = if isLeft then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right

	local face = Widgets.create("ImageLabel", slot(0, 0, FACE_SIZE, FACE_SIZE))
	face.BackgroundColor3 = FACE_BACK
	face.Parent = root
	Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = face })
	local ring = Widgets.create("UIStroke", { Color = color, Thickness = 4, Parent = face })
	local faceText = bigLabel(48, {
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		TextStrokeTransparency = 1,
		TextColor3 = Widgets.MUTED,
		Parent = face,
	})

	local name = Widgets.label("", 22, slot(FACE_SIZE + 12, 6, 200, 30))
	name.FontFace = Widgets.TITLE_FONT
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextXAlignment = align
	name.TextColor3 = color
	name.TextStrokeTransparency = 0
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = root

	local heartsLabel = Widgets.label("", 30, slot(FACE_SIZE + 10, 38, 200, 38))
	heartsLabel.AutomaticSize = Enum.AutomaticSize.None
	heartsLabel.TextXAlignment = align
	heartsLabel.Parent = root

	local ballProps = slot(4, FACE_SIZE + 10, 76, 76)
	ballProps.Parent = root
	local ball = BallIcon.new(ballProps)

	return { face = face, faceText = faceText, ring = ring, name = name, hearts = heartsLabel, ball = ball }
end

local function setCard(card: Card, info: CardInfo)
	local userId = info.userId or 0
	card.face.Image = if info.mystery or userId <= 0 then "" else string.format(HEADSHOT, userId)
	card.faceText.Text = if info.mystery then "?" elseif userId <= 0 then "🤖" else ""
	card.ring.Thickness = if info.you then 6 else 3
	-- The bot's robot face says enough.
	card.name.Text = if userId <= 0 then "" else info.name or ""
	card.hearts.Visible = info.hearts ~= nil
	card.hearts.Text = hearts(info.hearts or 0)
	card.ball.set(info.pick)
end

function Hud.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local root = Widgets.create("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local cards = { Left = makeCard(root, "Left"), Right = makeCard(root, "Right") }

	local timer = bigLabel(40, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(260, 0),
		Parent = root,
	})
	Widgets.fit(timer)

	local banner = Widgets.stack({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(700, 0),
		Parent = root,
	}, 4)
	Widgets.fit(banner)
	local bannerIcon = bigLabel(120, { LayoutOrder = 1, TextStrokeTransparency = 1, Parent = banner })
	local bannerText = bigLabel(44, { LayoutOrder = 2, TextColor3 = Widgets.ACCENT, Parent = banner })

	local hint = bigLabel(64, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(120, 0),
		TextStrokeTransparency = 1,
		Parent = root,
	})
	Widgets.fit(hint)

	local invite = Widgets.button("✉️", function()
		task.spawn(function()
			local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and canInvite then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			end
		end)
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = INVITE,
		TextSize = 44,
		Parent = root,
	})
	Widgets.fit(invite)

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "SuddenDeathTint"
	tint.Enabled = false
	tint.TintColor = SUDDEN_DEATH_TINT
	tint.Parent = Lighting

	local lastBeep = 0
	local mysterySide = ""

	local function refresh()
		local state = MyMatch.state()
		local waitingSide = if state then "" else MyMatch.waitingSide()
		root.Visible = state ~= nil or waitingSide ~= ""
		tint.Enabled = state ~= nil and state:GetAttribute("SuddenDeath") == true
		invite.Visible = waitingSide ~= ""
		mysterySide = ""

		if state then
			local mySide = MyMatch.side()
			for side, card in cards do
				setCard(card, {
					userId = tonumber(state:GetAttribute(`{side}UserId`)),
					name = tostring(state:GetAttribute(`{side}Name`) or ""),
					hearts = tonumber(state:GetAttribute(`{side}Hearts`)) or 0,
					pick = tostring(state:GetAttribute(`{side}Pick`) or ""),
					you = side == mySide,
				})
			end

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
		elseif waitingSide ~= "" then
			for side, card in cards do
				if side == waitingSide then
					setCard(card, { userId = player.UserId, name = player.DisplayName, you = true })
				else
					setCard(card, { mystery = true })
					mysterySide = side
				end
			end
			banner.Visible = false
		end
	end

	local function tick()
		if not root.Visible then
			return
		end
		for side, card in cards do
			card.ball.spin()
			-- The empty side breathes while you wait for someone to join.
			card.face.BackgroundTransparency = if side == mysterySide then 0.3 + math.abs(math.sin(os.clock() * 2)) * 0.5 else 0
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
