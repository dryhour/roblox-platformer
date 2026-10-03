local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Data = require(script.Parent.Data)
local Rewards = require(script.Parent.Rewards)

-- Spending: the Store's machines and daily deals, fusing balls, codes, and Robux (gem packs and
-- the All Balls pass).
local Shop = {}

local passOwners: { [Player]: boolean } = {}

-- Codes players can type in the Codes window, each once. Kept on the server so nobody can read
-- them from the game. Use capitals; what players type is matched ignoring case.
local CODES: { [string]: Economy.Reward } = {
	RELEASE = { kind = "coins", amount = 500 },
	BRAINROT = { kind = "gems", amount = 25 },
	TUNGTUNG = { kind = "ball" },
}

local rng = Random.new()

-- Rolls a Store machine `count` times (1, or 10 if it has a 10-roll price). Returns false and a
-- short reason if it can't.
function Shop.roll(player: Player, machineId: unknown, count: unknown): (boolean, string?)
	local machine = Economy.machine(machineId)
	local profile = Data.get(player)
	if not machine or not profile then
		return false, nil
	end
	local cost = if count == 10 then machine.ten else machine.one
	if not cost then
		return false, nil
	end
	local rolls = if count == 10 then 10 else 1
	if (profile :: any)[cost.currency] < cost.amount then
		return false, if cost.currency == "coins" then "Not enough coins" else "Not enough gems"
	end

	local rewards = {}
	if machine.kind == "ball" then
		for _ = 1, rolls do
			table.insert(rewards, { kind = "ball", id = Brainrots.roll(1, rng, nil, machine.weights)[1] })
		end
	else
		local reward = Rewards.resolve(profile, { kind = machine.kind })
		if reward.kind ~= machine.kind then
			return false, "You have them all!"
		end
		table.insert(rewards, reward)
	end

	Data.update(player, function(fresh)
		(fresh :: any)[cost.currency] -= cost.amount
		for _, reward in rewards do
			Rewards.apply(fresh, reward)
		end
	end)
	if #rewards == 1 then
		Rewards.spin(player, rewards[1], Rewards.filler(machine.kind))
	else
		Rewards.spinMany(player, rewards, Rewards.filler(machine.kind))
	end
	return true, nil
end

-- Buys one of today's deals, once a day each.
function Shop.buyDeal(player: Player, dealId: unknown): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local today = Economy.day(workspace:GetServerTimeNow())
	local deal = nil
	for _, entry in Economy.dailyDeals(today) do
		if entry.id == dealId then
			deal = entry
		end
	end
	if not deal then
		return false, nil
	end
	local bought = profile.dealsDay == today and profile.dealsBought[deal.id]
	local reward = deal.reward
	local owned = (reward.kind == "flyer" and profile.flyers[reward.id :: string])
		or (reward.kind == "explosion" and profile.explosions[reward.id :: string])
	if bought then
		return false, "Already bought today"
	elseif owned then
		return false, "You already have it"
	elseif (profile :: any)[deal.cost.currency] < deal.cost.amount then
		return false, if deal.cost.currency == "coins" then "Not enough coins" else "Not enough gems"
	end
	Data.update(player, function(fresh)
		if fresh.dealsDay ~= today then
			fresh.dealsDay = today
			fresh.dealsBought = {}
		end
		fresh.dealsBought[deal.id] = true
		(fresh :: any)[deal.cost.currency] -= deal.cost.amount
		Rewards.apply(fresh, deal.reward)
	end)
	Rewards.notify(player, "Receive", { reward = deal.reward })
	return true, nil
end

-- Redeems a code. Returns false and a short reason if it doesn't work.
function Shop.redeem(player: Player, text: unknown): (boolean, string?)
	local profile = Data.get(player)
	if not profile or typeof(text) ~= "string" or #text > 40 then
		return false, nil
	end
	local code = string.upper((string.gsub(text, "%s", "")))
	local reward = CODES[code]
	if not reward then
		return false, "That code doesn't work"
	elseif profile.redeemedCodes[code] then
		return false, "Already used"
	end
	local given: Economy.Reward? = nil
	Data.update(player, function(fresh)
		fresh.redeemedCodes[code] = true
		given = Rewards.resolve(fresh, reward)
		Rewards.apply(fresh, given :: Economy.Reward)
	end)
	if given then
		Rewards.notify(player, "Receive", { title = "Code redeemed!", reward = given })
	end
	return true, nil
end

-- Fuses Economy.FUSE_COUNT of one unlocked ball into a random ball one rarity up.
function Shop.fuse(player: Player, id: unknown): (boolean, string?)
	local profile = Data.get(player)
	if not profile or not Brainrots.exists(id) then
		return false, nil
	end
	local ballId = id :: string
	local nextRarity = Economy.nextRarity(Brainrots.get(ballId).rarity)
	if not nextRarity then
		return false, "Already the rarest"
	elseif profile.locked[ballId] then
		return false, "Unlock it first"
	elseif (profile.balls[ballId] or 0) < Economy.FUSE_COUNT then
		return false, `Needs {Economy.FUSE_COUNT}`
	end
	local choices = {}
	for _, brainrot in Brainrots.list do
		if brainrot.rarity == nextRarity then
			table.insert(choices, brainrot.id)
		end
	end
	local reward = { kind = "ball", id = choices[rng:NextInteger(1, #choices)] }
	Data.update(player, function(fresh)
		fresh.balls[ballId] -= Economy.FUSE_COUNT
		if fresh.balls[ballId] <= 0 then
			fresh.balls[ballId] = nil
		end
		Rewards.apply(fresh, reward)
	end)
	Rewards.notify(player, "Receive", { title = "Fusion!", reward = reward })
	return true, nil
end

-- Whether the player owns the All Balls game pass.
function Shop.ownsAllBalls(player: Player): boolean
	if Economy.ALL_BALLS_PASS == 0 then
		return false
	end
	if passOwners[player] == nil then
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Economy.ALL_BALLS_PASS)
		passOwners[player] = ok and owns
	end
	return passOwners[player] == true
end

local function gemsFor(productId: number): number?
	for _, product in Economy.GEM_PRODUCTS do
		if product.id ~= 0 and product.id == productId then
			return product.gems
		end
	end
	if Economy.OFFER.id ~= 0 and Economy.OFFER.id == productId then
		return Economy.OFFER.gems
	end
	return nil
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local gems = gemsFor(receipt.ProductId)
	local profile = player and Data.get(player)
	if not player or not gems or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not table.find(profile.purchases, receipt.PurchaseId) then
		Data.update(player, function(fresh)
			fresh.gems += gems
			table.insert(fresh.purchases, receipt.PurchaseId)
		end)
		Rewards.notify(player, "Receive", { reward = { kind = "gems", amount = gems } })
	end
	-- Only confirm once it's saved (or can't be, like in Studio), so Roblox retries otherwise.
	if Data.savable(player) and not Data.save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Economy.ALL_BALLS_PASS then
			passOwners[player] = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		passOwners[player] = nil
	end)
end

return Shop
