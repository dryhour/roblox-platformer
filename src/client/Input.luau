local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Reads every kind of input in one place, so the rest of the client works the same on keyboard,
-- gamepad and touch, without depending on Roblox's default PlayerModule controls.
--
-- On touch screens it draws its own controls: a joystick that appears wherever your thumb lands
-- on the left half of the screen, and buttons on the right for jump, boost, slam and brake.
local Input = {}

local STICK_DEADZONE = 0.2
local JOYSTICK_RADIUS = 60 -- pixels the thumb can move from where it touched down

-- Keys and gamepad buttons that trigger actions. Touch has its own buttons.
local ACTION_KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Space] = "Jump",
	[Enum.KeyCode.ButtonA] = "Jump",
	[Enum.KeyCode.LeftShift] = "Boost",
	[Enum.KeyCode.RightShift] = "Boost",
	[Enum.KeyCode.ButtonX] = "Boost",
	[Enum.KeyCode.ButtonR2] = "Boost",
	[Enum.KeyCode.E] = "Ability",
	[Enum.KeyCode.F] = "Ability",
	[Enum.KeyCode.ButtonY] = "Ability",
	[Enum.KeyCode.ButtonR1] = "Ability",
}

local BUTTON_IDLE = 0.65 -- background transparency of a touch button
local BUTTON_PRESSED = 0.3
local BUTTON_RECHARGING = 0.9

local handlers: { [string]: { () -> () } } = {}
local stick = Vector2.zero
local joystickTouch: InputObject? = nil
local joystickOrigin = Vector2.zero
local joystickVector = Vector2.zero
local brakeTouches: { [InputObject]: boolean } = {}
local buttons: { [string]: TextButton } = {}
local ready: { [string]: boolean } = {}

local function keyDown(keys: { Enum.KeyCode }): boolean
	-- Typing in chat isn't playing.
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function padDown(button: Enum.KeyCode): boolean
	return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button)
end

local function trigger(action: string)
	local list = handlers[action]
	if list then
		for _, handler in list do
			task.spawn(handler)
		end
	end
end

-- Where the player is steering: X is right, Y is forward (up the screen). Length 0 to 1.
function Input.move(): Vector2
	local x, y = 0, 0
	if keyDown({ Enum.KeyCode.D, Enum.KeyCode.Right }) then
		x += 1
	end
	if keyDown({ Enum.KeyCode.A, Enum.KeyCode.Left }) then
		x -= 1
	end
	if keyDown({ Enum.KeyCode.W, Enum.KeyCode.Up }) then
		y += 1
	end
	if keyDown({ Enum.KeyCode.S, Enum.KeyCode.Down }) then
		y -= 1
	end
	local move = Vector2.new(x, y)
	if move.Magnitude == 0 and stick.Magnitude > STICK_DEADZONE then
		move = stick
	end
	if move.Magnitude == 0 then
		move = joystickVector
	end
	return if move.Magnitude > 1 then move.Unit else move
end

function Input.brakeHeld(): boolean
	return keyDown({ Enum.KeyCode.LeftControl, Enum.KeyCode.C })
		or padDown(Enum.KeyCode.ButtonB)
		or padDown(Enum.KeyCode.ButtonL2)
		or next(brakeTouches) ~= nil
end

-- Calls handler whenever `action` ("Jump", "Boost" or "Ability") is pressed, on any device.
function Input.onAction(action: string, handler: () -> ())
	handlers[action] = handlers[action] or {}
	table.insert(handlers[action], handler)
end

-- Fades an action's touch button while it can't be used (recharging).
function Input.setReady(action: string, isReady: boolean)
	if ready[action] == isReady then
		return
	end
	ready[action] = isReady
	local button = buttons[action]
	if button then
		button.BackgroundTransparency = if isReady then BUTTON_IDLE else BUTTON_RECHARGING
		button.TextTransparency = if isReady then 0 else 0.6
	end
end

