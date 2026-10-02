local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local MyMatch = require(script.Parent.Parent.MyMatch)
local Profile = require(script.Parent.Parent.Profile)
local BallIcon = require(script.Parent.BallIcon)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- The lobby HUD, laid out like the reference game:
--   top bar      your avatar (Profile), a gift with a count (Gifts) and a gear (Settings)
--   left         Store, Inventory, and Emotes (R)
--   bottom left  coins, gems (+ opens the Store) and any x2 EXP timer
--   bottom       the next level's reward, and Play (joins whoever's waiting, or a free station)
--   top right    Daily Quests and Trade tabs, and Quick Join when someone's waiting
-- Hidden while you wait at a station or play a match (coins and gems stay up in the draft).
local LobbyHud = {}

local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local PANEL_WIDTH = 300

type QuestRow = { name: TextLabel, progress: TextLabel, button: TextButton }

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Whether a daily quest is done and whether it's been claimed, for today.
local function questState(profile: any, quest: any): (number, boolean)
	if not profile or profile.questDay ~= Economy.day(now()) then
		return 0, false
	end
	return profile.quests[quest.id] or 0, profile.questsClaimed[quest.id] == true
end

-- How many playtime gifts are ready to claim.
function LobbyHud.giftsReady(): number
	local session = Profile.session()
	if not session then
		return 0
	end
	local ready = 0
	for index, gift in Economy.GIFTS do
		if not session.gifts[tostring(index)] and now() - session.joinedAt >= gift.minutes * 60 then
			ready += 1
		end
	end
	return ready
end

local function circleButton(parent: Instance, onClick: () -> ()): ImageButton
	local button = Widgets.create("ImageButton", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		Parent = parent,
	}, { Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	button.Activated:Connect(onClick)
	return button
end

-- A square button on the left with a big icon and a word under it.
local function sideButton(parent: Instance, emoji: string, word: string, y: number, onClick: () -> ()): TextButton
	local button = Widgets.create("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.fromOffset(96, 104),
		BackgroundColor3 = Widgets.NAVY,
		Text = "",
		Parent = parent,
	}, {
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 3, Color = Widgets.EDGE }),
	})
	Widgets.create("TextLabel", {
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 70),
		BackgroundTransparency = 1,
		Text = emoji,
		TextScaled = true,
		Parent = button,
	})
	Widgets.title(word, 18, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 8, 0, 24),
		AutomaticSize = Enum.AutomaticSize.None,
		TextScaled = true,
		Parent = button,
	})
	button.Activated:Connect(onClick)
	return button
end

