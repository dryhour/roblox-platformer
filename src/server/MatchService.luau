local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Battle = require(script.Parent.Battle)
local Lobby = require(script.Parent.World.Lobby)
local Station = require(script.Parent.World.Station)

-- Matchmaking and the match loop. Players walk into a station's squares to queue: when both
-- squares stay filled for Config.SETTLE_TIME (a bot station's robot fills one), the match starts
-- right there. Both players float beside the station's box on hover pads, with their hearts over
-- their heads, and play rounds until one side runs out of hearts:
--   Draft    each side picks one of 3 random balls
--   Aim      each side aims its launch
--   Battle   the balls fight on their own
--   Resolve  the loser loses a heart
--
-- Clients follow along through attributes. On each player: WaitingAt (an arena's name) and
-- WaitingSide while standing in a square; MatchId (the arena's name), Side ("Left" or "Right"),
-- DraftOptions (comma-separated ids) and DraftPick during a match. On the arena's State: Phase
-- (empty between matches), EndsAt (server time), Round, SuddenDeath, and for each side
-- LeftName/RightName, LeftUserId/RightUserId (0 for the bot), LeftHearts/RightHearts and
-- LeftPick/RightPick; then RoundWinner ("Left", "Right" or "Draw") and MatchWinner (a name).
local MatchService = {}

local SIDES = { "Left", "Right" }
local CHECK_EVERY = 0.25

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
	station: Station.Station,
	competitors: { [string]: Competitor },
	players: { Player },
	phase: string,
	battle: Battle.Battle?,
}

local rng = Random.new()
local lobby: Lobby.Lobby
local matchOf: { [Player]: Match } = {}
local matchAt: { [Station.Station]: Match } = {}

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

-- The avatar standing in for a side: the player's character, or the station's robot.
local function bodyOf(match: Match, competitor: Competitor): Model?
	if competitor.player then
		return competitor.player.Character
	end
	return match.station.bot
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
		billboard = Instance.new("BillboardGui")
		billboard.Name = "MatchHearts"
		billboard.Size = UDim2.fromScale(4.5, 1.5)
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
		billboard.LightInfluence = 0
		billboard.MaxDistance = 250
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Parent = billboard
		billboard.Parent = head
	end
	local count = math.clamp(hearts, 0, Config.HEARTS)
	local label = billboard:FindFirstChild("Label") :: TextLabel
	label.Text = string.rep("❤️", count) .. string.rep("🖤", Config.HEARTS - count)
end

local function setHearts(match: Match, competitor: Competitor, hearts: number)
	competitor.hearts = hearts
	match.station.arena.state:SetAttribute(`{competitor.side}Hearts`, hearts)
	showHearts(bodyOf(match, competitor), hearts)
end

-- Rounds

local function draft(match: Match)
	local state = match.station.arena.state
	for side, competitor in match.competitors do
		competitor.options = Brainrots.roll(3, rng)
		competitor.pick = nil
		competitor.aim = nil
		competitor.locked = false
		state:SetAttribute(`{side}Pick`, "")
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

local function runMatch(match: Match)
	local state = match.station.arena.state
	local round = 0
	while not quitter(match) do
		round += 1
		state:SetAttribute("Round", round)
		state:SetAttribute("RoundWinner", "")

		draft(match)
		if quitter(match) then
			break
		end

		local battle = Battle.new(match.station.arena, {
			Left = match.competitors.Left.pick :: string,
			Right = match.competitors.Right.pick :: string,
		})
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
			setHearts(match, loser, loser.hearts - 1)
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

local function startMatch(station: Station.Station, occupants: { [string]: Station.Occupant? })
	local arena = station.arena
	local state = arena.state
	local match: Match = {
		id = arena.model.Name,
		station = station,
		competitors = {},
		players = {},
		phase = "",
		battle = nil,
	}
	for _, side in SIDES do
		local occupant = occupants[side]
		local player = if typeof(occupant) == "Instance" and occupant:IsA("Player") then occupant else nil
		local _, forward = arena.spawn(side)
		match.competitors[side] = {
			side = side,
			player = player,
			name = if player then player.DisplayName else "🤖",
			hearts = Config.HEARTS,
			forward = forward,
			options = {},
			pick = nil,
			aim = nil,
			locked = false,
		}
		if player then
			table.insert(match.players, player)
		end
	end
	matchAt[station] = match

	for _, name in { "RoundWinner", "MatchWinner", "LeftPick", "RightPick" } do
		state:SetAttribute(name, "")
	end
	state:SetAttribute("SuddenDeath", false)
	for side, competitor in match.competitors do
		state:SetAttribute(`{side}Name`, competitor.name)
		state:SetAttribute(`{side}UserId`, if competitor.player then competitor.player.UserId else 0)
		local player = competitor.player
		if player then
			player:SetAttribute("WaitingAt", "")
			player:SetAttribute("WaitingSide", "")
			player:SetAttribute("Side", side)
			player:SetAttribute("MatchId", match.id)
			matchOf[player] = match
		end
		place(bodyOf(match, competitor), station.stands[side], true)
		setHearts(match, competitor, Config.HEARTS)
	end

	task.spawn(function()
		local ok, err = xpcall(runMatch, debug.traceback, match)
		if not ok then
			warn(`Match at {match.id} broke: {err}`)
		end
		if match.battle then
			match.battle:destroy()
		end
		for side, competitor in match.competitors do
			local body = bodyOf(match, competitor)
			showHearts(body, nil)
			local player = competitor.player
			if player then
				matchOf[player] = nil
				if player.Parent == Players then
					player:SetAttribute("MatchId", "")
					player:SetAttribute("Side", "")
					player:SetAttribute("DraftOptions", "")
					place(body, station.exits[side], false)
				end
			elseif station.botHome then
				place(body, station.botHome, true)
			end
		end
		state:SetAttribute("Phase", "")
		matchAt[station] = nil
	end)
end

-- Lobby

local function inSquare(player: Player, square: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = square.CFrame:PointToObjectSpace(root.Position)
	return math.abs(offset.X) < square.Size.X / 2 and math.abs(offset.Z) < square.Size.Z / 2 and offset.Y > -1 and offset.Y < 8
end

-- Fills in who's standing in each station's squares, starts matches, and keeps each player's
-- WaitingAt and WaitingSide up to date.
local function checkStations(filledSince: { [Station.Station]: number })
	local now = os.clock()
	local waiting: { [Player]: { at: string, side: string } } = {}

	for _, station in lobby.stations do
		if matchAt[station] then
			station.show({}, true)
			continue
		end
		local occupants: { [string]: Station.Occupant? } = {}
		for _, side in SIDES do
			if side == "Right" and station.bot then
				occupants.Right = "Bot"
				continue
			end
			for _, player in Players:GetPlayers() do
				if not matchOf[player] and not waiting[player] and inSquare(player, station.squares[side]) then
					occupants[side] = player
					waiting[player] = { at = station.arena.model.Name, side = side }
					break
				end
			end
		end

		if occupants.Left and occupants.Right then
			filledSince[station] = filledSince[station] or now
			if now - filledSince[station] >= Config.SETTLE_TIME then
				filledSince[station] = nil
				for _, side in SIDES do
					local occupant = occupants[side]
					if typeof(occupant) == "Instance" and occupant:IsA("Player") then
						waiting[occupant] = nil
					end
				end
				startMatch(station, occupants)
				station.show({}, true)
				continue
			end
		else
			filledSince[station] = nil
		end
		station.show(occupants, false)
	end

	for _, player in Players:GetPlayers() do
		if matchOf[player] then
			continue
		end
		local spot = waiting[player]
		player:SetAttribute("WaitingAt", if spot then spot.at else "")
		player:SetAttribute("WaitingSide", if spot then spot.side else "")
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

function MatchService.start()
	lobby = Lobby.build()

	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end

	task.spawn(function()
		local filledSince: { [Station.Station]: number } = {}
		while true do
			checkStations(filledSince)
			task.wait(CHECK_EVERY)
		end
	end)
end

return MatchService
