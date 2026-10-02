-- Types shared by Match and the game modes.

export type Result = {
	points: number,
	detail: string, -- one line shown next to the points on the scoreboard, e.g. "Finished 2nd"
}

-- Lasts for a whole match (all its games).
export type MatchData = {
	history: { string }, -- ids of the modes played so far, in order
	attackerCounts: { [number]: number }, -- Beam Attack: how often each UserId has been the Attacker
}

-- Everything a mode gets for one game. Match creates it.
export type Context = {
	players: { Player }, -- who is taking part; players who join mid-game wait for the next one
	map: Model,
	duration: number,
	match: MatchData,
	live: boolean, -- false during the rules card, true once play starts
	isIn: (player: Player) -> boolean, -- still in the server and taking part
	timeLeft: () -> number,
	setTimeLeft: (seconds: number) -> (),
	-- Yields until time runs out, isDone() returns true, or every player has left.
	waitUntilOver: (isDone: () -> boolean) -> (),
	-- Spawns the player at `at`. Before play starts they're frozen until it does.
	spawn: (player: Player, at: CFrame) -> (),
	-- Calls respawn after the respawn delay, unless the map changed or they already respawned.
	respawnLater: (player: Player, respawn: () -> ()) -> (),
	announce: (message: string) -> (),
}

-- A game mode. Match calls setup (then shows the rules), then run, which yields until the game
-- is over and returns each player's result. onDied is called when a player taking part dies.
export type Mode = {
	map: string,
	setup: (ctx: Context) -> (),
	run: (ctx: Context) -> { [Player]: Result },
	onDied: (ctx: Context, player: Player) -> (),
}

return {}
