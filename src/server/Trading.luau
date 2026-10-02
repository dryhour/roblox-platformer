local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)

-- Trading balls between two players. One sends a request; if the other accepts, both get a
-- trade window. Each adds balls from their own unlocked collection; when both press Ready, a
-- short countdown starts, and any change cancels it. Then the server checks both sides still own
-- everything and swaps.
--
-- Clients hear about it through the Trade remote:
--   "Request"  (fromPlayer)        someone wants to trade with you
--   "Update"   (view)              the open trade changed; see `viewFor`
--   "Closed"   (reason)            the trade ended: "Done", "Cancelled" or a problem
local Trading = {}

local REQUEST_TIMEOUT = 30
local CONFIRM_TIME = 3

type Offer = { [string]: number } -- ball id -> how many

type Trade = {
	players: { Player },
	offers: { [Player]: Offer },
	ready: { [Player]: boolean },
	confirmAt: number?, -- server time the swap happens, once both are ready
}

local requests: { [Player]: { [Player]: number } } = {} -- target -> sender -> when
local tradeOf: { [Player]: Trade } = {}
local isBusy: (Player) -> boolean = function()
	return false
end

local function partnerOf(trade: Trade, player: Player): Player
	return if trade.players[1] == player then trade.players[2] else trade.players[1]
end

local function count(offer: Offer): number
	local total = 0
	for _, amount in offer do
		total += amount
	end
	return total
end

local function viewFor(trade: Trade, player: Player)
	local partner = partnerOf(trade, player)
	return {
		partner = partner,
		mine = trade.offers[player],
		theirs = trade.offers[partner],
		myReady = trade.ready[player] == true,
		theirReady = trade.ready[partner] == true,
		confirmAt = trade.confirmAt or 0,
	}
end

local function push(trade: Trade)
	for _, player in trade.players do
		Remotes.Trade:FireClient(player, "Update", viewFor(trade, player))
	end
end

local function close(trade: Trade, reason: string)
	for _, player in trade.players do
		if tradeOf[player] == trade then
			tradeOf[player] = nil
		end
		if player.Parent == Players then
			Remotes.Trade:FireClient(player, "Closed", reason)
		end
	end
end

-- Whether `player` can give everything in `offer` and still keep enough balls to draft.
local function canGive(player: Player, offer: Offer, receiving: Offer): boolean
	local profile = Data.get(player)
	if not profile then
		return false
	end
	for id, amount in offer do
		if profile.locked[id] or (profile.balls[id] or 0) < amount then
			return false
		end
	end
	local total = 0
	for _, amount in profile.balls do
		total += amount
	end
	return total - count(offer) + count(receiving) >= Economy.MIN_BALLS
end

local function swap(trade: Trade)
	local a, b = trade.players[1], trade.players[2]
	local offerA, offerB = trade.offers[a], trade.offers[b]
	if not canGive(a, offerA, offerB) or not canGive(b, offerB, offerA) then
		close(trade, "Someone doesn't have those balls anymore")
		return
	end
	local function move(from: Player, to: Player, offer: Offer)
		Data.update(from, function(profile)
			for id, amount in offer do
				profile.balls[id] -= amount
				if profile.balls[id] <= 0 then
					profile.balls[id] = nil
				end
			end
		end)
		Data.update(to, function(profile)
			for id, amount in offer do
				profile.balls[id] = (profile.balls[id] or 0) + amount
			end
		end)
	end
	move(a, b, offerA)
	move(b, a, offerB)
	close(trade, "Done")
	task.spawn(Data.save, a)
	task.spawn(Data.save, b)
end

local function free(player: Player): boolean
	return player.Parent == Players and not tradeOf[player] and not isBusy(player) and Data.get(player) ~= nil
end

function Trading.request(from: Player, to: unknown): boolean
	if typeof(to) ~= "Instance" or not to:IsA("Player") or to == from or not free(from) or not free(to) then
		return false
	end
	requests[to] = requests[to] or {}
	requests[to][from] = os.clock()
	Remotes.Trade:FireClient(to, "Request", from)
	return true
end

function Trading.respond(player: Player, from: unknown, accept: unknown): boolean
	if typeof(from) ~= "Instance" or not from:IsA("Player") then
		return false
	end
	local sentAt = requests[player] and requests[player][from]
	if requests[player] then
		requests[player][from] = nil
	end
	if not sentAt or os.clock() - sentAt > REQUEST_TIMEOUT or accept ~= true or not free(player) or not free(from) then
		return false
	end
	local trade: Trade = {
		players = { from, player },
		offers = { [from] = {}, [player] = {} },
		ready = {},
		confirmAt = nil,
	}
	tradeOf[from] = trade
	tradeOf[player] = trade
	push(trade)
	return true
end

-- Adds (`change` = 1) or takes back (-1) one of a ball in your offer.
function Trading.offer(player: Player, id: unknown, change: unknown): boolean
	local trade = tradeOf[player]
	local profile = Data.get(player)
	if not trade or not profile or not Brainrots.exists(id) or (change ~= 1 and change ~= -1) then
		return false
	end
	local ballId = id :: string
	local offer = trade.offers[player]
	local amount = (offer[ballId] or 0) + (change :: number)
	if amount < 0 or amount > (profile.balls[ballId] or 0) or profile.locked[ballId] then
		return false
	end
	if amount > 0 and not offer[ballId] then
		local stacks = 0
		for _ in offer do
			stacks += 1
		end
		if stacks >= Economy.MAX_TRADE_STACKS then
			return false
		end
	end
	offer[ballId] = if amount > 0 then amount else nil
	-- Any change means both have to look again.
	table.clear(trade.ready)
	trade.confirmAt = nil
	push(trade)
	return true
end

function Trading.setReady(player: Player, ready: unknown): boolean
	local trade = tradeOf[player]
	if not trade then
		return false
	end
	trade.ready[player] = ready == true
	trade.confirmAt = nil
	local a, b = trade.players[1], trade.players[2]
	if trade.ready[a] and trade.ready[b] then
		local confirmAt = workspace:GetServerTimeNow() + CONFIRM_TIME
		trade.confirmAt = confirmAt
		task.delay(CONFIRM_TIME, function()
			if tradeOf[a] == trade and trade.confirmAt == confirmAt then
				swap(trade)
			end
		end)
	end
	push(trade)
	return true
end

function Trading.cancel(player: Player)
	local trade = tradeOf[player]
	if trade then
		close(trade, "Cancelled")
	end
end

-- `busy` says whether a player can't trade right now, e.g. because they're in a match.
function Trading.start(busy: (Player) -> boolean)
	isBusy = busy
	Players.PlayerRemoving:Connect(function(player)
		Trading.cancel(player)
		requests[player] = nil
		for _, fromList in requests do
			fromList[player] = nil
		end
	end)
end

return Trading
