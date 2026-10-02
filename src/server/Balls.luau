local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Looks = require(script.Parent.Looks)

-- Players are balls, not humanoid characters. Each ball is a Model in workspace.Balls with:
--   * Core: an invisible physics sphere, simulated by its player's client (network ownership)
--   * Look: the brainrot's parts, which clients move to follow Core
-- and UserId and Brainrot attributes.
local Balls = {}

local folder = Instance.new("Folder")
folder.Name = "Balls"
folder.Parent = workspace

local byPlayer: { [Player]: Model } = {}
local lastSafe: { [Player]: Vector3 } = {}

Players.CharacterAutoLoads = false

local function physicsFor(id: string): PhysicalProperties
	local class = Brainrots.classOf(id)
	return PhysicalProperties.new(class.density, 0.4, class.elasticity, 1, 1)
end

local function addNameTag(body: BasePart, text: string)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(220, 26)
	tag.StudsOffset = Vector3.new(0, Config.BALL_SIZE * 0.8, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 17
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = tag

	tag.Parent = body
end

local function addTrail(body: BasePart, color: Color3)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, Config.BALL_SIZE * 0.3, 0)
	top.Parent = body
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -Config.BALL_SIZE * 0.3, 0)
	bottom.Parent = body

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.35
	trail.LightEmission = 0.5
	trail.Parent = body
end

-- Gives the ball the look and physics of a brainrot.
local function dress(model: Model, player: Player, id: string)
	local brainrot = Brainrots.get(id)
	local old = model:FindFirstChild("Look")
	if old then
		old:Destroy()
	end
	local core = model.PrimaryPart :: BasePart
	local look = Looks.build(brainrot.id)
	Looks.place(look, CFrame.new(core.Position))
	local body = look:FindFirstChild("Body") :: BasePart
	addNameTag(body, `{brainrot.emoji} {player.DisplayName}`)
	addTrail(body, brainrot.color)
	look.Parent = model

	core.CustomPhysicalProperties = physicsFor(brainrot.id)
	model:SetAttribute("Brainrot", brainrot.id)
end

function Balls.get(player: Player): Model?
	return byPlayer[player]
end

-- The ball's physics sphere, if the player has a ball.
function Balls.core(player: Player): BasePart?
	local model = byPlayer[player]
	return model and model.PrimaryPart
end

-- Every player who has a ball, and their ball.
function Balls.all(): { [Player]: Model }
	return byPlayer
end

function Balls.despawn(player: Player)
	local model = byPlayer[player]
	if model then
		model:Destroy()
	end
	byPlayer[player] = nil
	lastSafe[player] = nil
end

-- Gives the player a new ball at `position`, as their chosen brainrot. Frozen balls stay put
-- until Balls.setFrozen(player, false).
function Balls.spawn(player: Player, position: Vector3, frozen: boolean?): Model
	Balls.despawn(player)

	local model = Instance.new("Model")
	model.Name = player.Name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("UserId", player.UserId)

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * Config.BALL_SIZE
	core.Transparency = 1
	core.Position = position
	core.Anchored = frozen == true
	core.Parent = model
	model.PrimaryPart = core

	dress(model, player, Brainrots.get(player:GetAttribute("Brainrot")).id)
	model.Parent = folder
	-- The player's own client simulates their ball, so it responds instantly.
	if not core.Anchored then
		core:SetNetworkOwner(player)
	end

	byPlayer[player] = model
	lastSafe[player] = position
	return model
end

function Balls.setFrozen(player: Player, frozen: boolean)
	local core = Balls.core(player)
	if core then
		core.Anchored = frozen
		if not frozen then
			core:SetNetworkOwner(player)
		end
	end
end

-- Switches the player to a different brainrot, changing their ball in place if they have one.
function Balls.setBrainrot(player: Player, id: string)
	player:SetAttribute("Brainrot", id)
	local model = byPlayer[player]
	if model then
		dress(model, player, id)
	end
end

Players.PlayerRemoving:Connect(Balls.despawn)

-- Basic movement validation: clients simulate their own balls, so a ball moving impossibly fast
-- is put back where it last was.
RunService.Heartbeat:Connect(function()
	for player, model in byPlayer do
		local core = model.PrimaryPart
		if core and not core.Anchored then
			if core.AssemblyLinearVelocity.Magnitude > Config.MAX_LEGIT_SPEED then
				model:PivotTo(CFrame.new(lastSafe[player]))
			else
				lastSafe[player] = core.Position
			end
		end
	end
end)

return Balls
