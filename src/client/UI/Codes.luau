local Action = require(script.Parent.Parent.Action)
local Toast = require(script.Parent.Toast)
local Widgets = require(script.Parent.Widgets)
local Windows = require(script.Parent.Windows)

-- Codes: type a code and press Redeem.
local Codes = {}

function Codes.new(gui: ScreenGui)
	local root, content = Widgets.window(gui, "Codes", Vector2.new(560, 300), function()
		Windows.close("Codes")
	end)
	local box = Widgets.create("TextBox", {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Text = "",
		PlaceholderText = "Enter code",
		PlaceholderColor3 = Widgets.MUTED,
		TextColor3 = Widgets.TEXT,
		TextSize = 30,
		ClearTextOnFocus = false,
		Parent = content,
	}, {
		Widgets.corner(8),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
	})
	box.FontFace = Widgets.TITLE_FONT
	local function redeem()
		local text = box.Text
		if text == "" then
			return
		end
		task.spawn(function()
			local ok, message = Action.call("Redeem", text)
			if ok then
				box.Text = ""
				Windows.close("Codes")
			elseif message then
				Toast.show(message)
			end
		end)
	end
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	Widgets.bigButton("Redeem", Widgets.GREEN, redeem, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(240, 64),
		TextSize = 32,
		Parent = content,
	})

	Windows.register("Codes", root)
	return { refresh = function() end, tick = function() end }
end

return Codes
