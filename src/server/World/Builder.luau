local CollectionService = game:GetService("CollectionService")

-- Helpers for building the lobby and arenas in code.
local Builder = {}
Builder.__index = Builder

export type Builder = typeof(setmetatable({} :: { model: Model }, Builder))

function Builder.new(name: string): Builder
	local model = Instance.new("Model")
	model.Name = name
	-- Keep the whole thing loaded on every client even if the place uses streaming.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	return setmetatable({ model = model }, Builder)
end

-- A solid, anchored box centered at `position`.
function Builder.block(self: Builder, size: Vector3, position: Vector3, color: Color3, name: string?): Part
	local part = Instance.new("Part")
	part.Name = name or "Block"
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = self.model
	return part
end

-- An upright cylinder centered at `position`.
function Builder.cylinder(self: Builder, height: number, diameter: number, position: Vector3, color: Color3, name: string?): Part
	local part = self:block(Vector3.new(height, diameter, diameter), position, color, name)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	return part
end

-- Not solid, and invisible to raycasts and touches: for glows, zones and sign holders.
function Builder.ghost(_self: Builder, part: BasePart, transparency: number): BasePart
	part.Transparency = transparency
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- A pinball bumper standing on the ground at `position`. Combat bounces balls off anything
-- tagged "Bumper" with Radius and Height attributes.
function Builder.bumper(self: Builder, position: Vector3, diameter: number, height: number): Part
	local bumper = self:cylinder(height, diameter, position + Vector3.new(0, height / 2, 0), Color3.fromRGB(255, 70, 200), "Bumper")
	bumper.Material = Enum.Material.Neon
	bumper:SetAttribute("Radius", diameter / 2)
	bumper:SetAttribute("Height", height)
	CollectionService:AddTag(bumper, "Bumper")
	return bumper
end

-- A label floating at `position`, sized in studs so it scales with the world. Prefer icons and
-- numbers over words (see CLAUDE.md).
function Builder.sign(self: Builder, position: Vector3, text: string, width: number, height: number): TextLabel
	local holder = self:ghost(self:block(Vector3.one, position, Color3.new(), "Sign"), 1)

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(width, height)
	sign.LightInfluence = 0
	sign.MaxDistance = 400

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = sign

	sign.Parent = holder
	return label
end

function Builder.build(self: Builder): Model
	self.model.Parent = workspace
	return self.model
end

return Builder
