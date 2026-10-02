# roblox-platformer

A 2D party platformer for Roblox, inspired by *Together* and Mario Party. 3–6 players play a series of short minigames (1–2 minutes each, 5 by default). Each game awards points, and whoever has the most points at the end wins.

## Current state

The MVP from the design doc is in place:

- **Lobby**: player list, color choice, a ready button, and match settings the host can change (number of games, time per game, score multiplier, game order and which modes are in the mix). The match counts down once everyone is ready.
- **Match**: picks a random mode for each game, shows a rules card, runs the game on a timer, then shows the scoreboard. After the last game there's a winner screen, then everyone goes back to the lobby.
- **Three modes**, each with its own map:
  - **Beam Attack** (Combat): one Attacker fires beams at the Survivors. The Attacker role rotates to whoever has had it the fewest times.
  - **Platform Rush** (Racing): a side-scrolling obstacle course with lava, pits, moving and crumbling platforms, a launch pad, a speed pad and checkpoints.
  - **Coin Rush** (Collection): coins worth 1, 5 or 10 keep appearing around a cave; the best ones are in the riskiest spots.
- **Movement**: blocks locked to a 2D plane, floaty jumps with short hops, and a dash.

Not built yet: power-ups, the other five modes from the design doc, knockback/attacks for everyone, cosmetics beyond colors, sounds and animations.

## Setup

