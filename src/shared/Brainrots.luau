local Config = require(script.Parent.Config)

-- The ball roster (the design doc's BallRegistry), themed as brainrots. Each one has stats, a
-- rarity, an ability (a module in src/server/Skills), a short description for cards, and a look.
-- New players start with the STARTERS; the rest come from the Ball Machine, reward rolls, level
-- rewards, fusion and trades.
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
	skillHint: string, -- one or two words
	description: string, -- one short sentence for the draft and inventory cards
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
local CACTUS = Color3.fromRGB(95, 170, 80)
local ELEPHANT = Color3.fromRGB(150, 150, 165)
local FRIDGE = Color3.fromRGB(230, 238, 245)
local FROST = Color3.fromRGB(150, 220, 255)
local CAMEL = Color3.fromRGB(205, 160, 100)
local SHRIMP = Color3.fromRGB(255, 140, 95)
local SHRIMP_DARK = Color3.fromRGB(240, 105, 75)
local FROG = Color3.fromRGB(110, 190, 70)
local BALLET = Color3.fromRGB(255, 170, 205)
local SATURN = Color3.fromRGB(255, 200, 90)

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
		description = "Bananas heal it and blow up enemies.",
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
		description = "Grows bigger and hits harder.",
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
		description = "Steals health with every hit.",
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
		description = "Wall vines slow and hurt enemies.",
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
		description = "Builds turrets that fire homing shots.",
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
		description = "Opens a black hole when nearly broken.",
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
	{
		id = "LiriliLarila",
		name = "Lirilì Larilà",
		emoji = "🌵",
		rarity = "Common",
		stats = { health = 1300, mass = 14, speed = 21, impactPower = 1 },
		skill = "Blades",
		skillIcon = "🌵",
		skillHint = "Spikes",
		description = "Orbiting spikes that multiply.",
		color = CACTUS,
		word = "POKE!",
		look = join({ ball(SIZE, Vector3.zero, CACTUS) }, eyes(2.2, 1.2, -3.1, 1.3), {
			-- Elephant trunk and ears
			block(Vector3.new(1.1, 1.1, 3), Vector3.new(0, -0.5, -4.2), ELEPHANT, Vector3.new(25, 0, 0)),
			block(Vector3.new(0.4, 3, 2.6), Vector3.new(-3.6, 1, -0.4), ELEPHANT),
			block(Vector3.new(0.4, 3, 2.6), Vector3.new(3.6, 1, -0.4), ELEPHANT),
			-- Spikes
			block(Vector3.new(0.3, 1, 0.3), Vector3.new(0, 3.8, 0), WHITE),
			block(Vector3.new(0.3, 1, 0.3), Vector3.new(1.9, 3.2, 0.8), WHITE, Vector3.new(0, 0, -30)),
			block(Vector3.new(0.3, 1, 0.3), Vector3.new(-1.9, 3.2, 0.8), WHITE, Vector3.new(0, 0, 30)),
			block(Vector3.new(0.3, 1, 0.3), Vector3.new(3, 1.6, 1.6), WHITE, Vector3.new(0, 0, -60)),
			block(Vector3.new(0.3, 1, 0.3), Vector3.new(-3, 1.6, 1.6), WHITE, Vector3.new(0, 0, 60)),
		}),
	},
	{
		id = "FrigoCamelo",
		name = "Frigo Camelo",
		emoji = "🐪",
		rarity = "Common",
		stats = { health = 1500, mass = 20, speed = 19, impactPower = 1 },
		skill = "Frost",
		skillIcon = "❄️",
		skillHint = "Freeze",
		description = "Hits freeze enemies in place.",
		color = FROST,
		word = "BRRR!",
		look = join({ ball(SIZE, Vector3.zero, FRIDGE) }, eyes(2.2, 1.4, -3, 1.3), {
			-- Camel hump, fridge door and handle
			ball(3.6, Vector3.new(0, 3.3, 1), CAMEL),
			block(Vector3.new(6.6, 0.2, 0.2), Vector3.new(0, -0.4, -3.45), Color3.fromRGB(150, 160, 175)),
			block(Vector3.new(0.35, 1.6, 0.45), Vector3.new(2, -1.6, -3.2), STEEL),
			block(Vector3.new(1.6, 0.9, 1.6), Vector3.new(0, 0, -3.9), CAMEL),
		}),
	},
	{
		id = "TrippiTroppi",
		name = "Trippi Troppi",
		emoji = "🦐",
		rarity = "Rare",
		stats = { health = 1200, mass = 13, speed = 23, impactPower = 1.05 },
		skill = "Laser",
		skillIcon = "🔦",
		skillHint = "Lasers",
		description = "Shoots lasers that bounce off walls.",
		color = SHRIMP,
		word = "ZAP!",
		look = join({ ball(SIZE, Vector3.zero, SHRIMP) }, eyes(2.2, 1, -3.1, 1.4), {
			-- Cat ears, whiskers and a shrimp tail
			{ shape = "Wedge", size = Vector3.new(0.5, 1.8, 1.6), at = Vector3.new(-1.6, 3.6, -0.6), color = SHRIMP },
			{ shape = "Wedge", size = Vector3.new(0.5, 1.8, 1.6), at = Vector3.new(1.6, 3.6, -0.6), color = SHRIMP },
			block(Vector3.new(2.2, 0.12, 0.12), Vector3.new(-2.6, -0.3, -3), BLACK, Vector3.new(0, 0, 10)),
			block(Vector3.new(2.2, 0.12, 0.12), Vector3.new(2.6, -0.3, -3), BLACK, Vector3.new(0, 0, -10)),
			ball(2, Vector3.new(0, 0.5, 3.9), SHRIMP_DARK),
			ball(1.6, Vector3.new(0, 1.4, 5), SHRIMP_DARK),
			ball(1.2, Vector3.new(0, 2.4, 5.7), SHRIMP_DARK),
		}),
	},
	{
		id = "BonecaAmbalabu",
		name = "Boneca Ambalabu",
		emoji = "🐸",
		rarity = "Rare",
		stats = { health = 1400, mass = 17, speed = 20, impactPower = 1 },
		skill = "Lightning",
		skillIcon = "⚡",
		skillHint = "Lightning",
		description = "Calls down lightning on enemies.",
		color = FROG,
		word = "RIBBIT!",
		look = join({ ball(SIZE, Vector3.zero, FROG) }, eyes(2.6, 2.6, -2.2, 1.7), {
			-- A tire around its middle
			{
				shape = "Cylinder",
				size = Vector3.new(1.8, 8.4, 8.4),
				at = Vector3.new(0, -0.6, 0),
				rotate = Vector3.new(0, 0, 90),
				color = Color3.fromRGB(35, 35, 40),
			},
			block(Vector3.new(2.4, 0.3, 0.4), Vector3.new(0, 0.6, -3.4), BLACK),
		}),
	},
	{
		id = "BallerinaCappuccina",
		name = "Ballerina Cappuccina",
		emoji = "💃",
		rarity = "Epic",
		stats = { health = 1150, mass = 11, speed = 24, impactPower = 1.1 },
		skill = "Dice",
		skillIcon = "🎲",
		skillHint = "Lucky dice",
		description = "Every bounce rolls a lucky die.",
		color = BALLET,
		word = "TWIRL!",
		look = join({ ball(SIZE, Vector3.zero, BALLET) }, eyes(2.2, 0.8, -3.2, 1.2), {
			-- A coffee cup hat and a tutu
			{
				shape = "Cylinder",
				size = Vector3.new(2.4, 3.6, 3.6),
				at = Vector3.new(0, 4, 0),
				rotate = Vector3.new(0, 0, 90),
				color = WHITE,
			},
			{
				shape = "Cylinder",
				size = Vector3.new(0.3, 3.2, 3.2),
				at = Vector3.new(0, 5.25, 0),
				rotate = Vector3.new(0, 0, 90),
				color = COFFEE,
			},
			{
				shape = "Cylinder",
				size = Vector3.new(0.7, 9.4, 9.4),
				at = Vector3.new(0, -1.4, 0),
				rotate = Vector3.new(0, 0, 90),
				color = Color3.fromRGB(255, 205, 230),
			},
		}),
	},
	{
		id = "LaVacaSaturnoSaturnita",
		name = "La Vaca Saturno Saturnita",
		emoji = "🐄",
		rarity = "Legendary",
		stats = { health = 1700, mass = 26, speed = 19, impactPower = 0.95 },
		skill = "Shackles",
		skillIcon = "⛓️",
		skillHint = "Chains",
		description = "Chains enemies and drags them close.",
		color = SATURN,
		word = "MOO!",
		look = join({ ball(SIZE, Vector3.zero, WHITE) }, eyes(2.4, 1.2, -3, 1.3), {
			-- Cow spots, snout and horns, and Saturn's ring
			ball(2.2, Vector3.new(2.2, 1.6, 1.8), BLACK),
			ball(1.8, Vector3.new(-2.4, -1.4, 1.6), BLACK),
			ball(1.6, Vector3.new(-1, 2.6, 2.2), BLACK),
			block(Vector3.new(2.4, 1.4, 1), Vector3.new(0, -1.2, -3.3), Color3.fromRGB(255, 170, 180)),
			block(Vector3.new(0.4, 1.3, 0.4), Vector3.new(-1.4, 3.7, -0.4), Color3.fromRGB(240, 225, 190), Vector3.new(0, 0, 20)),
			block(Vector3.new(0.4, 1.3, 0.4), Vector3.new(1.4, 3.7, -0.4), Color3.fromRGB(240, 225, 190), Vector3.new(0, 0, -20)),
			{
				shape = "Cylinder",
				size = Vector3.new(0.3, 11, 11),
				at = Vector3.zero,
				rotate = Vector3.new(20, 0, 90),
				color = SATURN,
				material = Enum.Material.Neon,
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
	DESIGN_SIZE = SIZE,
	STARTERS = { "ChimpanziniBananini", "LiriliLarila", "TungTungTungSahur" },
}

-- Whether `id` is a real brainrot. Use it to check ids that come from clients.
function Brainrots.exists(id: unknown): boolean
	return typeof(id) == "string" and byId[id] ~= nil
end

-- The brainrot with this id, or the first one if the id is unknown. Takes attribute values as
-- they come, so callers needn't check them.
function Brainrots.get(id: unknown): Brainrot
	return (if typeof(id) == "string" then byId[id] else nil) or list[1]
end

-- `count` different brainrots, picked at random with rarer ones less likely. `from` limits the
-- pick to those ids (e.g. the balls a player owns).
function Brainrots.roll(count: number, rng: Random, from: { string }?): { string }
	local pool = {}
	for _, brainrot in list do
		if not from or table.find(from, brainrot.id) then
			table.insert(pool, brainrot)
		end
	end
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
