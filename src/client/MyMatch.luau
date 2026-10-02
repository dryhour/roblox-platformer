local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Finds the local player's match from the attributes MatchService sets (see its header).
local MyMatch = {}

local player = Players.LocalPlayer

-- The arena model of the match you're in, if any.
function MyMatch.arena(): Model?
	local id = player:GetAttribute("MatchId")
	local arenas = workspace:FindFirstChild("Arenas")
	if typeof(id) ~= "string" or id == "" or not arenas then
		return nil
	end
	local arena = arenas:FindFirstChild(id)
	return if arena and arena:IsA("Model") then arena else nil
end

-- The arena's State, whose attributes describe the match.
function MyMatch.state(): Configuration?
	local arena = MyMatch.arena()
	local state = arena and arena:FindFirstChild("State")
	return if state and state:IsA("Configuration") then state else nil
end

-- Where your arena is and which way its front faces (toward you), once you're in a match.
function MyMatch.frame(): (Vector3?, Vector3?)
	local arena = MyMatch.arena()
	local center = arena and arena:GetAttribute("Center")
	local facing = arena and arena:GetAttribute("Facing")
	if typeof(center) == "Vector3" and typeof(facing) == "Vector3" then
		return center, facing
	end
	return nil, nil
end

-- The side of the station square you're standing in while waiting for a match, or "".
function MyMatch.waitingSide(): string
	local side = player:GetAttribute("WaitingSide")
	return if typeof(side) == "string" then side else ""
end

function MyMatch.side(): string
	local side = player:GetAttribute("Side")
	return if typeof(side) == "string" then side else ""
end

function MyMatch.phase(): string
	local state = MyMatch.state()
	local phase = state and state:GetAttribute("Phase")
	return if typeof(phase) == "string" then phase else ""
end

-- Seconds left in the current phase.
function MyMatch.timeLeft(): number
	local state = MyMatch.state()
	local endsAt = state and state:GetAttribute("EndsAt")
	return if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
end

-- The balls in your arena.
function MyMatch.balls(): { Model }
	local arena = MyMatch.arena()
	local found = {}
	if arena then
		for _, ball in CollectionService:GetTagged("Ball") do
			if ball:IsA("Model") and ball:IsDescendantOf(arena) then
				table.insert(found, ball)
			end
		end
	end
	return found
end

-- Your ball, once it's in the arena.
function MyMatch.myBall(): Model?
	for _, ball in MyMatch.balls() do
		if ball:GetAttribute("Side") == MyMatch.side() then
			return ball
		end
	end
	return nil
end

return MyMatch
