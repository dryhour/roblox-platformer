local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Looks = require(Shared:WaitForChild("Looks"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local MyMatch = require(script.Parent.Parent.MyMatch)
local Widgets = require(script.Parent.Widgets)

-- The draft: three cards, each showing a ball spinning, its rarity (colored border and stars),
-- its health, speed and power, and its ability's icon. Tap one to pick it.
local Draft = {}

local CARD_WIDTH = 180
local CARD_HEIGHT = 250
local SPIN_SPEED = 1 -- radians per second, for the ball previews

type Card = { button: TextButton, stroke: UIStroke, scale: UIScale, viewport: ViewportFrame, look: Model, id: string }

local function preview(parent: GuiObject, id: string): (ViewportFrame, Model)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 0, 120)
	viewport.BackgroundTransparency = 1
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.Parent = parent

	local look = Looks.build(id)
	Looks.place(look, CFrame.new())
	look.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	-- Looks face -Z, so the camera sits in front at -Z.
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 3, -19), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, look
end

local function makeCard(parent: GuiObject, order: number, id: string): Card
	local brainrot = Brainrots.get(id)
	local rarity = Config.RARITIES[brainrot.rarity]

	local button = Widgets.create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = Widgets.PANEL,
		BackgroundTransparency = 0.05,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, { Widgets.corner(14) })
	local stroke = Widgets.create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = rarity.color,
		Thickness = 4,
		Parent = button,
	})
	local scale = Widgets.create("UIScale", { Parent = button })

	local content = Widgets.stack({ Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = button }, 2)
	Widgets.create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = content })

	local viewport, look = preview(content, id)
	viewport.LayoutOrder = 1
	local function line(order2: number, text: string, size: number, color: Color3?)
		Widgets.label(text, size, {
			LayoutOrder = order2,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color or Widgets.TEXT,
			Parent = content,
		})
	end
	line(2, string.rep("★", rarity.stars), 18, rarity.color)
	line(3, brainrot.name, 15)
	line(4, `❤️ {brainrot.stats.health}   ⚡ {brainrot.stats.speed}`, 15, Widgets.MUTED)
	line(5, `{brainrot.skillIcon} {brainrot.skillHint}`, 18, Widgets.ACCENT)

	button.Activated:Connect(function()
		Remotes.Draft:FireServer(id)
	end)
	return { button = button, stroke = stroke, scale = scale, viewport = viewport, look = look, id = id }
end

function Draft.new(gui: ScreenGui)
	local player = Players.LocalPlayer

	local root = Widgets.stack({
		Name = "Draft",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(CARD_WIDTH * 3 + 40, 0),
		Parent = gui,
	}, 10)
	local row = Widgets.stack({
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		Parent = root,
	}, 20, Enum.FillDirection.Horizontal)
	local track = Widgets.create("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Widgets.BUTTON,
		BorderSizePixel = 0,
		Parent = root,
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
			card.stroke.Thickness = if chosen then 7 else 4
			card.button.BackgroundTransparency = if picked and not chosen then 0.6 else 0.05
			card.viewport.ImageTransparency = if picked and not chosen then 0.6 else 0
		end
	end

	local function tick()
		if not root.Visible then
			return
		end
		bar.Size = UDim2.fromScale(math.clamp(MyMatch.timeLeft() / Config.DRAFT_TIME, 0, 1), 1)
		local spin = CFrame.Angles(0, os.clock() * SPIN_SPEED, 0)
		for _, card in cards do
			Looks.place(card.look, spin)
		end
	end

	return { refresh = refresh, tick = tick }
end

return Draft