function LobbyHud.new(gui: ScreenGui)
	local player = Players.LocalPlayer

	local root = Widgets.create("Frame", {
		Name = "LobbyHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	-- Top bar, next to Roblox's own buttons.
	local topbar = Widgets.create("ScreenGui", {
		Name = "LobbyTopbar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = gui.Parent,
	})
	local profileButton = circleButton(topbar, function()
		Windows.toggle("Profile")
	end)
	profileButton.Image = string.format(HEADSHOT, player.UserId)
	local giftButton = circleButton(topbar, function()
		Windows.toggle("Gifts")
	end)
	Widgets.create("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "🎁", TextScaled = true, Parent = giftButton }, {
		Widgets.create("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
	})
	local badge = Widgets.title("", 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		TextColor3 = Color3.new(0, 0, 0),
		Parent = giftButton,
	})
	Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	local settingsButton = circleButton(topbar, function()
		Windows.toggle("Settings")
	end)
	Widgets.create("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "⚙️", TextScaled = true, Parent = settingsButton }, {
		Widgets.create("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
	})
	local function layoutTopbar()
		local inset = GuiService.TopbarInset
		local height = if inset.Height > 0 then inset.Height else 44
		local size = height - 10
		local x = if inset.Height > 0 then inset.Min.X + 6 else 120
		for index, button in { profileButton, giftButton, settingsButton } do
			button.Size = UDim2.fromOffset(size, size)
			button.Position = UDim2.fromOffset(x + (index - 1) * (size + 8), inset.Min.Y + 5)
		end
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layoutTopbar)
	layoutTopbar()

	-- Left: Store, Inventory, Emotes.
	local left = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.42, 0),
		Size = UDim2.fromOffset(150, 300),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Widgets.fit(left)
	sideButton(left, "🎰", "Store", 52, function()
		Windows.toggle("Store")
	end)
	sideButton(left, "📦", "Inventory", 172, function()
		Windows.toggle("Inventory")
	end)
	local function toggleEmotes()
		GuiService:SetEmotesMenuOpen(not GuiService:GetEmotesMenuOpen())
	end
	local emotes = Widgets.create("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0, 262),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = Widgets.NAVY,
		Text = "",
		Parent = left,
	}, {
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 3, Color = Widgets.EDGE }),
	})
	Widgets.create("TextLabel", { Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Text = "🕺", TextScaled = true, Parent = emotes })
	Widgets.title("Emotes", 18, { Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(76, 48), AutomaticSize = Enum.AutomaticSize.None, Parent = emotes })
	local key = Widgets.title("R", 16, {
		Position = UDim2.fromOffset(118, 10),
		Size = UDim2.fromOffset(26, 28),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundColor3 = Widgets.GREY,
		BackgroundTransparency = 0,
		Parent = emotes,
	})
	Widgets.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = key })
	emotes.Activated:Connect(toggleEmotes)

	-- Bottom left: coins, gems, boost.
	local wallet = Widgets.create("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -16),
		Size = UDim2.fromOffset(260, 190),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Widgets.fit(wallet)
	local function walletRow(y: number, icon: GuiObject, color: Color3): TextLabel
		local strip = Widgets.create("Frame", {
			Position = UDim2.fromOffset(20, y + 10),
			Size = UDim2.fromOffset(220, 52),
			BackgroundColor3 = Widgets.NAVY,
			BackgroundTransparency = 0.35,
			Parent = wallet,
		}, {
			Widgets.create("UIGradient", {
				Transparency = NumberSequence.new(0, 1),
			}),
		})
		icon.Position = UDim2.fromOffset(0, y)
		icon.Parent = wallet
		return Widgets.title("0", 40, {
			Position = UDim2.fromOffset(86, 0),
			Size = UDim2.new(1, -86, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Parent = strip,
		})
	end
	local boost = Widgets.create("Frame", {
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = Widgets.NAVY,
		Parent = wallet,
	}, {
		Widgets.corner(6),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.CYAN }),
	})
	local boostText = Widgets.title("", 20, {
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.CYAN,
		Parent = boost,
	})
	local coins = walletRow(54, Widgets.coin(66), Color3.fromRGB(255, 175, 40))
	local gems = walletRow(124, Widgets.gem(72), Widgets.CYAN)
	local plus = Widgets.title("+", 34, {
		Position = UDim2.fromOffset(-8, 156),
		Size = UDim2.fromOffset(34, 34),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = wallet,
	})
	local plusButton = Widgets.create("TextButton", {
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.fromOffset(80, 66),
		BackgroundTransparency = 1,
		Text = "",
		Parent = wallet,
	})
	plusButton.Activated:Connect(function()
		Windows.open("Store")
	end)
	plus.ZIndex = 2

	-- Bottom middle: next level's reward and Play.
	local bottom = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(300, 130),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Widgets.fit(bottom)
	local rewardPlate = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(250, 52),
		BackgroundColor3 = Widgets.NAVY,
		BackgroundTransparency = 0.2,
		Parent = bottom,
	})
	local rewardText = Widgets.body("", 26, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -70, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = rewardPlate,
	})
	local rewardIconHolder = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundTransparency = 1,
		Parent = rewardPlate,
	})
	local rewardBall = BallIcon.new({ Size = UDim2.fromScale(1, 1), Parent = rewardIconHolder })
	local rewardIcon: GuiObject? = nil
	local shownReward = ""

	local play = Widgets.bigButton("Play", Widgets.GREEN, function()
		Action.send("Play")
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(280, 64),
		TextSize = 40,
	})
	play.Parent = bottom

	-- Top right: Daily Quests and Trade.
	local right = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 8),
		Size = UDim2.fromOffset(PANEL_WIDTH + 20, 520),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Widgets.fit(right)
	local tab = "Quests"
	local tabs = {}
	local function tabButton(name: string, emoji: string, word: string, x: number, width: number): TextButton
		local button = Widgets.create("TextButton", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(width, 46),
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			Text = "",
			Parent = right,
		}, {
			Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
		})
		Widgets.create("TextLabel", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Text = emoji, TextScaled = true, Parent = button })
		Widgets.title(word, 18, {
			Position = UDim2.fromOffset(42, 0),
			Size = UDim2.new(1, -48, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextScaled = true,
			Parent = button,
		})
		tabs[name] = button
		return button
	end
	local panel = Widgets.create("Frame", {
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.fromOffset(PANEL_WIDTH, 260),
		BackgroundColor3 = Widgets.NAVY,
		BackgroundTransparency = 0.25,
		Parent = right,
	})

	-- Daily Quests
	local questsPage = Widgets.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panel })
	local questsTitle = Widgets.title("", 20, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 30),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = questsPage,
	})
	local questRows: { QuestRow } = {}
	for index, quest in Economy.QUESTS do
		local y = 38 + (index - 1) * 74
		local row = Widgets.create("Frame", {
			Position = UDim2.fromOffset(6, y),
			Size = UDim2.new(1, -12, 0, 68),
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			BackgroundTransparency = 0.3,
			Parent = questsPage,
		})
		local name = Widgets.body(quest.text, 24, {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.new(1, -90, 0, 30),
			AutomaticSize = Enum.AutomaticSize.None,
			TextStrokeTransparency = 0,
			Parent = row,
		})
		local progress = Widgets.title("", 18, {
			Position = UDim2.fromOffset(6, 34),
			Size = UDim2.fromOffset(80, 28),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Widgets.coin(22, { Position = UDim2.fromOffset(110, 38), Parent = row })
		Widgets.title(`x{quest.reward.amount}`, 18, {
			Position = UDim2.fromOffset(136, 34),
			Size = UDim2.fromOffset(70, 28),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 175, 40),
			Parent = row,
		})
		local button = Widgets.create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(78, 44),
			BackgroundColor3 = Widgets.GREY,
			Text = "Undone",
			TextSize = 13,
			TextColor3 = Widgets.TEXT,
			Parent = row,
		}, {
			Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Color3.fromRGB(40, 40, 50) }),
		})
		button.FontFace = Widgets.TITLE_FONT
		button.Activated:Connect(function()
			Action.send("ClaimQuest", quest.id)
		end)
		questRows[index] = { name = name, progress = progress, button = button }
	end

	-- Trade
	local tradePage = Widgets.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = panel,
	}, {
		Widgets.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Widgets.create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
	})
	local noOne = Widgets.body("Nobody else is here yet", 20, { TextXAlignment = Enum.TextXAlignment.Center, Parent = tradePage })
	local tradeRows: { [Player]: Frame } = {}
	local sentAt: { [Player]: number } = {}
	local function refreshTradeList()
		local others = 0
		for _, other in Players:GetPlayers() do
			if other == player then
				continue
			end
			others += 1
			local row = tradeRows[other]
			if not row then
				row = Widgets.create("Frame", {
					Size = UDim2.new(1, 0, 0, 56),
					BackgroundColor3 = Widgets.NAVY_LIGHT,
					Parent = tradePage,
				}, { Widgets.corner(6) })
				local face = Widgets.create("ImageLabel", {
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.fromOffset(44, 44),
					BackgroundColor3 = Widgets.NAVY,
					Image = string.format(HEADSHOT, other.UserId),
					Parent = row,
				}, { Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				face.Name = "Face"
				Widgets.body(other.DisplayName, 22, {
					Position = UDim2.fromOffset(58, 0),
					Size = UDim2.new(1, -150, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = row,
				})
				local button = Widgets.bigButton("Trade", Widgets.BLUE, function()
					sentAt[other] = os.clock()
					Action.send("TradeRequest", other)
				end, {
					Name = "Send",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Size = UDim2.fromOffset(84, 40),
					TextSize = 16,
				})
				button.Parent = row
				tradeRows[other] = row :: Frame
			end
			local send = (row :: Frame):FindFirstChild("Send") :: TextButton
			local sent = sentAt[other] and os.clock() - sentAt[other] < 10
			send.Text = if sent then "Sent" else "Trade"
		end
		for other, row in tradeRows do
			if other.Parent ~= Players then
				row:Destroy()
				tradeRows[other] = nil
			end
		end
		noOne.Visible = others == 0
	end

	local function selectTab(name: string)
		tab = name
		questsPage.Visible = name == "Quests"
		tradePage.Visible = name == "Trade"
		for tabName, button in tabs do
			button.BackgroundColor3 = if tabName == name then Widgets.BLUE else Widgets.NAVY_LIGHT
		end
	end
	tabButton("Quests", "📝", "Daily Quests", 20, 170).Activated:Connect(function()
		selectTab("Quests")
	end)
	tabButton("Trade", "🤝", "Trade", 194, 126).Activated:Connect(function()
		selectTab("Trade")
	end)
	selectTab("Quests")

	-- Quick Join
	local quick = Widgets.create("Frame", {
		Position = UDim2.fromOffset(20, 322),
		Size = UDim2.fromOffset(PANEL_WIDTH, 120),
		BackgroundTransparency = 1,
		Parent = right,
	})
	Widgets.title("Quick Join", 28, {
		Size = UDim2.new(1, 0, 0, 36),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = quick,
	})
	local quickRow = Widgets.create("Frame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = Widgets.NAVY,
		BackgroundTransparency = 0.25,
		Parent = quick,
	})
	local function quickFace(x: number): (ImageLabel, UIStroke, TextLabel)
		local face = Widgets.create("ImageLabel", {
			Position = UDim2.fromOffset(x, 7),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			Parent = quickRow,
		}, { Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local ring = Widgets.create("UIStroke", { Thickness = 3, Parent = face })
		local mark = Widgets.title("", 34, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = face })
		return face, ring, mark
	end
	local waiterFace, waiterRing, waiterMark = quickFace(6)
	local _, openRing, openMark = quickFace(72)
	openMark.Text = "?"
	Widgets.coin(22, { Position = UDim2.fromOffset(140, 26), Parent = quickRow })
	Widgets.body(`Win {Economy.WIN_COINS}`, 20, {
		Position = UDim2.fromOffset(166, 0),
		Size = UDim2.fromOffset(60, 74),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.GOLD,
		Parent = quickRow,
	})
	local quickArena = ""
	local join = Widgets.bigButton("Join", Widgets.BLUE, function()
		if quickArena ~= "" then
			Action.send("QuickJoin", quickArena)
		end
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(70, 48),
		TextSize = 20,
	})
	join.Parent = quickRow

	-- Finds a station where someone else is waiting alone.
	local function refreshQuickJoin()
		local arenas = workspace:FindFirstChild("Arenas")
		local found = nil
		for _, arena in if arenas then arenas:GetChildren() else {} do
			local state = arena:FindFirstChild("State")
			if not state or (state:GetAttribute("Phase") or "") ~= "" then
				continue
			end
			local leftId = tonumber(state:GetAttribute("WaitingLeft")) or 0
			local rightId = tonumber(state:GetAttribute("WaitingRight")) or 0
			local waiter = if leftId ~= 0 then leftId else rightId
			if (leftId == 0) ~= (rightId == 0) and waiter ~= player.UserId then
				found = { arena = arena.Name, userId = waiter, side = if leftId ~= 0 then "Left" else "Right" }
				break
			end
		end
		quick.Visible = found ~= nil
		if found then
			quickArena = found.arena
			waiterFace.Image = string.format(HEADSHOT, found.userId)
			waiterMark.Text = ""
			local colors = { Left = Color3.fromRGB(255, 95, 140), Right = Color3.fromRGB(70, 160, 255) }
			waiterRing.Color = colors[found.side]
			openRing.Color = colors[if found.side == "Left" then "Right" else "Left"]
		else
			quickArena = ""
		end
	end

	local function setRewardIcon(reward: Economy.Reward)
		local _, emoji = Economy.describe(reward)
		local key = `{reward.kind}:{reward.id or reward.amount}`
		if key == shownReward then
			return
		end
		shownReward = key
		if rewardIcon then
			rewardIcon:Destroy()
			rewardIcon = nil
		end
		rewardBall.set(if reward.kind == "ball" then reward.id else nil)
		if reward.kind ~= "ball" then
			local icon = Widgets.icon(reward.kind, emoji, 44, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
			icon.Parent = rewardIconHolder
			rewardIcon = icon
		end
	end

	local function refresh()
		local inMatch = MyMatch.state() ~= nil
		local waiting = MyMatch.waitingSide() ~= ""
		root.Visible = not inMatch and not waiting
		topbar.Enabled = root.Visible
		wallet.Visible = not waiting and (not inMatch or MyMatch.phase() == "Draft")

		local profile = Profile.get()
		if not profile then
			return
		end
		coins.Text = tostring(profile.coins)
		gems.Text = tostring(profile.gems)
		rewardText.Text = `Lv {profile.level + 1} Reward`
		setRewardIcon(Economy.levelReward(profile.level + 1))

		for index, quest in Economy.QUESTS do
			local row = questRows[index]
			local progress, claimed = questState(profile, quest)
			row.progress.Text = `{progress}/{quest.goal}`
			local done = progress >= quest.goal
			row.button.Text = if claimed then "Done" elseif done then "Claim" else "Undone"
			row.button.BackgroundColor3 = if claimed then Widgets.NAVY_LIGHT elseif done then Widgets.GREEN else Widgets.GREY
		end

		local ready = LobbyHud.giftsReady()
		badge.Text = tostring(ready)
		badge.Visible = ready > 0

		if tab == "Trade" then
			refreshTradeList()
		end
		refreshQuickJoin()
	end

	local function tick()
		if not wallet.Visible then
			return
		end
		local profile = Profile.get()
		local boostLeft = if profile then profile.boostUntil - now() else 0
		boost.Visible = boostLeft > 0
		boostText.Text = `⚡ EXPx2 {Widgets.clock(boostLeft)}`
		if root.Visible then
			questsTitle.Text = `Daily Quests ({Widgets.clock(86400 - now() % 86400)})`
			rewardBall.spin()
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R and root.Visible and not UserInputService:GetFocusedTextBox() then
			toggleEmotes()
		end
	end)

	return { refresh = refresh, tick = tick }
end

return LobbyHud
