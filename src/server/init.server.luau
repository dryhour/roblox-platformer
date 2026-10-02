local Match = require(script.Match)

-- Leftovers from Roblox's Baseplate template would sit under the maps and catch players who
-- fall into pits.
for _, name in { "Baseplate", "SpawnLocation" } do
	local leftover = workspace:FindFirstChild(name)
	if leftover then
		leftover:Destroy()
	end
end

Match.start()
