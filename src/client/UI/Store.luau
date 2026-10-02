local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local Toast = require(script.Parent.Toast)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- The Store: three machines (balls for coins; flyers and explosions for gems), each rolling one
-- random thing with the reward spinner, and under them gem packs and the All Balls pass for
-- Robux, if their ids are set in Economy.
local Store = {}

local ROBUX = "⏣"

local function machineCard(parent: Instance, machine: any, order: number)
	local card = Widgets.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(250, 280),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Parent = parent,
	}, {
		Widgets.corner(8),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
	})
	Widgets.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(130, 130),
		BackgroundTransparency = 1,
		Text = machine.emoji,
		TextScaled = true,
		Parent = card,
	})
	Widgets.body(machine.name, 26, {
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 0, 32),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		Parent = card,
	})
	local cost = machine.cost
	local button = Widgets.bigButton(`   {cost.amount}`, Widgets.GREEN, function()
		task.spawn(function()
			local ok, message = Action.call("Roll", machine.id)
			if ok then
				Windows.close()
			elseif message then
				Toast.show(message)
			end
		end)
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(180, 56),
		TextSize = 28,
		Parent = card,
	})
	Widgets.icon(cost.currency, "", 32, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Parent = button,
	})
end

-- A Robux item: a picture, what you get, and a price button.
local function robuxCard(parent: Instance, order: number, picture: GuiObject, text: string, onBuy: () -> ()): TextButton
	local card = Widgets.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(170, 150),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Parent = parent,
	}, {
		Widgets.corner(8),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
	})
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 8)
	picture.Parent = card
	Widgets.title(text, 20, {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.CYAN,
		Parent = card,
	})
	local price = Widgets.bigButton(ROBUX, Widgets.GREEN, onBuy, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(130, 44),
		TextSize = 22,
		Parent = card,
	})
	return price
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
	local root, content = Widgets.window(gui, "Store", Vector2.new(880, 620), function()
		Windows.close("Store")
	end)

	local layout = Widgets.stack({ Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = content }, 14)
	local machines = Widgets.stack({ LayoutOrder = 1 }, 20, Enum.FillDirection.Horizontal)
	machines.Parent = layout
	local machinesLayout = machines:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	machinesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for index, machine in Economy.MACHINES do
		machineCard(machines, machine, index)
	end

	local robux = Widgets.stack({ LayoutOrder = 2 }, 14, Enum.FillDirection.Horizontal)
	robux.Parent = layout
	local robuxLayout = robux:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	robuxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local anyRobux = false
	for index, product in Economy.GEM_PRODUCTS do
		if product.id ~= 0 then
			anyRobux = true
			local button = robuxCard(robux, index, Widgets.gem(60), `{product.gems}`, function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
			showPrice(button, product.id, Enum.InfoType.Product)
		end
	end
	if Economy.ALL_BALLS_PASS ~= 0 then
		anyRobux = true
		local picture = Widgets.create("TextLabel", { Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Text = "⚽", TextScaled = true })
		local button = robuxCard(robux, 10, picture, "All Balls", function()
			MarketplaceService:PromptGamePassPurchase(player, Economy.ALL_BALLS_PASS)
		end)
		showPrice(button, Economy.ALL_BALLS_PASS, Enum.InfoType.GamePass)
	end
	robux.Visible = anyRobux

	Windows.register("Store", root)
	return { refresh = function() end, tick = function() end }
end

return Store
