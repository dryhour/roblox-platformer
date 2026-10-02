local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- The game's RemoteEvents. The server creates them when it starts, rather than
-- default.project.json, so they always match the code even if a Rojo sync misses them.
--   Draft   client -> server  (ballId)                  pick a ball during the draft
--   Aim     client -> server  (direction, locked)       where to launch during aiming
--   Effect  server -> client  (kind, position, ...)     hits, damage numbers, knockouts...

local NAMES = { "Draft", "Aim", "Effect" }

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

return {
	Draft = folder:WaitForChild("Draft") :: RemoteEvent,
	Aim = folder:WaitForChild("Aim") :: RemoteEvent,
	Effect = folder:WaitForChild("Effect") :: RemoteEvent,
}
