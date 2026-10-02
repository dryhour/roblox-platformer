local Action = require(script.Parent.Parent.Action)
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Settings, saved with your data: sound effects, camera shake and damage numbers.
local Settings = {}

local OPTIONS = {
	{ key = "sfx", text = "Sound Effects" },
	{ key = "shake", text = "Camera Shake" },
	{ key = "numbers", text = "Damage Numbers" },
}

function Settings.new(gui: ScreenGui)
	local root, content = Widgets.window(gui, "Settings", Vector2.new(560, 380), function()
		Windows.close("Settings")
	end)
	local buttons: { [string]: TextButton } = {}
	for index, option in OPTIONS do
		local row = Widgets.create("Frame", {
			Position = UDim2.fromOffset(0, (index - 1) * 84),
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = Widgets.NAVY_LIGHT,
			Parent = content,
		}, { Widgets.corner(8) })
		Widgets.body(option.text, 28, {
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -170, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			Parent = row,
		})
		local button = Widgets.bigButton("ON", Widgets.GREEN, function()
			Action.send("Setting", option.key, not Profile.setting(option.key))
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 52),
			TextSize = 24,
			Parent = row,
		})
		buttons[option.key] = button
	end

	local function refresh()
		for key, button in buttons do
			local on = Profile.setting(key)
			button.Text = if on then "ON" else "OFF"
			button.BackgroundColor3 = if on then Widgets.GREEN else Widgets.RED
		end
	end

	Windows.register("Settings", root, refresh)
	return { refresh = refresh, tick = function() end }
end

return Settings
