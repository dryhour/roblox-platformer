local Config = require(script.Parent.Config)

-- The ball roster (the design doc's BallRegistry), themed as brainrots. Each one has stats, a
-- rarity, an ability (a module in src/server/Skills) and a look.
--
-- Looks are built from parts around the ball's center: forward is -Z, up is +Y, right is +X.
-- The first part is the body. Part sizes are for a ball DESIGN_SIZE studs across; Looks scales
-- them to Config.BALL_SIZE in battle. In the arena, balls face the players and turn toward
-- where they're going.

export type PartSpec = {
	shape: "Ball" | "Block" | "Cylinder" | "Wedge",
	size: Vector3,
	at: Vector3,
	rotate: Vector3?, -- degrees around X, Y and Z
	color: Color3,
	material: Enum.Material?,
	spin: number?, -- radians per second around the part's own Z axis, e.g. a propeller
}

export type Stats = {
	health: number,
	mass: number, -- heavier balls deal more and take less in collisions
	speed: number, -- balls keep rolling at this speed the whole battle
	impactPower: number,
}

export type Brainrot = {
	id: string,
	name: string,
	emoji: string,
	rarity: string, -- a key of Config.RARITIES
	stats: Stats,
	skill: string, -- module name in src/server/Skills
	skillIcon: string,
	skillHint: string, -- one or two words for the draft card
	color: Color3,
	word: string, -- pops up when it hits something
	look: { PartSpec },
}

local SIZE = 7 -- looks are drawn for a ball this big (Brainrots.DESIGN_SIZE)
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
local LEAVES = Color3.fromRGB(70, 135, 60)
local BARK = Color3.fromRGB(110, 75, 45)
local COFFEE = Color3.fromRGB(205, 160, 110)
local STEEL = Color3.fromRGB(200, 205, 215)

local list: { Brainrot } = {
	{
		id = "ChimpanziniBananini",
		name = "Chimpanzini Bananini",
		emoji = "🍌",
		rarity = "Common",
		stats = { health = 1400, mass = 15, speed = 21, impactPower = 1 },
		skill = "Bananas",
		skillIcon = "🍌",
		skillHint = "Bananas",
		color = BANANA,
		word = "BANANA!",
		look = join({ ball(SIZE, Vector3.zero, BANANA) }, {
			ball(5, Vector3.new(0, 0.1, -1.7), MONKEY),
			ball(1.6, Vector3.new(-3.4, 0.9, -0.5), MONKEY),
			ball(1.6, Vector3.new(3.4, 0.9, -0.5), MONKEY),
		}, eyes(1.8, 0.7, -3.75, 1.3), {
			block(Vector3.new(1.6, 0.3, 0.3), Vector3.new(0, -0.9, -4.05), Color3.fromRGB(60, 35, 20)),
			{
				shape = "Cylinder",
				size = Vector3.new(1.6, 0.8, 0.8),
				at = Vector3.new(0, 4.1, 0),
				rotate = Vector3.new(0, 0, 90),
				color = Color3.fromRGB(90, 60, 30),
			},
		}),
	},
	{
		id = "TungTungTungSahur",
		name = "Tung Tung Tung Sahur",
		emoji = "🪵",
		rarity = "Rare",
		stats = { health = 1800, mass = 30, speed = 18, impactPower = 1 },
		skill = "Charge",
		skillIcon = "📈",
		skillHint = "Grows",
		color = WOOD,
		word = "BONK!",
		look = join({ ball(SIZE, Vector3.zero, WOOD, Enum.Material.Wood) }, eyes(2.3, 0.8, -3.05, 1.7), {
			block(Vector3.new(1.5, 0.35, 0.4), Vector3.new(-1.15, 1.95, -3), BLACK, Vector3.new(0, 0, -15)),
			block(Vector3.new(1.5, 0.35, 0.4), Vector3.new(1.15, 1.95, -3), BLACK, Vector3.new(0, 0, 15)),
			block(Vector3.new(2, 0.35, 0.4), Vector3.new(0, -1, -3.3), BLACK),
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
		rarity = "Epic",
		stats = { health = 1100, mass = 10, speed = 25, impactPower = 1.25 },
		skill = "Vampire",
		skillIcon = "🧛",
		skillHint = "Steals HP",
		color = SHARK,
		word = "SPLASH!",
		look = join({ ball(SIZE, Vector3.zero, SHARK) }, {
			ball(5.6, Vector3.new(0, -0.9, -1.4), WHITE),
		}, eyes(2.4, 1.3, -2.9, 1.5), {
			block(Vector3.new(2.6, 0.35, 0.4), Vector3.new(0, -0.4, -4.05), BLACK),
			{ shape = "Wedge", size = Vector3.new(0.6, 3, 3), at = Vector3.new(0, 4.3, 0.4), color = SHARK },
			{
				shape = "Wedge",
				size = Vector3.new(0.6, 3, 2.5),
				at = Vector3.new(0, 0.8, 4),
				rotate = Vector3.new(0, 180, 0),
				color = SHARK,
			},
			block(Vector3.new(1.5, 1, 2.4), Vector3.new(-1.3, -3.4, -0.5), Color3.fromRGB(40, 80, 200)),
			block(Vector3.new(1.5, 1, 2.4), Vector3.new(1.3, -3.4, -0.5), Color3.fromRGB(40, 80, 200)),
		}),
	},
	{
		id = "BrrBrrPatapim",
		name = "Brr Brr Patapim",
		emoji = "🌳",
		rarity = "Epic",
		stats = { health = 1300, mass = 16, speed = 21, impactPower = 0.95 },
		skill = "Vines",
		skillIcon = "🌿",
		skillHint = "Vines",
		color = LEAVES,
		word = "BRR BRR!",
		look = join({ ball(SIZE, Vector3.zero, LEAVES, Enum.Material.Grass) }, eyes(2.2, 1, -3, 1.4), {
			-- Long nose and a little hat
			block(Vector3.new(0.9, 0.9, 2.8), Vector3.new(0, 0, -4.4), BARK),
			{
				shape = "Cylinder",
				size = Vector3.new(1.2, 3, 3),
				at = Vector3.new(0, 3.9, 0),
				rotate = Vector3.new(0, 0, 90),
				color = BARK,
			},
			-- Twig arms and big feet
			block(Vector3.new(3, 0.5, 0.5), Vector3.new(-4.4, 0.5, 0), BARK, Vector3.new(0, 0, 30)),
			block(Vector3.new(3, 0.5, 0.5), Vector3.new(4.4, 0.5, 0), BARK, Vector3.new(0, 0, -30)),
			block(Vector3.new(1.8, 0.8, 3), Vector3.new(-1.4, -3.4, -0.8), BARK),
			block(Vector3.new(1.8, 0.8, 3), Vector3.new(1.4, -3.4, -0.8), BARK),
		}),
	},
	{
		id = "BombardiroCrocodilo",
		name = "Bombardiro Crocodilo",
		emoji = "🐊",
		rarity = "Legendary",
		stats = { health = 1300, mass = 18, speed = 20, impactPower = 0.9 },
		skill = "Cannon",
		skillIcon = "💣",
		skillHint = "Turrets",
		color = CROC,
		word = "BOOM!",
		look = join({ ball(SIZE, Vector3.zero, CROC) }, eyes(2.2, 2, -2.4, 1.5), {
			block(Vector3.new(3.4, 1.6, 3.6), Vector3.new(0, -0.6, -4.2), Color3.fromRGB(65, 125, 55)),
			ball(0.45, Vector3.new(-0.6, 0.25, -5.9), BLACK),
			ball(0.45, Vector3.new(0.6, 0.25, -5.9), BLACK),
			block(Vector3.new(11, 0.35, 2.6), Vector3.new(0, 0.2, 0.6), Color3.fromRGB(150, 155, 165)),
			{
				shape = "Wedge",
				size = Vector3.new(0.4, 2.4, 2.4),
				at = Vector3.new(0, 2.8, 3.4),
				rotate = Vector3.new(0, 180, 0),
				color = Color3.fromRGB(150, 155, 165),
			},
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
		id = "CappuccinoAssassino",
		name = "Cappuccino Assassino",
		emoji = "☕",
		rarity = "Mythic",
		stats = { health = 1000, mass = 12, speed = 24, impactPower = 1.15 },
		skill = "BlackHole",
		skillIcon = "🌀",
		skillHint = "Black hole",
		color = COFFEE,
		word = "SLICE!",
		look = join({ ball(SIZE, Vector3.zero, COFFEE) }, {
			-- Milk foam on top, and a ninja mask
			{
				shape = "Cylinder",
				size = Vector3.new(1.4, 6, 6),
				at = Vector3.new(0, 3.1, 0),
				rotate = Vector3.new(0, 0, 90),
				color = WHITE,
			},
			block(Vector3.new(7.2, 1.3, 7.2), Vector3.new(0, 0.9, 0), BLACK),
		}, eyes(2.2, 0.9, -3.4, 1), {
			-- Crossed katanas on the back
			block(Vector3.new(0.3, 0.3, 8), Vector3.new(-0.8, 1, 3.6), STEEL, Vector3.new(0, 30, 60)),
			block(Vector3.new(0.3, 0.3, 8), Vector3.new(0.8, 1, 3.6), STEEL, Vector3.new(0, -30, -60)),
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
	DESIGN_SIZE = SIZE,
}

-- The brainrot with this id, or the first one if the id is unknown. Takes attribute values as
-- they come, so callers needn't check them.
function Brainrots.get(id: unknown): Brainrot
	return (if typeof(id) == "string" then byId[id] else nil) or list[1]
end

-- `count` different brainrots, picked at random with rarer ones less likely.
function Brainrots.roll(count: number, rng: Random): { string }
	local pool = table.clone(list)
	local picked = {}
	while #picked < count and #pool > 0 do
		local total = 0
		for _, brainrot in pool do
			total += Config.RARITIES[brainrot.rarity].weight
		end
		local roll = rng:NextNumber() * total
		for index, brainrot in pool do
			roll -= Config.RARITIES[brainrot.rarity].weight
			if roll <= 0 or index == #pool then
				table.insert(picked, brainrot.id)
				table.remove(pool, index)
				break
			end
		end
	end
	return picked
end

return Brainrots
