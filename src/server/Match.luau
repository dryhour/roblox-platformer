local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ModeInfo = require(ReplicatedStorage.Shared.ModeInfo)
local Characters = require(script.Parent.Characters)
local Maps = require(script.Parent.Maps)
local Types = require(script.Parent.Types)

local modes: { [string]: Types.Mode } = {
	BeamAttack = require(script.Parent.Modes.BeamAttack),
	PlatformRush = require(script.Parent.Modes.PlatformRush),
	CoinRush = require(script.Parent.Modes.CoinRush),
}

-- Runs the lobby and matches: host settings, ready-up, picking each game, timing it and
-- keeping score. Clients follow along through attributes on ReplicatedStorage.MatchState and
-- on each Player (listed in the README).
local Match = {}

local state = ReplicatedStorage.MatchState
local remotes = ReplicatedStorage.Remotes
local rng = Random.new()

local joinOrder: { Player } = {}
local currentMap: Model? = nil
local mapToken = 0 -- changes with every map load, so stale respawns can tell
local activeMode: Types.Mode? = nil
local activeContext: Types.Context? = nil

state:SetAttribute("Phase", "Lobby")
state:SetAttribute("EndsAt", 0)
state:SetAttribute("MinPlayers", Config.MIN_PLAYERS)
for name, setting in Config.Settings do
	state:SetAttribute(name, setting.default)
end
state:SetAttribute("Randomization", Config.RANDOMIZATION_OPTIONS[1])
for _, info in ModeInfo.list do
	state:SetAttribute("Mode_" .. info.id, true)
end

-- Phases: Lobby, Intro (rules card), Playing, Scoreboard, Final. EndsAt is the server time
-- the phase ends, or 0 if it has no timer.
local function setPhase(phase: string, seconds: number?)
	state:SetAttribute("Phase", phase)
	state:SetAttribute("EndsAt", if seconds then workspace:GetServerTimeNow() + seconds else 0)
end

local function announce(message: string)
	remotes.Announce:FireAllClients(message)
end

local function loadMap(name: string): Model
	mapToken += 1
	local map = Maps.load(name)
	currentMap = map
	return map
end

local function randomSpawn(): CFrame
	return Maps.spawnPoints(assert(currentMap), "Spawn")[1]
end

local function respawnLater(player: Player, respawn: () -> ())
	local token = mapToken
	local dead = player.Character
	task.delay(Config.RESPAWN_DELAY, function()
		local current = player.Character
		if token == mapToken and player.Parent == Players and (current == nil or current == dead) then
			respawn()
		end
	end)
end

local function onDied(player: Player)
	local mode, ctx = activeMode, activeContext
	if mode and ctx and table.find(ctx.players, player) then
		mode.onDied(ctx, player)
	else
		respawnLater(player, function()
			Characters.spawn(player, randomSpawn())
		end)
	end
end

-- Lobby

local function updateHost()
	local host = joinOrder[1]
	state:SetAttribute("HostUserId", if host then host.UserId else 0)
end

