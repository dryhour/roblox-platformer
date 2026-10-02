local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(script.Parent.Parent.Sounds)
local BallIcon = require(script.Parent.BallIcon)
local Widgets = require(script.Parent.Widgets)

-- Rewards arriving from the server (the Notify remote), one at a time:
--   Roll     a strip of rewards spins past a marker and stops on yours (Skip jumps to the end),
--            then the Receive card shows it
--   Receive  a card with the reward's name and picture, glowing rays behind it, and Receive
local RewardPopups = {}

local TILE = 150
local GAP = 12
local WINDOW_WIDTH = 1000
local SPIN_TIME = 4.5

type Reward = Economy.Reward
type Item = { kind: string, data: any }

local function tile(reward: Reward, order: number): Frame
	local name, emoji, color = Economy.describe(reward)
	local frame = Widgets.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(TILE, TILE),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
	}, {
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
	})
	Widgets.icon(reward.kind, emoji, 96, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Parent = frame,
	})
	Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = frame,
	})
	frame:SetAttribute("Name", name)
	return frame
end

function RewardPopups.new(gui: ScreenGui)
	local root = Widgets.create("Frame", {
		Name = "Rewards",
		Position = UDim2.fromOffset(0, -100),
		Size = UDim2.new(1, 0, 1, 100),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})

	-- The spinner
	local spinner = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 50),
		Size = UDim2.fromOffset(1000, 420),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Widgets.fit(spinner)
	local window = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(WINDOW_WIDTH, TILE + 24),
		BackgroundColor3 = Widgets.NAVY,
		ClipsDescendants = true,
		Parent = spinner,
	}, {
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 3, Color = Widgets.EDGE }),
	})
	local strip = Widgets.create("Frame", {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(0, 0, 0, TILE),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		Widgets.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = Widgets.GOLD,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = window,
	})
	local skip = Widgets.bigButton("Skip", Widgets.PURPLE, function() end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(300, 90),
		TextSize = 54,
		Parent = spinner,
	})

	-- The Receive card
	local card = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 50),
		Size = UDim2.fromOffset(320, 360),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	Widgets.fit(card)
	local rays = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(520, 520),
		BackgroundTransparency = 1,
		Parent = card,
	})
	for index = 1, 8 do
		Widgets.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 60),
			Rotation = index * 22.5,
			BackgroundColor3 = Color3.fromRGB(160, 90, 255),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Parent = rays,
		}, {
			Widgets.create("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}) }),
		})
	end
	local plate = Widgets.box({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(300, 300),
		Parent = card,
	})
	local heading = Widgets.title("", 24, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(400, 34),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.GOLD,
		Parent = card,
	})
	local cardName = Widgets.body("", 32, {
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		Parent = plate,
	})
	local pictureHolder = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(200, 200),
		BackgroundTransparency = 1,
		Parent = plate,
	})
	local ballPicture = BallIcon.new({ Size = UDim2.fromScale(1, 1), Parent = pictureHolder })
	local picture: GuiObject? = nil
	local receive = Widgets.bigButton("Receive", Widgets.GREEN, function() end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(240, 64),
		TextSize = 34,
		Parent = card,
	})

	local queue: { Item } = {}
	local busy = false
	local finishSpin: (() -> ())? = nil
	local closeCard: (() -> ())? = nil

	skip.Activated:Connect(function()
		if finishSpin then
			finishSpin()
		end
	end)
	receive.Activated:Connect(function()
		if closeCard then
			closeCard()
		end
	end)

	local function select(button: GuiObject)
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = button
		end
	end

	-- Shows the Receive card and waits until it's closed.
	local function showCard(reward: Reward, title: string?)
		local name, emoji, color = Economy.describe(reward)
		heading.Text = title or ""
		cardName.Text = name
		cardName.TextColor3 = color
		ballPicture.set(if reward.kind == "ball" then reward.id else nil)
		if picture then
			picture:Destroy()
			picture = nil
		end
		if reward.kind ~= "ball" then
			local icon = Widgets.icon(reward.kind, emoji, 170, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
			icon.Parent = pictureHolder
			picture = icon
		end
		spinner.Visible = false
		card.Visible = true
		Sounds.play("Reward")
		select(receive)
		local closed = false
		closeCard = function()
			closed = true
		end
		while not closed do
			rays.Rotation = os.clock() * 25
			ballPicture.spin()
			task.wait()
		end
		closeCard = nil
		card.Visible = false
	end

	local function spin(data: any)
		Widgets.clear(strip)
		for index, reward in data.strip do
			tile(reward, index).Parent = strip
		end
		spinner.Visible = true
		card.Visible = false
		select(skip)
		-- Ends with the winning tile centered under the marker, a little off-center for suspense.
		local center = WINDOW_WIDTH / 2
		local target = (data.index - 1) * (TILE + GAP) + TILE / 2 - center + math.random(-TILE // 3, TILE // 3)
		strip.Position = UDim2.fromOffset(0, 12)
		local done = false
		local tween = TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(-target, 12),
		})
		finishSpin = function()
			tween:Cancel()
			strip.Position = UDim2.fromOffset(-target, 12)
			done = true
		end
		tween.Completed:Connect(function()
			done = true
		end)
		tween:Play()
		local lastTile = 0
		while not done do
			local passed = math.floor((-strip.Position.X.Offset + center) / (TILE + GAP))
			if passed ~= lastTile then
				lastTile = passed
				Sounds.play("Tick")
			end
			task.wait()
		end
		finishSpin = nil
		task.wait(0.4)
		showCard(data.reward)
	end

	local function run()
		if busy then
			return
		end
		busy = true
		while #queue > 0 do
			local item = table.remove(queue, 1) :: Item
			root.Visible = true
			if item.kind == "Roll" then
				spin(item.data)
			else
				showCard(item.data.reward, item.data.title)
			end
		end
		root.Visible = false
		GuiService.SelectedObject = nil
		busy = false
	end

	Remotes.Notify.OnClientEvent:Connect(function(kind: string, data: any)
		if (kind == "Roll" or kind == "Receive") and typeof(data) == "table" and data.reward then
			table.insert(queue, { kind = kind, data = data })
			task.spawn(run)
		end
	end)

	return {
		refresh = function() end,
		tick = function() end,
	}
end

return RewardPopups
