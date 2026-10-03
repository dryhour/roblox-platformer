local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Economy = require(Shared:WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local Profile = require(script.Parent.Parent.Profile)
local BallIcon = require(script.Parent.BallIcon)
local Toast = require(script.Parent.Toast)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- The Inventory, with four tabs:
--   Balls       what you own (with how many, and a lock so it can't be traded or fused), then
--               what you don't; View All shows each ball's chance from the Ball Machine
--   Explosions  knockout effects; pick one and Equip it
--   Flyers      things to ride; Equip or Unequip
--   Fusion      fuse 3 of one ball into a random ball one rarity up
-- Beside it: the limited gem pack (if set up) and an Invite button (a friend joining from your
-- invite earns you a free ball).
local Inventory = {}

local TILE = 132
local TAB_COLORS = {
	Balls = Color3.fromRGB(240, 170, 40),
	Explosions = Color3.fromRGB(160, 80, 240),
	Flyers = Color3.fromRGB(240, 90, 130),
	Fusion = Color3.fromRGB(60, 120, 230),
}
local TAB_EMOJIS = { Balls = "🔴", Explosions = "💥", Flyers = "🛸", Fusion = "🔄" }
local TABS = { "Balls", "Explosions", "Flyers", "Fusion" }

type Item = { id: string, name: string, emoji: string, rarity: string, description: string, kind: string }

local function items(tab: string): { Item }
	local list = {}
	if tab == "Balls" or tab == "Fusion" then
		for _, brainrot in Brainrots.list do
			table.insert(list, { id = brainrot.id, name = brainrot.name, emoji = brainrot.emoji, rarity = brainrot.rarity, description = brainrot.description, kind = "ball" })
		end
	elseif tab == "Flyers" then
		for _, flyer in Cosmetics.flyers do
			table.insert(list, { id = flyer.id, name = flyer.name, emoji = flyer.emoji, rarity = flyer.rarity, description = flyer.description, kind = "flyer" })
		end
	else
		for _, explosion in Cosmetics.explosions do
			table.insert(list, { id = explosion.id, name = explosion.name, emoji = explosion.emoji, rarity = explosion.rarity, description = explosion.description, kind = "explosion" })
		end
	end
	return list
end

local function owned(profile: any, item: Item): number
	if not profile then
		return 0
	elseif item.kind == "ball" then
		return profile.balls[item.id] or 0
	elseif item.kind == "flyer" then
		return if profile.flyers[item.id] then 1 else 0
	end
	return if profile.explosions[item.id] then 1 else 0
end

-- Each ball's chance from the Ball Machine, as a percent.
local function ballChance(id: string): number
	local total = 0
	for _, brainrot in Brainrots.list do
		total += Config.RARITIES[brainrot.rarity].weight
	end
	return Config.RARITIES[Brainrots.get(id).rarity].weight / total * 100
end

function Inventory.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local root, content = Widgets.window(gui, "Inventory", Vector2.new(900, 600), function()
		Windows.close("Inventory")
	end)
	-- A little left of center, to leave room for the offers beside it.
	root.Position = UDim2.fromScale(0.44, 0.52)
	Widgets.fit(root, 900 + 16 + 180 + 60, 0.88)

	local tab = "Balls"
	local selected: Item? = nil
	local viewAll = false
	local tabButtons = {}

	-- Tabs
	for index, name in TABS do
		local button = Widgets.create("TextButton", {
			Position = UDim2.fromOffset(100 + (index - 1) * 165, 0),
			Size = UDim2.fromOffset(155, 70),
			BackgroundColor3 = TAB_COLORS[name],
			Text = "",
			Parent = content,
		}, {
			Widgets.corner(6),
			Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Color3.fromRGB(20, 20, 30) }),
		})
		Widgets.create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -18),
			Size = UDim2.fromOffset(56, 56),
			BackgroundTransparency = 1,
			Text = TAB_EMOJIS[name],
			TextScaled = true,
			Parent = button,
		})
		Widgets.body(name, 26, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 34),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0,
			Parent = button,
		})
		tabButtons[name] = button
	end

	local grid = Widgets.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, -310, 1, -80),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		Widgets.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE, TILE),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Widgets.create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})

	-- Details
	local detail = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 80),
		Size = UDim2.new(0, 290, 1, -80),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		BackgroundTransparency = 0.3,
		Parent = content,
	})
	local detailName = Widgets.body("", 30, {
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		TextStrokeTransparency = 0,
		Parent = detail,
	})
	local pictureHolder = Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		Parent = detail,
	})
	local detailBall = BallIcon.new({ Size = UDim2.fromScale(1, 1), Parent = pictureHolder })
	local detailEmoji = Widgets.create("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Parent = pictureHolder })
	local detailRarity = Widgets.body("", 26, {
		Position = UDim2.fromOffset(8, 206),
		Size = UDim2.new(1, -16, 0, 30),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = detail,
	})
	local detailText = Widgets.body("", 21, {
		Position = UDim2.fromOffset(12, 240),
		Size = UDim2.new(1, -24, 0, 60),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = detail,
	})
	local actionButton = Widgets.bigButton("", Widgets.BLUE, function() end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(250, 60),
		TextSize = 28,
		Parent = detail,
	})

	-- Beside the window: the limited pack and Invite.
	local side = Widgets.create("Frame", {
		Position = UDim2.new(1, 16, 0, 60),
		Size = UDim2.fromOffset(180, 520),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local offerTimer = Widgets.title("", 22, { Size = UDim2.new(1, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.None, Parent = side })
	local offer = Widgets.create("TextButton", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromOffset(180, 190),
		BackgroundColor3 = Color3.fromRGB(110, 60, 200),
		Text = "",
		Parent = side,
	}, {
		Widgets.corner(8),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 3, Color = Color3.fromRGB(30, 20, 60) }),
	})
	Widgets.gem(110, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = offer })
	Widgets.title(`{Economy.OFFER.gems}`, 26, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 30),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.CYAN,
		Parent = offer,
	})
	local offerPrice = Widgets.title("⏣", 26, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 30),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = offer,
	})
	offer.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(player, Economy.OFFER.id)
	end)
	if Economy.OFFER.id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Economy.OFFER.id, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				offerPrice.Text = `⏣ {info.PriceInRobux}`
			end
		end)
	end

	local invite = Widgets.create("TextButton", {
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.fromOffset(180, 190),
		BackgroundColor3 = Widgets.NAVY,
		Text = "",
		Parent = side,
	}, {
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 3, Color = Widgets.EDGE }),
	})
	Widgets.create("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(110, 110), BackgroundTransparency = 1, Text = "✉️", TextScaled = true, Parent = invite })
	Widgets.title("Invite", 34, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 44), AutomaticSize = Enum.AutomaticSize.None, Parent = invite })
	Widgets.title("Free Ball +1", 24, {
		Position = UDim2.fromOffset(-10, -34),
		Size = UDim2.new(1, 30, 0, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		Rotation = 10,
		TextColor3 = Color3.fromRGB(255, 60, 50),
		Parent = invite,
	})
	invite.Activated:Connect(function()
		task.spawn(function()
			local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and canInvite then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			end
		end)
	end)

	local function showDetail(profile: any)
		local item = selected
		detail.Visible = item ~= nil
		if not item then
			return
		end
		local count = owned(profile, item)
		detailName.Text = item.name
		detailBall.set(if item.kind == "ball" then item.id else nil)
		detailEmoji.Text = if item.kind == "ball" then "" else item.emoji
		detailRarity.Text = item.rarity
		detailRarity.TextColor3 = Config.RARITIES[item.rarity].color
		detailText.Text = item.description
		actionButton.Visible = true
		actionButton.AutoButtonColor = true
		if tab == "Balls" then
			actionButton.Text = if viewAll then "My Balls" else "View All"
			actionButton.BackgroundColor3 = Widgets.BLUE
		elseif tab == "Fusion" then
			local next = Economy.nextRarity(item.rarity)
			actionButton.Text = if next then `Fuse {math.min(count, Economy.FUSE_COUNT)}/{Economy.FUSE_COUNT}` else "Rarest"
			actionButton.BackgroundColor3 = if next and count >= Economy.FUSE_COUNT then Widgets.GREEN else Widgets.GREY
			detailText.Text = if next then `Fuse {Economy.FUSE_COUNT} into a random {next} ball.` else "Can't fuse the rarest balls."
		elseif count == 0 then
			actionButton.Text = "Locked"
			actionButton.BackgroundColor3 = Widgets.GREY
		else
			local equipped = if item.kind == "flyer" then profile.flyer == item.id else profile.explosion == item.id
			actionButton.Text = if equipped then (if item.kind == "flyer" then "Unequip" else "Equipped") else "Equip"
			actionButton.BackgroundColor3 = if equipped then Widgets.GREY else Widgets.GREEN
		end
	end

	local function tile(item: Item, order: number, count: number, profile: any): TextButton
		local rarityColor = Config.RARITIES[item.rarity].color
		local button = Widgets.create("TextButton", {
			LayoutOrder = order,
			BackgroundColor3 = Widgets.NAVY,
			BackgroundTransparency = if count > 0 then 0 else 0.3,
			Text = "",
			Parent = grid,
		}, {
			Widgets.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = if selected and selected.id == item.id then 5 else 2,
				Color = if count > 0 then Widgets.EDGE else rarityColor,
			}),
		})
		if item.kind == "ball" then
			local icon = BallIcon.new({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -32, 1, -40), Parent = button })
			icon.set(item.id)
			icon.frame.ImageTransparency = if count > 0 then 0 else 0.5
		else
			Widgets.create("TextLabel", {
				Position = UDim2.fromOffset(20, 8),
				Size = UDim2.new(1, -40, 1, -44),
				BackgroundTransparency = 1,
				Text = item.emoji,
				TextScaled = true,
				TextTransparency = if count > 0 then 0 else 0.5,
				Parent = button,
			})
		end
		Widgets.body(item.name, 17, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -4),
			Size = UDim2.new(1, -8, 0, 22),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			TextStrokeTransparency = 0,
			Parent = button,
		})
		if item.kind == "ball" and (count > 0 or viewAll) then
			Widgets.title(if viewAll then string.format("%.1f%%", ballChance(item.id)) else `x{count}`, 20, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -28),
				Size = UDim2.fromOffset(70, 24),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = button,
			})
		end
		if item.kind == "ball" and count > 0 and tab == "Balls" and not viewAll then
			local locked = profile.locked[item.id] == true
			local lock = Widgets.create("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(32, 32),
				BackgroundTransparency = 1,
				Text = if locked then "🔒" else "🔓",
				TextScaled = true,
				Parent = button,
			})
			lock.Activated:Connect(function()
				Action.send("Lock", item.id)
			end)
		end
		button.Activated:Connect(function()
			selected = item
			Inventory.rebuild()
		end)
		return button
	end

	function Inventory.rebuild()
		local profile = Profile.get()
		for name, button in tabButtons do
			button.BackgroundTransparency = if name == tab then 0 else 0.45
		end
		Widgets.clear(grid)
		local list = items(tab)
		local order = 0
		local function add(item: Item, count: number)
			order += 1
			tile(item, order, count, profile)
		end
		if viewAll and tab == "Balls" then
			for _, item in list do
				add(item, owned(profile, item))
			end
		else
			for _, item in list do
				if owned(profile, item) > 0 then
					add(item, owned(profile, item))
				end
			end
			if tab ~= "Fusion" then
				local any = false
				for _, item in list do
					if owned(profile, item) == 0 then
						if not any then
							any = true
							order += 1
							local divider = Widgets.title("—Unowned—", 26, {
								LayoutOrder = order,
								BackgroundTransparency = 1,
								Parent = grid,
							})
							-- Grid cells are tile sized; a tall divider would leave a hole, so it sits in one.
							divider.TextScaled = true
						end
						add(item, 0)
					end
				end
			end
		end
		if selected and selected.kind ~= (if tab == "Flyers" then "flyer" elseif tab == "Explosions" then "explosion" else "ball") then
			selected = nil
		end
		if not selected then
			selected = list[1]
		end
		showDetail(profile)
	end

	actionButton.Activated:Connect(function()
		local item = selected
		local profile = Profile.get()
		if not item or not profile then
			return
		end
		if tab == "Balls" then
			viewAll = not viewAll
			Inventory.rebuild()
		elseif tab == "Fusion" then
			task.spawn(function()
				local ok, message = Action.call("Fuse", item.id)
				if not ok and message then
					Toast.show(message)
				end
			end)
		elseif owned(profile, item) > 0 then
			if item.kind == "flyer" then
				Action.send("Equip", "flyer", if profile.flyer == item.id then "" else item.id)
			else
				Action.send("Equip", "explosion", item.id)
			end
		end
	end)

	for name, button in tabButtons do
		button.Activated:Connect(function()
			tab = name
			selected = nil
			viewAll = false
			Inventory.rebuild()
		end)
	end

	Profile.changed:Connect(function()
		if root.Visible then
			Inventory.rebuild()
		end
	end)
	Windows.register("Inventory", root, Inventory.rebuild)

	local function tick()
		if not root.Visible then
			return
		end
		detailBall.spin()
		local profile = Profile.get()
		local left = if profile then profile.offerEndsAt - workspace:GetServerTimeNow() else 0
		local showOffer = Economy.OFFER.id ~= 0 and left > 0
		offer.Visible = showOffer
		offerTimer.Visible = showOffer
		offerTimer.Text = Widgets.clock(left)
	end

	return { refresh = function() end, tick = tick }
end

return Inventory
