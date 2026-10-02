local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Economy = require(Shared:WaitForChild("Economy"))
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Your profile, from the avatar button: level and XP, wins and matches, and how much of each
-- collection you have.
local ProfileWindow = {}

local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"

local function count(map: { [string]: any }): number
	local total = 0
	for _, value in map do
		if value == true or (typeof(value) == "number" and value > 0) then
			total += 1
		end
	end
	return total
end

function ProfileWindow.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local root, content = Widgets.window(gui, "Profile", Vector2.new(620, 460), function()
		Windows.close("Profile")
	end)
	local face = Widgets.create("ImageLabel", {
		Size = UDim2.fromOffset(130, 130),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Image = string.format(HEADSHOT, player.UserId),
		Parent = content,
	}, {
		Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Widgets.create("UIStroke", { Thickness = 4, Color = Widgets.EDGE }),
	})
	face.Name = "Face"
	Widgets.title(player.DisplayName, 30, {
		Position = UDim2.fromOffset(150, 6),
		Size = UDim2.new(1, -150, 0, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	local level = Widgets.title("", 24, {
		Position = UDim2.fromOffset(150, 52),
		Size = UDim2.new(1, -150, 0, 30),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Widgets.GOLD,
		Parent = content,
	})
	local track = Widgets.create("Frame", {
		Position = UDim2.fromOffset(150, 92),
		Size = UDim2.new(1, -150, 0, 26),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Parent = content,
	}, { Widgets.corner(13) })
	local fill = Widgets.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Widgets.GREEN,
		Parent = track,
	}, { Widgets.corner(13) })
	local xpText = Widgets.title("", 16, {
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		ZIndex = 2,
		Parent = track,
	})

	local stats = Widgets.create("Frame", {
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 1, -150),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		Widgets.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(280, 64),
			CellPadding = UDim2.fromOffset(16, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function stat(order: number, name: string): TextLabel
		local cell = Widgets.create("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			Parent = stats,
		}, { Widgets.corner(8) })
		Widgets.body(name, 22, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			Parent = cell,
		})
		return Widgets.title("", 22, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0.4, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = cell,
		})
	end
	local wins = stat(1, "Wins")
	local matches = stat(2, "Matches")
	local balls = stat(3, "Balls")
	local flyers = stat(4, "Flyers")
	local explosions = stat(5, "Explosions")

	local function refresh()
		local data = Profile.get()
		if not data or not root.Visible then
			return
		end
		local needed = Economy.xpToNext(data.level)
		level.Text = `Level {data.level}`
		fill.Size = UDim2.fromScale(math.clamp(data.xp / needed, 0, 1), 1)
		xpText.Text = `{data.xp}/{needed} XP`
		wins.Text = tostring(data.wins)
		matches.Text = tostring(data.matches)
		balls.Text = `{count(data.balls)}/{#Brainrots.list}`
		flyers.Text = `{count(data.flyers)}/{#Cosmetics.flyers}`
		explosions.Text = `{count(data.explosions)}/{#Cosmetics.explosions}`
	end

	Windows.register("Profile", root, refresh)
	return { refresh = refresh, tick = function() end }
end

return ProfileWindow
