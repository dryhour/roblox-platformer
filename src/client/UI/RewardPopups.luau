local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(script.Parent.Parent.Sounds)
local BallIcon = require(script.Parent.BallIcon)
local Fly = require(script.Parent.Fly)
local Widgets = require(script.Parent.Widgets)

-- Rewards arriving from the server (the Notify remote), one at a time:
--   Roll     a strip of rewards spins past a marker and stops on yours (Skip jumps to the end),
--            then the Receive card shows it; for an x10 roll, all ten show together
--   Receive  a card with the reward's name and picture, glowing rays behind it, and Receive
-- After Receive, items fly into the Inventory button and coins or gems into their counters
-- (see Fly).
local RewardPopups = {}

local TILE = 150
local GAP = 12
local WINDOW_WIDTH = 1000
local SPIN_TIME = 4.5

type Reward = Economy.Reward
type Item = { kind: string, data: any, releases: { [string]: () -> () } }

-- Lets go of any counters held for an item's coins or gems.
local function releaseAll(item: Item)
	for _, release in item.releases do
		release()
	end
end

-- Sends a received reward on its way from `from`: coins and gems to their counters, anything
-- else into the Inventory.
local function flyAway(reward: Reward, from: Vector2, releases: { [string]: () -> () }, delay: number?)
	if reward.kind == "coins" or reward.kind == "gems" then
		Fly.currency(reward.kind, from, releases[reward.kind])
	else
		local _, emoji = Economy.describe(reward)
		Fly.item(emoji, from, delay)
	end
end

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
	Widgets.fit(spinner, WINDOW_WIDTH, 0.96)
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
	Widgets.fit(card, 520, 0.9)
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

	-- All the rewards of an x10 roll, in a grid.
	local summary = Widgets.box({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 50),
		Size = UDim2.fromOffset(820, 470),
		Visible = false,
		Parent = root,
	})
	Widgets.fit(summary, 820, 0.96)
	Widgets.title("You got", 34, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 44),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.GOLD,
		Parent = summary,
	})
	local summaryGrid = Widgets.create("Frame", {
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 0, 300),
		BackgroundTransparency = 1,
		Parent = summary,
	}, {
		Widgets.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(142, 142),
			CellPadding = UDim2.fromOffset(12, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local summaryReceive = Widgets.bigButton("Receive", Widgets.GREEN, function() end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(240, 64),
		TextSize = 34,
		Parent = summary,
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
	summaryReceive.Activated:Connect(function()
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
	local function showCard(reward: Reward, title: string?, releases: { [string]: () -> () })
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
		flyAway(reward, plate.AbsolutePosition + plate.AbsoluteSize / 2, releases)
		card.Visible = false
	end

	-- Shows every reward of a multi-roll and waits until it's closed.
	local function showSummary(rewards: { Reward }, releases: { [string]: () -> () })
		Widgets.clear(summaryGrid)
		for index, reward in rewards do
			local item = tile(reward, index)
			item.Size = UDim2.fromOffset(142, 142)
			Widgets.body(item:GetAttribute("Name") :: string, 16, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 2, 1, -12),
				Size = UDim2.new(1, -4, 0, 20),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextScaled = true,
				TextStrokeTransparency = 0,
				Parent = item,
			})
			item.Parent = summaryGrid
		end
		spinner.Visible = false
		summary.Visible = true
		Sounds.play("Reward")
		select(summaryReceive)
		local closed = false
		closeCard = function()
			closed = true
		end
		while not closed do
			task.wait()
		end
		closeCard = nil
		for index, item in summaryGrid:GetChildren() do
			local reward = if item:IsA("GuiObject") then rewards[item.LayoutOrder] else nil
			if reward then
				flyAway(reward, (item :: GuiObject).AbsolutePosition + (item :: GuiObject).AbsoluteSize / 2, releases, index * 0.04)
			end
		end
		summary.Visible = false
	end

	local function spin(data: any, releases: { [string]: () -> () })
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
		if typeof(data.rewards) == "table" and #data.rewards > 1 then
			showSummary(data.rewards, releases)
		else
			showCard(data.reward, nil, releases)
		end
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
				spin(item.data, item.releases)
			else
				showCard(item.data.reward, item.data.title, item.releases)
			end
			-- Anything that didn't fly (say, the counter was hidden) still counts up.
			task.delay(2, releaseAll, item)
		end
		root.Visible = false
		GuiService.SelectedObject = nil
		busy = false
	end

	Remotes.Notify.OnClientEvent:Connect(function(kind: string, data: any)
		if (kind == "Roll" or kind == "Receive") and typeof(data) == "table" and data.reward then
			-- The coin and gem counters wait for this reward's coins to fly in.
			local releases = {}
			local rewards = if typeof(data.rewards) == "table" then data.rewards else { data.reward }
			for _, reward in rewards do
				if (reward.kind == "coins" or reward.kind == "gems") and not releases[reward.kind] then
					releases[reward.kind] = Fly.hold(reward.kind)
				end
			end
			table.insert(queue, { kind = kind, data = data, releases = releases })
			task.spawn(run)
		end
	end)

	return {
		refresh = function() end,
		tick = function() end,
	}
end

return RewardPopups
