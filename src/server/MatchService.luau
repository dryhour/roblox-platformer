local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Battle = require(script.Parent.Battle)
local Data = require(script.Parent.Data)
local Rewards = require(script.Parent.Rewards)
local Shop = require(script.Parent.Shop)
local Lobby = require(script.Parent.World.Lobby)
local Robot = require(script.Parent.World.Robot)
local Station = require(script.Parent.World.Station)

-- Matchmaking and the match loop. Players press Join at a station's square (or Play / Quick Join
-- in the HUD) and wait there, held in place, until someone takes the other side; after
-- Config.BOT_JOIN_AFTER seconds alone, a robot does. Then both float beside the station's box on
-- hover pads, with their hearts over their heads, and play rounds until one side runs out:
--   Draft    each side picks one of 3 random balls from its collection
--   Aim      each side aims its launch
--   Battle   the balls fight on their own
--   Finish   the finisher: the beaten ball bursts into energy in the winner's explosion style,
--            which flies into the loser's avatar and blows up on them, and they lose a heart
--   Resolve  ROUND WON / ROUND LOST
-- Afterwards everyone gets paid (Rewards.matchFinished) and a reward roll.
--
-- Clients follow along through attributes. On each player: WaitingAt (an arena's name) and
-- WaitingSide while waiting; MatchId (the arena's name), Side ("Left" or "Right"), DraftOptions
-- (comma-separated ids), DraftPick and AllBallsUsed during a match. On the arena's State:
-- WaitingLeft/WaitingRight (user ids, 0 for nobody) between matches, and during one Phase (empty
-- between matches), EndsAt (server time), Round, SuddenDeath, and for each side
-- LeftName/RightName, LeftUserId/RightUserId (0 for the bot), LeftHearts/RightHearts,
-- LeftPick/RightPick and LeftAvatar/RightAvatar (where each avatar's chest is, for the camera);
-- then RoundWinner ("Left", "Right" or "Draw"), MatchWinner (a name) and MatchWinnerSide.
local MatchService = {}

local SIDES = { "Left", "Right" }
local CHECK_EVERY = 0.25

-- The finisher, in seconds.
local SLOW_MOTION = 0.5 -- after the knockout, everything still moving goes at a fifth of the speed
local CAMERA_SWEEP = 0.15 -- a beat before the energy flies (the camera follows it to the loser)
local ENERGY_FLIGHT = 0.8 -- the beaten ball's energy flies into the loser
local HEART_DELAY = 0.5 -- the lost heart shatters, then it's gone
local CHEST = Vector3.new(0, 3, 0) -- from an avatar's feet to its chest

type Competitor = {
	side: string,
	player: Player?, -- nil for a bot
	body: Model?, -- the bot's robot
	name: string,
	hearts: number,
	forward: Vector3,
	explosion: string,
	friendly: boolean, -- the two players are Roblox friends
	options: { string },
	pick: string?,
	aim: Vector3?,
	locked: boolean,
}

type Match = {
	id: string,
	station: Station.Station,
	competitors: { [string]: Competitor },
	phase: string,
	battle: Battle.Battle?,
}

-- Who's waiting at a station, and since when the first of them has been.
type Seats = { Left: Player?, Right: Player?, since: number }

local rng = Random.new()
local lobby: Lobby.Lobby
local matchOf: { [Player]: Match } = {}
local matchAt: { [Station.Station]: Match } = {}
local seats: { [Station.Station]: Seats } = {}
local seatOf: { [Player]: { station: Station.Station, side: string } } = {}
local cancelTrade: (Player) -> () = function() end

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
	local state = match.station.arena.state
	state:SetAttribute("Phase", phase)
	state:SetAttribute("EndsAt", if seconds then workspace:GetServerTimeNow() + seconds else 0)
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

-- Avatars

-- The avatar standing in for a side: the player's character, or the bot's robot.
local function bodyOf(competitor: Competitor): Model?
	if competitor.player then
		return competitor.player.Character
	end
	return competitor.body
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and (character :: Model):FindFirstChild("HumanoidRootPart") ~= nil
end

-- Puts a character's feet at `feet`. `pinned` holds it there, e.g. on a hover pad in a match.
local function place(character: Model?, feet: CFrame, pinned: boolean)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local height = 3
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		height = humanoid.HipHeight + root.Size.Y / 2
	end
	root.Anchored = pinned
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(feet + Vector3.new(0, height, 0))
end

-- Hearts floating over a character's head, so people watching from the lobby can see the score.
local function showHearts(character: Model?, hearts: number?)
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not head then
		return
	end
	local billboard = head:FindFirstChild("MatchHearts")
	if not hearts then
		if billboard then
			billboard:Destroy()
		end
		return
	end
	if not billboard then
		-- One heart each, named Heart1, Heart2..., so clients can shatter the one being lost.
		billboard = Instance.new("BillboardGui")
		billboard.Name = "MatchHearts"
		billboard.Size = UDim2.fromScale(1.5 * Config.HEARTS, 1.5)
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
		billboard.LightInfluence = 0
		billboard.MaxDistance = 250
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = billboard
		for index = 1, Config.HEARTS do
			local heart = Instance.new("TextLabel")
			heart.Name = `Heart{index}`
			heart.LayoutOrder = index
			heart.Size = UDim2.fromScale(1 / Config.HEARTS, 1)
			heart.BackgroundTransparency = 1
			heart.Text = "❤️"
			heart.TextScaled = true
			heart.Parent = billboard
		end
		billboard.Parent = head
	end
	for index = 1, Config.HEARTS do
		local heart = billboard:FindFirstChild(`Heart{index}`)
		if heart and heart:IsA("TextLabel") then
			heart.Visible = index <= hearts
		end
	end
end

local function setHearts(match: Match, competitor: Competitor, hearts: number)
	competitor.hearts = hearts
	match.station.arena.state:SetAttribute(`{competitor.side}Hearts`, hearts)
	showHearts(bodyOf(competitor), hearts)
end

-- Rounds

-- The balls a player can draft: the ones they own, topped up with starters if they have fewer
-- than 3 different ones.
local function draftPool(player: Player): { string }
	local profile = Data.get(player)
	local pool = {}
	if profile then
		for id, count in profile.balls do
			if count > 0 and Brainrots.exists(id) then
				table.insert(pool, id)
			end
		end
	end
	for _, id in Brainrots.STARTERS do
		if #pool >= 3 then
			break
		end
		if not table.find(pool, id) then
			table.insert(pool, id)
		end
	end
	return pool
end

local function draft(match: Match)
	local state = match.station.arena.state
	for side, competitor in match.competitors do
		competitor.pick = nil
		competitor.aim = nil
		competitor.locked = false
		state:SetAttribute(`{side}Pick`, "")
		local player = competitor.player
		if player then
			competitor.options = Brainrots.roll(3, rng, draftPool(player))
			player:SetAttribute("DraftOptions", table.concat(competitor.options, ","))
			player:SetAttribute("DraftPick", "")
			player:SetAttribute("AllBallsUsed", false)
		else
			-- The bot picks from every ball after a moment's thought.
			competitor.options = Brainrots.roll(3, rng)
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
	for side, competitor in match.competitors do
		competitor.pick = competitor.pick or competitor.options[rng:NextInteger(1, #competitor.options)]
		state:SetAttribute(`{side}Pick`, competitor.pick)
		if competitor.player then
			competitor.player:SetAttribute("DraftPick", competitor.pick)
		end
	end
end

local function aim(match: Match, battle: Battle.Battle)
	local axis = match.station.arena.facing
	for side, competitor in match.competitors do
		if not competitor.player then
			-- The bot aims roughly at the other ball.
			local mine, theirs = battle.balls[side], battle.balls[other(side)]
			local toward = theirs.core.Position - mine.core.Position
			local wobble = CFrame.fromAxisAngle(axis, math.rad(rng:NextNumber(-35, 35)))
			competitor.aim = Battle.clampAim(wobble:VectorToWorldSpace(toward), competitor.forward, axis)
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

-- Smoke and fire on an avatar that just got blown up, for `duration` seconds.
local function smother(body: Model?, duration: number)
	local root = body and body:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cloud = Instance.new("Smoke")
	cloud.Color = Color3.fromRGB(30, 30, 30)
	cloud.Opacity = 0.6
	cloud.RiseVelocity = 4
	cloud.Size = 6
	cloud.Parent = root
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Parent = root
	task.delay(duration, function()
		cloud:Destroy()
		fire:Destroy()
	end)
end

-- The end of a round someone won: the beaten ball bursts into energy in the winner's explosion
-- style and flies into the loser's avatar (clients' cameras lean after it during the Finish
-- phase), it blows up on them, and they lose a heart.
local function finisher(match: Match, battle: Battle.Battle, winner: string)
	local state = match.station.arena.state
	local loser = match.competitors[other(winner)]
	state:SetAttribute("RoundWinner", winner)
	setPhase(match, "Finish", CAMERA_SWEEP + ENERGY_FLIGHT + HEART_DELAY)
	task.wait(CAMERA_SWEEP)

	local body = bodyOf(loser)
	local target = match.station.stands[loser.side].Position + CHEST
	local ball = battle.balls[loser.side]
	local brainrot = if ball then ball.def.id else ""
	local from = battle:disperse(loser.side) or target
	battle:effect("Finisher", from, target, match.competitors[winner].explosion, brainrot, body, ENERGY_FLIGHT)
	task.wait(ENERGY_FLIGHT)

	smother(body, HEART_DELAY + Config.RESOLVE_TIME)
	task.wait(HEART_DELAY)
	setHearts(match, loser, loser.hearts - 1)
	setPhase(match, "Resolve", Config.RESOLVE_TIME)
	task.wait(Config.RESOLVE_TIME)
end

-- Plays the match and returns the winning side.
local function runMatch(match: Match): string
	local state = match.station.arena.state
	local left, right = match.competitors.Left, match.competitors.Right
	local round = 0
	while not quitter(match) do
		round += 1
		state:SetAttribute("Round", round)
		state:SetAttribute("RoundWinner", "")

		draft(match)
		if quitter(match) then
			break
		end

		local battle = Battle.new(match.station.arena, { Left = left.pick :: string, Right = right.pick :: string })
		match.battle = battle
		aim(match, battle)

		if not quitter(match) then
			setPhase(match, "Battle", Config.BATTLE_TIME)
			battle:launch({ Left = left.aim, Right = right.aim })
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
		-- A knockout gets a moment of slow motion before everything stops.
		if #battle:aliveSides() < 2 then
			battle:slowMotion(SLOW_MOTION)
			task.wait(SLOW_MOTION)
		end
		battle:freeze()
		if winner then
			finisher(match, battle, winner)
		else
			state:SetAttribute("RoundWinner", "Draw")
			setPhase(match, "Resolve", Config.RESOLVE_TIME)
			task.wait(Config.RESOLVE_TIME)
		end
		battle:destroy()
		match.battle = nil

		if left.hearts <= 0 or right.hearts <= 0 then
			break
		end
	end

	-- Whoever quit loses; otherwise whoever has hearts left wins.
	local gone = quitter(match)
	local winnerSide = if gone then other(gone.side) elseif left.hearts > 0 then "Left" else "Right"
	state:SetAttribute("MatchWinner", match.competitors[winnerSide].name)
	state:SetAttribute("MatchWinnerSide", winnerSide)
	setPhase(match, "Over", Config.MATCH_OVER_TIME)
	-- The camera pans to the winner, who gets a crown.
	Remotes.Effect:FireAllClients("Crown", match.station.stands[winnerSide].Position + CHEST)
	task.wait(Config.MATCH_OVER_TIME)
	return winnerSide
end

-- Waiting

-- Frees a player's seat without moving them, e.g. when a match starts or they leave the game.
local function unseat(player: Player)
	local seat = seatOf[player]
	if not seat then
		return
	end
	seatOf[player] = nil
	local waiting = seats[seat.station]
	waiting[seat.side] = nil
	if not waiting.Left and not waiting.Right then
		waiting.since = 0
	end
	if player.Parent == Players then
		player:SetAttribute("WaitingAt", "")
		player:SetAttribute("WaitingSide", "")
	end
end

-- Pays out and cleans up a finished match. `winner` is nil if the match broke.
local function finishMatch(match: Match, winner: string?)
	local station = match.station
	if match.battle then
		match.battle:destroy()
	end
	for side, competitor in match.competitors do
		local body = bodyOf(competitor)
		showHearts(body, nil)
		local player = competitor.player
		if player then
			matchOf[player] = nil
			if player.Parent == Players then
				player:SetAttribute("MatchId", "")
				player:SetAttribute("Side", "")
				player:SetAttribute("DraftOptions", "")
				place(body, station.exits[side], false)
				if winner then
					local opponent = match.competitors[other(side)]
					Rewards.matchFinished(player, winner == side, competitor.friendly and opponent.player ~= nil)
					task.delay(0.5, Rewards.rollAfterMatch, player)
				end
			end
		elseif competitor.body then
			competitor.body:Destroy()
		end
	end
	station.arena.state:SetAttribute("Phase", "")
	matchAt[station] = nil
end

local function startMatch(station: Station.Station, waiting: Seats)
	local arena = station.arena
	local state = arena.state
	local match: Match = {
		id = arena.model.Name,
		station = station,
		competitors = {},
		phase = "",
		battle = nil,
	}
	for _, side in SIDES do
		local player: Player? = waiting[side]
		local profile = if player then Data.get(player) else nil
		local _, forward = arena.spawn(side)
		match.competitors[side] = {
			side = side,
			player = player,
			body = if player then nil else Robot.new(),
			name = if player then player.DisplayName else "🤖",
			hearts = Config.HEARTS,
			forward = forward,
			explosion = if profile then profile.explosion else "Default",
			friendly = false,
			options = {},
			pick = nil,
			aim = nil,
			locked = false,
		}
		if player then
			unseat(player)
			cancelTrade(player)
		end
	end
	matchAt[station] = match

	-- Matches against a friend count for the daily quest.
	local left, right = waiting.Left, waiting.Right
	if left and right then
		task.spawn(function()
			local ok, friends = pcall(left.IsFriendsWith, left, right.UserId)
			if ok and friends then
				match.competitors.Left.friendly = true
				match.competitors.Right.friendly = true
			end
		end)
	end

	for _, name in { "RoundWinner", "MatchWinner", "MatchWinnerSide", "LeftPick", "RightPick" } do
		state:SetAttribute(name, "")
	end
	for _, side in SIDES do
		state:SetAttribute(`{side}Avatar`, station.stands[side].Position + CHEST)
	end
	state:SetAttribute("SuddenDeath", false)
	state:SetAttribute("WaitingLeft", 0)
	state:SetAttribute("WaitingRight", 0)
	for side, competitor in match.competitors do
		state:SetAttribute(`{side}Name`, competitor.name)
		state:SetAttribute(`{side}UserId`, if competitor.player then competitor.player.UserId else 0)
		local player = competitor.player
		if player then
			player:SetAttribute("Side", side)
			player:SetAttribute("MatchId", match.id)
			matchOf[player] = match
		elseif competitor.body then
			competitor.body.Parent = arena.model
		end
		place(bodyOf(competitor), station.stands[side], true)
		setHearts(match, competitor, Config.HEARTS)
	end
	station.show({}, true)

	task.spawn(function()
		local ok, result = xpcall(runMatch, debug.traceback, match)
		if not ok then
			warn(`Match at {match.id} broke: {result}`)
		end
		finishMatch(match, if ok then result else nil)
	end)
end

-- Seats `player` at a station's side to wait for an opponent. Returns whether it worked.
function MatchService.join(player: Player, station: Station.Station, side: string): boolean
	local waiting = seats[station]
	if matchOf[player] or seatOf[player] or matchAt[station] or (waiting :: any)[side] or not alive(player) then
		return false
	end
	cancelTrade(player)
	if not waiting.Left and not waiting.Right then
		waiting.since = os.clock()
	end
	(waiting :: any)[side] = player
	seatOf[player] = { station = station, side = side }
	place(player.Character, station.seats[side], true)
	player:SetAttribute("WaitingAt", station.arena.model.Name)
	player:SetAttribute("WaitingSide", side)
	return true
end

-- Stops waiting and steps out of the square.
function MatchService.leave(player: Player): boolean
	local seat = seatOf[player]
	if not seat then
		return false
	end
	unseat(player)
	place(player.Character, seat.station.exits[seat.side], false)
	return true
end

local function stationNamed(name: unknown): Station.Station?
	for _, station in lobby.stations do
		if station.arena.model.Name == name then
			return station
		end
	end
	return nil
end

local function freeSide(station: Station.Station): string?
	local waiting = seats[station]
	if matchAt[station] then
		return nil
	end
	return if not waiting.Left then "Left" elseif not waiting.Right then "Right" else nil
end

-- Joins the station with this arena name, at whichever side is free.
function MatchService.quickJoin(player: Player, arenaName: unknown): boolean
	local station = stationNamed(arenaName)
	local side = if station then freeSide(station) else nil
	return station ~= nil and side ~= nil and MatchService.join(player, station, side)
end

-- Joins someone who's waiting if anyone is, or else an empty station.
function MatchService.play(player: Player): boolean
	local empty = {}
	for _, station in lobby.stations do
		local waiting = seats[station]
		local side = freeSide(station)
		if side and (waiting.Left or waiting.Right) then
			return MatchService.join(player, station, side)
		elseif side then
			table.insert(empty, station)
		end
	end
	if #empty == 0 then
		return false
	end
	return MatchService.join(player, empty[rng:NextInteger(1, #empty)], "Left")
end

-- Swaps your draft options for 3 from every ball: free once a day, then with a "Pick Any Card"
-- voucher, or every round with the pass.
function MatchService.allBalls(player: Player): boolean
	local match = matchOf[player]
	local competitor = match and competitorOf(match, player)
	local profile = Data.get(player)
	if not match or not competitor or not profile or match.phase ~= "Draft" or competitor.pick then
		return false
	end
	if player:GetAttribute("AllBallsUsed") == true then
		return false
	end
	if not Shop.ownsAllBalls(player) then
		local today = Economy.day(workspace:GetServerTimeNow())
		if profile.freeAllBallsDay ~= today then
			Data.update(player, function(fresh)
				fresh.freeAllBallsDay = today
			end)
		elseif profile.vouchers > 0 then
			Data.update(player, function(fresh)
				fresh.vouchers -= 1
			end)
		else
			return false
		end
	end
	competitor.options = Brainrots.roll(3, rng)
	player:SetAttribute("AllBallsUsed", true)
	player:SetAttribute("DraftOptions", table.concat(competitor.options, ","))
	return true
end

-- Whether a player is waiting at a station or playing a match.
function MatchService.busy(player: Player): boolean
	return matchOf[player] ~= nil or seatOf[player] ~= nil
end

-- Keeps the seats honest (people who died or left stop waiting), brings in the bot for anyone
-- who's waited too long, and starts matches.
local function checkStations()
	local now = os.clock()
	for _, station in lobby.stations do
		if matchAt[station] then
			continue
		end
		local waiting = seats[station]
		for _, side in SIDES do
			local player: Player? = (waiting :: any)[side]
			if player and (player.Parent ~= Players or not alive(player)) then
				unseat(player)
			end
		end
		local left, right = waiting.Left, waiting.Right
		local waited = now - waiting.since
		local alone = (left == nil) ~= (right == nil)
		if (left and right and waited >= Config.SETTLE_TIME) or (alone and waited >= Config.BOT_JOIN_AFTER) then
			startMatch(station, { Left = left, Right = right, since = waiting.since })
			continue
		end
		local state = station.arena.state
		state:SetAttribute("WaitingLeft", if left then left.UserId else 0)
		state:SetAttribute("WaitingRight", if right then right.UserId else 0)
		station.show({ Left = left, Right = right }, false)
	end
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
	competitor.aim = Battle.clampAim(direction, competitor.forward, match.station.arena.facing)
	competitor.locked = locked == true
end)

-- If a player respawns mid-match, put the new avatar back on its hover pad.
local function watchCharacter(player: Player)
	player.CharacterAdded:Connect(function(character)
		local match = matchOf[player]
		local competitor = match and competitorOf(match, player)
		if not match or not competitor then
			return
		end
		character:WaitForChild("HumanoidRootPart", 5)
		character:WaitForChild("Head", 5)
		if matchOf[player] == match then
			place(character, match.station.stands[competitor.side], true)
			showHearts(character, competitor.hearts)
		end
	end)
end

-- `endTrade` closes a player's open trade when they join a station or a match.
function MatchService.start(endTrade: (Player) -> ())
	cancelTrade = endTrade
	lobby = Lobby.build()
	task.spawn(Robot.preload)
	for _, station in lobby.stations do
		seats[station] = { since = 0 }
		for side, prompt in station.prompts do
			prompt.Triggered:Connect(function(player)
				MatchService.join(player, station, side)
			end)
		end
	end

	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerRemoving:Connect(unseat)

	task.spawn(function()
		while true do
			checkStations()
			task.wait(CHECK_EVERY)
		end
	end)
end

return MatchService
