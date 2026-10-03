local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Action = require(script.Parent.Parent.Action)
local Profile = require(script.Parent.Parent.Profile)
local BallIcon = require(script.Parent.BallIcon)
local Toast = require(script.Parent.Toast)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Trading (see src/server/Trading.luau). A request pops up at the top of the screen with Accept
-- and Decline. The trade window shows your offer and theirs side by side; tap balls from your
-- collection underneath to add them, tap your offer to take one back, then press Ready. When
-- both are ready, it counts down and swaps.
local Trade = {}

local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local REQUEST_SHOW_FOR = 30
local SMALL = 96

local function ballTile(parent: Instance, order: number, id: string, count: number, onClick: (() -> ())?): GuiObject
	local brainrot = Brainrots.get(id)
	local button = Widgets.create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(SMALL, SMALL),
		BackgroundColor3 = Widgets.NAVY,
		Text = "",
		AutoButtonColor = onClick ~= nil,
		Parent = parent,
	}, {
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Config.RARITIES[brainrot.rarity].color }),
	})
	local icon = BallIcon.new({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -16), Parent = button })
	icon.set(id)
	Widgets.title(`x{count}`, 18, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -2),
		Size = UDim2.fromOffset(50, 22),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = button,
	})
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

local function gridFrame(parent: Instance, props: { [string]: any }): ScrollingFrame
	local frame = Widgets.create("ScrollingFrame", {
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Widgets.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(SMALL, SMALL),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Widgets.create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6) }),
	})
	for key, value in props do
		(frame :: any)[key] = value
	end
	return frame
end

function Trade.new(gui: ScreenGui)
	-- The request popup
	local request = Widgets.box({
		Name = "TradeRequest",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(460, 150),
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	Widgets.fit(request, 460, 0.8)
	local requestFace = Widgets.create("ImageLabel", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(70, 70),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Parent = request,
	}, { Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local requestText = Widgets.body("", 24, {
		Position = UDim2.fromOffset(96, 14),
		Size = UDim2.new(1, -110, 0, 70),
		AutomaticSize = Enum.AutomaticSize.None,
		TextWrapped = true,
		Parent = request,
	})
	local requestFrom: Player? = nil
	local requestShownAt = 0
	local function answer(accept: boolean)
		local from = requestFrom
		request.Visible = false
		requestFrom = nil
		if from then
			Action.send("TradeRespond", from, accept)
		end
	end
	Widgets.bigButton("Accept", Widgets.GREEN, function()
		answer(true)
	end, {
		Position = UDim2.fromOffset(14, 94),
		Size = UDim2.fromOffset(206, 44),
		TextSize = 22,
		Parent = request,
	})
	Widgets.bigButton("Decline", Widgets.RED, function()
		answer(false)
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 94),
		Size = UDim2.fromOffset(206, 44),
		TextSize = 22,
		Parent = request,
	})

	-- The trade window
	local root, content = Widgets.window(gui, "Trade", Vector2.new(900, 620), function()
		Action.send("TradeCancel")
		Windows.close("Trade")
	end)
	Widgets.title("You", 22, {
		Size = UDim2.new(0.5, -8, 0, 28),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = content,
	})
	local theirTitle = Widgets.title("", 22, {
		Position = UDim2.new(0.5, 8, 0, 0),
		Size = UDim2.new(0.5, -8, 0, 28),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = content,
	})
	local mine = gridFrame(content, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(0.5, -8, 0, 220) })
	local theirs = gridFrame(content, { Position = UDim2.new(0.5, 8, 0, 32), Size = UDim2.new(0.5, -8, 0, 220) })
	local myStatus = Widgets.title("", 20, {
		Position = UDim2.fromOffset(0, 256),
		Size = UDim2.new(0.5, -8, 0, 26),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = content,
	})
	local theirStatus = Widgets.title("", 20, {
		Position = UDim2.new(0.5, 8, 0, 256),
		Size = UDim2.new(0.5, -8, 0, 26),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = content,
	})
	Widgets.body("Your balls: tap to add", 20, {
		Position = UDim2.fromOffset(0, 288),
		Size = UDim2.new(1, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.MUTED,
		Parent = content,
	})
	local collection = gridFrame(content, { Position = UDim2.fromOffset(0, 316), Size = UDim2.new(1, -220, 1, -316) })
	local countdown = Widgets.title("", 26, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 330),
		Size = UDim2.fromOffset(200, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.GOLD,
		Parent = content,
	})
	local view: any = nil
	local ready = Widgets.bigButton("Ready", Widgets.GREEN, function()
		if view then
			Action.send("TradeReady", not view.myReady)
		end
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(200, 70),
		TextSize = 32,
		Parent = content,
	})

	local function rebuild()
		if not view then
			return
		end
		theirTitle.Text = view.partner and view.partner.DisplayName or ""
		Widgets.clear(mine)
		Widgets.clear(theirs)
		Widgets.clear(collection)
		local order = 0
		for id, count in view.mine do
			order += 1
			ballTile(mine, order, id, count, function()
				Action.send("TradeOffer", id, -1)
			end)
		end
		for id, count in view.theirs do
			order += 1
			ballTile(theirs, order, id, count, nil)
		end
		local profile = Profile.get()
		if profile then
			for index, brainrot in Brainrots.list do
				local left = (profile.balls[brainrot.id] or 0) - (view.mine[brainrot.id] or 0)
				if left > 0 and not profile.locked[brainrot.id] then
					ballTile(collection, index, brainrot.id, left, function()
						Action.send("TradeOffer", brainrot.id, 1)
					end)
				end
			end
		end
		myStatus.Text = if view.myReady then "Ready ✓" else "Not ready"
		myStatus.TextColor3 = if view.myReady then Widgets.GREEN else Widgets.MUTED
		theirStatus.Text = if view.theirReady then "Ready ✓" else "Not ready"
		theirStatus.TextColor3 = if view.theirReady then Widgets.GREEN else Widgets.MUTED
		ready.Text = if view.myReady then "Unready" else "Ready"
		ready.BackgroundColor3 = if view.myReady then Widgets.GREY else Widgets.GREEN
	end

	Remotes.Trade.OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Request" and typeof(data) == "Instance" and data:IsA("Player") then
			requestFrom = data
			requestShownAt = os.clock()
			requestFace.Image = string.format(HEADSHOT, data.UserId)
			requestText.Text = `{data.DisplayName} wants to trade`
			request.Visible = true
		elseif kind == "Update" and typeof(data) == "table" then
			view = data
			if Windows.current() ~= "Trade" then
				Windows.open("Trade")
			end
			rebuild()
		elseif kind == "Closed" then
			view = nil
			Windows.close("Trade")
			if data == "Done" then
				Toast.show("Trade complete!")
			elseif typeof(data) == "string" then
				Toast.show(if data == "Cancelled" then "Trade cancelled" else data)
			end
		end
	end)
	Profile.changed:Connect(function()
		if root.Visible then
			rebuild()
		end
	end)

	Windows.register("Trade", root)

	local function tick()
		if request.Visible and os.clock() - requestShownAt > REQUEST_SHOW_FOR then
			answer(false)
		end
		if root.Visible and view then
			local left = view.confirmAt - workspace:GetServerTimeNow()
			countdown.Text = if view.confirmAt > 0 and left > 0 then `Trading in {math.ceil(left)}` else ""
		end
	end

	return { refresh = function() end, tick = tick }
end

return Trade
