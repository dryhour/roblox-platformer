local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)

-- Handing things out: rewards, XP and level-ups, daily quests, playtime gifts, and the reward
-- roll after each match. Clients hear about rewards through the Notify remote:
--   "Roll"     { strip = { Reward }, index = number, reward = Reward }   spin, then show it
--   "Receive"  { title = string?, reward = Reward }                       just show it
local Rewards = {}

type Reward = Economy.Reward
type Profile = Data.Profile

local STRIP_LENGTH = 36
local STRIP_WINNER = 30 -- where the real reward sits in the strip the client spins

local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A random cosmetic of `kind` ("flyer" or "explosion"), rarer ones less likely. `owned` leaves
-- out ones already owned; nil if there are none left.
local function randomCosmetic(kind: string, owned: { [string]: boolean }?): string?
	local list = if kind == "flyer" then Cosmetics.flyers else Cosmetics.explosions
	local entries = {}
	for _, item in list :: { any } do
		if not owned or not owned[item.id] then
			table.insert(entries, { weight = Config.RARITIES[item.rarity].weight, reward = { kind = kind, id = item.id } })
		end
	end
	if #entries == 0 then
		return nil
	end
	return Economy.pick(entries, rng).reward.id
end

-- Fills in a reward's random parts, like which ball a random ball is. Random cosmetics are ones
-- the player doesn't have yet; if they have them all, they get coins instead.
function Rewards.resolve(profile: Profile?, reward: Reward): Reward
	if reward.id or (reward.kind ~= "ball" and reward.kind ~= "flyer" and reward.kind ~= "explosion") then
		return reward
	end
	if reward.kind == "ball" then
		local weights = if reward.rarity then { [reward.rarity] = 1 } else nil
		return { kind = "ball", id = Brainrots.roll(1, rng, nil, weights)[1] }
	end
	local owned = if profile then (if reward.kind == "flyer" then profile.flyers else profile.explosions) else nil
	local id = randomCosmetic(reward.kind, owned)
	return if id then { kind = reward.kind, id = id } else { kind = "coins", amount = 200 }
end

-- Adds a resolved reward to a profile. Call it inside Data.update.
function Rewards.apply(profile: Profile, reward: Reward)
	local amount = reward.amount or 0
	if reward.kind == "coins" then
		profile.coins += amount
	elseif reward.kind == "gems" then
		profile.gems += amount
	elseif reward.kind == "boost" then
		profile.boostUntil = math.max(profile.boostUntil, now()) + amount
	elseif reward.kind == "voucher" then
		profile.vouchers += amount
	elseif reward.kind == "ball" and reward.id then
		profile.balls[reward.id] = (profile.balls[reward.id] or 0) + 1
	elseif reward.kind == "flyer" and reward.id then
		profile.flyers[reward.id] = true
	elseif reward.kind == "explosion" and reward.id then
		profile.explosions[reward.id] = true
	end
end

function Rewards.notify(player: Player, kind: string, data: any)
	Remotes.Notify:FireClient(player, kind, data)
end

-- Gives a reward and returns what it turned out to be, or nil if the profile isn't loaded.
function Rewards.give(player: Player, reward: Reward): Reward?
	local given = nil
	Data.update(player, function(profile)
		given = Rewards.resolve(profile, reward)
		Rewards.apply(profile, given :: Reward)
	end)
	return given
end

-- A strip of rewards for the client to spin past, with `winner` at STRIP_WINNER. `filler`
-- makes the rest.
local function strip(winner: Reward, filler: () -> Reward): { strip: { Reward }, index: number, reward: Reward }
	local rewards = {}
	for index = 1, STRIP_LENGTH do
		table.insert(rewards, if index == STRIP_WINNER then winner else filler())
	end
	return { strip = rewards, index = STRIP_WINNER, reward = winner }
end

-- Shows the reward spinning in. `filler` picks the other things in the strip.
function Rewards.spin(player: Player, reward: Reward, filler: () -> Reward)
	Rewards.notify(player, "Roll", strip(reward, filler))
end

-- How rare a reward is, for picking the best of several (0 for coins and such).
local function rank(reward: Reward): number
	local rarity = nil
	if reward.kind == "ball" and reward.id then
		rarity = Brainrots.get(reward.id).rarity
	elseif reward.kind == "flyer" and reward.id then
		local flyer = Cosmetics.flyer(reward.id)
		rarity = flyer and flyer.rarity
	elseif reward.kind == "explosion" and reward.id then
		rarity = Cosmetics.explosion(reward.id).rarity
	end
	return if rarity then table.find(Economy.RARITY_ORDER, rarity) or 0 else 0
end

-- Shows several rewards at once: the strip stops on the best, then they all show together.
function Rewards.spinMany(player: Player, rewards: { Reward }, filler: () -> Reward)
	local best = rewards[1]
	for _, reward in rewards do
		if rank(reward) > rank(best) then
			best = reward
		end
	end
	local data: any = strip(best, filler)
	data.rewards = rewards
	Rewards.notify(player, "Roll", data)
end

