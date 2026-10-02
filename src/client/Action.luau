local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

-- Asks the server to do something (see src/server/Actions.luau for the list). Yields until it
-- answers, so UI calls it from task.spawn.
local Action = {}

function Action.call(name: string, ...: any): (boolean, any)
	local ok, result, message = pcall(Remotes.Action.InvokeServer, Remotes.Action, name, ...)
	if not ok then
		warn(`Action {name} failed: {result}`)
		return false, nil
	end
	return result == true, message
end

-- Fires an action without waiting for the answer.
function Action.send(name: string, ...: any)
	task.spawn(Action.call, name, ...)
end

return Action
