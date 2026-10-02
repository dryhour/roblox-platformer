local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local Characters = require(script.Parent.Parent.Characters)
local Maps = require(script.Parent.Parent.Maps)
local Scoring = require(script.Parent.Parent.Scoring)
local Types = require(script.Parent.Parent.Types)

-- Coin Rush: coins keep appearing at the map's CoinSpawn markers. Players are ranked by the
-- total value they collect and score by place.
local CoinRush = {}
CoinRush.map = "CoinCaverns"

type CoinType = { value: number, size: number, color: Color3, material: Enum.Material }

local COIN_TYPES: { [string]: CoinType } = {
	normal = { value = 1, size = 3, color = Color3.fromRGB(255, 210, 50), material = Enum.Material.SmoothPlastic },
	gold = { value = 5, size = 3.6, color = Color3.fromRGB(255, 140, 20), material = Enum.Material.Neon },
	rare = { value = 10, size = 4.2, color = Color3.fromRGB(90, 230, 255), material = Enum.Material.Neon },
}

-- Chances of a gold or rare coin. Markers with a Risky attribute use the better odds.
local NORMAL_ODDS = { gold = 0.15, rare = 0.03 }
local RISKY_ODDS = { gold = 0.35, rare = 0.25 }

-- Coins on the map at once: BASE_COINS plus COINS_PER_PLAYER for each player, up to the
-- number of markers.
local BASE_COINS = 6
local COINS_PER_PLAYER = 2
local COIN_RESPAWN_DELAY = 1.5
-- Radians per second; clients do the spinning.
local SPIN_SPEED = 3

type Round = {
	ctx: Types.Context,
	active: boolean,
	coins: { [Player]: number },
	folder: Folder,
	spots: { BasePart },
	taken: { [BasePart]: boolean },
}

local round: Round? = nil

local function rollCoin(spot: BasePart): CoinType
	local odds = if spot:GetAttribute("Risky") then RISKY_ODDS else NORMAL_ODDS
	local roll = math.random()
	if roll < odds.rare then
		return COIN_TYPES.rare
	elseif roll < odds.rare + odds.gold then
		return COIN_TYPES.gold
	end
	return COIN_TYPES.normal
end

local function spawnCoin(r: Round)
	local free = {}
	for _, spot in r.spots do
		if not r.taken[spot] then
			table.insert(free, spot)
		end
	end
	if #free == 0 then
		return
	end
	local spot = free[math.random(#free)]
	local kind = rollCoin(spot)
	r.taken[spot] = true

	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.8, kind.size, kind.size)
	-- A cylinder's flat faces are on its X axis; turn them toward the camera.
	coin.CFrame = CFrame.new(spot.Position) * CFrame.Angles(0, math.pi / 2, 0)
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin.Color = kind.color
	coin.Material = kind.material
	coin:SetAttribute("Spin", SPIN_SPEED)

	local collected = false
	coin.Touched:Connect(function(hit)
		if collected or not r.active then
			return
		end
		local player = Characters.playerFromPart(hit)
		if not player or not r.coins[player] then
			return
		end
		collected = true
		coin:Destroy()
		r.taken[spot] = nil
		r.coins[player] += kind.value
		player:SetAttribute("Status", `Coins: {r.coins[player]}`)
		if kind == COIN_TYPES.rare then
			r.ctx.announce(`{player.DisplayName} grabbed a blue coin! +{kind.value}`)
		end
		task.delay(COIN_RESPAWN_DELAY, function()
			if round == r and r.active then
				spawnCoin(r)
			end
		end)
	end)
	coin.Parent = r.folder
end

function CoinRush.setup(ctx: Types.Context)
	local folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = ctx.map

	local r: Round = {
		ctx = ctx,
		active = false,
		coins = {},
		folder = folder,
		spots = Maps.markers(ctx.map, "CoinSpawn"),
		taken = {},
	}
	round = r

	local spawns = Maps.spawnPoints(ctx.map, "Spawn")
	for i, player in ctx.players do
		r.coins[player] = 0
		player:SetAttribute("Status", "Coins: 0")
		ctx.spawn(player, spawns[(i - 1) % #spawns + 1])
	end

	for _ = 1, math.min(BASE_COINS + COINS_PER_PLAYER * #ctx.players, #r.spots) do
		spawnCoin(r)
	end
end

function CoinRush.run(ctx: Types.Context): { [Player]: Types.Result }
	local r = assert(round, "CoinRush.run called before setup")
	r.active = true
	ctx.waitUntilOver(function()
		return false
	end)
	r.active = false
	round = nil

	local places = Scoring.places(r.coins)
	local results: { [Player]: Types.Result } = {}
	for player, coins in r.coins do
		results[player] = {
			-- Placing ahead of someone else with zero coins shouldn't be worth anything.
			points = if coins > 0 then Scoring.forPlace(places[player]) else 0,
			detail = `{Text.count(coins, "coin")} ({Text.ordinal(places[player])})`,
		}
	end
	return results
end

function CoinRush.onDied(ctx: Types.Context, player: Player)
	ctx.respawnLater(player, function()
		ctx.spawn(player, Maps.spawnPoints(ctx.map, "Spawn")[1])
	end)
end

return CoinRush
