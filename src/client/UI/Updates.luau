local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Updates: what's new in the game (Economy.UPDATES), newest first.
local Updates = {}

function Updates.new(gui: ScreenGui)
	local root, content = Widgets.window(gui, "Updates", Vector2.new(720, 560), function()
		Windows.close("Updates")
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
	for index, update in Economy.UPDATES do
		local entry = Widgets.panel({ LayoutOrder = index, Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Widgets.NAVY_LIGHT, Parent = list })
		Widgets.body(update.title, 26, { LayoutOrder = 1, TextStrokeTransparency = 0, Parent = entry })
		Widgets.body(update.body, 21, { LayoutOrder = 2, TextColor3 = Widgets.MUTED, Parent = entry })
	end

	Windows.register("Updates", root)
	return { refresh = function() end, tick = function() end }
end

return Updates
