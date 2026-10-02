local Config = require(script.Parent.Config)

-- The playable brainrots: their class (how they play) and their look (how they're recognized).
--
-- Every ball has the same invisible physics sphere; the look is a set of parts that follows it
-- around facing the way it rolls. Looks are described below in look space: the ball's center is
-- the origin, forward is -Z, up is +Y and right is +X. The first part is the body.

export type PartSpec = {
	shape: "Ball" | "Block" | "Cylinder" | "Wedge",
	size: Vector3,
	at: Vector3,
	rotate: Vector3?, -- degrees around X, Y and Z
	color: Color3,
	material: Enum.Material?,
	spin: number?, -- radians per second around the part's own Z axis, e.g. a propeller
}

export type Class = {
	density: number, -- all balls are the same size, so this sets weight
	topSpeed: number,
	accel: number,
	elasticity: number,
}

export type Brainrot = {
	id: string,
	name: string,
	emoji: string,
	class: string,
	color: Color3,
	word: string, -- pops up when it hits something
	look: { PartSpec },
}

local classes: { [string]: Class } = {
	Striker = { density = 0.7, topSpeed = 72, accel = 150, elasticity = 0.55 },
	Juggernaut = { density = 1.8, topSpeed = 54, accel = 110, elasticity = 0.15 },
	Trickster = { density = 1, topSpeed = 62, accel = 125, elasticity = 0.85 },
	Support = { density = 1.1, topSpeed = 62, accel = 130, elasticity = 0.45 },
}

local SIZE = Config.BALL_SIZE
local WHITE = Color3.fromRGB(250, 250, 250)
local BLACK = Color3.fromRGB(20, 20, 20)

local function ball(size: number, at: Vector3, color: Color3, material: Enum.Material?): PartSpec
	return { shape = "Ball", size = Vector3.one * size, at = at, color = color, material = material }
end

local function block(size: Vector3, at: Vector3, color: Color3, rotate: Vector3?): PartSpec
	return { shape = "Block", size = size, at = at, color = color, rotate = rotate }
end

-- Two eyes looking forward, `spread` studs apart, with their whites centered at depth z.
local function eyes(spread: number, y: number, z: number, size: number): { PartSpec }
	local half = spread / 2
	return {
		ball(size, Vector3.new(-half, y, z), WHITE),
		ball(size, Vector3.new(half, y, z), WHITE),
		ball(size * 0.5, Vector3.new(-half, y, z - size * 0.4), BLACK),
		ball(size * 0.5, Vector3.new(half, y, z - size * 0.4), BLACK),
	}
end

local function join(...: { PartSpec }): { PartSpec }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

local WOOD = Color3.fromRGB(176, 122, 68)
local SHARK = Color3.fromRGB(70, 150, 230)
local CROC = Color3.fromRGB(80, 150, 70)
local BANANA = Color3.fromRGB(250, 215, 60)
local MONKEY = Color3.fromRGB(140, 92, 55)

local list: { Brainrot } = {
	{
		id = "TungTungTungSahur",
		name = "Tung Tung Tung Sahur",
		emoji = "🪵",
		class = "Juggernaut",
		color = WOOD,
		word = "BONK!",
		look = join({ ball(SIZE, Vector3.zero, WOOD, Enum.Material.Wood) }, eyes(2.3, 0.8, -3.05, 1.7), {
			-- Angry eyebrows and a flat mouth
			block(Vector3.new(1.5, 0.35, 0.4), Vector3.new(-1.15, 1.95, -3), BLACK, Vector3.new(0, 0, -15)),
			block(Vector3.new(1.5, 0.35, 0.4), Vector3.new(1.15, 1.95, -3), BLACK, Vector3.new(0, 0, 15)),
			block(Vector3.new(2, 0.35, 0.4), Vector3.new(0, -1, -3.3), BLACK),
			-- The bat, held upright on the right
			{
				shape = "Cylinder",
				size = Vector3.new(7, 0.9, 0.9),
				at = Vector3.new(4.2, 1.6, -0.6),
				rotate = Vector3.new(0, 0, 75),
				color = Color3.fromRGB(215, 170, 110),
				material = Enum.Material.Wood,
			},
		}),
	},
	{
		id = "TralaleroTralala",
		name = "Tralalero Tralala",
		emoji = "🦈",
		class = "Striker",
		color = SHARK,
		word = "SPLASH!",
		look = join({ ball(SIZE, Vector3.zero, SHARK) }, {
			-- White belly, with the eyes above it and a wide grin on it
			ball(5.6, Vector3.new(0, -0.9, -1.4), WHITE),
		}, eyes(2.4, 1.3, -2.9, 1.5), {
			block(Vector3.new(2.6, 0.35, 0.4), Vector3.new(0, -0.4, -4.05), BLACK),
			-- Fins
			{ shape = "Wedge", size = Vector3.new(0.6, 3, 3), at = Vector3.new(0, 4.3, 0.4), color = SHARK },
			{
				shape = "Wedge",
				size = Vector3.new(0.6, 3, 2.5),
				at = Vector3.new(0, 0.8, 4),
				rotate = Vector3.new(0, 180, 0),
				color = SHARK,
			},
			-- Blue sneakers
			block(Vector3.new(1.5, 1, 2.4), Vector3.new(-1.3, -3.4, -0.5), Color3.fromRGB(40, 80, 200)),
			block(Vector3.new(1.5, 1, 2.4), Vector3.new(1.3, -3.4, -0.5), Color3.fromRGB(40, 80, 200)),
		}),
	},
	{
		id = "BombardiroCrocodilo",
		name = "Bombardiro Crocodilo",
		emoji = "🐊",
		class = "Trickster",
		color = CROC,
		word = "BOOM!",
		look = join({ ball(SIZE, Vector3.zero, CROC) }, eyes(2.2, 2, -2.4, 1.5), {
			-- Snout with nostrils
			block(Vector3.new(3.4, 1.6, 3.6), Vector3.new(0, -0.6, -4.2), Color3.fromRGB(65, 125, 55)),
			ball(0.45, Vector3.new(-0.6, 0.25, -5.9), BLACK),
			ball(0.45, Vector3.new(0.6, 0.25, -5.9), BLACK),
			-- Bomber wings and tail
			block(Vector3.new(11, 0.35, 2.6), Vector3.new(0, 0.2, 0.6), Color3.fromRGB(150, 155, 165)),
			{
				shape = "Wedge",
				size = Vector3.new(0.4, 2.4, 2.4),
				at = Vector3.new(0, 2.8, 3.4),
				rotate = Vector3.new(0, 180, 0),
				color = Color3.fromRGB(150, 155, 165),
			},
			-- Propeller on the nose
			ball(0.8, Vector3.new(0, -0.6, -6.2), Color3.fromRGB(90, 90, 95)),
			{
				shape = "Block",
				size = Vector3.new(4, 0.4, 0.2),
				at = Vector3.new(0, -0.6, -6.4),
				color = Color3.fromRGB(60, 60, 65),
				spin = 25,
			},
		}),
	},
	{
		id = "ChimpanziniBananini",
		name = "Chimpanzini Bananini",
		emoji = "🍌",
		class = "Support",
		color = BANANA,
		word = "BANANA!",
		look = join({ ball(SIZE, Vector3.zero, BANANA) }, {
			-- Monkey face and ears
			ball(5, Vector3.new(0, 0.1, -1.7), MONKEY),
			ball(1.6, Vector3.new(-3.4, 0.9, -0.5), MONKEY),
			ball(1.6, Vector3.new(3.4, 0.9, -0.5), MONKEY),
		}, eyes(1.8, 0.7, -3.75, 1.3), {
			block(Vector3.new(1.6, 0.3, 0.3), Vector3.new(0, -0.9, -4.05), Color3.fromRGB(60, 35, 20)),
			-- Banana stem
			{
				shape = "Cylinder",
				size = Vector3.new(1.6, 0.8, 0.8),
				at = Vector3.new(0, 4.1, 0),
				rotate = Vector3.new(0, 0, 90),
				color = Color3.fromRGB(90, 60, 30),
			},
		}),
	},
}

local byId: { [string]: Brainrot } = {}
for _, brainrot in list do
	byId[brainrot.id] = brainrot
end

local Brainrots = {
	list = list,
	byId = byId,
	classes = classes,
	default = list[1].id,
}

-- The brainrot with this id, or the default one if the id is unknown. Takes attribute values
-- as they come, so callers needn't check them.
function Brainrots.get(id: unknown): Brainrot
	return (if typeof(id) == "string" then byId[id] else nil) or byId[Brainrots.default]
end

function Brainrots.classOf(id: unknown): Class
	return classes[Brainrots.get(id).class]
end

return Brainrots
