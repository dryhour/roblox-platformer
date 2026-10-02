local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local MyMatch = require(script.Parent.Parent.MyMatch)
local BallIcon = require(script.Parent.BallIcon)
local Widgets = require(script.Parent.Widgets)

-- The draft: the screen dims, a big countdown shows at the top, and three cards appear, each
-- with a ball's name, the ball spinning, its rarity (colored border and stars), its health and
-- speed, and its ability's icon. Tap one to pick it.
local Draft = {}

local CARD_WIDTH = 190
local CARD_HEIGHT = 280
local GAP = 24
local CARD = Color3.fromRGB(14, 18, 38)
local PREVIEW = Color3.fromRGB(46, 54, 84)
local DIM = Color3.fromRGB(6, 8, 20)

type Card = { button: TextButton, stroke: UIStroke, scale: UIScale, icon: BallIcon.BallIcon, id: string }

local function makeCard(parent: GuiObject, order: number, id: string): Card
	local brainrot = Brainrots.get(id)
	local rarity = Config.RARITIES[brainrot.rarity]

	local button = Widgets.create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = CARD,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, { Widgets.corner(10) })
	local stroke = Widgets.create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = rarity.color,
		Thickness = 3,
		Parent = button,
	})
	local scale = Widgets.create("UIScale", { Parent = button })

	local content = Widgets.stack({ Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = button }, 6)
	local layout = content:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Widgets.create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = content })

	local function line(lineOrder: number, text: string, size: number, color: Color3?)
		Widgets.label(text, size, {
			LayoutOrder = lineOrder,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color or Widgets.TEXT,
			Parent = content,
		})
	end
	line(1, brainrot.name, 16)
	local preview = Widgets.create("Frame", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = PREVIEW,
		Parent = content,
	}, { Widgets.corner(6) })
	local icon = BallIcon.new({ Size = UDim2.fromScale(1, 1), Parent = preview })
	icon.set(id)
	line(3, string.rep("★", rarity.stars), 18, rarity.color)
	line(4, `❤️ {brainrot.stats.health}   ⚡ {brainrot.stats.speed}`, 15, Widgets.MUTED)
	line(5, `{brainrot.skillIcon} {brainrot.skillHint}`, 18, Widgets.ACCENT)

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
	local content = Widgets.stack({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 50),
		Size = UDim2.fromOffset(CARD_WIDTH * 3 + GAP * 2, 0),
		Parent = root,
	}, 16)
	Widgets.fit(content)

	local countdown = Widgets.label("", 56, {
		LayoutOrder = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		Parent = content,
	})
	countdown.FontFace = Widgets.TITLE_FONT
	local row = Widgets.stack({
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		Parent = content,
	}, GAP, Enum.FillDirection.Horizontal)
	local track = Widgets.create("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Widgets.BUTTON,
		BorderSizePixel = 0,
		Parent = content,
	}, { Widgets.corner(5) })
	local bar = Widgets.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Widgets.ACCENT,
		BorderSizePixel = 0,
		Parent = track,
	}, { Widgets.corner(5) })

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
			card.scale.Scale = if chosen then 1.08 else 1
			card.stroke.Thickness = if chosen then 7 else 3
			card.button.BackgroundTransparency = if picked and not chosen then 0.6 else 0
			card.icon.frame.ImageTransparency = if picked and not chosen then 0.6 else 0
		end
	end

	local function tick()
		if not root.Visible then
			return
		end
		local left = MyMatch.timeLeft()
		countdown.Text = tostring(math.max(0, math.ceil(left)))
		countdown.TextColor3 = if left <= 3 then Widgets.BAD else Widgets.TEXT
		bar.Size = UDim2.fromScale(math.clamp(left / Config.DRAFT_TIME, 0, 1), 1)
		for _, card in cards do
			card.icon.spin()
		end
	end

	return { refresh = refresh, tick = tick }
end

return Draft