local function circle(parent: Instance, size: number, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = transparency
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Transparency = 0.4
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function roundButton(gui: ScreenGui, symbol: string, size: number, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = BUTTON_IDLE
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = symbol
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0.4

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0.24, 0)
	end
	padding.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Transparency = 0.3
	stroke.Parent = button

	button.Parent = gui
	return button
end

-- A touch button that triggers an action when tapped.
local function tapButton(button: TextButton, action: string)
	buttons[action] = button
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			trigger(action)
			if ready[action] ~= false then
				button.BackgroundTransparency = BUTTON_PRESSED
				task.delay(0.15, function()
					if ready[action] ~= false then
						button.BackgroundTransparency = BUTTON_IDLE
					end
				end)
			end
		end
	end)
end

local function createTouchControls()
	-- Our controls replace Roblox's thumbstick and jump button.
	GuiService.TouchControlsEnabled = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- The joystick rests faintly in the corner, so it's clear where to put your thumb.
	local restPosition = UDim2.new(0, 110, 1, -110)
	local base = circle(gui, 2 * JOYSTICK_RADIUS + 30, 0.8)
	local knob = circle(gui, 64, 0.45)
	local function showJoystick(origin: Vector2?, offset: Vector2)
		base.Position = if origin then UDim2.fromOffset(origin.X, origin.Y) else restPosition
		knob.Position = base.Position + UDim2.fromOffset(offset.X, offset.Y)
		base.BackgroundTransparency = if origin then 0.7 else 0.85
	end
	showJoystick(nil, Vector2.zero)

	tapButton(roundButton(gui, "▲", 120, UDim2.new(1, -90, 1, -90)), "Jump")
	tapButton(roundButton(gui, "💨", 88, UDim2.new(1, -220, 1, -70)), "Boost")
	tapButton(roundButton(gui, "💥", 88, UDim2.new(1, -90, 1, -225)), "Ability")
	local brake = roundButton(gui, "✋", 72, UDim2.new(1, -205, 1, -185))
	brake.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			brakeTouches[input] = true
			brake.BackgroundTransparency = BUTTON_PRESSED
		end
	end)

	UserInputService.TouchStarted:Connect(function(touch, processed)
		if processed or joystickTouch or not gui.Enabled then
			return
		end
		if touch.Position.X > workspace.CurrentCamera.ViewportSize.X / 2 then
			return
		end
		joystickTouch = touch
		joystickOrigin = Vector2.new(touch.Position.X, touch.Position.Y)
		showJoystick(joystickOrigin, Vector2.zero)
	end)
	UserInputService.TouchMoved:Connect(function(touch)
		if touch ~= joystickTouch then
			return
		end
		local offset = Vector2.new(touch.Position.X, touch.Position.Y) - joystickOrigin
		if offset.Magnitude > JOYSTICK_RADIUS then
			offset = offset.Unit * JOYSTICK_RADIUS
		end
		-- Screen Y points down; forward is up.
		joystickVector = Vector2.new(offset.X, -offset.Y) / JOYSTICK_RADIUS
		showJoystick(joystickOrigin, offset)
	end)
	UserInputService.TouchEnded:Connect(function(touch)
		if touch == joystickTouch then
			joystickTouch = nil
			joystickVector = Vector2.zero
			showJoystick(nil, Vector2.zero)
		end
		if brakeTouches[touch] then
			brakeTouches[touch] = nil
			if next(brakeTouches) == nil then
				brake.BackgroundTransparency = BUTTON_IDLE
			end
		end
	end)

	-- Show the controls while the player is using touch; hide them for keyboard, mouse or
	-- gamepad (e.g. a laptop with a touchscreen).
	gui.Enabled = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if inputType == Enum.UserInputType.Touch then
			gui.Enabled = true
		elseif
			inputType == Enum.UserInputType.Keyboard
			or inputType == Enum.UserInputType.MouseButton1
			or string.find(inputType.Name, "Gamepad") ~= nil
		then
			gui.Enabled = false
		end
	end)
end

function Input.start()
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.zero
		end
	end)
	UserInputService.GamepadDisconnected:Connect(function()
		stick = Vector2.zero
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		local action = ACTION_KEYS[input.KeyCode]
		if action and not processed then
			trigger(action)
		end
	end)
	createTouchControls()
end

return Input
