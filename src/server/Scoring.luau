local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Scoring = {}

-- Points for finishing in `place`. Places past the end of the table get its last entry.
function Scoring.forPlace(place: number): number
	local points = Config.PLACEMENT_POINTS
	return points[math.min(place, #points)]
end

-- Ranks players by score, highest first. Tied players share the better place (1st, 1st, 3rd...).
function Scoring.places(scores: { [Player]: number }): { [Player]: number }
	local places = {}
	for player, score in scores do
		local place = 1
		for _, other in scores do
			if other > score then
				place += 1
			end
		end
		places[player] = place
	end
	return places
end

return Scoring
