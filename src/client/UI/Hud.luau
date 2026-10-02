local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Text"))
local Action = require(script.Parent.Parent.Action)
local AimController = require(script.Parent.Parent.AimController)
local MyMatch = require(script.Parent.Parent.MyMatch)
local Sounds = require(script.Parent.Parent.Sounds)
local BallIcon = require(script.Parent.BallIcon)
local Widgets = require(script.Parent.Widgets)

-- The HUD while you wait at a station or play a match, laid out like the reference game: each
-- side's card in its top corner (face, name, hearts, and the ball it's playing). While waiting,
-- the empty side reads "Waiting For Opponent", with Invite and Leave buttons at the bottom.
-- In a match: the phase timer at the top, a pointing hand while you aim, the round result and
-- match winner, and a red tint in sudden death.
local Hud = {}

local PHASE_ICONS = { Aim = "🎯", Battle = "⚔️" } -- the draft shows its own countdown
local SUDDEN_DEATH_TINT = Color3.fromRGB(255, 170, 170)
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local FACE_SIZE = 96
local FACE_BACK = Color3.fromRGB(25, 30, 58)
local PLACEHOLDER = Color3.fromRGB(250, 215, 40)

local CENTER = Enum.TextXAlignment.Center

type Card = {
	face: ImageLabel,
	faceText: TextLabel,
	name: TextLabel,
	hearts: TextLabel,
	ballName: TextLabel,
	ball: BallIcon.BallIcon,
}

type CardInfo = {
	userId: number?, -- 0 for the bot
	name: string?,
	hearts: number?,
	pick: string?,
	waiting: boolean?, -- nobody yet
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

-- A side's card, pinned to its top corner and mirrored on the right.
local function makeCard(parent: GuiObject, side: string): Card
	local isLeft = side == "Left"
	local color = Config.SIDE_COLORS[side]
	local root = Widgets.create("Frame", {
		Name = `{side}Card`,
		AnchorPoint = Vector2.new(if isLeft then 0 else 1, 0),
		Position = UDim2.new(if isLeft then 0 else 1, if isLeft then 16 else -16, 0, 12),
		Size = UDim2.fromOffset(420, 250),
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
	Widgets.create("UIStroke", { Color = color, Thickness = 4, Parent = face })
	local faceText = bigLabel(60, {
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		TextStrokeTransparency = 1,
		TextColor3 = Color3.fromRGB(40, 40, 40),
		Parent = face,
	})

	local nameProps = slot(FACE_SIZE + 10, 10, 300, 34)
	nameProps.Parent = root
	nameProps.TextXAlignment = align
	nameProps.TextColor3 = color
	nameProps.TextScaled = true
	nameProps.AutomaticSize = Enum.AutomaticSize.None
	local name = Widgets.title("", 26, nameProps)

	local heartsLabel = Widgets.label("", 34, slot(FACE_SIZE + 8, 44, 200, 44))
	heartsLabel.AutomaticSize = Enum.AutomaticSize.None
	heartsLabel.TextXAlignment = align
	heartsLabel.Parent = root

	local ballName = Widgets.body("", 26, slot(0, FACE_SIZE + 6, 260, 32))
	ballName.AutomaticSize = Enum.AutomaticSize.None
	ballName.TextXAlignment = align
	ballName.TextStrokeTransparency = 0
	ballName.Parent = root

	local ballProps = slot(10, FACE_SIZE + 42, 84, 84)
	ballProps.Parent = root
	local ball = BallIcon.new(ballProps)

	return { face = face, faceText = faceText, name = name, hearts = heartsLabel, ballName = ballName, ball = ball }
end

local function setCard(card: Card, info: CardInfo)
	local userId = info.userId or 0
	card.face.Image = if info.waiting or userId <= 0 then "" else string.format(HEADSHOT, userId)
	card.face.BackgroundColor3 = if info.waiting then PLACEHOLDER else FACE_BACK
	card.faceText.Text = if info.waiting then "🙂" elseif userId <= 0 then "🤖" else ""
	card.name.Text = if info.waiting then "Waiting For Opponent" else info.name or ""
	card.hearts.Visible = info.hearts ~= nil
	card.hearts.Text = string.rep("❤️", math.clamp(info.hearts or 0, 0, Config.HEARTS))
	local pick = info.pick or ""
	card.ballName.Text = if pick ~= "" then Brainrots.get(pick).name else ""
	card.ball.set(pick)
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

	-- Invite and Leave, while waiting.
	local waitButtons = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(500, 210),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Widgets.fit(waitButtons)
	Widgets.bigButton("Invite", Widgets.BLUE, function()
		task.spawn(function()
			local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and canInvite then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			end
		end)
	end, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(330, 86),
		TextSize = 54,
		Parent = waitButtons,
	})
	Widgets.bigButton("Leave", Widgets.RED, function()
		Action.send("Leave")
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(500, 104),
		TextSize = 64,
		Parent = waitButtons,
	})

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "SuddenDeathTint"
	tint.Enabled = false
	tint.TintColor = SUDDEN_DEATH_TINT
	tint.Parent = Lighting

	local lastBeep = 0

	local function refresh()
		local state = MyMatch.state()
		local waitingSide = if state then "" else MyMatch.waitingSide()
		root.Visible = state ~= nil or waitingSide ~= ""
		tint.Enabled = state ~= nil and state:GetAttribute("SuddenDeath") == true
		waitButtons.Visible = waitingSide ~= ""

		if state then
			for side, card in cards do
				setCard(card, {
					userId = tonumber(state:GetAttribute(`{side}UserId`)),
					name = tostring(state:GetAttribute(`{side}Name`) or ""),
					hearts = tonumber(state:GetAttribute(`{side}Hearts`)) or 0,
					pick = tostring(state:GetAttribute(`{side}Pick`) or ""),
				})
			end

			local mySide = MyMatch.side()
			local phase = MyMatch.phase()
			if phase == "Resolve" then
				local winner = state:GetAttribute("RoundWinner")
				bannerIcon.Text = if winner == mySide then "🏆" elseif winner == "Draw" then "🤝" else "💔"
				bannerText.Text = if winner == mySide then "ROUND WON" elseif winner == "Draw" then "DRAW" else "ROUND LOST"
			elseif phase == "Over" then
				bannerIcon.Text = "👑"
				bannerText.Text = `{state:GetAttribute("MatchWinner") or ""} WINS`
			end
			banner.Visible = phase == "Resolve" or phase == "Over"
		elseif waitingSide ~= "" then
			for side, card in cards do
				if side == waitingSide then
					setCard(card, { userId = player.UserId, name = player.DisplayName })
				else
					setCard(card, { waiting = true })
				end
			end
			banner.Visible = false
		end
	end

	local function tick()
		if not root.Visible then
			return
		end
		for _, card in cards do
			card.ball.spin()
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
