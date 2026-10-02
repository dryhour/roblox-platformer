-- Helpers for building maps in code. Everything sits on the Z = 0 play plane, and blocks are
-- given by their edges: x1/x2 are left/right, y1/y2 are bottom/top.
local Builder = {}
Builder.__index = Builder

-- How thick solid parts are along Z, toward the camera.
local DEPTH = 10

export type Builder = typeof(setmetatable({} :: { model: Model }, Builder))

function Builder.new(): Builder
	return setmetatable({ model = Instance.new("Model") }, Builder)
end

-- A solid, anchored block.
function Builder.block(self: Builder, x1: number, y1: number, x2: number, y2: number, color: Color3, name: string?): Part
	local part = Instance.new("Part")
	part.Name = name or "Block"
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Size = Vector3.new(x2 - x1, y2 - y1, DEPTH)
	part.Position = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, 0)
	part.Parent = self.model
	return part
end

-- A 1-stud-thick platform whose top is at `top`.
function Builder.platform(self: Builder, x1: number, x2: number, top: number, color: Color3): Part
	return self:block(x1, top - 1, x2, top, color, "Platform")
end

-- An invisible wall that keeps players in bounds.
function Builder.wall(self: Builder, x1: number, y1: number, x2: number, y2: number): Part
	local part = self:block(x1, y1, x2, y2, Color3.new(), "Wall")
	part.Transparency = 1
	part.CastShadow = false
	return part
end

-- Kills players who touch it.
function Builder.hazard(self: Builder, x1: number, y1: number, x2: number, y2: number): Part
	local part = self:block(x1, y1, x2, y2, Color3.fromRGB(255, 85, 30), "Hazard")
	part.Material = Enum.Material.Neon
	return part
end

-- A platform that gives way shortly after a player touches it, then comes back.
function Builder.crumbling(self: Builder, x1: number, x2: number, top: number): Part
	return self:block(x1, top - 1, x2, top, Color3.fromRGB(235, 165, 60), "FallingPlatform")
end

-- Makes a part slide back and forth between where it is and `offset` away, over `period`
-- seconds. Clients move it, so it's smooth for the player riding it. `phase` (radians) offsets
-- it from other moving parts.
function Builder.move(_self: Builder, part: BasePart, offset: Vector3, period: number, phase: number?)
	part:SetAttribute("MoveOffset", offset)
	part:SetAttribute("MovePeriod", period)
	part:SetAttribute("MovePhase", phase or 0)
end

-- A pad that launches players straight up at `power` studs per second.
function Builder.jumpPad(self: Builder, x1: number, x2: number, y: number, power: number): Part
	local part = self:block(x1, y, x2, y + 0.6, Color3.fromRGB(60, 230, 120), "JumpPad")
	part.Material = Enum.Material.Neon
	part:SetAttribute("Power", power)
	return part
end

-- A pad that sets players' walk speed to `speed` for `duration` seconds.
function Builder.speedPad(self: Builder, x1: number, x2: number, y: number, speed: number, duration: number): Part
	local part = self:block(x1, y, x2, y + 0.6, Color3.fromRGB(255, 220, 50), "SpeedPad")
	part.Material = Enum.Material.Neon
	part:SetAttribute("Speed", speed)
	part:SetAttribute("Duration", duration)
	return part
end

-- A see-through pole standing on the ground at (x, y). Touching it saves your respawn point.
function Builder.checkpoint(self: Builder, x: number, y: number): Part
	local part = self:block(x - 0.5, y, x + 0.5, y + 14, Color3.fromRGB(120, 230, 255), "Checkpoint")
	part.Material = Enum.Material.Neon
	part.Transparency = 0.5
	part.CanCollide = false
	part.CastShadow = false
	return part
end

-- The finish line for races, standing on the ground at (x, y).
function Builder.finishLine(self: Builder, x: number, y: number): Part
	local part = self:block(x - 1, y, x + 1, y + 30, Color3.fromRGB(70, 230, 120), "Finish")
	part.Material = Enum.Material.Neon
	part.Transparency = 0.4
	part.CanCollide = false
	part.CastShadow = false
	return part
end

-- The backdrop behind the play plane. Not solid, and ignored by raycasts and touches.
function Builder.backdrop(self: Builder, x1: number, y1: number, x2: number, y2: number, color: Color3): Part
	local part = self:block(x1, y1, x2, y2, color, "Backdrop")
	part.Size = Vector3.new(x2 - x1, y2 - y1, 1)
	part.Position = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, -6)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- An invisible marker standing on the ground at (x, y), for spawn points and coin spots.
function Builder.marker(self: Builder, name: string, x: number, y: number): Part
	local part = self:block(x - 2, y, x + 2, y + 1, Color3.new(), name)
	part.Size = Vector3.new(4, 1, 4)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- The part the camera copies. It sits `distance` studs in front of (x, y), looking at the map.
function Builder.camera(self: Builder, x: number, y: number, distance: number): Part
	local part = self:marker("CameraPart", x, y)
	part.Size = Vector3.new(2, 2, 2)
	part.Position = Vector3.new(x, y, distance)
	return part
end

-- Names the finished map and returns it.
function Builder.build(self: Builder, name: string): Model
	self.model.Name = name
	return self.model
end

return Builder
