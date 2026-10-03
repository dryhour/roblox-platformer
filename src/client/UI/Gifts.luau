local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Online Rewards, for time played this visit: a bar fills up as you play, and each gift opens
-- after so many minutes (shown as a countdown), then Claim.
local Gifts = {}

type Tile = { button: TextButton, timer: TextLabel }

function Gifts.new(gui: ScreenGui)
	local root, outer = Widgets.window(gui, "Online Rewards", Vector2.new(1100, 420), function()
		Windows.close("Gifts")
	end)
	-- How far through the hour you've played.
	local track = Widgets.create("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Parent = outer,
	}, { Widgets.corner(11) })
	local fill = Widgets.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Widgets.GOLD,
		Parent = track,
	}, { Widgets.corner(11) })
	local content = Widgets.create("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		Parent = outer,
	}, {
		Widgets.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(196, 230),
			CellPadding = UDim2.fromOffset(14, 14),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local tiles: { Tile } = {}
	for index, gift in Economy.GIFTS do
		local name, emoji = Economy.describe(gift.reward)
		local card = Widgets.create("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			Parent = content,
		}, {
			Widgets.corner(8),
			Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
		})
		Widgets.icon(gift.reward.kind, emoji, 70, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Parent = card,
		})
		Widgets.body(name, 20, {
			Position = UDim2.fromOffset(0, 82),
			Size = UDim2.new(1, 0, 0, 26),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		local timer = Widgets.title("", 18, {
			Position = UDim2.fromOffset(0, 108),
			Size = UDim2.new(1, 0, 0, 22),
			AutomaticSize = Enum.AutomaticSize.None,
			TextColor3 = Widgets.MUTED,
			Parent = card,
		})
		local button = Widgets.bigButton("Claim", Widgets.GREEN, function()
			Action.send("ClaimGift", index)
		end, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(150, 44),
			TextSize = 20,
			Parent = card,
		})
		tiles[index] = { button = button, timer = timer }
	end

	local function tick()
		if not root.Visible then
			return
		end
		local session = Profile.session()
		local played = if session then workspace:GetServerTimeNow() - session.joinedAt else 0
		local last = Economy.GIFTS[#Economy.GIFTS].minutes * 60
		fill.Size = UDim2.fromScale(math.clamp(played / last, 0, 1), 1)
		for index, gift in Economy.GIFTS do
			local tile = tiles[index]
			local claimed = session and session.gifts[tostring(index)]
			local left = gift.minutes * 60 - played
			tile.timer.Text = if claimed then "" elseif left > 0 then Widgets.clock(left) else "Ready!"
			tile.button.Text = if claimed then "Claimed" elseif left > 0 then "Wait" else "Claim"
			tile.button.BackgroundColor3 = if not claimed and left <= 0 then Widgets.GREEN else Widgets.GREY
		end
	end

	Windows.register("Gifts", root)
	return { refresh = function() end, tick = tick }
end

return Gifts
