-- What each game mode is called, how it's explained to players, and how many players it needs.
-- The server code for each mode is in src/server/Modes.

export type Info = {
	id: string,
	name: string,
	category: string,
	objective: string,
	rules: { string },
	scoring: string,
	minPlayers: number,
	maxPlayers: number,
}

local list: { Info } = {
	{
		id = "BeamAttack",
		name = "Beam Attack",
		category = "Combat",
		objective = "One Attacker hunts everyone else with beams.",
		rules = {
			"Attacker: aim with the mouse and click to fire, or press F to fire the way you're moving.",
			"Beams flash red before they fire. Platforms and walls block them.",
			"Survivors: keep moving and stay out of the line of fire. Shift dashes.",
		},
		scoring = "The Attacker scores for each elimination. Survivors score for time survived, plus a bonus for lasting the whole round.",
		minPlayers = 3,
		maxPlayers = 6,
	},
	{
		id = "PlatformRush",
		name = "Platform Rush",
		category = "Racing",
		objective = "Race to the finish line.",
		rules = {
			"Avoid lava and pits, and don't stand still on orange platforms.",
			"Green pads launch you upward. Yellow pads speed you up.",
			"If you fall, you go back to your last checkpoint.",
			"When the first player finishes, the clock drops to 20 seconds.",
		},
		scoring = "Points by finishing place. Players who don't finish get points for how far they got.",
		minPlayers = 2,
		maxPlayers = 6,
	},
	{
		id = "CoinRush",
		name = "Coin Rush",
		category = "Collection",
		objective = "Grab as many coins as you can.",
		rules = {
			"Yellow coins are worth 1, orange coins 5 and blue coins 10.",
			"The best coins appear in the riskiest spots.",
			"Touching lava sends you back to the start.",
		},
		scoring = "Points by place in total coin value.",
		minPlayers = 2,
		maxPlayers = 6,
	},
}

local byId: { [string]: Info } = {}
for _, info in list do
	byId[info.id] = info
end

return {
	list = list,
	byId = byId,
}
