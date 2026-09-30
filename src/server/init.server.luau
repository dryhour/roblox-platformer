local Players = game:GetService("Players")

-- The game is played on the Z = 0 plane; the camera looks at it from +Z.
-- A PlaneConstraint keeps each character on that plane, so it can only move left/right and up/down.
local planeAnchor = Instance.new("Attachment")
planeAnchor.Name = "PlaneAnchor"
planeAnchor.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis) -- primary axis = plane normal (Z)
planeAnchor.Parent = workspace.Terrain

local function onCharacterAdded(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	local attachment = Instance.new("Attachment")
	attachment.Name = "Attachment2D"
	attachment.Parent = root

	local plane = Instance.new("PlaneConstraint")
	plane.Attachment0 = planeAnchor
	plane.Attachment1 = attachment
	plane.Parent = root

	-- Holds the block upright and facing exactly left or right. The client flips
	-- its CFrame when the player changes direction; this starts it facing right (+X).
	local facing = Instance.new("AlignOrientation")
	facing.Name = "Facing"
	facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facing.Attachment0 = attachment
	facing.RigidityEnabled = true
	facing.CFrame = CFrame.lookAt(Vector3.zero, Vector3.xAxis)
	facing.Parent = root
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
