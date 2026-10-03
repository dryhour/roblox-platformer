local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Parent.Sounds)
local Widgets = require(script.Parent.Widgets)

-- Little flights across the screen when you get something: an item's icon shrinks and curves
-- into the Inventory button (which pulses), and coins or gems shower into their counters. While
-- coins or gems are on their way, their counter holds still, then counts up as they land.
local Fly = {}

local COINS = 8
local FLIGHT_TIME = 0.6

local layer: ScreenGui? = nil
local targets: { [string]: GuiObject } = {}
local holds: { [string]: number } = {}

function Fly.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Flights"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	layer = gui
end

-- Where things fly to: "inventory", "coins" or "gems".
function Fly.setTarget(name: string, object: GuiObject)
	targets[name] = object
end

-- Keeps a counter ("coins" or "gems") from counting up until the flight lands. Returns a
-- function that lets it go.
function Fly.hold(kind: string): () -> ()
	holds[kind] = (holds[kind] or 0) + 1
	local released = false
	return function()
		if not released then
			released = true
			holds[kind] -= 1
		end
	end
end

function Fly.held(kind: string): boolean
	return (holds[kind] or 0) > 0
end

local function middleOf(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

-- Makes a target bounce: up to 1.2x size, then springing back.
function Fly.pulse(name: string)
	local target = targets[name]
	if not target then
		return
	end
	local scale = target:FindFirstChild("Pulse") :: UIScale?
	if not scale then
		local newScale = Instance.new("UIScale")
		newScale.Name = "Pulse"
		newScale.Parent = target
		scale = newScale
	end
	local pulse = scale :: UIScale
	local grow = TweenService:Create(pulse, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.2 })
	grow.Completed:Connect(function()
		TweenService:Create(pulse, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	grow:Play()
end

-- Flies `object` (put in the flight layer) along a curve from `from` to `to`, shrinking it by
-- half, then removes it and calls `landed`.
local function arc(object: GuiObject, from: Vector2, to: Vector2, delay: number, landed: () -> ())
	local flight = layer
	if not flight then
		object:Destroy()
		landed()
		return
	end
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = UDim2.fromOffset(from.X, from.Y)
	object.ZIndex = 10
	object.Visible = delay <= 0
	object.Parent = flight
	local scale = Instance.new("UIScale")
	scale.Parent = object
	-- P(t) = (1-t)^2 P0 + 2(1-t)t Pc + t^2 P1, with the control point above the middle.
	local control = (from + to) / 2 + Vector2.new(0, -math.max(120, (to - from).Magnitude * 0.35))
	local start = os.clock() + delay
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / FLIGHT_TIME
		if t < 0 then
			return
		end
		object.Visible = true
		t = math.min(t, 1)
		local point = (1 - t) ^ 2 * from + 2 * (1 - t) * t * control + t ^ 2 * to
		object.Position = UDim2.fromOffset(point.X, point.Y)
		scale.Scale = 1 - 0.5 * t
		if t >= 1 then
			connection:Disconnect()
			object:Destroy()
			landed()
		end
	end)
end

-- Flies an item's icon from `from` into the Inventory button.
function Fly.item(emoji: string, from: Vector2, delay: number?)
	local target = targets.inventory
	if not target or not target.Visible then
		return
	end
	local icon = Widgets.create("TextLabel", {
		Size = UDim2.fromOffset(110, 110),
		BackgroundTransparency = 1,
		Text = emoji,
		TextScaled = true,
	})
	arc(icon, from, middleOf(target), delay or 0, function()
		Fly.pulse("inventory")
	end)
end

-- Showers coins or gems from `from` into their counter, then lets go of `release` (from
-- Fly.hold) so the counter counts up.
function Fly.currency(kind: string, from: Vector2, release: (() -> ())?)
	local target = targets[kind]
	if not target or not target.Visible then
		if release then
			release()
		end
		return
	end
	local landed = 0
	for index = 1, COINS do
		local icon = if kind == "gems" then Widgets.gem(40) else Widgets.coin(40)
		local spread = Vector2.new(math.random(-60, 60), math.random(-40, 40))
		arc(icon, from + spread, middleOf(target), (index - 1) * 0.05, function()
			landed += 1
			if landed == 1 and release then
				release()
			end
			if landed % 2 == 1 then
				Sounds.play("Tick")
			end
			Fly.pulse(kind)
		end)
	end
end

return Fly
