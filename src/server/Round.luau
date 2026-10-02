local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Balls = require(script.Parent.Balls)
local Arena = require(script.Parent.World.Arena)
local Lobby = require(script.Parent.World.Lobby)

-- The round loop: lobby, then a round of Last Brainrot Standing, then back to the lobby.
-- Clients follow along through attributes on ReplicatedStorage.MatchState:
--   Phase    Lobby, Countdown (frozen in the arena), Playing or Winner
--   EndsAt   server time the current countdown or round ends, or 0
--   Alive    balls still in the round
--   Winners  the winners' brainrot emoji and names, during Winner
local Round = {}

local LOBBY_CENTER = Vector3.zero
local ARENA_CENTER = Vector3.new(0, 0, 600)
local LOBBY_FALL_Y = -40 -- in case a ball gets over the lobby walls

local state = ReplicatedStorage.MatchState
local remotes = ReplicatedStorage.Remotes
local lobby: Lobby.Lobby

local function setPhase(phase: string, seconds: number?)
	state:SetAttribute("Phase", phase)
	state:SetAttribute("EndsAt", if seconds then workspace:GetServerTimeNow() + seconds else 0)
end

local function effect(kind: string, position: Vector3, ...: any)
	remotes.Effect:FireAllClients(kind, position, ...)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function brainrotOf(player: Player): Brainrots.Brainrot
	local model = Balls.get(player)
	return Brainrots.get(model and model:GetAttribute("Brainrot") or player:GetAttribute("Brainrot"))
end

-- Rolling onto a brainrot's pad turns you into it.
local function checkPads(player: Player, core: BasePart)
	for _, pad in lobby.pads do
		local id = pad:GetAttribute("Brainrot")
		local onPad = flatDistance(core.Position, pad.Position) < pad.Size.Y / 2
			and core.Position.Y < pad.Position.Y + Config.BALL_SIZE
		if onPad and typeof(id) == "string" and brainrotOf(player).id ~= id then
			Balls.setBrainrot(player, id)
			effect("Select", core.Position, id)
		end
	end
end

-- Everyone rolls around; the round starts once they're all in the green circle.
local function runLobby()
	setPhase("Lobby")
	local startAt: number? = nil
	while true do
		local players = Players:GetPlayers()
		local ready = 0
		for _, player in players do
			local core = Balls.core(player)
			if not core or core.Position.Y < LOBBY_FALL_Y then
				Balls.spawn(player, lobby.spawnPoint())
			else
				checkPads(player, core)
				if flatDistance(core.Position, lobby.zoneCenter) < lobby.zoneRadius then
					ready += 1
				end
			end
		end

		-- Leaving the circle (or someone joining) stops the countdown.
		local everyoneIn = #players >= Config.MIN_PLAYERS and ready == #players
		if everyoneIn and not startAt then
			startAt = os.clock() + Config.LOBBY_COUNTDOWN
			setPhase("Lobby", Config.LOBBY_COUNTDOWN)
		elseif not everyoneIn and startAt then
			startAt = nil
			setPhase("Lobby")
		end
		if startAt and os.clock() >= startAt then
			return
		end

		lobby.sign.Text = if startAt
			then tostring(math.ceil(startAt - os.clock()))
			elseif #players < Config.MIN_PLAYERS then `👥 {#players}/{Config.MIN_PLAYERS}`
			else `✅ {ready}/{#players}`
		task.wait(0.1)
	end
end

-- Last Brainrot Standing: knock everyone else off the arena while it crumbles.
local function runRound()
	local arena = Arena.build(ARENA_CENTER)
	local alive = Players:GetPlayers()
	local spawns = arena.spawnPoints(#alive)
	for index, player in alive do
		Balls.spawn(player, spawns[index], true)
	end
	local startCount = #alive
	state:SetAttribute("Alive", #alive)

	setPhase("Countdown", Config.ROUND_COUNTDOWN)
	task.wait(Config.ROUND_COUNTDOWN)
	for _, player in alive do
		Balls.setFrozen(player, false)
	end
	setPhase("Playing", Config.ROUND_TIME)

	local startedAt = os.clock()
	while true do
		local elapsed = os.clock() - startedAt
		arena.update(elapsed)
		for index = #alive, 1, -1 do
			local player = alive[index]
			local core = Balls.core(player)
			if player.Parent ~= Players or not core then
				table.remove(alive, index)
			elseif core.Position.Y < arena.killY then
				table.remove(alive, index)
				-- Show the burst at arena level, where the camera can see it.
				effect("Eliminated", Vector3.new(core.Position.X, ARENA_CENTER.Y, core.Position.Z), brainrotOf(player).id)
				remotes.Announce:FireAllClients(`💥 {player.DisplayName}`)
				Balls.despawn(player)
			end
		end
		state:SetAttribute("Alive", #alive)

		-- Alone (testing in Studio), play until you fall or time runs out.
		local decided = #alive == 0 or (startCount > 1 and #alive <= 1)
		if decided or elapsed >= Config.ROUND_TIME then
			break
		end
		task.wait(0.05)
	end

	local winners = {}
	for _, player in alive do
		local brainrot = brainrotOf(player)
		table.insert(winners, `{brainrot.emoji} {player.DisplayName}`)
		local core = Balls.core(player)
		if core then
			effect("Confetti", core.Position)
		end
	end
	state:SetAttribute("Winners", table.concat(winners, "   "))
	setPhase("Winner", Config.WINNER_TIME)
	task.wait(Config.WINNER_TIME)

	for _, player in Players:GetPlayers() do
		Balls.despawn(player)
	end
	arena.destroy()
	state:SetAttribute("Winners", "")
	state:SetAttribute("Alive", 0)
end

local function onPlayerAdded(player: Player)
	-- Everyone starts as a random brainrot; the lobby pads change it.
	player:SetAttribute("Brainrot", Brainrots.list[math.random(#Brainrots.list)].id)
	player:SetAttribute("AbilityReadyAt", 0)
end

function Round.start()
	setPhase("Lobby")
	state:SetAttribute("Alive", 0)
	state:SetAttribute("Winners", "")
	lobby = Lobby.build(LOBBY_CENTER)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			-- If something breaks mid-round, log it and go back to the lobby instead of stopping.
			local ok, err = xpcall(function()
				runLobby()
				runRound()
			end, debug.traceback)
			if not ok then
				warn(`Round error, returning to the lobby: {err}`)
				for _, player in Players:GetPlayers() do
					Balls.despawn(player)
				end
				for _, child in workspace:GetChildren() do
					if child.Name == "Arena" then
						child:Destroy()
					end
				end
				task.wait(1)
			end
		end
	end)
end

return Round
