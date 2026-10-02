local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Looks = require(ReplicatedStorage.Shared.Looks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)

-- Things on players' avatars that everyone can see: the equipped flyer, welded under their feet
-- (it holds them up a little higher; the client plays a sitting pose), and stickers that pop up
-- over their heads.
local Avatars = {}

local STICKER_TIME = 2.5
local STICKER_COOLDOWN = 1

local lastSticker: { [Player]: number } = {}

-- Puts the player's equipped flyer on their current avatar, replacing any old one.
function Avatars.refreshFlyer(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local profile = Data.get(player)
	if not character or not humanoid or not root or not root:IsA("BasePart") or not profile then
		return
	end
	local old = character:FindFirstChild("Flyer")
	if old then
		old:Destroy()
	end
	local baseHipHeight = humanoid:GetAttribute("BaseHipHeight")
	if typeof(baseHipHeight) ~= "number" then
		baseHipHeight = humanoid.HipHeight
		humanoid:SetAttribute("BaseHipHeight", baseHipHeight)
	end

	local flyer = Cosmetics.flyer(profile.flyer)
	if not flyer then
		humanoid.HipHeight = baseHipHeight
		return
	end
	local model = Looks.fromParts(flyer.parts, 1)
	model.Name = "Flyer"
	-- The flyer's top goes where the feet are; raising HipHeight lifts the avatar onto it.
	local feet = root.CFrame * CFrame.new(0, -(baseHipHeight + root.Size.Y / 2), 0)
	Looks.place(model, feet)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
			part.Massless = true
		end
	end
	model.Parent = character
	humanoid.HipHeight = baseHipHeight + Cosmetics.FLYER_LIFT
end

-- Shows sticker number `index` over the player's head for a moment.
function Avatars.sticker(player: Player, index: unknown): boolean
	local emoji = if typeof(index) == "number" then Economy.STICKERS[index] else nil
	local head = player.Character and player.Character:FindFirstChild("Head")
	local now = os.clock()
	if not emoji or not head or now - (lastSticker[player] or 0) < STICKER_COOLDOWN then
		return false
	end
	lastSticker[player] = now
	local old = head:FindFirstChild("Sticker")
	if old then
		old:Destroy()
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sticker"
	billboard.Size = UDim2.fromScale(3, 3)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = emoji
	label.Parent = billboard
	billboard.Parent = head
	Debris:AddItem(billboard, STICKER_TIME)
	Remotes.Effect:FireAllClients("Sticker", (head :: BasePart).Position)
	return true
end

function Avatars.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			if player.Character == character then
				Avatars.refreshFlyer(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Data.loaded:Connect(Avatars.refreshFlyer)
	Players.PlayerRemoving:Connect(function(player)
		lastSticker[player] = nil
	end)
end

return Avatars
