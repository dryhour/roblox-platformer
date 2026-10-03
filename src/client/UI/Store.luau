local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local Profile = require(script.Parent.Parent.Profile)
local BallIcon = require(script.Parent.BallIcon)
local Toast = require(script.Parent.Toast)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- The Store, in tabs:
--   Daily       3 deals that change at midnight UTC (once each per day)
--   Balls       the Coin and Gem Ball Machines, with x1 and x10 rolls and their odds
--   Explosions  the Explosion Machine
--   Flyers      the Flyer Machine
--   Gems        gem packs and the All Balls pass for Robux (only if their ids are set)
-- Rolls play the reward spinner.
local Store = {}

-- Opens the Store at a tab, e.g. Gems from the + next to your gems. (Store.new fills this in.)
function Store.open(_tab: string?)
	Windows.open("Store")
end

local ROBUX = "⏣"
local TABS = { "Daily", "Balls", "Explosions", "Flyers", "Gems" }
local TAB_COLORS = {
	Daily = Color3.fromRGB(60, 190, 120),
	Balls = Color3.fromRGB(240, 170, 40),
	Explosions = Color3.fromRGB(160, 80, 240),
	Flyers = Color3.fromRGB(240, 90, 130),
	Gems = Color3.fromRGB(60, 140, 240),
}

local function card(parent: Instance, order: number, width: number, height: number): Frame
	return Widgets.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Parent = parent,
	}, {
		Widgets.corner(8),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
	})
end

-- A price button: a coin or gem, then the amount.
local function priceButton(parent: Instance, cost: Economy.Cost, label: string?, onClick: () -> (), props: { [string]: any }): TextButton
	local text = if label then `{label}  {cost.amount}` else `{cost.amount}`
	props.Parent = parent
	local button = Widgets.bigButton(`     {text}`, Widgets.GREEN, onClick, props)
	Widgets.icon(cost.currency, "", 28, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Parent = button,
	})
	return button
end

local function roll(machineId: string, count: number)
	task.spawn(function()
		local ok, message = Action.call("Roll", machineId, count)
		if ok then
			Windows.close()
		elseif message then
			Toast.show(message)
		end
	end)
end

local function machineCard(parent: Instance, machine: Economy.Machine, order: number)
	local box = card(parent, order, 360, 420)
	Widgets.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(110, 110),
		BackgroundTransparency = 1,
		Text = machine.emoji,
		TextScaled = true,
		Parent = box,
	})
	Widgets.body(machine.name, 28, {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		Parent = box,
	})
	-- The odds, one line per rarity.
	local odds = Widgets.stack({ Position = UDim2.fromOffset(20, 160), Size = UDim2.new(1, -40, 0, 0) }, 2)
	odds.Parent = box
	if machine.weights then
		for index, entry in Economy.machineOdds(machine) do
			Widgets.body(string.format("%s  %.1f%%", entry.rarity, entry.percent), 22, {
				LayoutOrder = index,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Config.RARITIES[entry.rarity].color,
				Parent = odds,
			})
		end
	else
		Widgets.body("Only ones you don't have yet", 22, {
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Widgets.MUTED,
			Parent = odds,
		})
	end
	local buttons = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -24, 0, 56),
		BackgroundTransparency = 1,
		Parent = box,
	})
	local ten = machine.ten
	priceButton(buttons, machine.one, "x1", function()
		roll(machine.id, 1)
	end, {
		Size = if ten then UDim2.new(0.5, -6, 1, 0) else UDim2.fromScale(1, 1),
		TextSize = 22,
	})
	if ten then
		priceButton(buttons, ten, "x10", function()
			roll(machine.id, 10)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.5, -6, 1, 0),
			TextSize = 22,
		})
	end
end

-- A Robux item: a picture, what you get, and a price button.
local function robuxCard(parent: Instance, order: number, picture: GuiObject, text: string, onBuy: () -> ()): TextButton
	local box = card(parent, order, 190, 190)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 12)
	picture.Parent = box
	Widgets.title(text, 22, {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.CYAN,
		Parent = box,
	})
	return Widgets.bigButton(ROBUX, Widgets.GREEN, onBuy, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(150, 48),
		TextSize = 22,
		Parent = box,
	})
end

-- Fills in a price button once Roblox says how much the item costs.
local function showPrice(button: TextButton, id: number, infoType: Enum.InfoType)
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			button.Text = `{ROBUX} {info.PriceInRobux}`
		end
	end)
end

