local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.Builder)

-- A station's arena: an upright square box (Config.ARENA_SIZE inside) that the balls bounce
-- around in, like a screen standing on its edge, watched from the front. Every lobby station
-- has one, in workspace.Arenas. During sudden death the walls move in and turn red.
--
-- The model holds:
--   Walls     the four walls, each with IsArenaWall and Normal (pointing into the arena)
--   Effects   parts that abilities create (turrets, bananas, vines...)
--   State     a Configuration whose attributes tell clients how the match is going
-- and the attributes Center (the middle of the box), Facing (out of the front, toward the
-- players watching) and HalfWidth (from the middle to the inside of the walls).
local Arena = {}

export type Arena = {
	model: Model,
	state: Configuration,
	walls: Folder,
	effects: Folder,
	backdrop: Part, -- the back of the box; Station puts the VS screen on it
	cframe: CFrame, -- at the center, looking into the box, so RightVector is the watchers' right
	center: Vector3,
	facing: Vector3,
	halfWidth: () -> number,
	setHalfWidth: (number) -> (), -- moves the walls
	setDanger: (boolean) -> (), -- shows the walls in red for sudden death
	spawn: (side: string) -> (Vector3, Vector3), -- a ball's starting position and forward
}

local FRAME = 2 -- thickness of the frame around the box
local DEPTH = Config.BALL_SIZE * 1.6 + 1 -- front to back, with room for a fully grown ball
local BEVEL = 2.5 -- how far the frame sticks out past the front
local WALL_THICKNESS = 2

local FRAME_COLOR = Color3.fromRGB(24, 32, 60)
local BACKDROP = Color3.fromRGB(36, 48, 84)
local DANGER = Color3.fromRGB(255, 50, 70)

local folder = Instance.new("Folder")
folder.Name = "Arenas"
folder.Parent = workspace

-- Builds an arena named `id` centered at `cframe`, which looks into the box.
function Arena.build(id: string, cframe: CFrame): Arena
	local b = Builder.new(id)
	local defaultHalf = Config.ARENA_SIZE / 2
	local outer = Config.ARENA_SIZE + FRAME * 2

	-- Local +Z points out of the front, toward the players.
	local backdrop = b:box(Vector3.new(outer, outer, 1), cframe * CFrame.new(0, 0, -DEPTH / 2 - 0.5), BACKDROP, "Backdrop")

	-- The frame sits just outside the walls' starting place, so the walls hide inside it until
	-- sudden death pulls them in.
	local frameDepth = DEPTH + 1 + BEVEL
	local frameZ = (BEVEL - 1) / 2
	local frameOffset = defaultHalf + 0.05 + FRAME / 2
	for _, along in { Vector3.xAxis, Vector3.yAxis } do
		local across = Vector3.one - along - Vector3.zAxis
		for _, sign in { 1, -1 } do
			local size = along * outer + across * FRAME + Vector3.new(0, 0, frameDepth)
			b:box(size, cframe * CFrame.new(across * sign * frameOffset + Vector3.new(0, 0, frameZ)), FRAME_COLOR, "Frame")
		end
	end

	-- An invisible front so nothing gets in or out.
	local glass = b:box(Vector3.new(outer, outer, 0.5), cframe * CFrame.new(0, 0, DEPTH / 2 + 0.25), FRAME_COLOR, "Glass")
	b:ghost(glass, 1)
	glass.CanCollide = true

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = b.model
	-- Each wall's direction from the center, in the arena's own space.
	local sides = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis }
	local wallParts: { { side: Vector3, wall: Part } } = {}
	for _, side in sides do
		local wall = b:box(Vector3.one, cframe, DANGER, "Wall", walls)
		wall.Material = Enum.Material.Neon
		wall.Transparency = 1
		wall.CastShadow = false
		wall:SetAttribute("IsArenaWall", true)
		wall:SetAttribute("Normal", cframe:VectorToWorldSpace(-side))
		table.insert(wallParts, { side = side, wall = wall })
	end

	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = b.model

	local state = Instance.new("Configuration")
	state.Name = "State"
	state.Parent = b.model

	local facing = -cframe.LookVector
	b.model:SetAttribute("Center", cframe.Position)
	b.model:SetAttribute("Facing", facing)
	local model = b:build(folder)

	local half = defaultHalf
	local function setHalfWidth(newHalf: number)
		half = newHalf
		model:SetAttribute("HalfWidth", half)
		local length = half * 2 + WALL_THICKNESS * 2
		for _, entry in wallParts do
			local across = entry.side:Abs()
			local along = Vector3.new(across.Y, across.X, 0)
			entry.wall.Size = across * WALL_THICKNESS + along * length + Vector3.new(0, 0, DEPTH)
			entry.wall.CFrame = cframe * CFrame.new(entry.side * (half + WALL_THICKNESS / 2))
		end
	end
	setHalfWidth(defaultHalf)

	return {
		model = model,
		state = state,
		walls = walls,
		effects = effects,
		backdrop = backdrop,
		cframe = cframe,
		center = cframe.Position,
		facing = facing,
		halfWidth = function()
			return half
		end,
		setHalfWidth = setHalfWidth,
		setDanger = function(danger: boolean)
			for _, entry in wallParts do
				entry.wall.Transparency = if danger then 0.15 else 1
			end
		end,
		spawn = function(side: string)
			local direction = if side == "Left" then 1 else -1
			local right = cframe.RightVector
			return cframe.Position - right * direction * defaultHalf * 0.6, right * direction
		end,
	}
end

return Arena
