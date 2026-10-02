local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Text"))
local BallController = require(script.Parent.Parent.BallController)
local Input = require(script.Parent.Parent.Input)
local Sounds = require(script.Parent.Parent.Sounds)
local Widgets = require(script.Parent.Widgets)

-- Everything on screen: the timer and how many are left, your boost meter and slam charge,
-- 3-2-1-GO, short announcements and the winner. Icons and numbers, as few words as possible
-- (see CLAUDE.md).
local Hud = {}

local ANNOUNCEMENT_TIME = 3
local GO_TIME = 1

local CENTER = Enum.TextXAlignment.Center

-- Big outlined text that reads well over the game.
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

local function pill(props: { [string]: any }): Frame
	local frame = Widgets.create("Frame", {
		BackgroundColor3 = Widgets.PANEL,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, { Widgets.corner(14) })
	for key, value in props do
		(frame :: any)[key] = value
	end
	return frame
end

function Hud.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild("MatchState")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Top: time left and balls left
	local timer = bigLabel(44, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -60, 0, 4),
		Size = UDim2.fromOffset(140, 0),
		Parent = gui,
	})
	local alive = bigLabel(36, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 80, 0, 8),
		Size = UDim2.fromOffset(120, 0),
		Parent = gui,
	})

	-- Below them: boost meter and slam charge
	local meters = pill({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(250, 44),
		Parent = gui,
	})
	bigLabel(24, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(32, 44), AutomaticSize = Enum.AutomaticSize.None, Parent = meters }).Text = "💨"
	local track = Widgets.create("Frame", {
		Position = UDim2.fromOffset(46, 15),
		Size = UDim2.fromOffset(140, 14),
		BackgroundColor3 = Widgets.BUTTON,
		BorderSizePixel = 0,
		Parent = meters,
	}, { Widgets.corner(7) })
	local fill = Widgets.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Widgets.GOOD,
		BorderSizePixel = 0,
		Parent = track,
	}, { Widgets.corner(7) })
	local slam = bigLabel(26, {
		Position = UDim2.fromOffset(196, 0),
		Size = UDim2.fromOffset(46, 44),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = meters,
	})

	local countdown = bigLabel(140, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(400, 0),
		TextColor3 = Widgets.ACCENT,
		Parent = gui,
	})

	local winner = Widgets.stack({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(700, 0),
		Parent = gui,
	}, 4)
	bigLabel(110, { LayoutOrder = 1, TextStrokeTransparency = 1, Parent = winner }).Text = "👑"
	local winnerNames = bigLabel(48, { LayoutOrder = 2, TextColor3 = Widgets.ACCENT, Parent = winner })

	local feed = Widgets.stack({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(500, 0),
		Parent = gui,
	}, 4)
	local announcementCount = 0
	remotes.Announce.OnClientEvent:Connect(function(message: string)
		announcementCount += 1
		local line = bigLabel(28, { LayoutOrder = announcementCount, Parent = feed })
		line.Text = message
		task.delay(ANNOUNCEMENT_TIME, function()
			local fade = TweenService:Create(line, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			line:Destroy()
		end)
	end)

	local lastPhase = nil
	local goUntil = 0
	local lastCount = 0

	local function refresh()
		local phase = state:GetAttribute("Phase")
		if phase ~= lastPhase then
			lastPhase = phase
			if phase == "Playing" then
				goUntil = os.clock() + GO_TIME
			end
		end
		local inRound = phase == "Countdown" or phase == "Playing"
		timer.Visible = phase == "Playing"
		alive.Visible = inRound
		alive.Text = `👥 {state:GetAttribute("Alive") or 0}`
		winner.Visible = phase == "Winner"
		local names = state:GetAttribute("Winners") or ""
		winnerNames.Text = if names ~= "" then names else "🤝"
	end

	local function tick()
		local phase = state:GetAttribute("Phase")
		local endsAt = state:GetAttribute("EndsAt") or 0
		local now = workspace:GetServerTimeNow()
		local left = endsAt - now

		if timer.Visible then
			timer.Text = Text.clock(left)
			timer.TextColor3 = if left <= 10 then Widgets.BAD else Widgets.TEXT
		end

		-- Big numbers before a round (in the lobby circle and frozen in the arena), then GO!
		local counting = endsAt > 0 and left > 0 and (phase == "Lobby" or phase == "Countdown")
		if counting then
			local number = math.ceil(left)
			countdown.Text = tostring(number)
			if number ~= lastCount then
				lastCount = number
				Sounds.play("Beep")
			end
		elseif phase == "Playing" and os.clock() < goUntil then
			countdown.Text = "GO!"
		end
		countdown.Visible = counting or (phase == "Playing" and os.clock() < goUntil)
		if not counting then
			lastCount = 0
		end

		-- Meters, only while you have a ball.
		local hasBall = BallController.myBall() ~= nil
		meters.Visible = hasBall
		local meter = BallController.boostMeter()
		fill.Size = UDim2.fromScale(meter / 100, 1)
		fill.BackgroundColor3 = if meter >= Config.BOOST_COST then Widgets.GOOD else Widgets.MUTED
		local slamLeft = (player:GetAttribute("AbilityReadyAt") or 0) - now
		slam.Text = if slamLeft > 0 then tostring(math.ceil(slamLeft)) else "💥"
		slam.TextColor3 = if slamLeft > 0 then Widgets.MUTED else Widgets.TEXT
		Input.setReady("Boost", meter >= Config.BOOST_COST)
		Input.setReady("Ability", slamLeft <= 0)
	end

	return { refresh = refresh, tick = tick }
end

return Hud
