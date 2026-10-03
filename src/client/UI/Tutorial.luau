local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local AimController = require(script.Parent.Parent.AimController)
local MyMatch = require(script.Parent.Parent.MyMatch)
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)

-- A first-time tutorial that shows instead of tells, until you finish your first match:
--   lobby  a hand bounces over Play, and glowing arrows on the floor lead to the nearest open
--          station, with a big arrow bobbing over its square
--   draft  a hand taps the middle card
--   aim    a hand drags out from your ball, then goes and taps Lock Aim
-- After that, a hand points at any daily quest that's ready to claim.
local Tutorial = {}

type Targets = {
	play: GuiObject,
	lockButton: GuiObject,
	claimable: () -> GuiObject?,
	cardToPick: () -> GuiObject?,
}

local GUIDE_ARROWS = 14
local GUIDE_SPACING = 5
local GUIDE_START = 4 -- studs in front of you
local ARROW_COLOR = Color3.fromRGB(255, 225, 60)
local AIM_LOOP = 2.6 -- seconds for one drag, then a tap on Lock Aim

-- The station squares in the lobby, found once.
local function findSquares(): { BasePart }
	local squares = {}
	local lobby = workspace:WaitForChild("Lobby")
	for _, part in lobby:GetDescendants() do
		if part:IsA("BasePart") and typeof(part:GetAttribute("Arena")) == "string" then
			table.insert(squares, part)
		end
	end
	return squares
end

-- The best square to send you to: a free one where someone's already waiting (so you'll play
-- right away), or else the nearest free one.
local function bestSquare(squares: { BasePart }, from: Vector3): BasePart?
	local arenas = workspace:FindFirstChild("Arenas")
	local best, bestScore = nil, math.huge
	for _, square in squares do
		local arena = arenas and arenas:FindFirstChild(square:GetAttribute("Arena") :: string)
		local state = arena and arena:FindFirstChild("State")
		if not state or (state:GetAttribute("Phase") or "") ~= "" then
			continue
		end
		local side = square:GetAttribute("Side")
		local other = if side == "Left" then "Right" else "Left"
		if (tonumber(state:GetAttribute(`Waiting{side}`)) or 0) ~= 0 then
			continue
		end
		local someoneWaiting = (tonumber(state:GetAttribute(`Waiting{other}`)) or 0) ~= 0
		local score = (square.Position - from).Magnitude - (if someoneWaiting then 1000 else 0)
		if score < bestScore then
			best, bestScore = square, score
		end
	end
	return best
end

