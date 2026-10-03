local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Daily Rewards: a 7-day calendar. Today's reward glows with a Claim button; earlier days in the
-- streak are ticked off. Opens by itself when you join with a reward waiting.
local Daily = {}

type Tile = { box: Frame, stroke: UIStroke, check: TextLabel }

-- Which day is next, whether it can be claimed now, and how many days are already ticked off.
function Daily.state(): (number, boolean, number)
	local profile = Profile.get()
	if not profile then
		return 1, false, 0
	end
	local nextDay, claimable = Economy.loginState(profile.loginDay, profile.loginStreak, Economy.day(workspace:GetServerTimeNow()))
	return nextDay, claimable, if claimable then nextDay - 1 else profile.loginStreak
end

function Daily.new(gui: ScreenGui)
	local root, content = Widgets.window(gui, "Daily Rewards", Vector2.new(900, 560), function()
		Windows.close("Daily")
	end)
	local tiles: { Tile } = {}
	for index, reward in Economy.LOGIN_REWARDS do
		local name, emoji, color = Economy.describe(reward)
		local big = index == #Economy.LOGIN_REWARDS
		local column = (index - 1) % 4
		local row = (index - 1) // 4
		local box = Widgets.create("Frame", {
			Position = UDim2.fromOffset(column * 215, row * 190),
			Size = UDim2.fromOffset(if big then 415 else 200, 175),
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			Parent = content,
		}, { Widgets.corner(8) })
		local stroke = Widgets.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 2,
			Color = Widgets.EDGE,
			Parent = box,
		})
		Widgets.title(`Day {index}`, 20, {
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 26),
			AutomaticSize = Enum.AutomaticSize.None,
			Parent = box,
		})
		Widgets.icon(reward.kind, emoji, 80, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 36),
			Parent = box,
		})
		Widgets.body(name, 20, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -6),
			Size = UDim2.new(1, -8, 0, 44),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			TextColor3 = color,
			TextStrokeTransparency = 0,
			Parent = box,
		})
		local check = Widgets.create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			Text = "✅",
			TextScaled = true,
			Parent = box,
		})
		tiles[index] = { box = box, stroke = stroke, check = check }
	end
	local claim = Widgets.bigButton("Claim", Widgets.GREEN, function()
		Action.send("ClaimLogin")
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(220, 64),
		TextSize = 32,
		Parent = content,
	})
	local comeBack = Widgets.title("", 22, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -14),
		Size = UDim2.fromOffset(420, 32),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Widgets.MUTED,
		Parent = content,
	})

	local function tick()
		if not root.Visible then
			return
		end
		local nextDay, claimable, done = Daily.state()
		for index, tile in tiles do
			local today = claimable and index == nextDay
			tile.check.Visible = index <= done
			tile.stroke.Color = if today then Widgets.GOLD else Widgets.EDGE
			tile.stroke.Thickness = if today then 4 + math.abs(math.sin(os.clock() * 4)) * 3 else 2
			tile.box.BackgroundTransparency = if index <= done then 0.5 else 0
		end
		claim.Visible = claimable
		comeBack.Visible = not claimable
		local now = workspace:GetServerTimeNow()
		comeBack.Text = `Next reward in {Widgets.clock(86400 - now % 86400)}`
	end

	-- Opens itself once, when your data first arrives and a reward is waiting.
	local opened = false
	Profile.changed:Connect(function()
		if opened then
			return
		end
		opened = true
		local _, claimable = Daily.state()
		if claimable then
			task.delay(2, function()
				if not Windows.current() then
					Windows.open("Daily")
				end
			end)
		end
	end)

	Windows.register("Daily", root)
	return { refresh = function() end, tick = tick }
end

return Daily
