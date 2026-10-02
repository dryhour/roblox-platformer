local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)

-- Builds a brainrot's look from its part list (see Brainrots). Look parts are anchored and not
-- solid; each stores where it sits relative to the look's center in an Offset attribute.
-- For balls, clients move the parts every frame to follow the physics sphere (see the client's
-- Visuals module); lobby statues are placed once with Looks.place.
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

-- A folder named "Look" with the brainrot's parts. The first one is named "Body".
function Looks.build(id: string, scale: number?): Folder
	local brainrot = Brainrots.get(id)
	local folder = Instance.new("Folder")
	folder.Name = "Look"
	folder:SetAttribute("Brainrot", brainrot.id)
	for index, spec in brainrot.look do
		local part = makePart(spec, scale or 1)
		part.Name = if index == 1 then "Body" else "Part"
		part.Parent = folder
	end
	return folder
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
