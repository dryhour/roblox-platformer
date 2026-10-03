local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Action = require(script.Parent.Parent.Action)
local MyMatch = require(script.Parent.Parent.MyMatch)
local Profile = require(script.Parent.Parent.Profile)
local BallIcon = require(script.Parent.BallIcon)
local Widgets = require(script.Parent.Widgets)

-- The draft, like the reference game: the screen dims, "CHOOSE YOUR BALL" with a countdown,
-- and three cards from your collection, each with the ball's name, picture and what it does.
-- Tap one to pick it. All Balls swaps the three for picks from every ball: free once a day, with
-- a "Pick Any Card" voucher, or every round with the game pass.
local Draft = {}

local CARD_WIDTH = 230
local CARD_HEIGHT = 380
local GAP = 50
local CARD = Color3.fromRGB(14, 18, 34)
local PREVIEW = Color3.fromRGB(70, 74, 86)
local DIM = Color3.fromRGB(6, 8, 20)

type Card = { button: TextButton, stroke: UIStroke, scale: UIScale, icon: BallIcon.BallIcon, id: string }

local function makeCard(parent: GuiObject, order: number, id: string): Card
	local brainrot = Brainrots.get(id)
	local button = Widgets.create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = CARD,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	})
	local stroke = Widgets.create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
		Thickness = 2,
		Parent = button,
	})
	local scale = Widgets.create("UIScale", { Parent = button })

	Widgets.body(brainrot.name, 28, {
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 0, 60),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Parent = button,
	})
	local preview = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(140, 140),
		BackgroundColor3 = PREVIEW,
		Parent = button,
	}, {
		Widgets.create("UIStroke", { Thickness = 1, Color = Color3.fromRGB(110, 115, 130) }),
	})
	local icon = BallIcon.new({ Size = UDim2.fromScale(1, 1), Parent = preview })
	icon.set(id)
	Widgets.body(brainrot.description, 26, {
		Position = UDim2.fromOffset(12, 270),
		Size = UDim2.new(1, -24, 0, 84),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Parent = button,
	})
	-- A thin bar along the bottom in the ball's rarity color.
	Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Config.RARITIES[brainrot.rarity].color,
		BorderSizePixel = 0,
		Parent = button,
	})

	button.Activated:Connect(function()
		Remotes.Draft:FireServer(id)
	end)
	return { button = button, stroke = stroke, scale = scale, icon = icon, id = id }
end

function Draft.new(gui: ScreenGui)
	local player = Players.LocalPlayer

	-- Reaches up under Roblox's top bar so the whole screen dims.
	local root = Widgets.create("Frame", {
		Name = "Draft",
		Position = UDim2.fromOffset(0, -100),
		Size = UDim2.new(1, 0, 1, 100),
		BackgroundColor3 = DIM,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local content = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 50),
		Size = UDim2.fromOffset(CARD_WIDTH * 3 + GAP * 2, 640),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Widgets.fit(content, CARD_WIDTH * 3 + GAP * 2, 0.96)

	local title = Widgets.title("", 44, {
		Size = UDim2.new(1, 0, 0, 60),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = content,
	})
	local row = Widgets.stack({
		Position = UDim2.fromOffset(0, 90),
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		Parent = content,
	}, GAP, Enum.FillDirection.Horizontal)

	local allBalls = Widgets.bigButton("All Balls", Widgets.PURPLE, function()
		task.spawn(function()
			local ok = Action.call("AllBalls")
			if not ok and Economy.ALL_BALLS_PASS ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, Economy.ALL_BALLS_PASS)
			end
		end)
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(320, 84),
		TextSize = 44,
		Parent = content,
	})
	local free = Widgets.title("Free", 30, {
		Position = UDim2.fromOffset(30, -26),
		Size = UDim2.fromOffset(100, 36),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(130, 170, 255),
		Parent = allBalls,
	})

	local cards: { Card } = {}
	local shownOptions = ""

	local function refresh()
		local options = player:GetAttribute("DraftOptions")
		local visible = MyMatch.phase() == "Draft" and typeof(options) == "string" and options ~= ""
		root.Visible = visible
		if not visible then
			return
		end

		if options ~= shownOptions then
			shownOptions = options :: string
			for _, card in cards do
				card.button:Destroy()
			end
			table.clear(cards)
			for index, id in string.split(shownOptions, ",") do
				table.insert(cards, makeCard(row, index, id))
			end
			-- Gamepads need a selected button to move between the cards.
			if UserInputService.GamepadEnabled and cards[1] then
				GuiService.SelectedObject = cards[1].button
			end
		end

		local pick = player:GetAttribute("DraftPick")
		local picked = typeof(pick) == "string" and pick ~= ""
		for _, card in cards do
			local chosen = card.id == pick
			card.scale.Scale = if chosen then 1.06 else 1
			card.stroke.Thickness = if chosen then 6 else 2
			card.stroke.Color = if chosen then Widgets.GOLD else Color3.new(1, 1, 1)
			card.button.BackgroundTransparency = if picked and not chosen then 0.6 else 0
			card.icon.frame.ImageTransparency = if picked and not chosen then 0.6 else 0
		end

		-- All Balls: once per round, free once a day or with a voucher (the pass makes it always
		-- available).
		local profile = Profile.get()
		local freeToday = profile ~= nil and profile.freeAllBallsDay ~= Economy.day(workspace:GetServerTimeNow())
		local vouchers = if profile then profile.vouchers or 0 else 0
		local used = player:GetAttribute("AllBallsUsed") == true
		allBalls.Visible = not picked and not used and (freeToday or vouchers > 0 or Economy.ALL_BALLS_PASS ~= 0)
		free.Visible = freeToday or vouchers > 0
		free.Text = if freeToday or vouchers <= 1 then "Free" else `Free x{vouchers}`
	end

	local function tick()
		if not root.Visible then
			return
		end
		local left = math.max(0, math.ceil(MyMatch.timeLeft()))
		title.Text = `CHOOSE YOUR BALL - {left}`
		title.TextColor3 = if left <= 3 then Widgets.BAD else Widgets.TEXT
		for _, card in cards do
			card.icon.spin()
		end
	end

	-- The middle card while you still need to pick (the tutorial points at it).
	local function cardToPick(): GuiObject?
		local pick = player:GetAttribute("DraftPick")
		if not root.Visible or (typeof(pick) == "string" and pick ~= "") then
			return nil
		end
		local card = cards[2] or cards[1]
		return if card then card.button else nil
	end

	return { refresh = refresh, tick = tick, cardToPick = cardToPick }
end

return Draft
