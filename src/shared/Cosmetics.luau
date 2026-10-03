local Brainrots = require(script.Parent.Brainrots)

-- Cosmetics: flyers you ride around the lobby (and float on beside the arena), and explosions:
-- when your ball wins a round, the beaten ball bursts into energy in your explosion's style,
-- which flies into the losing player and blows up on them. Both come from the Store's machines,
-- level rewards and reward rolls, and are equipped in the Inventory.
--
-- Flyer parts sit around the flyer's top center, where your feet go: forward is -Z.
local Cosmetics = {}

export type Flyer = {
	id: string,
	name: string,
	emoji: string,
	rarity: string, -- a key of Config.RARITIES
	description: string,
	parts: { Brainrots.PartSpec },
}

export type Explosion = {
	id: string,
	name: string,
	emoji: string, -- pops up over the blast
	rarity: string,
	description: string,
	colors: { Color3 },
	texture: string, -- what the particles look like
	speed: number, -- how fast they fly out
	lifetime: number, -- how long they last
	rise: number, -- upward pull on them (negative falls)
}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

Cosmetics.FLYER_LIFT = 1.4 -- how much higher a flyer holds you up

local WHITE = Color3.fromRGB(245, 248, 255)
local GOLD = Color3.fromRGB(255, 200, 60)

local function block(size: Vector3, at: Vector3, color: Color3, rotate: Vector3?, material: Enum.Material?): Brainrots.PartSpec
	return { shape = "Block", size = size, at = at, color = color, rotate = rotate, material = material }
end

local function puff(size: number, at: Vector3): Brainrots.PartSpec
	return { shape = "Ball", size = Vector3.one * size, at = at, color = WHITE }
end

local function disc(height: number, diameter: number, at: Vector3, color: Color3, material: Enum.Material?): Brainrots.PartSpec
	return {
		shape = "Cylinder",
		size = Vector3.new(height, diameter, diameter),
		at = at,
		rotate = Vector3.new(0, 0, 90),
		color = color,
		material = material,
	}
end

-- A folded paper plane: two wings narrowing toward the front, and a keel underneath.
local function plane(color: Color3): { Brainrots.PartSpec }
	return {
		block(Vector3.new(2.2, 0.2, 6), Vector3.new(-1.1, -0.5, 0.2), color, Vector3.new(0, -10, -8)),
		block(Vector3.new(2.2, 0.2, 6), Vector3.new(1.1, -0.5, 0.2), color, Vector3.new(0, 10, 8)),
		block(Vector3.new(0.25, 0.8, 5), Vector3.new(0, -0.95, 0.4), color),
	}
end

Cosmetics.flyers = {
	{
		id = "PaperPlane",
		name = "Paper Plane",
		emoji = "✈️",
		rarity = "Common",
		description = "A trusty folded plane.",
		parts = plane(WHITE),
	},
	{
		id = "GreenPlane",
		name = "Green Plane",
		emoji = "🛩️",
		rarity = "Rare",
		description = "Folded from lucky green paper.",
		parts = plane(Color3.fromRGB(90, 200, 110)),
	},
	{
		id = "Cloud",
		name = "Cloud",
		emoji = "☁️",
		rarity = "Rare",
		description = "Soft, fluffy and always floating.",
		parts = {
			puff(2.6, Vector3.new(0, -1.2, 0)),
			puff(2, Vector3.new(-1.6, -1.3, 0.4)),
			puff(2, Vector3.new(1.6, -1.3, -0.3)),
			puff(1.7, Vector3.new(0.4, -1.3, 1.6)),
			puff(1.7, Vector3.new(-0.6, -1.3, -1.6)),
		},
	},
	{
		id = "Hoverboard",
		name = "Hoverboard",
		emoji = "🛹",
		rarity = "Epic",
		description = "Glows underneath as it glides.",
		parts = {
			block(Vector3.new(2.2, 0.4, 5.4), Vector3.new(0, -0.5, 0), Color3.fromRGB(40, 45, 70)),
			block(Vector3.new(1.8, 0.15, 5), Vector3.new(0, -0.8, 0), Color3.fromRGB(80, 220, 255), nil, Enum.Material.Neon),
		},
	},
	{
		id = "MagicCarpet",
		name = "Magic Carpet",
		emoji = "🧶",
		rarity = "Epic",
		description = "Woven with a little magic.",
		parts = {
			block(Vector3.new(4, 0.25, 5.6), Vector3.new(0, -0.5, 0), Color3.fromRGB(150, 50, 160), nil, Enum.Material.Fabric),
			block(Vector3.new(4.3, 0.2, 0.3), Vector3.new(0, -0.5, 2.8), GOLD),
			block(Vector3.new(4.3, 0.2, 0.3), Vector3.new(0, -0.5, -2.8), GOLD),
		},
	},
	{
		id = "UFO",
		name = "UFO",
		emoji = "🛸",
		rarity = "Legendary",
		description = "Borrowed from very far away.",
		parts = {
			disc(0.7, 6, Vector3.new(0, -0.7, 0), Color3.fromRGB(190, 200, 215), Enum.Material.Metal),
			disc(0.3, 6.6, Vector3.new(0, -0.8, 0), Color3.fromRGB(120, 255, 170), Enum.Material.Neon),
			disc(0.6, 3, Vector3.new(0, -1.3, 0), Color3.fromRGB(150, 160, 180), Enum.Material.Metal),
		},
	},
} :: { Flyer }

