local Brainrots = require(script.Parent.Brainrots)
local Config = require(script.Parent.Config)
local Cosmetics = require(script.Parent.Cosmetics)

-- The economy: what things cost, what you earn, and what's in each machine. Shared, so the UI
-- shows the same prices and rewards the server hands out.
--
-- Coins come from winning, quests, gifts and reward rolls, and buy Ball Machine rolls. Gems are
-- rarer (levels, gifts, rolls, or Robux) and buy Flyer and Explosion Machine rolls.
local Economy = {}

export type Reward = {
	kind: string, -- "coins", "gems", "ball", "flyer", "explosion" or "boost"
	id: string?, -- which ball, flyer or explosion; a random one if left out
	amount: number?, -- how many coins or gems, or seconds of boost
}

export type Cost = { currency: string, amount: number } -- currency is "coins" or "gems"

Economy.WIN_COINS = 100
Economy.WIN_XP = 60
Economy.LOSS_XP = 25
Economy.BOOST_SECONDS = 15 * 60 -- x2 EXP from reward rolls
Economy.FUSE_COUNT = 3 -- this many of one ball fuse into a ball one rarity up
Economy.MIN_BALLS = 3 -- trades can't leave you with fewer balls than this (you draft 3)
Economy.MAX_TRADE_STACKS = 6
Economy.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
Economy.STICKERS = { "😮", "🤔", "😲", "😴", "🤢", "😵" }

-- Robux. Make these on the Creator Dashboard (Monetization) and paste their ids here; anything
-- left at 0 is hidden in game.
Economy.GEM_PRODUCTS = {
	{ id = 0, gems = 100 },
	{ id = 0, gems = 550 },
	{ id = 0, gems = 1200 },
}
Economy.OFFER = { id = 0, gems = 500, hours = 12 } -- a limited pack shown for 12 hours after joining
Economy.ALL_BALLS_PASS = 0 -- game pass: the draft's All Balls button, every round

-- Levels
function Economy.xpToNext(level: number): number
	return 100 + (level - 1) * 50
end

local LEVEL_REWARDS: { [number]: Reward } = {
	[2] = { kind = "coins", amount = 150 },
	[3] = { kind = "ball", id = "TrippiTroppi" },
	[4] = { kind = "gems", amount = 25 },
	[5] = { kind = "flyer", id = "PaperPlane" },
	[6] = { kind = "coins", amount = 300 },
	[7] = { kind = "ball", id = "BonecaAmbalabu" },
	[8] = { kind = "gems", amount = 50 },
	[9] = { kind = "explosion", id = "Confetti" },
	[10] = { kind = "ball", id = "BallerinaCappuccina" },
	[12] = { kind = "flyer", id = "Cloud" },
	[15] = { kind = "gems", amount = 100 },
	[18] = { kind = "explosion", id = "Lightning" },
	[20] = { kind = "ball", id = "LaVacaSaturnoSaturnita" },
	[25] = { kind = "flyer", id = "UFO" },
	[30] = { kind = "ball", id = "CappuccinoAssassino" },
}

-- What you get for reaching `level`.
function Economy.levelReward(level: number): Reward
	return LEVEL_REWARDS[level] or { kind = "coins", amount = 50 * level }
end

-- Daily quests, reset at midnight UTC.
Economy.QUESTS = {
	{ id = "Friend", text = "Duel with a friend", goal = 1, reward = { kind = "coins", amount = 100 } :: Reward },
	{ id = "Win", text = "Win 3 times", goal = 3, reward = { kind = "coins", amount = 100 } :: Reward },
	{ id = "Play", text = "Play 10 times", goal = 10, reward = { kind = "coins", amount = 100 } :: Reward },
}

function Economy.day(now: number): number
	return now // 86400
end

-- Gifts for time played this visit.
Economy.GIFTS = {
	{ minutes = 2, reward = { kind = "coins", amount = 50 } :: Reward },
	{ minutes = 5, reward = { kind = "gems", amount = 5 } :: Reward },
	{ minutes = 10, reward = { kind = "coins", amount = 150 } :: Reward },
	{ minutes = 15, reward = { kind = "ball" } :: Reward },
	{ minutes = 25, reward = { kind = "gems", amount = 15 } :: Reward },
	{ minutes = 40, reward = { kind = "coins", amount = 400 } :: Reward },
}

-- The Store's machines. Each roll gives one random thing of its kind; flyer and explosion rolls
-- only give ones you don't have yet.
Economy.MACHINES = {
	{ id = "Balls", name = "Ball Machine", kind = "ball", emoji = "🎰", cost = { currency = "coins", amount = 250 } :: Cost },
	{ id = "Flyers", name = "Flyer Machine", kind = "flyer", emoji = "🛸", cost = { currency = "gems", amount = 30 } :: Cost },
	{ id = "Explosions", name = "Explosion Machine", kind = "explosion", emoji = "💥", cost = { currency = "gems", amount = 30 } :: Cost },
}

function Economy.machine(id: unknown)
	for _, machine in Economy.MACHINES do
		if machine.id == id then
			return machine
		end
	end
	return nil
end

-- The reward roll after every match.
Economy.ROLL = {
	{ weight = 30, reward = { kind = "coins", amount = 50 } :: Reward },
	{ weight = 18, reward = { kind = "coins", amount = 100 } :: Reward },
	{ weight = 6, reward = { kind = "coins", amount = 250 } :: Reward },
	{ weight = 16, reward = { kind = "boost", amount = Economy.BOOST_SECONDS } :: Reward },
	{ weight = 24, reward = { kind = "ball" } :: Reward },
	{ weight = 6, reward = { kind = "gems", amount = 10 } :: Reward },
}

export type WeightedReward = { weight: number, reward: Reward }

-- One entry from a weighted list, like Economy.ROLL.
function Economy.pick(entries: { WeightedReward }, rng: Random): WeightedReward
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

-- How a reward looks: its name, an emoji, and its rarity color (white for plain rewards).
function Economy.describe(reward: Reward): (string, string, Color3)
	local white = Color3.new(1, 1, 1)
	if reward.kind == "coins" then
		return `{reward.amount} Coins`, "🪙", Color3.fromRGB(255, 200, 60)
	elseif reward.kind == "gems" then
		return `{reward.amount} Gems`, "💎", Color3.fromRGB(90, 200, 255)
	elseif reward.kind == "boost" then
		return `x2 EXP {math.round((reward.amount or 0) / 60)} mins`, "⚡", Color3.fromRGB(130, 255, 120)
	elseif reward.kind == "ball" and reward.id then
		local brainrot = Brainrots.get(reward.id)
		return brainrot.name, brainrot.emoji, Config.RARITIES[brainrot.rarity].color
	elseif reward.kind == "flyer" and reward.id then
		local flyer = Cosmetics.flyer(reward.id)
		if flyer then
			return flyer.name, flyer.emoji, Config.RARITIES[flyer.rarity].color
		end
	elseif reward.kind == "explosion" and reward.id then
		local explosion = Cosmetics.explosion(reward.id)
		return explosion.name, explosion.emoji, Config.RARITIES[explosion.rarity].color
	elseif reward.kind == "ball" then
		return "Random Ball", "🎁", white
	end
	return "Mystery", "🎁", white
end

-- The rarity one step up from `rarity`, or nil for the rarest.
function Economy.nextRarity(rarity: string): string?
	local index = table.find(Economy.RARITY_ORDER, rarity)
	return if index then Economy.RARITY_ORDER[index + 1] else nil
end

return Economy
