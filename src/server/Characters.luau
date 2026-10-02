local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

-- Player characters: spawning, freezing and killing them, keeping them on the 2D plane, and
-- coloring and labeling them. Characters appear only when the match spawns them, so
-- CharacterAutoLoads is off.
local Characters = {}

-- How long a dead character's pieces stay before they're removed.
local CORPSE_TIME = 3
-- Characters that fall below this height die. A map can set its own with a KillY attribute.
local DEFAULT_KILL_Y = -60

local deathHandler: ((Player) -> ())? = nil

Players.CharacterAutoLoads = false

-- The game is played on the Z = 0 plane; the camera looks at it from +Z.
-- A PlaneConstraint keeps each character on that plane, so it can only move left/right and up/down.
local planeAnchor = Instance.new("Attachment")
planeAnchor.Name = "PlaneAnchor"
planeAnchor.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis) -- primary axis = plane normal (Z)
planeAnchor.Parent = workspace.Terrain

local function colorOf(player: Player): Color3
	return Config.PLAYER_COLORS[player:GetAttribute("ColorIndex") or 1] or Config.PLAYER_COLORS[1]
end

-- Paints the character's body and name tag in the player's chosen color.
function Characters.applyColor(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local color = colorOf(player)
	local body = character:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		body.Color = color
	end
	local label = character:FindFirstChild("NameLabel", true)
	if label and label:IsA("TextLabel") then
		label.TextColor3 = color
	end
end

local function addNameTag(player: Player, root: BasePart)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(200, 24)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextStrokeTransparency = 0.3
	label.Text = player.DisplayName
	label.Parent = tag

	tag.Parent = root
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

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

	addNameTag(player, root)
	Characters.applyColor(player)

	humanoid.Died:Connect(function()
		if deathHandler then
			deathHandler(player)
		end
		task.delay(CORPSE_TIME, function()
			if player.Character == character then
				player.Character = nil
			end
			character:Destroy()
		end)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:GetAttributeChangedSignal("ColorIndex"):Connect(function()
		Characters.applyColor(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- Sets the function called whenever a player's character dies.
function Characters.onDied(handler: (Player) -> ())
	deathHandler = handler
end

-- Gives the player a fresh character standing at `at`.
function Characters.spawn(player: Player, at: CFrame)
	if player.Parent ~= Players then
		return
	end
	-- Loading errors if the player leaves while it runs.
	local ok, err = pcall(player.LoadCharacterAsync, player)
	if not ok then
		warn(`Couldn't spawn {player.Name}: {err}`)
		return
	end
	local character = player.Character
	if character then
		character:PivotTo(at)
	end
end

-- Anchors the character in place, or lets it move again.
function Characters.setFrozen(player: Player, frozen: boolean)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = frozen
	end
end

-- The player's HumanoidRootPart, if their character is alive.
function Characters.root(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Characters.kill(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end

-- The living player whose character `part` belongs to, for Touched handlers.
function Characters.playerFromPart(part: BasePart): Player?
	local character = part.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if player and Characters.root(player) then
		return player
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local map = workspace:FindFirstChild("Map")
	local killY = map and map:GetAttribute("KillY") or DEFAULT_KILL_Y
	for _, player in Players:GetPlayers() do
		local root = Characters.root(player)
		if root and root.Position.Y < killY then
			Characters.kill(player)
		end
	end
end)

return Characters
