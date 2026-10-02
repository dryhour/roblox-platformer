local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local Characters = require(script.Parent.Parent.Characters)
local Maps = require(script.Parent.Parent.Maps)
local Scoring = require(script.Parent.Parent.Scoring)
local Types = require(script.Parent.Parent.Types)

-- Platform Rush: race left to right to the Finish part. Dying sends you back to the last
-- Checkpoint you touched. Finishers score by place; everyone else scores by distance covered.
local PlatformRush = {}
PlatformRush.map = "RushCourse"

-- Once the first player finishes, the clock drops to this many seconds (if it's higher).
local FINISH_GRACE = 20
-- The most a player who didn't finish can score, for getting all the way to the line.
local UNFINISHED_MAX_POINTS = 40

type Round = {
	ctx: Types.Context,
	active: boolean,
	startedAt: number,
	finishers: { Player },
	finishTimes: { [Player]: number },
	checkpoints: { [Player]: CFrame },
	bestX: { [Player]: number }, -- furthest right each player has been
	startX: number,
	finishX: number,
}

local round: Round? = nil

local function progress(r: Round, player: Player): number
	if r.finishTimes[player] then
		return 1
	end
	return math.clamp((r.bestX[player] - r.startX) / (r.finishX - r.startX), 0, 1)
end

local function finishRace(r: Round, player: Player)
	local elapsed = workspace:GetServerTimeNow() - r.startedAt
	table.insert(r.finishers, player)
	r.finishTimes[player] = elapsed
	local place = Text.ordinal(#r.finishers)
	player:SetAttribute("Status", string.format("Finished %s! (%.1fs)", place, elapsed))
	r.ctx.announce(`{player.DisplayName} finished {place}!`)
	if #r.finishers == 1 and r.ctx.timeLeft() > FINISH_GRACE then
		r.ctx.setTimeLeft(FINISH_GRACE)
		r.ctx.announce(`{FINISH_GRACE} seconds left!`)
	end
end

function PlatformRush.setup(ctx: Types.Context)
	local spawns = Maps.spawnPoints(ctx.map, "Spawn")
	local finish = Maps.markers(ctx.map, "Finish")[1]
	assert(finish, "RushCourse needs a part named Finish")

	local startX = 0
	for _, spawnAt in spawns do
		startX += spawnAt.Position.X / #spawns
	end

	local r: Round = {
		ctx = ctx,
		active = false,
		startedAt = 0,
		finishers = {},
		finishTimes = {},
		checkpoints = {},
		bestX = {},
		startX = startX,
		finishX = finish.Position.X,
	}
	round = r

	for i, player in ctx.players do
		local spawnAt = spawns[(i - 1) % #spawns + 1]
		r.checkpoints[player] = spawnAt
		r.bestX[player] = spawnAt.Position.X
		player:SetAttribute("Status", "Progress: 0%")
		ctx.spawn(player, spawnAt)
	end

	for _, checkpoint in Maps.markers(ctx.map, "Checkpoint") do
		local respawnAt = Maps.standAt(checkpoint)
		checkpoint.Touched:Connect(function(hit)
			local player = Characters.playerFromPart(hit)
			local saved = player and r.checkpoints[player]
			if player and saved and saved.Position.X < respawnAt.Position.X then
				r.checkpoints[player] = respawnAt
			end
		end)
	end

	finish.Touched:Connect(function(hit)
		local player = Characters.playerFromPart(hit)
		if player and r.active and r.checkpoints[player] and not r.finishTimes[player] then
			finishRace(r, player)
		end
	end)
end

function PlatformRush.run(ctx: Types.Context): { [Player]: Types.Result }
	local r = assert(round, "PlatformRush.run called before setup")
	r.startedAt = workspace:GetServerTimeNow()
	r.active = true
	ctx.waitUntilOver(function()
		local allFinished = true
		for _, player in ctx.players do
			if ctx.isIn(player) and not r.finishTimes[player] then
				allFinished = false
				local root = Characters.root(player)
				if root then
					r.bestX[player] = math.max(r.bestX[player], root.Position.X)
					player:SetAttribute("Status", `Progress: {math.floor(progress(r, player) * 100)}%`)
				end
			end
		end
		return allFinished
	end)
	r.active = false
	round = nil

	local results: { [Player]: Types.Result } = {}
	for place, player in r.finishers do
		results[player] = {
			points = Scoring.forPlace(place),
			detail = string.format("Finished %s (%.1fs)", Text.ordinal(place), r.finishTimes[player]),
		}
	end
	for _, player in ctx.players do
		if not results[player] then
			local covered = progress(r, player)
			results[player] = {
				points = math.round(UNFINISHED_MAX_POINTS * covered),
				detail = `Made it {math.floor(covered * 100)}% of the way`,
			}
		end
	end
	return results
end

function PlatformRush.onDied(ctx: Types.Context, player: Player)
	local r = round
	if not r then
		return
	end
	ctx.respawnLater(player, function()
		ctx.spawn(player, r.checkpoints[player])
	end)
end

return PlatformRush
