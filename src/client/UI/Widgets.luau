-- Small helpers and colors for building the UI in code.
local Widgets = {}

Widgets.FONT = Enum.Font.GothamBold
Widgets.FONT_REGULAR = Enum.Font.GothamMedium

Widgets.PANEL = Color3.fromRGB(22, 24, 32)
Widgets.BUTTON = Color3.fromRGB(56, 60, 78)
Widgets.TEXT = Color3.fromRGB(245, 246, 250)
Widgets.DARK_TEXT = Color3.fromRGB(25, 25, 30)
Widgets.MUTED = Color3.fromRGB(160, 166, 184)
Widgets.ACCENT = Color3.fromRGB(255, 196, 40)
Widgets.GOOD = Color3.fromRGB(70, 200, 110)
Widgets.BAD = Color3.fromRGB(240, 80, 80)

type Props = { [string]: any }

local function merge(defaults: Props, overrides: Props?): Props
	local merged = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			merged[key] = value
		end
	end
	return merged
end

-- Instance.new with properties and children. Parent is set last.
function Widgets.create(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = parent
	return instance
end

function Widgets.corner(radius: number): UICorner
	return Widgets.create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function list(padding: number, direction: Enum.FillDirection?): UIListLayout
	return Widgets.create("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- A rounded dark box that stacks its children top to bottom (by LayoutOrder) and grows to fit.
function Widgets.panel(props: Props): Frame
	return Widgets.create(
		"Frame",
		merge({
			BackgroundColor3 = Widgets.PANEL,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
		}, props),
		{
			Widgets.corner(12),
			Widgets.create("UIPadding", {
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			}),
			list(8),
		}
	)
end

-- An invisible full-width frame that stacks its children and grows to fit.
function Widgets.stack(props: Props, padding: number, direction: Enum.FillDirection?): Frame
	return Widgets.create(
		"Frame",
		merge({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, props),
		{ list(padding, direction) }
	)
end

-- Full-width wrapping text that grows to fit, unless props say otherwise.
function Widgets.label(text: string, size: number, props: Props?): TextLabel
	return Widgets.create(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			Font = Widgets.FONT,
			Text = text,
			TextSize = size,
			TextColor3 = Widgets.TEXT,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, props)
	)
end

function Widgets.button(text: string, onClick: () -> (), props: Props?): TextButton
	local button = Widgets.create(
		"TextButton",
		merge({
			BackgroundColor3 = Widgets.BUTTON,
			BorderSizePixel = 0,
			Font = Widgets.FONT,
			Text = text,
			TextSize = 16,
			TextColor3 = Widgets.TEXT,
			Size = UDim2.fromOffset(30, 30),
		}, props),
		{ Widgets.corner(8) }
	)
	button.Activated:Connect(onClick)
	return button
end

-- A small square of color, e.g. a player's color next to their name.
function Widgets.swatch(color: Color3, size: number, props: Props?): Frame
	return Widgets.create(
		"Frame",
		merge({
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
		}, props),
		{ Widgets.corner(4) }
	)
end

-- Removes the visible children of a frame, keeping its layout objects.
function Widgets.clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Widgets
