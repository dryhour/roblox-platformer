-- Small helpers and colors for building the UI in code.
local Widgets = {}

Widgets.FONT = Enum.Font.GothamBold
Widgets.FONT_REGULAR = Enum.Font.GothamMedium
Widgets.TITLE_FONT = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Bold)
Widgets.BODY_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

Widgets.PANEL = Color3.fromRGB(16, 22, 44)
Widgets.BUTTON = Color3.fromRGB(56, 60, 78)
Widgets.TEXT = Color3.fromRGB(245, 246, 250)
Widgets.DARK_TEXT = Color3.fromRGB(25, 25, 30)
Widgets.MUTED = Color3.fromRGB(160, 166, 184)
Widgets.ACCENT = Color3.fromRGB(255, 196, 40)
Widgets.GOOD = Color3.fromRGB(70, 200, 110)
Widgets.BAD = Color3.fromRGB(240, 80, 80)

-- The look: matte dark slate panels, a little see-through, with rounded corners and soft grey
-- edges, and chunky colored buttons.
Widgets.NAVY = Color3.fromRGB(26, 28, 35) -- #1A1C23
Widgets.NAVY_LIGHT = Color3.fromRGB(40, 44, 55)
Widgets.EDGE = Color3.fromRGB(61, 68, 85) -- #3D4455
Widgets.PANEL_TRANSPARENCY = 0.15
Widgets.ROUND = 12
Widgets.GREEN = Color3.fromRGB(110, 200, 40)
Widgets.BLUE = Color3.fromRGB(70, 115, 220)
Widgets.RED = Color3.fromRGB(205, 35, 30)
Widgets.PURPLE = Color3.fromRGB(130, 120, 230)
Widgets.GREY = Color3.fromRGB(90, 95, 110)
Widgets.GOLD = Color3.fromRGB(255, 200, 50)
Widgets.CYAN = Color3.fromRGB(110, 210, 255)

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

-- A text label in the title font with a dark outline, like the lobby's big words.
function Widgets.title(text: string, size: number, props: Props?): TextLabel
	local label = Widgets.create("TextLabel", merge({
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = Widgets.TEXT,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, props), {
		Widgets.create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(10, 10, 20) }),
	})
	label.FontFace = Widgets.TITLE_FONT
	return label
end

-- A text label in the body font.
function Widgets.body(text: string, size: number, props: Props?): TextLabel
	local label = Widgets.label(text, size, props)
	label.FontFace = Widgets.BODY_FONT
	return label
end

-- A big colored button with outlined title-font text, like Play, Invite and Leave.
function Widgets.bigButton(text: string, color: Color3, onClick: () -> (), props: Props?): TextButton
	local button = Widgets.create("TextButton", merge({
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = text,
		TextSize = 30,
		TextColor3 = Widgets.TEXT,
		Size = UDim2.fromOffset(220, 56),
	}, props), {
		Widgets.corner(10),
		Widgets.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 2,
			Color = color:Lerp(Color3.new(), 0.45),
		}),
		Widgets.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		}),
	})
	button.FontFace = Widgets.TITLE_FONT
	button.TextStrokeTransparency = 0
	button.Activated:Connect(onClick)
	return button
end

-- A gold coin.
function Widgets.coin(size: number, props: Props?): Frame
	return Widgets.create("Frame", merge({
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Widgets.GOLD,
	}, props), {
		Widgets.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Widgets.create("UIStroke", { Thickness = math.max(2, size / 10), Color = Color3.fromRGB(205, 120, 20) }),
		Widgets.create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(240, 160, 30)),
		}),
	})
end

-- A blue gem: a turned square with a shine.
function Widgets.gem(size: number, props: Props?): Frame
	local holder = Widgets.create("Frame", merge({
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, props))
	Widgets.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		Rotation = 45,
		BackgroundColor3 = Widgets.CYAN,
		Parent = holder,
	}, {
		Widgets.create("UICorner", { CornerRadius = UDim.new(0, math.max(2, size / 10)) }),
		Widgets.create("UIStroke", { Thickness = math.max(2, size / 12), Color = Color3.fromRGB(20, 70, 170) }),
		Widgets.create("UIGradient", {
			Rotation = 0,
			Color = ColorSequence.new(Color3.fromRGB(200, 245, 255), Color3.fromRGB(40, 120, 230)),
		}),
	})
	return holder
end

-- An icon for a reward or currency: a drawn coin or gem, or an emoji.
function Widgets.icon(kind: string, emoji: string, size: number, props: Props?): GuiObject
	if kind == "coins" then
		return Widgets.coin(size, props)
	elseif kind == "gems" then
		return Widgets.gem(size, props)
	end
	return Widgets.create("TextLabel", merge({
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Text = emoji,
		TextScaled = true,
	}, props))
end

-- A matte slate panel with rounded corners and a soft grey edge.
function Widgets.box(props: Props?): Frame
	return Widgets.create("Frame", merge({
		BackgroundColor3 = Widgets.NAVY,
		BackgroundTransparency = Widgets.PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
	}, props), {
		Widgets.corner(Widgets.ROUND),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
	})
end

-- A window in the middle of the screen: a big title, an X button at the top right corner, and
-- a `content` frame below the title. Starts hidden; UI/Windows shows one at a time.
function Widgets.window(parent: Instance, title: string, size: Vector2, onClose: () -> ()): (Frame, Frame)
	local root = Widgets.box({
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		Parent = parent,
	})
	-- The X sticks out past the corner.
	Widgets.fit(root, size.X + 80)
	Widgets.title(title, 46, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(1, -120, 0, 56),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = root,
	})
	local close = Widgets.create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = Widgets.NAVY_LIGHT,
		Text = "X",
		TextSize = 40,
		TextColor3 = Widgets.TEXT,
		Parent = root,
	}, {
		Widgets.corner(Widgets.ROUND),
		Widgets.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = Widgets.EDGE }),
	})
	close.FontFace = Widgets.TITLE_FONT
	close.TextStrokeTransparency = 0
	close.Activated:Connect(onClose)
	local content = Widgets.create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 1, -92),
		BackgroundTransparency = 1,
		Parent = root,
	})
	return root, content
end

-- "1:05:09" or "4:59".
function Widgets.clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	local hours, minutes, secs = whole // 3600, (whole % 3600) // 60, whole % 60
	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

-- Scales a piece of UI to the screen (UI.start says how big the screen is). Give it to each
-- group pinned to a corner or edge rather than the whole ScreenGui, so groups pinned to the
-- right or bottom stay there. It follows the screen's height; give `width` (the group's width
-- in design pixels) and `share` (the most of the screen's width it may take) to also keep it
-- from crowding narrow screens. Calling it again on the same group changes those.
type Fitted = { scale: UIScale, width: number?, share: number }

local fitted: { [GuiObject]: Fitted } = {}
local fitScale = 1
local screenWidth = 1920

local function apply(entry: Fitted)
	local scale = fitScale
	if entry.width then
		scale = math.min(scale, screenWidth * entry.share / entry.width)
	end
	entry.scale.Scale = scale
end

function Widgets.fit(object: GuiObject, width: number?, share: number?)
	local entry = fitted[object]
	if not entry then
		local scale = Instance.new("UIScale")
		scale.Parent = object
		entry = { scale = scale, width = width, share = share or 0.95 }
		fitted[object] = entry
	else
		entry.width = width
		entry.share = share or 0.95
	end
	apply(entry :: Fitted)
end

function Widgets.setFitScale(scale: number, width: number)
	fitScale = scale
	screenWidth = width
	for _, entry in fitted do
		apply(entry)
	end
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
