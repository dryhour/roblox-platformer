local Debris = game:GetService("Debris")

local Builder = require(script.Parent.Builder)

-- The arena for Last Brainrot Standing: a round floor of tiles floating over the void. After a
-- short grace period the edge crumbles inward, ring by ring. Tiles about to fall turn red first.
local Arena = {}

export type Arena = {
	model: Model,
	killY: number, -- balls below this are out
	spawnPoints: (count: number) -> { Vector3 },
	update: (elapsed: number) -> (), -- crumbles the edge; call with seconds since GO
	destroy: () -> (),
}

local RADIUS = 60
local TILE = 10
local FINAL_RADIUS = 16
local GRACE = 10 -- seconds before the edge starts crumbling
local SHRINK_END = 90 -- seconds after GO when it reaches FINAL_RADIUS
local WARN_AHEAD = 8 -- tiles turn red this many studs before the edge reaches them
local FALL_TIME = 3
local KILL_DEPTH = 40
local SPAWN_RADIUS = 38

local TILE_A = Color3.fromRGB(120, 70, 210)
local TILE_B = Color3.fromRGB(40, 190, 210)
local WARNING = Color3.fromRGB(255, 60, 60)

type Piece = { parts: { BasePart }, distance: number, state: "solid" | "warning" | "gone" }

function Arena.build(center: Vector3): Arena
	local b = Builder.new("Arena")
	local pieces: { Piece } = {}

	local cells = RADIUS // TILE
	for gx = -cells, cells - 1 do
		for gz = -cells, cells - 1 do
			local offset = Vector3.new((gx + 0.5) * TILE, 0, (gz + 0.5) * TILE)
			local distance = offset.Magnitude
			if distance <= RADIUS - TILE / 2 then
				local color = if (gx + gz) % 2 == 0 then TILE_A else TILE_B
				local tile = b:block(Vector3.new(TILE, 4, TILE), center + offset - Vector3.new(0, 2, 0), color, "Tile")
				table.insert(pieces, { parts = { tile }, distance = distance, state = "solid" })
			end
		end
	end

	for i = 0, 2 do
		local angle = math.rad(90 + i * 120)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 26
		local bumper = b:bumper(center + offset, 7, 6)
		table.insert(pieces, { parts = { bumper }, distance = offset.Magnitude, state = "solid" })
	end

	-- A glow far below, so the void reads as a drop.
	local glow = b:ghost(b:cylinder(2, RADIUS * 4, center - Vector3.new(0, 120, 0), Color3.fromRGB(90, 30, 160), "Void"), 0.3)
	glow.Material = Enum.Material.Neon

	local model = b:build()

	local function update(elapsed: number)
		local progress = math.clamp((elapsed - GRACE) / (SHRINK_END - GRACE), 0, 1)
		local radius = RADIUS + (FINAL_RADIUS - RADIUS) * progress
		for _, piece in pieces do
			local outer = piece.distance + TILE / 2
			if piece.state ~= "gone" and outer > radius then
				piece.state = "gone"
				for _, part in piece.parts do
					part.CanCollide = false
					part.Anchored = false
					Debris:AddItem(part, FALL_TIME)
				end
			elseif piece.state == "solid" and outer > radius + WARN_AHEAD then
				piece.state = "warning"
				for _, part in piece.parts do
					part.Color = WARNING
					part.Material = Enum.Material.Neon
				end
			end
		end
	end

	return {
		model = model,
		killY = center.Y - KILL_DEPTH,
		spawnPoints = function(count)
			local points = {}
			for i = 1, count do
				local angle = (i - 1) / math.max(count, 1) * math.pi * 2
				table.insert(points, center + Vector3.new(math.cos(angle) * SPAWN_RADIUS, 5, math.sin(angle) * SPAWN_RADIUS))
			end
			return points
		end,
		update = update,
		destroy = function()
			model:Destroy()
		end,
	}
end

return Arena
