-- Leftovers from Roblox's Baseplate template, or the map from an older version of this project,
-- would sit in the middle of the lobby.
for _, name in { "Baseplate", "SpawnLocation", "Map" } do
	local leftover = workspace:FindFirstChild(name)
	if leftover then
		leftover:Destroy()
	end
end

require(script.Combat)
require(script.Round).start()
