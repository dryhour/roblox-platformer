local Brainrots = require(script.Parent.Brainrots)
local Config = require(script.Parent.Config)
local Cosmetics = require(script.Parent.Cosmetics)

-- The economy: what things cost, what you earn, and what's in each machine. Shared, so the UI
-- shows the same prices and rewards the server hands out.
--
-- Coins come from winning, quests, daily and online rewards and reward rolls, and buy Coin Ball
-- Machine rolls. Gems are rarer (levels, daily rewards, rolls, codes, or Robux) and buy the Gem
-- Ball, Flyer and Explosion Machines.
local Economy = {}

export type Reward = {
	kind: string, -- "coins", "gems", "ball", "flyer", "explosion", "boost" or "voucher"
	id: string?, -- which ball, flyer or explosion; a random one if left out
	rarity: string?, -- for a random ball, only this rarity
	amount: number?, -- how many coins, gems or vouchers, or seconds of boost
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

-- Online rewards: for time played this visit. A voucher is a free "Pick Any Card": the draft's
-- All Balls button.
Economy.GIFTS = {
	{ minutes = 10, reward = { kind = "coins", amount = 100 } :: Reward },
	{ minutes = 20, reward = { kind = "boost", amount = 10 * 60 } :: Reward },
	{ minutes = 30, reward = { kind = "voucher", amount = 1 } :: Reward },
	{ minutes = 45, reward = { kind = "coins", amount = 300 } :: Reward },
	{ minutes = 60, reward = { kind = "ball" } :: Reward },
}

-- Daily rewards: claim one a day for a 7-day streak, then it starts over. Missing a day starts
-- it over too.
Economy.LOGIN_REWARDS = {
	{ kind = "coins", amount = 100 } :: Reward,
	{ kind = "ball" } :: Reward,
	{ kind = "coins", amount = 150 } :: Reward,
	{ kind = "gems", amount = 10 } :: Reward,
	{ kind = "coins", amount = 250 } :: Reward,
	{ kind = "gems", amount = 20 } :: Reward,
	{ kind = "ball", rarity = "Legendary" } :: Reward,
}

-- Which daily reward (1-7) is next, and whether it can be claimed today, given when the last one
-- was claimed and how far into the streak that was.
function Economy.loginState(lastDay: number, streak: number, today: number): (number, boolean)
	if lastDay == today then
		return math.max(streak, 1), false
	end
	if lastDay ~= today - 1 or streak >= #Economy.LOGIN_REWARDS then
		return 1, true
	end
	return streak + 1, true
end

-- The Store's machines, by tab. Each roll gives one random thing of its kind; flyer and
-- explosion rolls only give ones you don't have yet. Ball machines have their own odds.
export type Machine = {
	id: string,
	tab: string,
	name: string,
	kind: string,
	emoji: string,
	one: Cost,
	ten: Cost?, -- 10 rolls at once, a little cheaper
	weights: { [string]: number }?, -- rarity -> weight, for ball machines
}

Economy.MACHINES = {
	{
		id = "CoinBalls",
		tab = "Balls",
		name = "Coin Ball Machine",
		kind = "ball",
		emoji = "🎰",
		one = { currency = "coins", amount = 250 },
		ten = { currency = "coins", amount = 2250 },
		weights = { Common = 55, Rare = 30, Epic = 12, Legendary = 2.8, Mythic = 0.2 },
	},
	{
		id = "GemBalls",
		tab = "Balls",
		name = "Gem Ball Machine",
		kind = "ball",
		emoji = "💎",
		one = { currency = "gems", amount = 25 },
		ten = { currency = "gems", amount = 225 },
		weights = { Common = 20, Rare = 40, Epic = 28, Legendary = 10, Mythic = 2 },
	},
	{
		id = "Flyers",
		tab = "Flyers",
		name = "Flyer Machine",
		kind = "flyer",
		emoji = "🛸",
		one = { currency = "gems", amount = 30 },
	},
	{
		id = "Explosions",
		tab = "Explosions",
		name = "Explosion Machine",
		kind = "explosion",
		emoji = "💥",
		one = { currency = "gems", amount = 30 },
	},
} :: { Machine }

function Economy.machine(id: unknown): Machine?
	for _, machine in Economy.MACHINES do
		if machine.id == id then
			return machine
		end
	end
	return nil
end

-- Each rarity's chance from a ball machine, as percents, in rarity order.
function Economy.machineOdds(machine: Machine): { { rarity: string, percent: number } }
	local weights = machine.weights or {}
	local total = 0
	for _, brainrot in Brainrots.list do
		total += weights[brainrot.rarity] or 0
	end
	local odds = {}
	for _, rarity in Economy.RARITY_ORDER do
		local share = 0
		for _, brainrot in Brainrots.list do
			if brainrot.rarity == rarity then
				share += weights[rarity] or 0
			end
		end
		if share > 0 and total > 0 then
			table.insert(odds, { rarity = rarity, percent = share / total * 100 })
		end
	end
	return odds
end

-- The daily shop: 3 deals that change at midnight UTC, the same for everyone. Each can be
-- bought once a day.
export type Deal = { id: string, reward: Reward, cost: Cost }

local DEAL_PRICES = { Common = 150, Rare = 300, Epic = 600, Legendary = 1200, Mythic = 2500 }

function Economy.dailyDeals(day: number): { Deal }
	local rng = Random.new(day * 7919 + 13)
	local deals = {}
	-- A ball for coins.
	local brainrot = Brainrots.list[rng:NextInteger(1, #Brainrots.list)]
	table.insert(deals, {
		id = "Ball",
		reward = { kind = "ball", id = brainrot.id },
		cost = { currency = "coins", amount = DEAL_PRICES[brainrot.rarity] },
	})
	-- A flyer and an explosion for gems.
	local flyer = Cosmetics.flyers[rng:NextInteger(1, #Cosmetics.flyers)]
	table.insert(deals, {
		id = "Flyer",
		reward = { kind = "flyer", id = flyer.id },
		cost = { currency = "gems", amount = math.round(DEAL_PRICES[flyer.rarity] / 20) },
	})
	local explosion = Cosmetics.explosions[rng:NextInteger(2, #Cosmetics.explosions)]
	table.insert(deals, {
		id = "Explosion",
		reward = { kind = "explosion", id = explosion.id },
		cost = { currency = "gems", amount = math.round(DEAL_PRICES[explosion.rarity] / 20) },
	})
	return deals
end

-- Mail: messages everyone gets once, some with a gift. Add new ones at the top with a new id.
Economy.MAIL = {
	{
		id = "welcome",
		title = "Welcome to Brainrot VS Brainrot!",
		body = "Pick a ball, aim it, and watch it fight. Here's something to get you started.",
		reward = { kind = "coins", amount = 300 } :: Reward?,
	},
}

-- Updates: what's new, newest first.
Economy.UPDATES = {
	{ title = "3 New Balls", body = "Backrooms Mold strings hazard tape, Sigma Mewing charges and dashes, and Pure Brainrot Smile rages when it's hurt." },
	{ title = "Daily Rewards & Store", body = "Claim a gift every day for 7 days, roll the new Gem Ball Machine, and check the daily deals." },
	{ title = "Smoother Battles", body = "Balls glide and bounce smoothly, never get stuck bouncing flat, and every ball has 100 health." },
	{ title = "Trading & Fusion", body = "Trade balls with anyone in your server, and fuse 3 of a ball into a rarer one." },
}

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
	elseif reward.kind == "voucher" then
		return "Pick Any Card", "🃏", Color3.fromRGB(190, 140, 255)
	elseif reward.kind == "ball" and reward.rarity then
		return `Random {reward.rarity} Ball`, "🎁", Config.RARITIES[reward.rarity].color
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
