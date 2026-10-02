local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Battle = require(script.Parent.Battle)
local Arena = require(script.Parent.World.Arena)
local Lobby = require(script.Parent.World.Lobby)

-- Matchmaking and the match loop. Players stand on a lobby pad to queue: two on the ⚔️ pad
-- start a 1v1; one on the 🤖 pad starts a match against a bot. Each match gets its own arena
-- and runs rounds until one side runs out of hearts:
--   Draft    each side picks one of 3 random balls
--   Aim      each side aims its launch
--   Battle   the balls fight on their own
--   Resolve  the loser loses a heart
--
-- Clients follow along through attributes. On each player: MatchId, Side ("Left" or "Right"),
-- DraftOptions (comma-separated ids) and DraftPick. On the arena's State: Phase, EndsAt
-- (server time), Round, SuddenDeath, LeftName, RightName, LeftHearts, RightHearts,
-- RoundWinner ("Left", "Right" or "Draw") and MatchWinner (a name).
local MatchService = {}

local MAX_ARENAS = 12
local BOT_PAD_DELAY = 1 -- seconds on the 🤖 pad before the match starts

type Competitor = {
	side: string,
	player: Player?, -- nil for a bot
	name: string,
	hearts: number,
	forward: Vector3,
	options: { string },
	pick: string?,
	aim: Vector3?,
	locked: boolean,
}

type Match = {
	id: string,
	arena: Arena.Arena,
	slot: number,
	competitors: { [string]: Competitor },
	players: { Player },
	phase: string,
	battle: Battle.Battle?,
}

local rng = Random.new()
local lobby: Lobby.Lobby
local matchOf: { [Player]: Match } = {}
local slotsInUse: { [number]: boolean } = {}
local matchCount = 0

local function competitorOf(match: Match, player: Player): Competitor?
	for _, competitor in match.competitors do
		if competitor.player == player then
			return competitor
		end
	end
	return nil
end

local function other(side: string): string
	return if side == "Left" then "Right" else "Left"
end

local function setPhase(match: Match, phase: string, seconds: number?)
	match.phase = phase
	match.arena.state:SetAttribute("Phase", phase)
	match.arena.state:SetAttribute("EndsAt", if seconds then workspace:GetServerTimeNow() + seconds else 0)
end

-- A side whose player has left the game, if any.
local function quitter(match: Match): Competitor?
	for _, competitor in match.competitors do
		if competitor.player and competitor.player.Parent ~= Players then
			return competitor
		end
	end
	return nil
end

-- Waits up to `seconds`, or until isDone() or someone quits.
local function waitFor(match: Match, seconds: number, isDone: () -> boolean)
	local endsAt = os.clock() + seconds
	while os.clock() < endsAt and not isDone() and not quitter(match) do
		task.wait(0.1)
	end
end

local function everyone(match: Match, check: (Competitor) -> boolean): boolean
	for _, competitor in match.competitors do
		if not check(competitor) then
			return false
		end
	end
	return true
end

