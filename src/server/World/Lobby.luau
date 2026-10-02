local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Looks = require(script.Parent.Parent.Looks)
local Builder = require(script.Parent.Builder)

-- The lobby: a walled floor to roll around on. Rolling onto a brainrot's glowing pad turns you
-- into it, and once everyone is in the green circle the round starts. No menus (see CLAUDE.md);
-- Round runs the pads and the circle.
local Lobby = {}

export type Lobby = {
	model: Model,
	pads: { BasePart }, -- each has a Brainrot attribute
	zoneCenter: Vector3,
	zoneRadius: number,
	sign: TextLabel, -- over the green circle
	spawnPoint: () -> Vector3,
}

local SIZE = 160
local FLOOR = Color3.fromRGB(45, 35, 80)
local EDGE = Color3.fromRGB(255, 70, 200)
local READY = Color3.fromRGB(70, 230, 110)
local PEDESTAL = Color3.fromRGB(30, 25, 55)
local STATUE_SCALE = 1.6

function Lobby.build(center: Vector3): Lobby
	local b = Builder.new("Lobby")
	local half = SIZE / 2

	b:block(Vector3.new(SIZE, 4, SIZE), center + Vector3.new(0, -2, 0), FLOOR, "Floor")
	-- Glowing edges, with invisible walls behind them so nobody rolls off.
	for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local length = Vector3.new(math.abs(side.Z), 0, math.abs(side.X)) * SIZE
		local across = side:Abs()
		local strip = b:block(length + across * 1.5 + Vector3.new(0, 0.6, 0), center + side * half + Vector3.new(0, 0.3, 0), EDGE, "Edge")
		strip.Material = Enum.Material.Neon
		local wall = b:block(length + across * 4 + Vector3.new(0, 40, 0), center + side * (half + 2) + Vector3.new(0, 20, 0), EDGE, "Wall")
		b:ghost(wall, 1)
		wall.CanCollide = true
	end

	b:sign(center + Vector3.new(0, 30, -half + 6), "BRAINROT VS BRAINROT", 120, 16).TextColor3 = Color3.fromRGB(255, 220, 60)

	-- A pad, a statue and a name for each brainrot, in a row along the back.
	local pads = {}
	for index, brainrot in Brainrots.list do
		local x = -54 + (index - 1) * 36
		local pad = b:cylinder(1, 16, center + Vector3.new(x, 0.5, -42), brainrot.color, "BrainrotPad")
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.2
		pad:SetAttribute("Brainrot", brainrot.id)
		table.insert(pads, pad)

		local pedestalTop = 4
		b:block(Vector3.new(8, pedestalTop, 8), center + Vector3.new(x, pedestalTop / 2, -58), PEDESTAL, "Pedestal")
		local statue = Looks.build(brainrot.id, STATUE_SCALE)
		statue.Name = "Statue"
		-- Facing the camera, which looks toward -Z.
		local statueCenter = center + Vector3.new(x, pedestalTop + Config.BALL_SIZE / 2 * STATUE_SCALE, -58)
		Looks.place(statue, CFrame.new(statueCenter) * CFrame.Angles(0, math.pi, 0))
		statue.Parent = b.model
		b:sign(statueCenter + Vector3.new(0, 10, 0), `{brainrot.emoji} {brainrot.name}`, 30, 4)
	end

	-- The green circle where everyone gathers to start.
	local zoneCenter = center + Vector3.new(0, 0, 40)
	local zoneRadius = 14
	local floorGlow = b:cylinder(0.6, zoneRadius * 2, zoneCenter + Vector3.new(0, 0.3, 0), READY, "ReadyPad")
	floorGlow.Material = Enum.Material.Neon
	local column = b:ghost(b:cylinder(20, zoneRadius * 2, zoneCenter + Vector3.new(0, 10.6, 0), READY, "ReadyZone"), 0.88)
	column.Material = Enum.Material.Neon
	local sign = b:sign(zoneCenter + Vector3.new(0, 26, 0), "", 18, 8)

	b:bumper(center + Vector3.new(-45, 0, 15), 8, 6)
	b:bumper(center + Vector3.new(45, 0, 15), 8, 6)

	local rng = Random.new()
	return {
		model = b:build(),
		pads = pads,
		zoneCenter = zoneCenter,
		zoneRadius = zoneRadius,
		sign = sign,
		spawnPoint = function()
			return center + Vector3.new(rng:NextNumber(-12, 12), 5, rng:NextNumber(-8, 12))
		end,
	}
end

return Lobby
