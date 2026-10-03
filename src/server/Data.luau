local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Saved player data. A player's profile loads when they join, saves every couple of minutes and
-- when they leave (or the server shuts down), and is sent to their client whenever it changes.
--
-- If loading fails, the player gets a fresh profile that is never saved, so a hiccup can't
-- overwrite real progress. Studio can't reach DataStores unless you turn on Game Settings →
-- Security → Enable Studio Access to API Services; until then nothing saves between tests.
local Data = {}

export type Profile = {
	coins: number,
	gems: number,
	xp: number, -- toward the next level
	level: number,
	balls: { [string]: number }, -- brainrot id -> how many
	locked: { [string]: boolean }, -- locked balls can't be traded or fused
	flyers: { [string]: boolean },
	explosions: { [string]: boolean },
	flyer: string, -- equipped; "" for none
	explosion: string, -- equipped
	questDay: number, -- the day (see Economy.day) the quests below are for
	quests: { [string]: number }, -- quest id -> progress
	questsClaimed: { [string]: boolean },
	boostUntil: number, -- x2 EXP until this server time
	freeAllBallsDay: number, -- the day the free All Balls was last used
	wins: number,
	matches: number,
	settings: { [string]: boolean },
	purchases: { string }, -- recent Robux purchase ids, so none is granted twice
	offerEndsAt: number, -- when the limited gem pack stops showing
	tutorialDone: boolean, -- finished a first match, so the tutorial pointers stop
	loginDay: number, -- the day the last daily reward was claimed
	loginStreak: number, -- how many daily rewards in a row (1-7) as of loginDay
	vouchers: number, -- free "Pick Any Card" uses of the draft's All Balls button
	redeemedCodes: { [string]: boolean },
	mailClaimed: { [string]: boolean },
	dealsDay: number, -- the day dealsBought is for
	dealsBought: { [string]: boolean },
}

-- Things that last only for this visit.
export type Session = {
	joinedAt: number, -- server time
	gifts: { [string]: boolean }, -- playtime gifts claimed, by index
}

local STORE_NAME = "Profiles_v1"
local AUTOSAVE_EVERY = 120
local RETRIES = 3
local MAX_PURCHASES_KEPT = 50

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local profiles: { [Player]: Profile } = {}
local sessions: { [Player]: Session } = {}
local canSave: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")

-- Fires (player, profile) once a player's profile is ready.
Data.loaded = loadedEvent.Event

local function now(): number
	return workspace:GetServerTimeNow()
end

local function defaults(): Profile
	local balls = {}
	for _, id in Brainrots.STARTERS do
		balls[id] = 1
	end
	return {
		coins = 0,
		gems = 0,
		xp = 0,
		level = 1,
		balls = balls,
		locked = {},
		flyers = {},
		explosions = { Default = true },
		flyer = "",
		explosion = "Default",
		questDay = 0,
		quests = {},
		questsClaimed = {},
		boostUntil = 0,
		freeAllBallsDay = 0,
		wins = 0,
		matches = 0,
		settings = { sfx = true, shake = true, numbers = true },
		purchases = {},
		offerEndsAt = 0,
		tutorialDone = false,
		loginDay = 0,
		loginStreak = 0,
		vouchers = 0,
		redeemedCodes = {},
		mailClaimed = {},
		dealsDay = 0,
		dealsBought = {},
	}
end

-- A full profile from saved data, filling in anything an older save is missing.
local function reconcile(saved: unknown): Profile
	local profile = defaults()
	if typeof(saved) ~= "table" then
		return profile
	end
	local fresh = profile :: any
	for key, value in saved :: any do
		if key == "settings" and typeof(value) == "table" then
			for name, setting in value do
				fresh.settings[name] = setting
			end
		elseif fresh[key] ~= nil and typeof(fresh[key]) == typeof(value) then
			fresh[key] = value
		end
	end
	return profile
end

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function load(player: Player): (boolean, unknown)
	if not store then
		return false, nil
	end
	for attempt = 1, RETRIES do
		local ok, result = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			return true, result
		end
		warn(`Couldn't load {player.Name}'s data (try {attempt}): {result}`)
		-- Studio without API access fails the same way every time.
		local message = tostring(result)
		if string.find(message, "403") or string.find(message, "Studio") then
			break
		end
		task.wait(attempt)
	end
	return false, nil
end

-- What the client sees: the profile and this visit's session.
local function view(player: Player)
	return { profile = profiles[player], session = sessions[player] }
end

local function push(player: Player)
	if profiles[player] and player.Parent == Players then
		Remotes.Profile:FireClient(player, view(player))
	end
end

function Data.get(player: Player): Profile?
	return profiles[player]
end

function Data.session(player: Player): Session?
	return sessions[player]
end

-- Changes a player's profile and sends it to their client. Returns false if it isn't loaded.
function Data.update(player: Player, change: (Profile) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	change(profile)
	push(player)
	return true
end

-- Waits for a player's profile to load, for up to 15 seconds.
function Data.waitFor(player: Player): Profile?
	local deadline = os.clock() + 15
	while not profiles[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- What the client asks for when it starts.
function Data.view(player: Player)
	Data.waitFor(player)
	return view(player)
end

-- Whether this player's data will be saved (false after a failed load, or without DataStores).
function Data.savable(player: Player): boolean
	return canSave[player] == true
end

function Data.save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not canSave[player] or not store then
		return false
	end
	while #profile.purchases > MAX_PURCHASES_KEPT do
		table.remove(profile.purchases, 1)
	end
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function()
		return profile
	end)
	if not ok then
		warn(`Couldn't save {player.Name}'s data: {err}`)
	end
	return ok
end

local function onPlayerAdded(player: Player)
	sessions[player] = { joinedAt = now(), gifts = {} }
	local ok, saved = load(player)
	if player.Parent ~= Players then
		return
	end
	local profile = reconcile(saved)
	if profile.offerEndsAt == 0 then
		profile.offerEndsAt = now() + Economy.OFFER.hours * 3600
	end
	profiles[player] = profile
	canSave[player] = ok
	push(player)
	loadedEvent:Fire(player, profile)
end

function Data.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		Data.save(player)
		profiles[player] = nil
		sessions[player] = nil
		canSave[player] = nil
	end)

	game:BindToClose(function()
		local saving = 0
		for player in profiles do
			saving += 1
			task.spawn(function()
				Data.save(player)
				saving -= 1
			end)
		end
		local deadline = os.clock() + 25
		while saving > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_EVERY)
			for player in profiles do
				task.spawn(Data.save, player)
			end
		end
	end)
end

return Data
