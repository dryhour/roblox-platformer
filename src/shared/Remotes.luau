local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- The game's remotes. The server creates them when it starts, rather than default.project.json,
-- so they always match the code even if a Rojo sync misses them.
--   Draft    client -> server  (ballId)                 pick a ball during the draft
--   Aim      client -> server  (direction, locked)      where to launch during aiming
--   Effect   server -> client  (kind, position, ...)    hits, damage numbers, knockouts...
--   Action   client -> server  (name, ...) -> result    everything else: shop, quests, trading...
--   Profile  server -> client  (data)                   your saved data changed
--   Notify   server -> client  (kind, data)             reward rolls and "Receive" popups
--   Trade    server -> client  (kind, data)             trade requests and the open trade

local EVENTS = { "Draft", "Aim", "Effect", "Profile", "Notify", "Trade" }
local FUNCTIONS = { "Action" }

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	for _, list in { { EVENTS, "RemoteEvent" }, { FUNCTIONS, "RemoteFunction" } } do
		for _, name in list[1] do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new(list[2])
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

return {
	Draft = folder:WaitForChild("Draft") :: RemoteEvent,
	Aim = folder:WaitForChild("Aim") :: RemoteEvent,
	Effect = folder:WaitForChild("Effect") :: RemoteEvent,
	Profile = folder:WaitForChild("Profile") :: RemoteEvent,
	Notify = folder:WaitForChild("Notify") :: RemoteEvent,
	Trade = folder:WaitForChild("Trade") :: RemoteEvent,
	Action = folder:WaitForChild("Action") :: RemoteFunction,
}
