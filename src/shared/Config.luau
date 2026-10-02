local RunService = game:GetService("RunService")

-- Match rules and tuning shared by the server and clients.
local Config = {}

-- In Studio a match can start with fewer players, and every mode is allowed at any player
-- count, so you can test alone.
Config.TESTING = RunService:IsStudio()

Config.MIN_PLAYERS = if Config.TESTING then 1 else 3
Config.MAX_PLAYERS = 6

-- Seconds spent on each step between games.
Config.LOBBY_COUNTDOWN = 5 -- after everyone is ready
Config.INTRO_TIME = 7 -- rules card before a game
Config.SCOREBOARD_TIME = 8 -- results after a game
Config.FINAL_TIME = 15 -- winner screen
Config.RESPAWN_DELAY = 2

-- Host settings in the lobby. The keys are the attribute names on ReplicatedStorage.MatchState.
Config.Settings = {
	Games = { default = 5, min = 3, max = 10, step = 1 },
	GameTime = { default = 90, min = 30, max = 180, step = 15 },
	Multiplier = { default = 1, min = 1, max = 3, step = 1 },
}

-- How the next game is picked. NoRepeat never plays the same game twice in a row; Weighted
-- makes a game half as likely to come up for each time it has already been played this match.
Config.RANDOMIZATION_OPTIONS = { "NoRepeat", "Random", "Weighted" }
Config.RANDOMIZATION_LABELS = {
	NoRepeat = "No repeats",
	Random = "Fully random",
	Weighted = "Weighted",
}

-- Points for 1st, 2nd, 3rd... in games scored by placement.
Config.PLACEMENT_POINTS = { 100, 80, 65, 50, 35, 25 }

Config.PLAYER_COLORS = {
	Color3.fromRGB(235, 64, 52), -- red
	Color3.fromRGB(52, 120, 235), -- blue
	Color3.fromRGB(60, 190, 75), -- green
	Color3.fromRGB(245, 200, 40), -- yellow
	Color3.fromRGB(170, 80, 220), -- purple
	Color3.fromRGB(255, 140, 30), -- orange
}

-- Beam Attack: seconds between the Attacker's shots. The client uses it to avoid sending shots
-- the server would ignore.
Config.BEAM_COOLDOWN = 1.2

return Config
