-- Match rules and balance shared by the server and clients. Times are in seconds, distances in
-- studs, speeds in studs per second.
local Config = {}

Config.HEARTS = 3 -- lose a round, lose a heart; lose them all, lose the match

-- Lobby
Config.SETTLE_TIME = 1 -- both squares at a station must stay filled this long to start a match

-- Round phases
Config.DRAFT_TIME = 10
Config.AIM_TIME = 6
Config.BATTLE_TIME = 45 -- if both balls survive, the one with more health left wins the round
Config.RESOLVE_TIME = 4
Config.MATCH_OVER_TIME = 6

-- Sudden death: the walls close in and every hit hurts more.
Config.SUDDEN_DEATH_AT = 30 -- seconds into the battle
Config.SHRINK_EVERY = 3
Config.SHRINK_FACTOR = 0.8 -- the arena's width is multiplied by this each time
Config.MIN_ARENA_HALF_WIDTH = 5
Config.SUDDEN_DEATH_DAMAGE = 2.5

-- Arena and balls. The arena is an upright square box, like a screen standing on its edge; balls
-- bounce around inside it with no gravity.
Config.ARENA_SIZE = 24 -- inside width and height
Config.BALL_SIZE = 4
Config.AIM_ARC = math.rad(85) -- how far from straight ahead you can aim, each way

-- Damage when balls collide, for each ball:
--   relative speed * its ImpactPower * (its mass / other mass, kept between 0.5 and 2)
--   * DAMAGE_SCALE + FLAT_DAMAGE
Config.DAMAGE_SCALE = 3.6
Config.FLAT_DAMAGE = 25
Config.MIN_IMPACT_SPEED = 2
Config.WALL_DAMAGE = 10 -- every bounce off a wall chips a little health
Config.LOW_HEALTH = 0.25 -- fraction of health that triggers OnLowHealth abilities

-- Draft odds, and how each rarity looks on the cards.
Config.RARITIES = {
	Common = { weight = 52, color = Color3.fromRGB(180, 180, 190), stars = 1 },
	Rare = { weight = 30, color = Color3.fromRGB(70, 150, 255), stars = 2 },
	Epic = { weight = 13, color = Color3.fromRGB(175, 90, 255), stars = 3 },
	Legendary = { weight = 4.5, color = Color3.fromRGB(255, 190, 40), stars = 4 },
	Mythic = { weight = 0.5, color = Color3.fromRGB(255, 70, 90), stars = 5 },
}

-- Left is pink, right is blue: the station squares, hover pads, HUD cards and health numbers.
Config.SIDE_COLORS = {
	Left = Color3.fromRGB(255, 95, 140),
	Right = Color3.fromRGB(70, 160, 255),
}

-- Built-in Roblox sounds. Swap in sound ids from the Creator Store for better ones.
Config.Sounds = {
	Hit = "rbxasset://sounds/collide.wav",
	Launch = "rbxasset://sounds/swoosh.wav",
	KnockOut = "rbxasset://sounds/action_falling.mp3",
	Beep = "rbxasset://sounds/electronicpingshort.wav",
	Pick = "rbxasset://sounds/electronicpingshort.wav",
	Boom = "rbxasset://sounds/impact_water.mp3",
}

return Config
