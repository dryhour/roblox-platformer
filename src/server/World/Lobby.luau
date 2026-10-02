local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Looks = require(ReplicatedStorage.Shared.Looks)
local Builder = require(script.Parent.Builder)
local Station = require(script.Parent.Station)

-- The lobby: a big floating platform over the ocean where players walk around as their normal
-- avatars. Glowing arrows lead from the spawn down the middle, duel stations line both sides,
-- a gumball machine by the spawn opens the Store, and statues of every brainrot ball stand at
-- the far end.
local Lobby = {}

export type Lobby = {
	stations: { Station.Station },
}

local WIDTH = 180
local FRONT_Z = 115 -- the spawn end
local BACK_Z = -135
local THICKNESS = 8
local WALKWAY_WIDTH = 28
local STATION_X = 72 -- each column's boxes are this far from the middle
local STATION_ZS = { 70, 14, -42, -98 }
local CHEVRON_EVERY = 9

local FLOOR = Color3.fromRGB(58, 86, 150)
local WALKWAY = Color3.fromRGB(78, 112, 186)
local SIDE = Color3.fromRGB(32, 44, 84)
local EDGE = Color3.fromRGB(110, 210, 255)
local ARROW = Color3.fromRGB(235, 245, 255)
local PEDESTAL = Color3.fromRGB(26, 36, 70)

local function decorateWorld()
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -14, 0), Vector3.new(1200, 16, 1200), Enum.Material.Water)
	terrain.WaterColor = Color3.fromRGB(40, 110, 200)
	terrain.WaterReflectance = 0.6
	terrain.WaterTransparency = 0.4
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Parent = terrain
	end
end

-- A ">" made of two glowing strips on the floor, pointing along -Z.
local function chevron(b: Builder.Builder, folder: Folder, tip: Vector3, order: number)
	for _, sign in { -1, 1 } do
		local back = tip + Vector3.new(sign * 3, 0, 3)
		local arm = b:box(Vector3.new(0.9, 0.12, (back - tip).Magnitude + 0.9), CFrame.lookAt((tip + back) / 2, tip), ARROW, "Arrow", folder)
		arm.Material = Enum.Material.Neon
		arm.CanCollide = false
		arm.CastShadow = false
		arm:SetAttribute("Order", order)
	end
end

-- A big gumball machine. Its prompt opens the Store window (clients watch for prompts with an
-- OpensWindow attribute).
local function gumballMachine(b: Builder.Builder, position: Vector3)
	local base = b:block(Vector3.new(6, 6, 6), position + Vector3.new(0, 3, 0), Color3.fromRGB(220, 50, 70), "StoreMachine")
	b:block(Vector3.new(2.4, 1.6, 0.4), position + Vector3.new(0, 2.6, 3.1), Color3.fromRGB(40, 40, 50), "Chute")
	local globe = b:block(Vector3.new(7, 7, 7), position + Vector3.new(0, 9.5, 0), Color3.fromRGB(200, 230, 255), "Globe")
	globe.Shape = Enum.PartType.Ball
	globe.Material = Enum.Material.Glass
	globe.Transparency = 0.6
	local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 230, 110) }
	for index = 1, 14 do
		local angle = index * 2.4
		local offset = Vector3.new(math.cos(angle) * 2, (index % 4) * 0.9 - 1.6, math.sin(angle) * 2)
		local gumball = b:block(Vector3.one * 1.3, position + Vector3.new(0, 9.5, 0) + offset, colors[index % #colors + 1], "Gumball")
		gumball.Shape = Enum.PartType.Ball
		gumball.CanCollide = false
	end
	b:cylinder(1.2, 4, position + Vector3.new(0, 13.4, 0), Color3.fromRGB(220, 50, 70), "Cap")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Store"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensWindow", "Store")
	prompt.Parent = base
end

function Lobby.build(): Lobby
	decorateWorld()

	local b = Builder.new("Lobby")
	local length = FRONT_Z - BACK_Z
	local middleZ = (FRONT_Z + BACK_Z) / 2

	b:block(Vector3.new(WIDTH, THICKNESS, length), Vector3.new(0, -THICKNESS / 2, middleZ), FLOOR, "Floor")
	b:block(Vector3.new(WIDTH + 2, THICKNESS - 1, length + 2), Vector3.new(0, -THICKNESS / 2 - 1, middleZ), SIDE, "Base")
	-- A glowing rim, and invisible walls so nobody falls in the sea.
	for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local span = if side.X ~= 0 then length else WIDTH
		local reach = if side.X ~= 0 then WIDTH / 2 else length / 2
		local along = Vector3.new(math.abs(side.Z), 0, math.abs(side.X)) * span
		local middle = Vector3.new(0, 0, middleZ) + side * reach
		local rim = b:block(along + side:Abs() * 1.2 + Vector3.new(0, 0.5, 0), middle + Vector3.new(0, 0.25, 0), EDGE, "Rim")
		rim.Material = Enum.Material.Neon
		local wall = b:block(along + side:Abs() * 4 + Vector3.new(0, 40, 0), middle + side * 2 + Vector3.new(0, 20, 0), EDGE, "Wall")
		b:ghost(wall, 1)
		wall.CanCollide = true
	end

	b:block(Vector3.new(WALKWAY_WIDTH, 0.2, length - 20), Vector3.new(0, 0.1, middleZ - 5), WALKWAY, "Walkway")

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, FRONT_Z - 18)
	spawnLocation.Color = WALKWAY
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = b.model

	local chevrons = Instance.new("Folder")
	chevrons.Name = "Chevrons"
	chevrons.Parent = b.model
	local order = 0
	for z = FRONT_Z - 30, BACK_Z + 30, -CHEVRON_EVERY do
		order += 1
		chevron(b, chevrons, Vector3.new(0, 0.26, z), order)
	end

	local stations = {}
	for _, z in STATION_ZS do
		for _, sign in { -1, 1 } do
			-- Each station faces the walkway.
			local origin = Vector3.new(sign * STATION_X, 0, z)
			local into = Vector3.new(sign, 0, 0)
			local id = `Arena{#stations + 1}`
			table.insert(stations, Station.build(b, id, CFrame.lookAt(origin, origin + into)))
		end
	end

	gumballMachine(b, Vector3.new(-24, 0, FRONT_Z - 22))

	-- A statue of every brainrot ball at the far end, facing the spawn.
	local count = #Brainrots.list
	local statueZ = BACK_Z + 14
	for index, brainrot in Brainrots.list do
		local x = (index - (count + 1) / 2) * 9 -- close together, so all 12 fit between the stations
		local pedestalTop = 3
		b:block(Vector3.new(7, pedestalTop, 7), Vector3.new(x, pedestalTop / 2, statueZ), PEDESTAL, "Pedestal")
		local statue = Looks.build(brainrot.id, 1)
		statue.Name = "Statue"
		local center = Vector3.new(x, pedestalTop + Brainrots.DESIGN_SIZE / 2, statueZ)
		Looks.place(statue, CFrame.new(center) * CFrame.Angles(0, math.pi, 0))
		statue.Parent = b.model
		local sign = b:sign(center + Vector3.new(0, 7, 0), brainrot.emoji, 4, 4)
		sign.TextStrokeTransparency = 1
	end
	b:sign(Vector3.new(0, 26, BACK_Z + 6), "BRAINROT VS BRAINROT", 100, 13).TextColor3 = Color3.fromRGB(255, 220, 60)

	b:build()
	return { stations = stations }
end

return Lobby
