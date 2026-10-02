local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Looks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Looks"))
local Widgets = require(script.Parent.Widgets)

-- A small 3D picture of a brainrot ball, turning slowly, for the draft cards and the HUD.
local BallIcon = {}

local SPIN_SPEED = 1 -- radians per second

export type BallIcon = {
	frame: ViewportFrame,
	set: (id: string?) -> (), -- shows this ball, or nothing for nil or ""
	spin: () -> (), -- call every frame
}

function BallIcon.new(props: { [string]: any }): BallIcon
	local viewport = Widgets.create("ViewportFrame", {
		BackgroundTransparency = 1,
		LightDirection = Vector3.new(-1, -1, -1),
		Ambient = Color3.fromRGB(170, 170, 180),
	})
	for key, value in props do
		if key ~= "Parent" then
			(viewport :: any)[key] = value
		end
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	-- Looks face -Z, so the camera sits in front at -Z.
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 3, -19), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = props.Parent

	local look: Model? = nil
	local shown = ""

	local function set(id: string?)
		id = id or ""
		if id == shown then
			return
		end
		shown = id :: string
		if look then
			look:Destroy()
			look = nil
		end
		if shown ~= "" then
			local newLook = Looks.build(shown, 1)
			Looks.place(newLook, CFrame.new())
			newLook.Parent = viewport
			look = newLook
		end
	end

	local function spin()
		if look then
			Looks.place(look, CFrame.Angles(0, os.clock() * SPIN_SPEED, 0))
		end
	end

	return { frame = viewport, set = set, spin = spin }
end

return BallIcon
