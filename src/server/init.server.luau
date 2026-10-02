local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Leftovers from Roblox's Baseplate template or older versions of this project would sit in the
-- middle of the lobby.
for _, name in { "Baseplate", "SpawnLocation", "Map", "Balls" } do
	local leftover = workspace:FindFirstChild(name)
	if leftover then
		leftover:Destroy()
	end
end

-- The first version of this project swapped everyone's avatar for a block character. Players
-- walk around as their own R15 avatars now, so remove it and respawn anyone who got the block.
local starterCharacter = StarterPlayer:FindFirstChild("StarterCharacter")
if starterCharacter then
	warn("Removed StarterPlayer.StarterCharacter, left over from an old version. Delete it from the place in Studio.")
	starterCharacter:Destroy()
	for _, player in Players:GetPlayers() do
		task.spawn(player.LoadCharacter, player)
	end
end

require(ReplicatedStorage.Shared.Remotes) -- creates the remotes

local Actions = require(script.Actions)
local Avatars = require(script.Avatars)
local Data = require(script.Data)
local MatchService = require(script.MatchService)
local Shop = require(script.Shop)
local Trading = require(script.Trading)

Data.start()
Shop.start()
Avatars.start()
Trading.start(MatchService.busy)
MatchService.start(Trading.cancel)
Actions.start()