-- Fillers for spins of each kind.
function Rewards.filler(kind: string): () -> Reward
	if kind == "ball" then
		return function()
			return { kind = "ball", id = Brainrots.roll(1, rng)[1] }
		end
	elseif kind == "flyer" or kind == "explosion" then
		return function()
			return { kind = kind, id = randomCosmetic(kind, nil) }
		end
	end
	return function()
		return Rewards.resolve(nil, Economy.pick(Economy.ROLL, rng).reward)
	end
end

-- Levels

function Rewards.addXp(player: Player, amount: number)
	local levelUps: { { level: number, reward: Reward } } = {}
	Data.update(player, function(profile)
		if profile.boostUntil > now() then
			amount *= 2
		end
		profile.xp += amount
		while profile.xp >= Economy.xpToNext(profile.level) do
			profile.xp -= Economy.xpToNext(profile.level)
			profile.level += 1
			local reward = Rewards.resolve(profile, Economy.levelReward(profile.level))
			Rewards.apply(profile, reward)
			table.insert(levelUps, { level = profile.level, reward = reward })
		end
	end)
	for _, levelUp in levelUps do
		Rewards.notify(player, "Receive", { title = `Level {levelUp.level}!`, reward = levelUp.reward })
	end
end

-- Quests

-- Starts a new day's quests if the day has changed. Call it inside Data.update.
local function freshQuests(profile: Profile)
	local today = Economy.day(now())
	if profile.questDay ~= today then
		profile.questDay = today
		profile.quests = {}
		profile.questsClaimed = {}
	end
end

local function questDef(id: unknown)
	for _, quest in Economy.QUESTS do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

local function addProgress(profile: Profile, id: string, amount: number)
	local quest = questDef(id)
	if quest then
		profile.quests[id] = math.min(quest.goal, (profile.quests[id] or 0) + amount)
	end
end

function Rewards.claimQuest(player: Player, id: unknown): boolean
	local quest = questDef(id)
	if not quest then
		return false
	end
	local claimed = false
	Data.update(player, function(profile)
		freshQuests(profile)
		if (profile.quests[quest.id] or 0) >= quest.goal and not profile.questsClaimed[quest.id] then
			profile.questsClaimed[quest.id] = true
			Rewards.apply(profile, quest.reward)
			claimed = true
		end
	end)
	return claimed
end

-- Gifts

function Rewards.claimGift(player: Player, index: unknown): boolean
	local session = Data.session(player)
	local gift = if typeof(index) == "number" then Economy.GIFTS[index] else nil
	if not session or not gift then
		return false
	end
	local key = tostring(index)
	if session.gifts[key] or now() - session.joinedAt < gift.minutes * 60 then
		return false
	end
	session.gifts[key] = true
	local reward = Rewards.give(player, gift.reward)
	if reward then
		Rewards.notify(player, "Receive", { reward = reward })
	end
	return reward ~= nil
end

-- Daily rewards

function Rewards.claimLogin(player: Player): boolean
	local claimed: Reward? = nil
	Data.update(player, function(profile)
		local today = Economy.day(now())
		local nextDay, claimable = Economy.loginState(profile.loginDay, profile.loginStreak, today)
		if claimable then
			profile.loginDay = today
			profile.loginStreak = nextDay
			claimed = Rewards.resolve(profile, Economy.LOGIN_REWARDS[nextDay])
			Rewards.apply(profile, claimed :: Reward)
		end
	end)
	if claimed then
		Rewards.notify(player, "Receive", { reward = claimed })
	end
	return claimed ~= nil
end

-- Mail

function Rewards.claimMail(player: Player, id: unknown): boolean
	local mail = nil
	for _, entry in Economy.MAIL do
		if entry.id == id then
			mail = entry
		end
	end
	if not mail then
		return false
	end
	local claimed: Reward? = nil
	Data.update(player, function(profile)
		if not profile.mailClaimed[mail.id] then
			profile.mailClaimed[mail.id] = true
			if mail.reward then
				claimed = Rewards.resolve(profile, mail.reward)
				Rewards.apply(profile, claimed :: Reward)
			end
		end
	end)
	if claimed then
		Rewards.notify(player, "Receive", { reward = claimed })
	end
	return true
end

-- Matches

-- Pays out a finished match: coins for a win, XP, stats and quest progress. `friendly` is true if
-- the opponent was a Roblox friend.
function Rewards.matchFinished(player: Player, won: boolean, friendly: boolean)
	Data.update(player, function(profile)
		freshQuests(profile)
		profile.tutorialDone = true
		profile.matches += 1
		addProgress(profile, "Play", 1)
		if won then
			profile.wins += 1
			profile.coins += Economy.WIN_COINS
			addProgress(profile, "Win", 1)
		end
		if friendly then
			addProgress(profile, "Friend", 1)
		end
	end)
	Rewards.addXp(player, if won then Economy.WIN_XP else Economy.LOSS_XP)
end

-- The reward roll everyone gets after a match.
function Rewards.rollAfterMatch(player: Player)
	local reward = Rewards.give(player, Economy.pick(Economy.ROLL, rng).reward)
	if reward then
		Rewards.spin(player, reward, Rewards.filler("roll"))
	end
end

return Rewards