-- Freezes the player's avatar in the lobby during a match (their camera is in the arena), or
-- sends it back to the lobby spawn afterward.
local function holdAvatar(player: Player, hold: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		root.Anchored = hold
		if not hold then
			character:PivotTo(lobby.spawn)
		end
	end
end

local function draft(match: Match)
	for _, competitor in match.competitors do
		competitor.options = Brainrots.roll(3, rng)
		competitor.pick = nil
		competitor.aim = nil
		competitor.locked = false
		local player = competitor.player
		if player then
			player:SetAttribute("DraftOptions", table.concat(competitor.options, ","))
			player:SetAttribute("DraftPick", "")
		else
			-- The bot thinks for a moment, then picks at random.
			task.delay(rng:NextNumber(1, 3), function()
				competitor.pick = competitor.options[rng:NextInteger(1, #competitor.options)]
			end)
		end
	end
	setPhase(match, "Draft", Config.DRAFT_TIME)
	waitFor(match, Config.DRAFT_TIME, function()
		return everyone(match, function(competitor)
			return competitor.pick ~= nil
		end)
	end)
	-- Anyone who didn't pick gets one of their options.
	for _, competitor in match.competitors do
		competitor.pick = competitor.pick or competitor.options[rng:NextInteger(1, #competitor.options)]
		if competitor.player then
			competitor.player:SetAttribute("DraftPick", competitor.pick)
		end
	end
end

local function aim(match: Match, battle: Battle.Battle)
	for side, competitor in match.competitors do
		if not competitor.player then
			-- The bot aims roughly at the other ball.
			local mine, theirs = battle.balls[side], battle.balls[other(side)]
			local toward = theirs.core.Position - mine.core.Position
			local wobble = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(rng:NextNumber(-35, 35)))
			competitor.aim = Battle.clampAim(wobble:VectorToWorldSpace(toward), competitor.forward)
			competitor.locked = true
		end
	end
	setPhase(match, "Aim", Config.AIM_TIME)
	waitFor(match, Config.AIM_TIME, function()
		return everyone(match, function(competitor)
			return competitor.locked
		end)
	end)
end

local function runMatch(match: Match)
	local state = match.arena.state
	local round = 0
	while not quitter(match) do
		round += 1
		state:SetAttribute("Round", round)
		state:SetAttribute("RoundWinner", "")

		draft(match)
		if quitter(match) then
			break
		end

		local battle = Battle.new(match.arena, {
			Left = match.competitors.Left.pick :: string,
			Right = match.competitors.Right.pick :: string,
		}, match.players)
		match.battle = battle
		aim(match, battle)

		if not quitter(match) then
			setPhase(match, "Battle", Config.BATTLE_TIME)
			battle:launch({ Left = match.competitors.Left.aim, Right = match.competitors.Right.aim })
			waitFor(match, Config.BATTLE_TIME, function()
				return #battle:aliveSides() < 2
			end)
		end
		if quitter(match) then
			battle:destroy()
			match.battle = nil
			break
		end

		local winner = battle:winner()
		battle.running = false
		if winner then
			local loser = match.competitors[other(winner)]
			loser.hearts -= 1
			state:SetAttribute(`{loser.side}Hearts`, loser.hearts)
		end
		state:SetAttribute("RoundWinner", winner or "Draw")
		setPhase(match, "Resolve", Config.RESOLVE_TIME)
		task.wait(Config.RESOLVE_TIME)
		battle:destroy()
		match.battle = nil

		if match.competitors.Left.hearts <= 0 or match.competitors.Right.hearts <= 0 then
			break
		end
	end

	-- Whoever quit loses; otherwise whoever has hearts left wins.
	local gone = quitter(match)
	local winnerSide = if gone
		then other(gone.side)
		elseif match.competitors.Left.hearts > 0 then "Left"
		else "Right"
	state:SetAttribute("MatchWinner", match.competitors[winnerSide].name)
	setPhase(match, "Over", Config.MATCH_OVER_TIME)
	task.wait(Config.MATCH_OVER_TIME)
end

local function startMatch(left: Player, right: Player?)
	local slot = 0
	while slotsInUse[slot] do
		slot += 1
	end
	if slot >= MAX_ARENAS then
		return
	end
	slotsInUse[slot] = true
	matchCount += 1

	local id = `Match{matchCount}`
	local arena = Arena.build(id, slot)
	local players = { left }
	if right then
		table.insert(players, right)
	end

	local function competitor(side: string, player: Player?): Competitor
		local _, forward = arena.spawn(side)
		return {
			side = side,
			player = player,
			name = if player then player.DisplayName else "🤖 Bot",
			hearts = Config.HEARTS,
			forward = forward,
			options = {},
			pick = nil,
			aim = nil,
			locked = false,
		}
	end
	local match: Match = {
		id = id,
		arena = arena,
		slot = slot,
		competitors = { Left = competitor("Left", left), Right = competitor("Right", right) },
		players = players,
		phase = "",
		battle = nil,
	}

	for side, entry in match.competitors do
		arena.state:SetAttribute(`{side}Name`, entry.name)
		arena.state:SetAttribute(`{side}Hearts`, entry.hearts)
		if entry.player then
			entry.player:SetAttribute("Side", side)
			entry.player:SetAttribute("MatchId", id)
			matchOf[entry.player] = match
			holdAvatar(entry.player, true)
		end
	end

	task.spawn(function()
		local ok, err = xpcall(runMatch, debug.traceback, match)
		if not ok then
			warn(`Match {id} broke: {err}`)
		end
		if match.battle then
			match.battle:destroy()
		end
		for _, player in players do
			matchOf[player] = nil
			if player.Parent == Players then
				player:SetAttribute("MatchId", "")
				player:SetAttribute("Side", "")
				player:SetAttribute("DraftOptions", "")
				holdAvatar(player, false)
			end
		end
		arena.destroy()
		slotsInUse[slot] = nil
	end)
end

local function onPad(player: Player, pad: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local offset = root.Position - pad.Position
	-- Pads are upright cylinders, so their diameter is Size.Y.
	return Vector2.new(offset.X, offset.Z).Magnitude < pad.Size.Y / 2 and math.abs(offset.Y) < 8
end

Remotes.Draft.OnServerEvent:Connect(function(player: Player, id: unknown)
	local match = matchOf[player]
	local competitor = match and competitorOf(match, player)
	if match and competitor and match.phase == "Draft" and typeof(id) == "string" and table.find(competitor.options, id) then
		competitor.pick = id
		player:SetAttribute("DraftPick", id)
	end
end)

Remotes.Aim.OnServerEvent:Connect(function(player: Player, direction: unknown, locked: unknown)
	local match = matchOf[player]
	local competitor = match and competitorOf(match, player)
	if not match or not competitor or match.phase ~= "Aim" or competitor.locked then
		return
	end
	competitor.aim = Battle.clampAim(direction, competitor.forward)
	competitor.locked = locked == true
end)

function MatchService.start()
	lobby = Lobby.build()

	local botPadSince: { [Player]: number } = {}
	task.spawn(function()
		while true do
			local waiting = {}
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if matchOf[player] then
					botPadSince[player] = nil
				elseif onPad(player, lobby.duelPad) then
					table.insert(waiting, player)
				elseif onPad(player, lobby.botPad) then
					botPadSince[player] = botPadSince[player] or now
					if now - botPadSince[player] >= BOT_PAD_DELAY then
						botPadSince[player] = nil
						startMatch(player, nil)
					end
				else
					botPadSince[player] = nil
				end
			end
			while #waiting >= 2 do
				startMatch(table.remove(waiting, 1) :: Player, table.remove(waiting, 1))
			end
			lobby.duelSign.Text = `⚔️ {#waiting}/2`
			task.wait(0.25)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		botPadSince[player] = nil
	end)
end

return MatchService
