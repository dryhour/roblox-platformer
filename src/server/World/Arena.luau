local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.Builder)

-- A match's arena: an enclosed glowing box (Config.ARENA_SIZE) with a glass roof. Each match
-- gets its own, side by side, in workspace.Arenas. During sudden death the walls move in.
--
-- The model holds:
--   Walls     the four walls, each with IsArenaWall and Normal (pointing into the arena)
--   Effects   parts that abilities create (turrets, bananas, vines...)
--   State     a Configuration whose attributes tell clients how the match is going
-- and a Center attribute.
local Arena = {}

export type Arena = {
	model: Model,
	state: Configuration,
	walls: Folder,
	effects: Folder,
	center: Vector3, -- on the floor, in the middle
	halfWidth: () -> number,
	setHalfWidth: (number) -> (), -- moves the walls
	setDanger: (boolean) -> (), -- turns the walls red for sudden death
	spawn: (side: string) -> (Vector3, Vector3), -- a ball's starting position and forward
	destroy: () -> (),
}

local ORIGIN = Vector3.new(0, 0, 500)
local SLOT_SPACING = 200
local WALL_THICKNESS = 4

local FLOOR = Color3.fromRGB(28, 26, 44)
local WALL = Color3.fromRGB(90, 200, 255)
local DANGER = Color3.fromRGB(255, 50, 70)

local folder = Instance.new("Folder")
folder.Name = "Arenas"
folder.Parent = workspace

-- Builds arena number `slot` (0, 1, 2...), named `id`.
function Arena.build(id: string, slot: number): Arena
	local b = Builder.new(id)
	local center = ORIGIN + Vector3.new(slot * SLOT_SPACING, 0, 0)
	local size = Config.ARENA_SIZE
	local defaultHalf = size.X / 2
	local outer = size.X + WALL_THICKNESS * 2

	b:block(Vector3.new(outer + 20, 2, outer + 20), center - Vector3.new(0, 1, 0), FLOOR, "Floor")
	local roof = b:block(Vector3.new(outer, 1, outer), center + Vector3.new(0, size.Y + 0.5, 0), WALL, "Roof")
	roof.Material = Enum.Material.Glass
	roof.Transparency = 0.92
	roof.CastShadow = false

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = b.model
	local sides = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
	local wallParts: { { side: Vector3, wall: Part } } = {}
	for _, side in sides do
		local along = Vector3.new(math.abs(side.Z), 0, math.abs(side.X)) * outer
		local wall = b:block(along + side:Abs() * WALL_THICKNESS + Vector3.new(0, size.Y, 0), center, WALL, "Wall", walls)
		wall.Material = Enum.Material.Neon
		-- The wall nearest the camera is see-through so it doesn't hide the action.
		wall.Transparency = if side == Vector3.zAxis then 0.85 else 0.55
		wall.CastShadow = false
		wall:SetAttribute("IsArenaWall", true)
		wall:SetAttribute("Normal", -side)
		table.insert(wallParts, { side = side, wall = wall })
	end

	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = b.model

	local state = Instance.new("Configuration")
	state.Name = "State"
	state.Parent = b.model

	b.model:SetAttribute("Center", center)
	local model = b:build(folder)

	local half = defaultHalf
	local function setHalfWidth(newHalf: number)
		half = newHalf
		for _, entry in wallParts do
			entry.wall.Position = center + entry.side * (half + WALL_THICKNESS / 2) + Vector3.new(0, size.Y / 2, 0)
		end
	end
	setHalfWidth(defaultHalf)

	return {
		model = model,
		state = state,
		walls = walls,
		effects = effects,
		center = center,
		halfWidth = function()
			return half
		end,
		setHalfWidth = setHalfWidth,
		setDanger = function(danger: boolean)
			for _, entry in wallParts do
				entry.wall.Color = if danger then DANGER else WALL
			end
		end,
		spawn = function(side: string)
			local direction = if side == "Left" then 1 else -1
			local position = center + Vector3.new(-direction * defaultHalf * 0.6, Config.BALL_SIZE / 2 + 0.5, 0)
			return position, Vector3.xAxis * direction
		end,
		destroy = function()
			model:Destroy()
		end,
	}
end

return Arena
