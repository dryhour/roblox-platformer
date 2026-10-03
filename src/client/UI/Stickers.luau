local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local Action = require(script.Parent.Parent.Action)
local MyMatch = require(script.Parent.Parent.MyMatch)
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)

-- Stickers, while you wait at a station or watch a match (they step aside while you pick a
-- ball or aim): a button in the bottom right opens a panel of emoji; tap one and it pops up
-- over your head for everyone to see. The speaker turns sticker sounds on and off (the same
-- switch as Sound Effects in Settings).
local Stickers = {}

function Stickers.new(gui: ScreenGui)
	local root = Widgets.create("Frame", {
		Name = "Stickers",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(380, 460),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Widgets.fit(root, 380, 0.45)

	local panel = Widgets.create("Frame", {
		Size = UDim2.fromOffset(380, 340),
		BackgroundColor3 = Color3.fromRGB(30, 32, 38),
		Visible = false,
		Parent = root,
	}, { Widgets.corner(10) })
	Widgets.create("TextLabel", { Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Text = "🙂", TextScaled = true, Parent = panel })
	Widgets.body("Stickers", 28, {
		Position = UDim2.fromOffset(62, 12),
		Size = UDim2.fromOffset(180, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = panel,
	})
	local speaker = Widgets.create("TextButton", {
		Position = UDim2.fromOffset(250, 12),
		Size = UDim2.fromOffset(46, 40),
		BackgroundTransparency = 1,
		Text = "🔊",
		TextScaled = true,
		Parent = panel,
	})
	speaker.Activated:Connect(function()
		Action.send("Setting", "sfx", not Profile.setting("sfx"))
	end)
	local close = Widgets.create("TextButton", {
		Position = UDim2.fromOffset(318, 12),
		Size = UDim2.fromOffset(46, 40),
		BackgroundTransparency = 1,
		Text = "✕",
		TextScaled = true,
		TextColor3 = Widgets.TEXT,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	for index, emoji in Economy.STICKERS do
		local column, row = (index - 1) % 3, (index - 1) // 3
		local button = Widgets.create("TextButton", {
			Position = UDim2.fromOffset(18 + column * 118, 70 + row * 130),
			Size = UDim2.fromOffset(110, 120),
			BackgroundColor3 = Color3.fromRGB(45, 48, 56),
			Text = emoji,
			TextScaled = true,
			Parent = panel,
		}, {
			Widgets.corner(8),
			Widgets.create("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16) }),
		})
		button.Activated:Connect(function()
			Action.send("Sticker", index)
		end)
	end

	local open = Widgets.create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Color3.fromRGB(30, 32, 38),
		Text = "🙂",
		TextScaled = true,
		Parent = root,
	}, {
		Widgets.corner(12),
		Widgets.create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
	})
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	local function refresh()
		local phase = MyMatch.phase()
		local busy = phase == "Draft" or phase == "Aim"
		root.Visible = (MyMatch.state() ~= nil or MyMatch.waitingSide() ~= "") and not busy
		if not root.Visible then
			panel.Visible = false
		end
		speaker.Text = if Profile.setting("sfx") then "🔊" else "🔇"
	end

	return { refresh = refresh, tick = function() end }
end

return Stickers
