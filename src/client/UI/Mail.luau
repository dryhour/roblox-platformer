local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Mail: messages from the game (Economy.MAIL), some with a gift to claim.
local Mail = {}

-- How many messages are still unopened.
function Mail.unread(): number
	local profile = Profile.get()
	if not profile then
		return 0
	end
	local count = 0
	for _, mail in Economy.MAIL do
		if not profile.mailClaimed[mail.id] then
			count += 1
		end
	end
	return count
end

function Mail.new(gui: ScreenGui)
	local root, content = Widgets.window(gui, "Mail", Vector2.new(720, 560), function()
		Windows.close("Mail")
	end)
	local list = Widgets.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		Widgets.create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Widgets.create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	local buttons: { [string]: TextButton } = {}
	for index, mail in Economy.MAIL do
		local row = Widgets.create("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 130),
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			Parent = list,
		}, { Widgets.corner(8) })
		Widgets.create("TextLabel", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(50, 50), BackgroundTransparency = 1, Text = "✉️", TextScaled = true, Parent = row })
		Widgets.body(mail.title, 26, {
			Position = UDim2.fromOffset(74, 8),
			Size = UDim2.new(1, -250, 0, 32),
			AutomaticSize = Enum.AutomaticSize.None,
			TextStrokeTransparency = 0,
			Parent = row,
		})
		Widgets.body(mail.body, 20, {
			Position = UDim2.fromOffset(74, 42),
			Size = UDim2.new(1, -250, 0, 80),
			AutomaticSize = Enum.AutomaticSize.None,
			TextWrapped = true,
			TextColor3 = Widgets.MUTED,
			Parent = row,
		})
		local label = "Read"
		if mail.reward then
			local name = Economy.describe(mail.reward)
			label = "Claim"
			Widgets.body(name, 18, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 12),
				Size = UDim2.fromOffset(160, 24),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Widgets.GOLD,
				Parent = row,
			})
		end
		buttons[mail.id] = Widgets.bigButton(label, Widgets.GREEN, function()
			Action.send("ClaimMail", mail.id)
		end, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(160, 52),
			TextSize = 22,
			Parent = row,
		})
	end

	local function refresh()
		local profile = Profile.get()
		for id, button in buttons do
			local done = profile ~= nil and profile.mailClaimed[id] == true
			button.Visible = not done
		end
	end

	Windows.register("Mail", root, refresh)
	return { refresh = refresh, tick = function() end }
end

return Mail