function Tutorial.new(gui: ScreenGui, targets: Targets)
	local player = Players.LocalPlayer

	-- On screen: a pointing hand and a pulsing ring around what it points at.
	local hand = Widgets.create("TextLabel", {
		Name = "TutorialHand",
		Size = UDim2.fromOffset(90, 90),
		BackgroundTransparency = 1,
		Text = "👇",
		TextScaled = true,
		Visible = false,
		ZIndex = 15, -- over the HUD and draft, under reward popups
		Parent = gui,
	})
	local ring = Widgets.create("Frame", {
		Name = "TutorialRing",
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 14,
		Parent = gui,
	}, {
		Widgets.corner(12),
		Widgets.create("UIStroke", { Name = "Glow", Thickness = 5, Color = ARROW_COLOR }),
	})
	local glow = ring:FindFirstChild("Glow") :: UIStroke

	-- In the world: arrows on the floor toward a station, and a big arrow over its square.
	local folder = Instance.new("Folder")
	folder.Name = "TutorialGuide"
	folder.Parent = workspace
	local guideParts: { BasePart } = {}
	for _ = 1, GUIDE_ARROWS * 2 do
		local arm = Instance.new("Part")
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.CastShadow = false
		arm.Material = Enum.Material.Neon
		arm.Color = ARROW_COLOR
		arm.Size = Vector3.new(0.6, 0.12, 3)
		arm.Transparency = 1
		arm.Parent = folder
		table.insert(guideParts, arm)
	end
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromScale(5, 5)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Enabled = false
	local markerLabel = Instance.new("TextLabel")
	markerLabel.Size = UDim2.fromScale(1, 1)
	markerLabel.BackgroundTransparency = 1
	markerLabel.Text = "⬇️"
	markerLabel.TextScaled = true
	markerLabel.Parent = marker
	marker.Parent = gui.Parent

	local squares: { BasePart }? = nil
	task.spawn(function()
		squares = findSquares()
	end)
	local target: BasePart? = nil

	-- Points the hand at a spot on screen (in this ScreenGui's pixels), from `above` or below.
	local function pointAt(point: Vector2, above: boolean)
		local bob = math.abs(math.sin(os.clock() * 5)) * 14
		hand.Visible = true
		hand.Rotation = 0
		hand.Text = if above then "👇" else "👆"
		hand.AnchorPoint = Vector2.new(0.5, if above then 1 else 0)
		hand.Position = UDim2.fromOffset(point.X, point.Y + (if above then -bob else bob))
		hand.TextTransparency = 0
		hand.Size = UDim2.fromOffset(90, 90)
	end

	local function circle(object: GuiObject)
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		local pad = 8 + pulse * 6
		ring.Visible = true
		ring.Position = UDim2.fromOffset(object.AbsolutePosition.X - pad, object.AbsolutePosition.Y - pad)
		ring.Size = UDim2.fromOffset(object.AbsoluteSize.X + pad * 2, object.AbsoluteSize.Y + pad * 2)
		glow.Transparency = pulse * 0.6
	end

	local function hideGuide()
		for _, part in guideParts do
			part.Transparency = 1
		end
		marker.Enabled = false
	end

	-- Lays the floor arrows from you toward the square, lighting up one after another.
	local function showGuide(square: BasePart)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			hideGuide()
			return
		end
		marker.Adornee = square
		marker.StudsOffset = Vector3.new(0, 7 + math.abs(math.sin(os.clock() * 4)) * 1.5, 0)
		marker.Enabled = true

		local from = Vector3.new(root.Position.X, 0.35, root.Position.Z)
		local to = Vector3.new(square.Position.X, 0.35, square.Position.Z)
		local offset = to - from
		local distance = offset.Magnitude
		local direction = if distance > 0.1 then offset / distance else Vector3.zAxis
		local side = direction:Cross(Vector3.yAxis)
		local now = os.clock()
		for index = 1, GUIDE_ARROWS do
			local along = GUIDE_START + (index - 1) * GUIDE_SPACING
			local left, right = guideParts[index * 2 - 1], guideParts[index * 2]
			if along > distance - 4 then
				left.Transparency = 1
				right.Transparency = 1
				continue
			end
			local tip = from + direction * along
			local glowing = 0.15 + 0.6 * (1 - (math.sin(now * 6 - index * 0.8) + 1) / 2)
			for armIndex, arm in { left, right } do
				local back = tip - direction * 1.6 + side * (if armIndex == 1 then 1.6 else -1.6)
				arm.Size = Vector3.new(0.6, 0.12, (tip - back).Magnitude + 0.5)
				arm.CFrame = CFrame.lookAt((tip + back) / 2, tip)
				arm.Transparency = glowing
			end
		end
	end

	-- A hand that drags out from your ball the way you'd aim, then taps Lock Aim.
	local function showAim()
		local ball = MyMatch.myBall()
		local core = ball and ball.PrimaryPart
		local forward = ball and ball:GetAttribute("Forward")
		if not core or typeof(forward) ~= "Vector3" then
			hand.Visible = false
			return
		end
		local camera = workspace.CurrentCamera
		local inset = GuiService:GetGuiInset()
		local function onScreen(point: Vector3): Vector2
			local screen = camera:WorldToViewportPoint(point)
			return Vector2.new(screen.X, screen.Y) - inset
		end
		local start = onScreen(core.Position)
		local finish = onScreen(core.Position + forward * 7 + Vector3.yAxis * 4)
		local button = targets.lockButton
		local lock = button.AbsolutePosition + button.AbsoluteSize / 2
		local t = (os.clock() % AIM_LOOP) / AIM_LOOP
		local function ease(from: number, to: number): number
			local x = math.clamp((t - from) / (to - from), 0, 1)
			return 1 - (1 - x) ^ 2
		end
		local point = start:Lerp(finish, ease(0, 0.4)):Lerp(lock, ease(0.45, 0.65))
		hand.Visible = true
		hand.Text = "👆"
		hand.Rotation = 0
		hand.AnchorPoint = Vector2.new(0.4, 0)
		hand.Position = UDim2.fromOffset(point.X, point.Y)
		-- Press down on the button, then fade out before the next one.
		local tapping = t > 0.68 and t < 0.8
		hand.Size = if tapping then UDim2.fromOffset(76, 76) else UDim2.fromOffset(90, 90)
		hand.TextTransparency = if t > 0.85 then (t - 0.85) / 0.15 else 0
	end

	local function refresh()
		local profile = Profile.get()
		local inLobby = MyMatch.state() == nil and MyMatch.waitingSide() == ""
		local learning = profile ~= nil and profile.tutorialDone ~= true
		if learning and inLobby and squares then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			target = if root and root:IsA("BasePart") then bestSquare(squares :: { BasePart }, root.Position) else nil
		else
			target = nil
		end
	end

	local function tick()
		local profile = Profile.get()
		local learning = profile ~= nil and profile.tutorialDone ~= true
		local inLobby = MyMatch.state() == nil and MyMatch.waitingSide() == ""
		local phase = MyMatch.phase()
		hand.Visible = false
		ring.Visible = false

		local claim = targets.claimable()
		if learning and inLobby then
			local play = targets.play
			if play.AbsoluteSize.X > 0 then
				pointAt(Vector2.new(play.AbsolutePosition.X + play.AbsoluteSize.X / 2, play.AbsolutePosition.Y - 4), true)
				circle(play)
			end
		elseif claim then
			-- Points at the Claim button from its left.
			hand.Visible = true
			hand.Text = "👉"
			hand.Rotation = 0
			hand.TextTransparency = 0
			hand.Size = UDim2.fromOffset(70, 70)
			hand.AnchorPoint = Vector2.new(1, 0.5)
			local bob = math.abs(math.sin(os.clock() * 5)) * 12
			hand.Position = UDim2.fromOffset(claim.AbsolutePosition.X - 4 - bob, claim.AbsolutePosition.Y + claim.AbsoluteSize.Y / 2)
			circle(claim)
		elseif learning and phase == "Draft" then
			local card = targets.cardToPick()
			if card then
				pointAt(Vector2.new(card.AbsolutePosition.X + card.AbsoluteSize.X / 2, card.AbsolutePosition.Y + card.AbsoluteSize.Y * 0.45), true)
				circle(card)
			end
		elseif learning and phase == "Aim" and not AimController.isLocked() then
			showAim()
		end

		if target then
			showGuide(target)
		else
			hideGuide()
		end
	end

	return { refresh = refresh, tick = tick }
end

return Tutorial
