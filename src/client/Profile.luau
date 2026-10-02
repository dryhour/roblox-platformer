local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

-- Your saved data, as the server last sent it (see src/server/Data.luau for the fields), and
-- this visit's session. Read-only here: change things by asking the server through Action.
local Profile = {}

local data: any = nil
local session: any = nil
local changed = Instance.new("BindableEvent")

-- Fires whenever your data changes.
Profile.changed = changed.Event

function Profile.get(): any
	return data
end

function Profile.session(): any
	return session
end

-- A setting's value, true until your data arrives.
function Profile.setting(name: string): boolean
	return not data or data.settings[name] ~= false
end

local function receive(view: any)
	if typeof(view) == "table" and view.profile then
		data = view.profile
		session = view.session
		changed:Fire(data)
	end
end

function Profile.start()
	Remotes.Profile.OnClientEvent:Connect(receive)
	task.spawn(function()
		local ok, success, view = pcall(Remotes.Action.InvokeServer, Remotes.Action, "GetProfile")
		if ok and success and not data then
			receive(view)
		end
	end)
end

return Profile
