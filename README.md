# Brainrot VS Brainrot

A physics arena battler for Roblox. Every player is a ball dressed up as a brainrot (Tung Tung Tung Sahur, Tralalero Tralala, Bombardiro Crocodilo, Chimpanzini Bananini). Roll, build momentum, boost and slam into each other to knock everyone else off a crumbling arena. The last brainrot standing wins.

The design is in the Brainrot VS Brainrot blueprint. Players learn by playing, not reading: see [CLAUDE.md](CLAUDE.md).

## Current state

This is the blueprint's MVP (section 23):

- **Lobby**: roll around freely. Roll onto a brainrot's glowing pad to become it. When everyone is in the green circle, the round counts down. There are bumpers to practice on.
- **Last Brainrot Standing**: everyone spawns in a ring on a round arena over the void. After 10 seconds the edge starts crumbling inward; tiles turn red before they drop. Fall off and you're out (you then watch someone still playing). The last ball left wins, or everyone left after 2 minutes shares the win.
- **Movement**: rolling with momentum (top speed builds the longer you roll straight, and sharp turns bleed it), jump, boost (uses a meter), and brake.
- **Collisions**: the server works out knockback from how fast each ball was moving into the other, its class's weight, and whether it just boosted.
- **One ability, Slam**: a shockwave that knocks nearby balls away. Used in the air, you dive into the ground first.
- **4 brainrots, 4 classes**: Juggernaut (heavy and slow), Striker (light and fast), Trickster (bouncy), Support (balanced).
- **Feel**: comic hit words ("BONK!", "SPLASH!"), particle bursts, shockwave rings, camera shake, a camera that widens with speed, trails, and confetti for the winner.
- **Every device**: keyboard, gamepad and touch, with an on-screen joystick and buttons on phones and tablets.

Not built yet (later phases in the blueprint): HP/durability, class-specific abilities and ultimates, team and soccer modes, more hazards (ice, mud, hammers, lasers), off-screen indicators, coins, XP, cosmetics and saving player data. The sounds are Roblox built-ins; swap in better ones in `Config.Sounds`.

## Setup

This project uses [Rojo](https://rojo.space) to sync code from this folder into Roblox Studio. Rojo's version is pinned in `aftman.toml` (7.7.0-rc.1).

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder.
2. Install the Rojo plugin in Studio, either with `rojo plugin install` or from the Creator Store. **The plugin version must match the server version**, or Studio will refuse to connect. If `rojo --version` doesn't print 7.7.0-rc.1, an older Rojo earlier in your PATH is winning. Run `~/.aftman/bin/rojo serve`, or put `~/.aftman/bin` first in your PATH.
3. Run `rojo serve` in this folder.
4. In Studio, open a place and go to **Plugins → Rojo → Connect**.
5. Delete anything left over from older versions of this project or from the Baseplate template: a `Map` or `Baseplate` in Workspace, a `Maps` folder in ServerStorage, a `StarterCharacter` in StarterPlayer. (The server also removes `Map`, `Baseplate` and `SpawnLocation` when it starts.)

Sync only goes one way, from files to Studio. Edit scripts here, not in Studio.

## Testing

Press **Play**. In Studio a round can start with one player: roll into the green circle. Alone, the round lasts until you fall off or time runs out.

To test collisions, use **Test → Clients and Servers** with 2 or more players, and roll every player into the circle. To try touch controls, use Studio's device emulator (**Test → Device**).

On a live server a round needs at least 2 players.

## Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Roll | WASD or arrow keys | Left stick | Joystick (put your thumb anywhere on the left half) |
| Jump | Space | A | ▲ |
| Boost | Shift | X or R2 | 💨 |
| Slam | E or F | Y or R1 | 💥 |
| Brake (hold) | Ctrl or C | B or L2 | ✋ |

The blueprint puts brake on Space and jump on a double-tap. Here Space jumps and brake has its own key, which is easier to pick up.

All input goes through `src/client/Input.luau`, which also draws the touch controls.

## Project layout

| Path | Syncs to | What it does |
|---|---|---|
| `src/shared/Config.luau` | ReplicatedStorage.Shared | Every tuning number: timings, movement, knockback, the ability, sounds. |
| `src/shared/Brainrots.luau` | | The brainrots: name, class, color, hit word, and the parts their look is built from. Class stats live here too. |
| `src/server/Round.luau` | ServerScriptService.Server | Lobby (pads, green circle, countdown) and the Last Brainrot Standing round. |
| `src/server/Balls.luau` | | Spawning balls, network ownership, dressing them as brainrots, basic speed validation. |
| `src/server/Combat.luau` | | Ball-on-ball knockback, bumpers, boosts and the Slam ability. |
| `src/server/Looks.luau` | | Builds a brainrot's look from its parts. |
| `src/server/World/` | | `Builder` helpers, the `Lobby`, and the crumbling `Arena`. |
| `src/client/BallController.luau` | StarterPlayerScripts.Client | Rolls your ball: steering, momentum, jump, boost, brake, slam dive, and applying knockback. |
| `src/client/Camera.luau` | | Fixed-angle follow camera with speed FOV and shake. |
| `src/client/Visuals.luau` | | Moves every ball's look to follow it, and plays hit, slam and knockout effects. |
| `src/client/Input.luau`, `Sounds.luau` | | Input for every device, and sound playback. |
| `src/client/UI/` | | The HUD: timer, balls left, boost meter, slam charge, 3-2-1-GO, announcements, winner. |

`default.project.json` also creates `ReplicatedStorage.Remotes` (Boost, Ability, Knockback, Effect, Announce) and `ReplicatedStorage.MatchState`, whose attributes tell clients what's going on: `Phase` (`Lobby`, `Countdown`, `Playing`, `Winner`), `EndsAt`, `Alive` and `Winners`. Each player has `Brainrot` and `AbilityReadyAt` attributes.

## How the physics works

Each player's ball is an invisible sphere (`Core`) that their own client simulates, so it responds instantly. The client pushes it with a `VectorForce` toward where the player is steering. The brainrot look is a separate set of non-solid parts that every client moves each frame to follow the sphere, facing the way it rolls.

Collisions are decided on the server: when two balls touch while moving toward each other, it works out each one's knockback and tells each client to apply it to its own ball. Bumpers and slams work the same way. Roblox physics also bounces the balls off each other on its own; the server's knockback is what makes hits big.

## Adding a brainrot

Add an entry to `src/shared/Brainrots.luau` with an id, name, emoji, class, color, hit word and look. The look is a list of parts around the ball's center, facing -Z. The lobby makes a pad and statue for every brainrot automatically; widen the row in `src/server/World/Lobby.luau` past 4 or 5.