This project uses [Rojo](https://rojo.space) to sync code from this folder into Roblox Studio. Rojo's version is pinned in `aftman.toml` (7.7.0-rc.1).

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder.
2. Install the Rojo plugin in Studio, either with `rojo plugin install` or from the Creator Store. **The plugin version must match the server version**, or Studio will refuse to connect. If `rojo --version` doesn't print 7.7.0-rc.1, an older Rojo earlier in your PATH is winning. Run `~/.aftman/bin/rojo serve`, or put `~/.aftman/bin` first in your PATH.
3. Run `rojo serve` in this folder.
4. In Studio, open a place, go to **Plugins → Rojo → Connect**.
5. If the place came from the Baseplate template, delete its `Baseplate` and `SpawnLocation` from Workspace. (The server also removes them when a game starts, since the baseplate would fill in the pits.) If an older version of this project synced a `Map` into Workspace, delete that too. Maps now live in ServerStorage.

Sync only goes one way, from files to Studio. Edit scripts here, not in Studio.

## Testing

In Studio, a match can start with just one player, and every mode is allowed at any player count. This is controlled by `Config.TESTING` in `src/shared/Config.luau`. Alone, Beam Attack makes you the Attacker with nobody to hunt, so it runs until the timer ends.

To test with several players, use **Test → Clients and Servers** with 3 players. Each client needs to click **Ready Up**.

On a live server the minimum is 3 players. Set the place's max players to 6 in Game Settings.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | A / D or ← / → | Left stick |
| Jump | Space, W or ↑ | A |
| Dash | Shift or Q | B |
| Fire beam (Attacker only) | Click to fire at the mouse, or F to fire the way you're moving/facing (hold W to fire up) | X or R2 |

On mobile, the default thumbstick and jump button work, plus on-screen Dash and Beam buttons.

## Project layout

| Path | Syncs to | What it does |
|---|---|---|
| `src/server/init.server.luau` | ServerScriptService.Server | Starts the match loop. |
| `src/server/Match.luau` | | Lobby, settings, ready-up, mode selection, game timing and scores. |
| `src/server/Characters.luau` | | Spawning, freezing and killing characters, the 2D plane lock, colors and name tags. |
| `src/server/Modes/` | | One module per game mode. |
| `src/server/Maps/` | | Map loader (`init.luau`), the `Builder` helpers, and one module per code-built map. |
| `src/server/Scoring.luau`, `Types.luau` | | Placement points; types shared by Match and the modes. |
| `src/client/` | StarterPlayerScripts.Client | Camera, movement and dash, moving/spinning map parts and pads, beam input. |
| `src/client/UI/` | | Lobby, in-game HUD, rules card, announcements, scoreboard and winner screen. |
| `src/shared/` | ReplicatedStorage.Shared | `Config` (rules and tuning), `ModeInfo` (mode names, rules text, player counts), `Text` (formatting). |
| `src/maps/` | ServerStorage.Maps | Maps saved as model files. The lobby is `Lobby.model.json`. |
| `src/character/StarterCharacter.model.json` | StarterPlayer | The block character. |

`default.project.json` also creates the `ReplicatedStorage.Remotes` folder (RemoteEvents) and `ReplicatedStorage.MatchState`.

### How the client knows what's going on

The server publishes match state as attributes, and the UI redraws when they change.

- **`ReplicatedStorage.MatchState`**: `Phase` (`Lobby`, `Intro`, `Playing`, `Scoreboard`, `Final`), `EndsAt` (server time the phase ends, or 0), `HostUserId`, `MinPlayers`, `GameNumber`, `GameCount`, `ModeId`. It also holds the settings: `Games`, `GameTime`, `Multiplier`, `Randomization`, and a `Mode_<id>` flag for each mode.
- **Each Player**: `ColorIndex`, `Ready`, `Score` (match total), `LastPoints` and `LastDetail` (the last game's result), `Role` (`Attacker`, `Survivor`, `Eliminated` or empty), and `Status` (the mode's one-line HUD text, such as "Coins: 12").

## Tuning

- **Match timings, player counts, settings ranges, placement points, colors**: `src/shared/Config.luau`.
- **Per-mode scoring and mechanics**: the constants at the top of each file in `src/server/Modes/`.
- **Gravity**: `Gravity` in `default.project.json`.
- **Walk speed and jump height**: `WalkSpeed` and `JumpHeight` on the Humanoid in `src/character/StarterCharacter.model.json`.
- **Short hops and dash**: `JUMP_CUT_MULTIPLIER` and the `DASH_` constants in `src/client/Movement.luau`. Set `JUMP_CUT_MULTIPLIER` to 1 to turn short hops off.
- **Camera flatness**: `FIELD_OF_VIEW` in `src/client/Camera.luau`. Lower is flatter; move the map's `CameraPart` farther back to compensate.

## Making maps

The server loads one map at a time into Workspace as `Map`. It looks for a Model with the requested name in `ServerStorage.Maps` first (from `src/maps/`, or built in Studio), and otherwise runs the module with that name in `src/server/Maps/`. To replace a code-built map with one built in Studio, save a Model with the same name (for example `BeamArena`) as `src/maps/BeamArena.rbxm`.

Everything players touch sits at **Z = 0**, with some thickness (code-built maps use 10 studs). The server finds special parts by name:

| Part name | What it does |
|---|---|
| `CameraPart` | Invisible, non-colliding, in front of the map with its front face pointing at it. The camera copies it. With a `Follow` attribute, the camera follows the player instead, staying within the `MinX`/`MaxX` attributes and between the part's height and `MaxY`. `OffsetY` sets how far above the player it aims. |
| `Spawn…` (any name starting with Spawn) | Spawn points. Players appear standing on the bottom face. |
| `AttackerSpawn` | Beam Attack: where the Attacker starts. |
| `CoinSpawn` | Coin Rush: coins appear centered here. Give it a `Risky` attribute for better coins. |
| `Checkpoint`, `Finish` | Platform Rush: respawn points, and the finish line. |
| `Hazard` | Kills on touch. |
| `FallingPlatform` | Gives way shortly after it's touched, then comes back. |
| `JumpPad` | Launches players upward at its `Power` attribute (studs/second). |
| `SpeedPad` | Sets walk speed to its `Speed` attribute for `Duration` seconds. |

Any part with a `MoveOffset` (Vector3) attribute slides back and forth by that offset, taking `MovePeriod` seconds (and starting `MovePhase` radians into its cycle). A `Spin` attribute spins a part around its vertical axis at that many radians per second. Clients run both, so platforms feel smooth for the player riding them. The map Model can set a `KillY` attribute: characters below that height die (the default is -60).

## Adding a game mode

1. Add its name, rules text and player counts to `src/shared/ModeInfo.luau`.
2. Create `src/server/Modes/<Id>.luau` with `map`, `setup(ctx)`, `run(ctx)` and `onDied(ctx, player)`. `Types.luau` describes what `ctx` provides, and the existing modes are short examples.
3. Register it in the `modes` table at the top of `src/server/Match.luau`.
4. Build its map, either as a module in `src/server/Maps/` or as a Model in `src/maps/`.
