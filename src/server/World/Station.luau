local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Arena = require(script.Parent.Arena)
local Builder = require(script.Parent.Builder)

-- A duel station in the lobby: a stage with two glowing squares (pink for Left, blue for Right)
-- in front of an arena box. Press Join (E) at a square to take that side and wait there; when
-- both sides are taken, the match starts and the two players float beside the box on hover pads
-- to watch their balls fight. Between matches the box shows a VS screen with the faces of
-- whoever is waiting, and a sign shows how many have joined. MatchService runs the stations.
local Station = {}

export type Station = {
	id: string,
	arena: Arena.Arena,
	prompts: { [string]: ProximityPrompt }, -- Join, one per square
	seats: { [string]: CFrame }, -- where a waiting player's feet go, facing out
	stands: { [string]: CFrame }, -- where each side's feet go during a match, facing out
	exits: { [string]: CFrame }, -- where each side's feet go after leaving or a match
	-- Updates the squares, prompts, sign and VS screen. `busy` while a match is on.
	show: (waiting: { [string]: Player? }, busy: boolean) -> (),
}

local SIDES = { "Left", "Right" }

-- Layout, in the station's own space: X is the right as seen from the front, +Z points out of
-- the front toward the players, and the floor is at Y = 0.
local STAGE_SIZE = Vector3.new(46, 1.2, 16)
local STAGE_Z = 8.5
local SQUARE_SIZE = 7
local SQUARE_X = 5.5
local SQUARE_Z = 9
local BOX_Z = -6 -- the plane the balls move in
local PAD_X = Config.ARENA_SIZE / 2 + 6.5
local PAD_TOP = 10 -- hover pads sit beside the box, about a third of the way up
local PAD_Z = BOX_Z + 2.5
local EXIT_Z = 20

local STAGE = Color3.fromRGB(26, 36, 70)
local TILE = Color3.fromRGB(34, 46, 88)
local SCREEN = Color3.fromRGB(45, 50, 205)
local STRIPE = Color3.fromRGB(70, 90, 235)
local GOLD = Color3.fromRGB(255, 205, 50)
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"

local VS_FONT = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
local SIGN_FONT = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Bold)

type Square = { tile: Part, beam: Part }
type Face = { image: ImageLabel, label: TextLabel }

