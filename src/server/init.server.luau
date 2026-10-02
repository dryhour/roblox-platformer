local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Leftovers from Roblox's Baseplate template or older versions of this project would sit in the
-- middle of the lobby.
for _, name in { "Baseplate", "SpawnLocation", "Map", "Balls" } do
	local leftover = workspace:FindFirstChild(name)
	if leftover then
		leftover:Destroy()
	end
end

require(ReplicatedStorage.Shared.Remotes) -- creates the RemoteEvents
require(script.MatchService).start()
