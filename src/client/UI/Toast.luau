local TweenService = game:GetService("TweenService")

local Widgets = require(script.Parent.Widgets)

-- A short message a third of the way down the screen (clear of the corner cards and titles),
-- like "Not enough coins", that fades away.
local Toast = {}

local SHOW_FOR = 2

local label: TextLabel? = nil
local shownAt = 0

function Toast.attach(gui: ScreenGui)
	label = Widgets.title("", 28, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(600, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Widgets.GOLD,
		Visible = false,
		ZIndex = 50,
		Parent = gui,
	})
	Widgets.fit(label :: TextLabel, 600, 0.9)
end

function Toast.show(text: string)
	local toast = label
	if not toast then
		return
	end
	toast.Text = text
	toast.TextTransparency = 0
	toast.Visible = true
	shownAt = os.clock()
	local started = shownAt
	task.delay(SHOW_FOR, function()
		if shownAt == started then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

return Toast