Cosmetics.explosions = {
	{
		id = "Default",
		texture = FIRE,
		speed = 26,
		lifetime = 0.8,
		rise = 4,
		name = "Boom",
		emoji = "💥",
		rarity = "Common",
		description = "The classic knockout.",
		colors = { Color3.fromRGB(255, 150, 40), Color3.new(1, 1, 1) },
	},
	{
		id = "Confetti",
		texture = SPARKLES,
		speed = 30,
		lifetime = 1.4,
		rise = -20,
		name = "Confetti",
		emoji = "🎉",
		rarity = "Rare",
		description = "Every knockout is a party.",
		colors = {
			Color3.fromRGB(255, 90, 120),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(80, 200, 255),
			Color3.fromRGB(120, 230, 110),
		},
	},
	{
		id = "Hearts",
		texture = SPARKLES,
		speed = 18,
		lifetime = 1.2,
		rise = 6,
		name = "Hearts",
		emoji = "💖",
		rarity = "Rare",
		description = "Knock them out with love.",
		colors = { Color3.fromRGB(255, 90, 160), Color3.fromRGB(255, 180, 210) },
	},
	{
		id = "Lightning",
		texture = SPARKLES,
		speed = 45,
		lifetime = 0.4,
		rise = 0,
		name = "Lightning",
		emoji = "⚡",
		rarity = "Epic",
		description = "A crackling blue blast.",
		colors = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 255, 140) },
	},
	{
		id = "Fire",
		texture = FIRE,
		speed = 20,
		lifetime = 1,
		rise = 18,
		name = "Fire",
		emoji = "🔥",
		rarity = "Epic",
		description = "Leaves nothing but embers.",
		colors = { Color3.fromRGB(255, 80, 30), Color3.fromRGB(255, 190, 40) },
	},
	{
		id = "Galaxy",
		texture = SPARKLES,
		speed = 8,
		lifetime = 2,
		rise = 0,
		name = "Galaxy",
		emoji = "🌌",
		rarity = "Legendary",
		description = "A burst of stars.",
		colors = { Color3.fromRGB(140, 80, 255), Color3.fromRGB(60, 40, 160), Color3.new(1, 1, 1) },
	},
} :: { Explosion }

local flyersById: { [string]: Flyer } = {}
for _, flyer in Cosmetics.flyers do
	flyersById[flyer.id] = flyer
end
local explosionsById: { [string]: Explosion } = {}
for _, explosion in Cosmetics.explosions do
	explosionsById[explosion.id] = explosion
end

-- The flyer with this id, or nil.
function Cosmetics.flyer(id: unknown): Flyer?
	return if typeof(id) == "string" then flyersById[id] else nil
end

-- The explosion with this id, or the default one.
function Cosmetics.explosion(id: unknown): Explosion
	return (if typeof(id) == "string" then explosionsById[id] else nil) or Cosmetics.explosions[1]
end

function Cosmetics.explosionExists(id: unknown): boolean
	return typeof(id) == "string" and explosionsById[id] ~= nil
end

return Cosmetics
