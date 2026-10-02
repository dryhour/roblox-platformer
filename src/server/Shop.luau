local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Data = require(script.Parent.Data)
local Rewards = require(script.Parent.Rewards)

-- Spending: the Store's machines, fusing balls, and Robux (gem packs and the All Balls pass).
local Shop = {}

local passOwners: { [Player]: boolean } = {}

-- Rolls a Store machine. Returns false and a short reason if it can't.
function Shop.roll(player: Player, machineId: unknown): (boolean, string?)
	local machine = Economy.machine(machineId)
	local profile = Data.get(player)
	if not machine or not profile then
		return false, nil
	end
	local cost = machine.cost
	if (profile :: any)[cost.currency] < cost.amount then
		return false, if cost.currency == "coins" then "Not enough coins" else "Not enough gems"
	end
	local reward = Rewards.resolve(profile, { kind = machine.kind })
	if reward.kind ~= machine.kind then
		return false, "You have them all!"
	end
	Data.update(player, function(fresh)
		(fresh :: any)[cost.currency] -= cost.amount
		Rewards.apply(fresh, reward)
	end)
	Rewards.spin(player, reward, Rewards.filler(machine.kind))
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
	local reward = { kind = "ball", id = choices[math.random(1, #choices)] }
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
