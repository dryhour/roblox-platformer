local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Avatars = require(script.Parent.Avatars)
local Data = require(script.Parent.Data)
local MatchService = require(script.Parent.MatchService)
local Rewards = require(script.Parent.Rewards)
local Shop = require(script.Parent.Shop)
local Trading = require(script.Parent.Trading)

-- Everything the HUD asks the server to do, through the Action remote function:
--   Remotes.Action:InvokeServer(name, ...) -> (ok, message?)
-- Every argument comes from the client, so each handler checks it before doing anything.
local Actions = {}

local MAX_PER_SECOND = 15
local SETTINGS = { sfx = true, shake = true, numbers = true }

local handlers: { [string]: (Player, ...any) -> (boolean, any) } = {}

handlers.GetProfile = function(player)
	return true, Data.view(player)
end

-- Lobby
handlers.Play = function(player)
	return MatchService.play(player)
end
handlers.QuickJoin = function(player, arenaName)
	return MatchService.quickJoin(player, arenaName)
end
handlers.Leave = function(player)
	return MatchService.leave(player)
end
handlers.AllBalls = function(player)
	return MatchService.allBalls(player)
end
handlers.Sticker = function(player, index)
	return Avatars.sticker(player, index)
end

-- Rewards
handlers.ClaimQuest = function(player, id)
	return Rewards.claimQuest(player, id)
end
handlers.ClaimGift = function(player, index)
	return Rewards.claimGift(player, index)
end

-- Store and inventory
handlers.Roll = function(player, machineId)
	return Shop.roll(player, machineId)
end
handlers.Fuse = function(player, id)
	return Shop.fuse(player, id)
end
handlers.Lock = function(player, id)
	if not Brainrots.exists(id) then
		return false
	end
	local ballId = id :: string
	return Data.update(player, function(profile)
		profile.locked[ballId] = if profile.locked[ballId] then nil else true
	end)
end
handlers.Equip = function(player, kind, id)
	local profile = Data.get(player)
	if not profile or typeof(id) ~= "string" then
		return false
	end
	if kind == "flyer" and (id == "" or (Cosmetics.flyer(id) and profile.flyers[id])) then
		Data.update(player, function(fresh)
			fresh.flyer = id
		end)
		Avatars.refreshFlyer(player)
		return true
	elseif kind == "explosion" and Cosmetics.explosionExists(id) and profile.explosions[id] then
		Data.update(player, function(fresh)
			fresh.explosion = id
		end)
		return true
	end
	return false
end
handlers.Setting = function(player, key, value)
	if typeof(key) ~= "string" or not SETTINGS[key] or typeof(value) ~= "boolean" then
		return false
	end
	return Data.update(player, function(profile)
		profile.settings[key] = value
	end)
end

-- Trading
handlers.TradeRequest = function(player, target)
	return Trading.request(player, target)
end
handlers.TradeRespond = function(player, from, accept)
	return Trading.respond(player, from, accept)
end
handlers.TradeOffer = function(player, id, change)
	return Trading.offer(player, id, change)
end
handlers.TradeReady = function(player, ready)
	return Trading.setReady(player, ready)
end
handlers.TradeCancel = function(player)
	Trading.cancel(player)
	return true
end

function Actions.start()
	local recent: { [Player]: { count: number, since: number } } = {}
	Remotes.Action.OnServerInvoke = function(player: Player, name: unknown, ...: any)
		local handler = if typeof(name) == "string" then handlers[name] else nil
		if not handler then
			return false
		end
		local now = os.clock()
		local rate = recent[player]
		if not rate or now - rate.since >= 1 then
			rate = { count = 0, since = now }
			recent[player] = rate
		end
		rate.count += 1
		if rate.count > MAX_PER_SECOND then
			return false
		end
		local ok, result, message = pcall(handler, player, ...)
		if not ok then
			warn(`Action {name} from {player.Name} failed: {result}`)
			return false
		end
		return result, message
	end
	Players.PlayerRemoving:Connect(function(player)
		recent[player] = nil
	end)

	-- Someone who joins from your invite earns you a free ball.
	Data.loaded:Connect(function(player)
		local ok, joinData = pcall(player.GetJoinData, player)
		local referrer = if ok and typeof(joinData) == "table" then joinData.ReferredByPlayerId else nil
		local inviter = if typeof(referrer) == "number" and referrer > 0 then Players:GetPlayerByUserId(referrer) else nil
		if inviter and inviter ~= player then
			local reward = Rewards.give(inviter, { kind = "ball" })
			if reward then
				Rewards.notify(inviter, "Receive", { title = "Thanks for inviting!", reward = reward })
			end
		end
	end)
end

return Actions