function Store.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local root, content = Widgets.window(gui, "Store", Vector2.new(940, 640), function()
		Windows.close("Store")
	end)

	-- Tabs along the top, a page for each underneath.
	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local tab = "Daily"
	local function select(name: string)
		tab = name
		for pageName, page in pages do
			page.Visible = pageName == name
		end
		for buttonName, button in tabButtons do
			button.BackgroundTransparency = if buttonName == name then 0 else 0.5
		end
	end
	local tabRow = Widgets.stack({ Size = UDim2.new(1, 0, 0, 56), AutomaticSize = Enum.AutomaticSize.None }, 10, Enum.FillDirection.Horizontal)
	tabRow.Parent = content
	local function page(name: string): Frame
		local frame = Widgets.stack({
			Position = UDim2.fromOffset(0, 70),
			Size = UDim2.new(1, 0, 1, -70),
			AutomaticSize = Enum.AutomaticSize.None,
			Visible = false,
		}, 20, Enum.FillDirection.Horizontal)
		local layout = frame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Wraps = true
		frame.Parent = content
		pages[name] = frame
		return frame
	end

	-- Daily deals
	local daily = page("Daily")
	local dealsTimer = Widgets.title("", 20, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 14),
		Size = UDim2.fromOffset(240, 28),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Widgets.GOLD,
		Parent = content,
	})
	local shownDay = -1
	local dealButtons: { [string]: TextButton } = {}
	local function buildDeals(day: number)
		shownDay = day
		Widgets.clear(daily)
		table.clear(dealButtons)
		for index, deal in Economy.dailyDeals(day) do
			local name, emoji, color = Economy.describe(deal.reward)
			local box = card(daily, index, 270, 400)
			local holder = Widgets.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 14),
				Size = UDim2.fromOffset(170, 170),
				BackgroundTransparency = 1,
				Parent = box,
			})
			if deal.reward.kind == "ball" then
				BallIcon.new({ Size = UDim2.fromScale(1, 1), Parent = holder }).set(deal.reward.id)
			else
				Widgets.icon(deal.reward.kind, emoji, 150, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Parent = holder,
				})
			end
			Widgets.body(name, 28, {
				Position = UDim2.fromOffset(8, 196),
				Size = UDim2.new(1, -16, 0, 64),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = true,
				TextColor3 = color,
				TextStrokeTransparency = 0,
				Parent = box,
			})
			dealButtons[deal.id] = priceButton(box, deal.cost, nil, function()
				task.spawn(function()
					local ok, message = Action.call("BuyDeal", deal.id)
					if not ok and message then
						Toast.show(message)
					end
				end)
			end, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -14),
				Size = UDim2.fromOffset(210, 56),
				TextSize = 24,
			})
		end
	end

	-- Machines
	local pageFor = { Balls = page("Balls"), Explosions = page("Explosions"), Flyers = page("Flyers") }
	for index, machine in Economy.MACHINES do
		machineCard(pageFor[machine.tab], machine, index)
	end

	-- Robux
	local gemsPage = page("Gems")
	local anyRobux = false
	for index, product in Economy.GEM_PRODUCTS do
		if product.id ~= 0 then
			anyRobux = true
			local button = robuxCard(gemsPage, index, Widgets.gem(76), `{product.gems}`, function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
			showPrice(button, product.id, Enum.InfoType.Product)
		end
	end
	if Economy.ALL_BALLS_PASS ~= 0 then
		anyRobux = true
		local picture = Widgets.create("TextLabel", { Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1, Text = "🃏", TextScaled = true })
		local button = robuxCard(gemsPage, 10, picture, "All Balls", function()
			MarketplaceService:PromptGamePassPurchase(player, Economy.ALL_BALLS_PASS)
		end)
		showPrice(button, Economy.ALL_BALLS_PASS, Enum.InfoType.GamePass)
	end

	for index, name in TABS do
		if name == "Gems" and not anyRobux then
			continue
		end
		local button = Widgets.bigButton(name, TAB_COLORS[name], function()
			select(name)
		end, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(160, 52),
			TextSize = 20,
			Parent = tabRow,
		})
		tabButtons[name] = button
	end
	select(tab)

	-- Opens the Store at a tab, e.g. Gems from the + next to your gems.
	function Store.open(name: string?)
		Windows.open("Store")
		select(if name and tabButtons[name] then name else tab)
	end

	local function tick()
		if not root.Visible then
			return
		end
		local now = workspace:GetServerTimeNow()
		local today = Economy.day(now)
		if today ~= shownDay then
			buildDeals(today)
		end
		dealsTimer.Visible = tab == "Daily"
		dealsTimer.Text = `New deals in {Widgets.clock(86400 - now % 86400)}`
		local profile = Profile.get()
		for id, button in dealButtons do
			local bought = profile ~= nil and profile.dealsDay == today and profile.dealsBought[id] == true
			button.Active = not bought
			button.AutoButtonColor = not bought
			button.BackgroundColor3 = if bought then Widgets.GREY else Widgets.GREEN
		end
	end

	Windows.register("Store", root)
	return { refresh = function() end, tick = tick }
end

return Store
