local Players = game:GetService("Players")

-- The bot's body: a default R15 avatar in grey metal. It stands in for a player who never came,
-- after someone waits alone at a station for a while.
local Robot = {}

local METAL = Color3.fromRGB(120, 130, 145)
local DARK = Color3.fromRGB(70, 75, 90)

local template: Model? = nil

local function build(): Model
	local ok, robot = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = DARK
		description.TorsoColor = METAL
		description.LeftArmColor = METAL
		description.RightArmColor = METAL
		description.LeftLegColor = DARK
		description.RightLegColor = DARK
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		-- Avatar loading can fail (e.g. offline in Studio); a box robot will do.
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Transparency = 1
		root.Parent = model
		local body = Instance.new("Part")
		body.Name = "Head"
		body.Size = Vector3.new(3, 5, 1.5)
		body.Color = METAL
		body.CFrame = root.CFrame * CFrame.new(0, -0.5, 0)
		body.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = body
		weld.Parent = root
		model.PrimaryPart = root
		robot = model
	end
	robot.Name = "🤖"
	local humanoid = robot:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, part in robot:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.Metal
		end
	end
	local root = robot:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	return robot
end

-- Builds the robot ahead of time; loading its avatar can take a moment.
function Robot.preload()
	if not template then
		template = build()
	end
end

-- A new robot, not yet in the world. Its root is anchored.
function Robot.new(): Model
	Robot.preload()
	return (template :: Model):Clone()
end

return Robot
