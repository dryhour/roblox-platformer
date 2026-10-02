local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Config = require(ReplicatedStorage.Shared.Config)
local Looks = require(ReplicatedStorage.Shared.Looks)
local Builder = require(script.Parent.Builder)

-- The lobby, where players walk around as their normal avatars. No menus (see CLAUDE.md):
-- stand on the ⚔️ pad to queue for a 1v1, or on the 🤖 pad to play a bot. Statues of every
-- brainrot ball line the back. MatchService runs the pads.
local Lobby = {}

export type Lobby = {
	duelPad: BasePart,
	botPad: BasePart,
	duelSign: TextLabel,
	spawn: CFrame, -- where players come back to after a match
}

local SIZE = 140
local FLOOR = Color3.fromRGB(45, 35, 80)
local EDGE = Color3.fromRGB(255, 70, 200)
local DUEL = Color3.fromRGB(70, 160, 255)
local BOT = Color3.fromRGB(175, 90, 255)
local PEDESTAL = Color3.fromRGB(30, 25, 55)
local STATUE_SCALE = 1.4

function Lobby.build(): Lobby
	local b = Builder.new("Lobby")
	local half = SIZE / 2

	b:block(Vector3.new(SIZE, 2, SIZE), Vector3.new(0, -1, 0), FLOOR, "Floor")
	for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local length = Vector3.new(math.abs(side.Z), 0, math.abs(side.X)) * SIZE
		local strip = b:block(length + side:Abs() * 1.5 + Vector3.new(0, 0.6, 0), side * half + Vector3.new(0, 0.3, 0), EDGE, "Edge")
		strip.Material = Enum.Material.Neon
		local wall = b:block(length + side:Abs() * 4 + Vector3.new(0, 30, 0), side * (half + 2) + Vector3.new(0, 15, 0), EDGE, "Wall")
		b:ghost(wall, 1)
		wall.CanCollide = true
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(10, 1, 10)
	spawnLocation.Position = Vector3.new(0, 0.5, 30)
	spawnLocation.Color = Color3.fromRGB(70, 60, 120)
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Parent = b.model

	b:sign(Vector3.new(0, 30, -half + 8), "BRAINROT VS BRAINROT", 110, 15).TextColor3 = Color3.fromRGB(255, 220, 60)

	local duelPad = b:cylinder(1, 18, Vector3.new(-22, 0.5, -10), DUEL, "DuelPad")
	duelPad.Material = Enum.Material.Neon
	local duelSign = b:sign(Vector3.new(-22, 10, -10), "⚔️ 0/2", 14, 6)
	local botPad = b:cylinder(1, 18, Vector3.new(22, 0.5, -10), BOT, "BotPad")
	botPad.Material = Enum.Material.Neon
	b:sign(Vector3.new(22, 10, -10), "🤖", 8, 6)

	-- A statue of every brainrot ball along the back.
	local count = #Brainrots.list
	for index, brainrot in Brainrots.list do
		local x = (index - (count + 1) / 2) * 18
		local pedestalTop = 3
		b:block(Vector3.new(8, pedestalTop, 8), Vector3.new(x, pedestalTop / 2, -45), PEDESTAL, "Pedestal")
		local statue = Looks.build(brainrot.id, STATUE_SCALE)
		statue.Name = "Statue"
		local center = Vector3.new(x, pedestalTop + Config.BALL_SIZE / 2 * STATUE_SCALE, -45)
		-- Facing the spawn, toward +Z.
		Looks.place(statue, CFrame.new(center) * CFrame.Angles(0, math.pi, 0))
		statue.Parent = b.model
		local sign = b:sign(center + Vector3.new(0, 8, 0), brainrot.emoji, 4, 4)
		sign.TextStrokeTransparency = 1
	end

	b:build()
	return {
		duelPad = duelPad,
		botPad = botPad,
		duelSign = duelSign,
		spawn = CFrame.new(spawnLocation.Position + Vector3.new(0, 4, 0)),
	}
end

return Lobby
