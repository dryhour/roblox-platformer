local Brainrots = require(script.Parent.Brainrots)
local Config = require(script.Parent.Config)

-- Builds models from part lists (see Brainrots.PartSpec): brainrot looks, and cosmetics like
-- flyers. Parts are anchored and not solid; each stores where it sits relative to the model's
-- center in an Offset attribute. In a battle, clients move a ball's look every frame to follow
-- it; statues, cards and flyers are placed with Looks.place. Used by both the server and clients.
local Looks = {}

local function makePart(spec: Brainrots.PartSpec, scale: number): BasePart
	local part: BasePart
	if spec.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		basic.Shape = (Enum.PartType :: any)[spec.shape]
		part = basic
	end
	part.Size = spec.size * scale
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true

	local rotate = spec.rotate or Vector3.zero
	local offset = CFrame.new(spec.at * scale)
		* CFrame.fromOrientation(math.rad(rotate.X), math.rad(rotate.Y), math.rad(rotate.Z))
	part:SetAttribute("Offset", offset)
	if spec.spin then
		part:SetAttribute("Spin", spec.spin)
	end
	return part
end

-- A Model with a part for each spec, at `scale`. The first part is named "Body".
function Looks.fromParts(specs: { Brainrots.PartSpec }, scale: number): Model
	local model = Instance.new("Model")
	for index, spec in specs do
		local part = makePart(spec, scale)
		part.Name = if index == 1 then "Body" else "Part"
		part.Parent = model
	end
	return model
end

-- A Model named "Look" with the brainrot's parts. `scale` is relative to Brainrots.DESIGN_SIZE;
-- leave it out to fit a ball Config.BALL_SIZE across.
function Looks.build(id: string, scale: number?): Model
	local brainrot = Brainrots.get(id)
	local model = Looks.fromParts(brainrot.look, scale or Config.BALL_SIZE / Brainrots.DESIGN_SIZE)
	model.Name = "Look"
	model:SetAttribute("Brainrot", brainrot.id)
	return model
end

-- Puts every part of a look in place around `center`.
function Looks.place(look: Instance, center: CFrame)
	for _, part in look:GetChildren() do
		local offset = part:GetAttribute("Offset")
		if part:IsA("BasePart") and typeof(offset) == "CFrame" then
			part.CFrame = center * offset
		end
	end
end

return Looks