local function freeColor(): number
	for index in Config.PLAYER_COLORS do
		local taken = false
		for _, other in Players:GetPlayers() do
			if other:GetAttribute("ColorIndex") == index then
				taken = true
				break
			end
		end
		if not taken then
			return index
		end
	end
	return rng:NextInteger(1, #Config.PLAYER_COLORS)
end

local function onPlayerAdded(player: Player)
	table.insert(joinOrder, player)
	updateHost()
	player:SetAttribute("ColorIndex", freeColor())
	player:SetAttribute("Ready", false)
	player:SetAttribute("Score", 0)
	player:SetAttribute("LastPoints", 0)
	player:SetAttribute("LastDetail", "")
	player:SetAttribute("Role", "")
	player:SetAttribute("Status", "")
	-- Players who join mid-match wait (watching) until the next game starts.
	if state:GetAttribute("Phase") == "Lobby" and currentMap then
		Characters.spawn(player, randomSpawn())
	end
end

local function onPlayerRemoving(player: Player)
	local index = table.find(joinOrder, player)
	if index then
		table.remove(joinOrder, index)
	end
	updateHost()
end

local function everyoneReady(): boolean
	local players = Players:GetPlayers()
	if #players < Config.MIN_PLAYERS then
		return false
	end
	for _, player in players do
		if not player:GetAttribute("Ready") then
			return false
		end
	end
	return true
end

remotes.SetReady.OnServerEvent:Connect(function(player: Player, ready: unknown)
	if state:GetAttribute("Phase") == "Lobby" and typeof(ready) == "boolean" then
		player:SetAttribute("Ready", ready)
	end
end)

remotes.ChooseColor.OnServerEvent:Connect(function(player: Player, index: unknown)
	if state:GetAttribute("Phase") ~= "Lobby" or typeof(index) ~= "number" or not Config.PLAYER_COLORS[index] then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("ColorIndex") == index then
			return
		end
	end
	player:SetAttribute("ColorIndex", index)
end)

remotes.ChangeSetting.OnServerEvent:Connect(function(player: Player, name: unknown, value: unknown)
	if
		player.UserId ~= state:GetAttribute("HostUserId")
		or state:GetAttribute("Phase") ~= "Lobby"
		or typeof(name) ~= "string"
	then
		return
	end

	local setting = Config.Settings[name]
	if setting then
		if typeof(value) == "number" and value == value then
			local stepped = math.round(value / setting.step) * setting.step
			state:SetAttribute(name, math.clamp(stepped, setting.min, setting.max))
		end
	elseif name == "Randomization" then
		if table.find(Config.RANDOMIZATION_OPTIONS, value) then
			state:SetAttribute(name, value)
		end
	elseif string.sub(name, 1, 5) == "Mode_" and ModeInfo.byId[string.sub(name, 6)] and typeof(value) == "boolean" then
		-- Keep at least one mode switched on.
		if not value then
			local othersOn = 0
			for _, info in ModeInfo.list do
				if "Mode_" .. info.id ~= name and state:GetAttribute("Mode_" .. info.id) then
					othersOn += 1
				end
			end
			if othersOn == 0 then
				return
			end
		end
		state:SetAttribute(name, value)
	end
end)

local function runLobby()
	activeMode, activeContext = nil, nil
	setPhase("Lobby")
	loadMap("Lobby")
	for _, player in Players:GetPlayers() do
		task.spawn(Characters.spawn, player, randomSpawn())
	end

	-- Count down once everyone is ready; start over if anyone un-readies or leaves.
	while true do
		while not everyoneReady() do
			task.wait(0.25)
		end
		setPhase("Lobby", Config.LOBBY_COUNTDOWN)
		local startAt = os.clock() + Config.LOBBY_COUNTDOWN
		local stillReady = true
		while stillReady and os.clock() < startAt do
			task.wait(0.1)
			stillReady = everyoneReady()
		end
		if stillReady then
			return
		end
		setPhase("Lobby")
	end
end

-- Games

local function pickMode(playerCount: number, history: { string }): string?
	local fits, enabled = {}, {}
	for _, info in ModeInfo.list do
		local minPlayers = if Config.TESTING then 1 else info.minPlayers
		if playerCount >= minPlayers and playerCount <= info.maxPlayers then
			table.insert(fits, info.id)
			if state:GetAttribute("Mode_" .. info.id) then
				table.insert(enabled, info.id)
			end
		end
	end
	-- If every enabled mode needs more (or fewer) players, play any mode that fits.
	local pool = if #enabled > 0 then enabled else fits
	if #pool == 0 then
		return nil
	end

	local method = state:GetAttribute("Randomization")
	local last = history[#history]
	if method == "NoRepeat" and last and #pool > 1 then
		local index = table.find(pool, last)
		if index then
			table.remove(pool, index)
		end
	elseif method == "Weighted" then
		local weights, total = {}, 0
		for i, id in pool do
			local plays = 0
			for _, played in history do
				if played == id then
					plays += 1
				end
			end
			weights[i] = 0.5 ^ plays
			total += weights[i]
		end
		local roll = rng:NextNumber() * total
		for i, id in pool do
			roll -= weights[i]
			if roll <= 0 then
				return id
			end
		end
		return pool[#pool]
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function anyoneLeft(players: { Player }): boolean
	for _, player in players do
		if player.Parent == Players then
			return true
		end
	end
	return false
end

local function newContext(participants: { Player }, map: Model, matchData: Types.MatchData): Types.Context
	local ctx: Types.Context
	ctx = {
		players = participants,
		map = map,
		duration = state:GetAttribute("GameTime"),
		match = matchData,
		live = false,
		isIn = function(player)
			return player.Parent == Players and table.find(participants, player) ~= nil
		end,
		timeLeft = function()
			return state:GetAttribute("EndsAt") - workspace:GetServerTimeNow()
		end,
		setTimeLeft = function(seconds)
			state:SetAttribute("EndsAt", workspace:GetServerTimeNow() + seconds)
		end,
		waitUntilOver = function(isDone)
			while ctx.timeLeft() > 0 and not isDone() and anyoneLeft(participants) do
				task.wait(0.1)
			end
		end,
		spawn = function(player, at)
			Characters.spawn(player, at)
			Characters.setFrozen(player, not ctx.live)
		end,
		respawnLater = respawnLater,
		announce = announce,
	}
	return ctx
end

-- Plays one game. Returns false if no mode fits the players left.
local function runGame(number: number, matchData: Types.MatchData): boolean
	local participants = Players:GetPlayers()
	local modeId = pickMode(#participants, matchData.history)
	if not modeId then
		return false
	end
	table.insert(matchData.history, modeId)
	local mode = modes[modeId]

	for _, player in Players:GetPlayers() do
		player:SetAttribute("Role", "")
		player:SetAttribute("Status", "")
	end

	-- The previous scoreboard stays up while the map loads and players spawn in.
	local ctx = newContext(participants, loadMap(mode.map), matchData)
	activeMode, activeContext = mode, ctx
	mode.setup(ctx)
	state:SetAttribute("GameNumber", number)
	state:SetAttribute("ModeId", modeId)
	setPhase("Intro", Config.INTRO_TIME)
	task.wait(Config.INTRO_TIME)

	ctx.live = true
	for _, player in participants do
		Characters.setFrozen(player, false)
	end
	setPhase("Playing", ctx.duration)
	local results = mode.run(ctx)
	activeMode, activeContext = nil, nil

	local multiplier = state:GetAttribute("Multiplier")
	for _, player in Players:GetPlayers() do
		local result = results[player]
		local points = if result then result.points * multiplier else 0
		player:SetAttribute("LastPoints", points)
		player:SetAttribute("LastDetail", if result then result.detail else "Joined mid-game")
		player:SetAttribute("Score", player:GetAttribute("Score") + points)
	end
	setPhase("Scoreboard", Config.SCOREBOARD_TIME)
	task.wait(Config.SCOREBOARD_TIME)
	return true
end

local function runMatch()
	local gameCount = state:GetAttribute("Games")
	state:SetAttribute("GameCount", gameCount)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Ready", false)
		player:SetAttribute("Score", 0)
		player:SetAttribute("LastPoints", 0)
		player:SetAttribute("LastDetail", "")
	end

	local matchData: Types.MatchData = { history = {}, attackerCounts = {} }
	for number = 1, gameCount do
		if #Players:GetPlayers() == 0 or not runGame(number, matchData) then
			break
		end
	end

	if #Players:GetPlayers() > 0 then
		setPhase("Final", Config.FINAL_TIME)
		task.wait(Config.FINAL_TIME)
	end
end

function Match.start()
	Characters.onDied(onDied)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			-- If something breaks mid-match, log it and go back to the lobby instead of stopping.
			local ok, err = xpcall(function()
				runLobby()
				runMatch()
			end, debug.traceback)
			if not ok then
				warn(`Match error, returning to the lobby: {err}`)
				task.wait(1)
			end
		end
	end)
end

return Match