-- The floating sign over the squares: "1/2 PLAYERS" and "Win 100" with a coin.
local function makeSign(b: Builder.Builder, position: Vector3): (BillboardGui, TextLabel)
	local holder = b:ghost(b:block(Vector3.one, position, Color3.new(), "Sign"), 1)
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(13, 4.4)
	sign.LightInfluence = 0
	sign.MaxDistance = 250
	sign.Parent = holder

	local function line(text: string, y: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.BackgroundTransparency = 1
		label.FontFace = SIGN_FONT
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = color
		label.Parent = sign
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(15, 15, 30)
		stroke.Parent = label
		return label
	end
	local players = line("0/2 PLAYERS", 0, 0.55, Color3.new(1, 1, 1))
	local win = line(`Win {Economy.WIN_COINS}`, 0.58, 0.42, GOLD)
	win.Size = UDim2.fromScale(0.8, 0.42)
	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromScale(0.8, 0.79)
	coin.Size = UDim2.fromScale(0.11, 0.34)
	coin.BackgroundColor3 = GOLD
	coin.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = coin
	local rim = Instance.new("UIStroke")
	rim.Thickness = 3
	rim.Color = Color3.fromRGB(200, 120, 20)
	rim.Parent = coin
	return sign, players
end

-- The VS screen on the back of the box, with a face for each side at the top.
local function makeScreen(backdrop: Part): (SurfaceGui, { [string]: Face })
	local screen = Instance.new("SurfaceGui")
	screen.Name = "VsScreen"
	screen.Face = Enum.NormalId.Back -- the side facing the players
	screen.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screen.PixelsPerStud = 20
	screen.LightInfluence = 0
	screen.Parent = backdrop

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = SCREEN
	background.BorderSizePixel = 0
	background.Parent = screen
	for index = 1, 14 do
		local stripe = Instance.new("Frame")
		stripe.AnchorPoint = Vector2.new(0, 0.5)
		stripe.Position = UDim2.fromScale(0, index / 15)
		stripe.Size = UDim2.new(1, 0, 0, 6)
		stripe.BackgroundColor3 = STRIPE
		stripe.BorderSizePixel = 0
		stripe.Parent = background
	end

	local vs = Instance.new("TextLabel")
	vs.AnchorPoint = Vector2.new(0.5, 0.5)
	vs.Position = UDim2.fromScale(0.5, 0.56)
	vs.Size = UDim2.fromScale(0.8, 0.36)
	vs.BackgroundTransparency = 1
	vs.FontFace = VS_FONT
	vs.Text = "VS"
	vs.TextScaled = true
	vs.TextColor3 = Color3.new(1, 1, 1)
	vs.Parent = background
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 8
	stroke.Color = Color3.fromRGB(20, 20, 40)
	stroke.Parent = vs

	local faces = {}
	for _, side in SIDES do
		local isLeft = side == "Left"
		local image = Instance.new("ImageLabel")
		image.AnchorPoint = Vector2.new(if isLeft then 0 else 1, 0)
		image.Position = UDim2.new(if isLeft then 0 else 1, if isLeft then 30 else -30, 0, 30)
		image.Size = UDim2.fromOffset(170, 170)
		image.BackgroundColor3 = Color3.fromRGB(25, 30, 60)
		image.Parent = background
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = image
		local ring = Instance.new("UIStroke")
		ring.Thickness = 10
		ring.Color = Config.SIDE_COLORS[side]
		ring.Parent = image
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = VS_FONT
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(150, 160, 200)
		label.Parent = image
		faces[side] = { image = image, label = label }
	end
	return screen, faces
end

-- Builds a station named `id` (its arena gets the same name). `cframe` is on the floor at the
-- middle of the box's bottom edge, looking into the box.
function Station.build(b: Builder.Builder, id: string, cframe: CFrame): Station
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	-- Looking out of the front, toward the players.
	local function facingOut(x: number, y: number, z: number): CFrame
		return at(x, y, z) * CFrame.Angles(0, math.pi, 0)
	end

	local boxCenterY = Config.ARENA_SIZE / 2 + 2
	local arena = Arena.build(id, at(0, boxCenterY, BOX_Z))

	b:box(STAGE_SIZE, at(0, STAGE_SIZE.Y / 2, STAGE_Z), STAGE, "Stage")
	local top = STAGE_SIZE.Y

	local squares: { [string]: Square } = {}
	local prompts: { [string]: ProximityPrompt } = {}
	local seats: { [string]: CFrame } = {}
	local stands: { [string]: CFrame } = {}
	local exits: { [string]: CFrame } = {}
	for _, side in SIDES do
		local sign = if side == "Left" then -1 else 1
		local color = Config.SIDE_COLORS[side]
		local x = SQUARE_X * sign

		local tile = b:box(Vector3.new(SQUARE_SIZE, 0.2, SQUARE_SIZE), at(x, top + 0.1, SQUARE_Z), TILE, `{side}Square`)
		-- So clients (the tutorial) can tell which station and side a square is.
		tile:SetAttribute("Arena", id)
		tile:SetAttribute("Side", side)
		for _, offset in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			local length = Vector3.new(math.abs(offset.Z), 0, math.abs(offset.X)) * (SQUARE_SIZE + 0.6)
			local edge = b:box(
				length + offset:Abs() * 0.6 + Vector3.new(0, 0.3, 0),
				at(x + offset.X * SQUARE_SIZE / 2, top + 0.15, SQUARE_Z + offset.Z * SQUARE_SIZE / 2),
				color,
				"Edge"
			)
			edge.Material = Enum.Material.Neon
			edge.CanCollide = false
		end
		-- A column of light while someone waits in the square.
		local beam = b:cylinder(24, SQUARE_SIZE * 0.8, at(x, top + 12, SQUARE_Z).Position, color, "Beam")
		b:ghost(beam, 1)
		beam.Material = Enum.Material.Neon
		squares[side] = { tile = tile, beam = beam }

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Join"
		prompt.ObjectText = ""
		prompt.HoldDuration = 0
		-- The squares are 11 studs apart, so someone waiting in one doesn't get the other's prompt.
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = tile
		prompts[side] = prompt

		-- The hover pad beside the box, with a faint light under it.
		local padX = PAD_X * sign
		local pad = b:cylinder(0.8, 6, at(padX, PAD_TOP - 0.4, PAD_Z).Position, color, "HoverPad")
		pad.Material = Enum.Material.Neon
		local glow = b:cylinder(PAD_TOP - 0.8, 4.5, at(padX, (PAD_TOP - 0.8) / 2, PAD_Z).Position, color, "PadGlow")
		b:ghost(glow, 0.88)
		glow.Material = Enum.Material.Neon

		seats[side] = facingOut(x, top + 0.2, SQUARE_Z)
		stands[side] = facingOut(padX, PAD_TOP, PAD_Z)
		exits[side] = at(x, 0, EXIT_Z) -- facing the box
	end

	local signGui, signText = makeSign(b, at(0, 8.5, SQUARE_Z).Position)
	local screen, faces = makeScreen(arena.backdrop)

	local function show(waiting: { [string]: Player? }, busy: boolean)
		local count = 0
		for _, side in SIDES do
			local player = waiting[side]
			local square = squares[side]
			local filled = player ~= nil and not busy
			if player then
				count += 1
			end
			square.tile.Material = if filled then Enum.Material.Neon else Enum.Material.SmoothPlastic
			square.tile.Color = if filled then Config.SIDE_COLORS[side] else TILE
			square.tile.Transparency = if filled then 0.3 else 0
			square.beam.Transparency = if filled then 0.82 else 1
			prompts[side].Enabled = not busy and player == nil

			local face = faces[side]
			face.image.Image = if player then string.format(HEADSHOT, player.UserId) else ""
			face.label.Text = if player then "" else "?"
		end
		screen.Enabled = not busy
		signGui.Enabled = not busy
		signText.Text = `{count}/2 PLAYERS`
	end
	show({}, false)

	return {
		id = id,
		arena = arena,
		prompts = prompts,
		seats = seats,
		stands = stands,
		exits = exits,
		show = show,
	}
end

return Station
