# Brainrot VS Brainrot

A Roblox physics auto-battler, based on the viral "ball vs ball" simulation videos. Two players each pick a ball, aim it, and let go. The balls bounce around an enclosed box on their own, slam into each other, set off their abilities and lose health until one breaks. Lose a round and you lose a heart; everyone has 3.

The game follows the Ball VS Ball design doc, with every ball themed as a brainrot (from the Brainrot VS Brainrot blueprint). Players learn by playing, not reading: see [CLAUDE.md](CLAUDE.md).

## How a match works

1. **Lobby**: walk your avatar onto the blue ⚔️ pad. When two players are on it, they're matched 1v1. Or stand on the purple 🤖 pad to play a bot.
2. **Draft (10s)**: pick one of three random balls. Rarer balls come up less often.
3. **Aim (6s)**: a line shows where your ball will go, bouncing off the walls. Point and lock in.
4. **Battle (up to 45s)**: both balls launch at once and fight on their own. After 30 seconds, sudden death starts: the walls close in, turn red, and every hit does 2.5× damage. If both balls survive, the one with more of its health left wins.
5. **Resolve**: the loser loses a heart (🏆 / 💔). A draw costs nobody a heart.
6. Repeat from the draft until someone is out of hearts (👑). Leaving mid-match forfeits it.

## The balls

| Brainrot | Rarity | Ability (doc ball) | What it does |
|---|---|---|---|
| 🍌 Chimpanzini Bananini | Common | Bananas (Apple) | Drops a banana every 3s. Rolling over your own heals 15%; the other ball touching one makes it explode for 120. |
| 🪵 Tung Tung Tung Sahur | Rare | Charge | Grows 2% bigger and heavier every second. Each wall bounce adds +5% to its next hit (up to 10). |
| 🦈 Tralalero Tralala | Epic | Vampire | Heals 35% of the damage it deals, then gets a 15% speed boost for 2s. |
| 🌳 Brr Brr Patapim | Epic | Vines (Spider) | Each wall bounce stretches a vine back to its last bounce point. The other ball crossing a vine is slowed 60% and takes 40 damage a second. |
| 🐊 Bombardiro Crocodilo | Legendary | Cannon | Wall bounces plant turrets (up to 3) that fire a homing shot for 65 every 1.5s. |
| ☕ Cappuccino Assassino | Mythic | Black Hole | Below 25% health, opens a black hole for 3s that pulls the other ball in and switches off its ability. |

Collision damage for each ball is `relative speed × its impact power × (its mass ÷ the other's mass, between 0.5 and 2) × 1.5 + 25`. Every wall bounce also chips 10 health. All of these numbers are in `src/shared/Config.luau` and `src/shared/Brainrots.luau`.

## Not built yet

These are from the design doc's later phases: 2v2, the once-per-match Collection Pick, coins and XP, the gacha machine, trading, and saving player data. The sounds are Roblox built-ins; swap in better ones in `Config.Sounds`.

Where this differs from the doc: battles last up to 45s as written, but sudden death starts at 30s instead of 40s so the shrinking walls have time to matter. The doc doesn't have walls chip health; that's here because balls are meant to lose health bouncing around.

## Setup

This project uses [Rojo](https://rojo.space) to sync code from this folder into Roblox Studio. Rojo's version is pinned in `aftman.toml` (7.7.0-rc.1).

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder.
2. Install the Rojo plugin in Studio, either with `rojo plugin install` or from the Creator Store. **The plugin version must match the server version**, or Studio will refuse to connect. If `rojo --version` doesn't print 7.7.0-rc.1, an older Rojo earlier in your PATH is winning. Run `~/.aftman/bin/rojo serve`, or put `~/.aftman/bin` first in your PATH.
3. Run `rojo serve` in this folder.
4. In Studio, open a place and go to **Plugins → Rojo → Connect**.
5. Delete anything left over from older versions of this project: `StarterPlayer.StarterCharacter`, `ServerStorage.Maps`, `ReplicatedStorage.MatchState`. (The server removes leftovers in Workspace itself, and makes its own `ReplicatedStorage.Remotes`.)

Sync only goes one way, from files to Studio. Edit scripts here, not in Studio.

## Testing

Press **Play** and walk onto the 🤖 pad to play a bot. For a real 1v1, use **Test → Clients and Servers** with 2 players and walk both onto the ⚔️ pad. To try touch controls, use Studio's device emulator (**Test → Device**).

## Controls

The lobby uses normal Roblox avatar controls. In a match:

| | Mouse | Touch | Gamepad | Keyboard |
|---|---|---|---|---|
| Pick a ball | Click a card | Tap a card | Select a card, A | |
| Aim | Move the mouse | Drag | Left stick | A/D or arrow keys |
| Lock in | Click | Let go | A | Space or Enter |

## Project layout

| Path | Syncs to | What it does |
|---|---|---|
| `src/shared/Config.luau` | ReplicatedStorage.Shared | Match timings, sudden death, damage formula, rarity odds and colors, sounds. |
| `src/shared/Brainrots.luau` | | The ball roster: stats, rarity, ability, and the parts each look is built from. |
| `src/shared/Looks.luau`, `AimMath.luau`, `Remotes.luau` | | Building looks, aim clamping and bounce tracing, and the RemoteEvents (created by the server). |
| `src/server/MatchService.luau` | ServerScriptService.Server | Lobby pads, matchmaking, bots, and the Draft → Aim → Battle → Resolve loop with hearts. |
| `src/server/Battle.luau` | | One round's fight: server-owned physics, constant-speed bouncing, damage, ability hooks, sudden death. |
| `src/server/Skills/` | | One module per ability, using the hooks `onStart`, `onTick`, `onWallHit`, `onEnemyHit` and `onLowHealth`. |
| `src/server/World/` | | The lobby, the box arena (one per match, side by side) and `Builder` helpers. |
| `src/client/Camera.luau` | StarterPlayerScripts.Client | Frames your arena, following the midpoint of the two balls. |
| `src/client/AimController.luau` | | Aiming on every device, and the bouncing aim line. |
| `src/client/Visuals.luau` | | Moves each ball's look to follow it, and shows hits, damage numbers, explosions and knockouts. |
| `src/client/UI/` | | The draft cards and the match HUD (hearts, timer, round result, winner, sudden-death tint). |

Clients follow a match through attributes. On each player: `MatchId`, `Side`, `DraftOptions` and `DraftPick`. On the arena's `State`: `Phase`, `EndsAt`, `Round`, `SuddenDeath`, `LeftName`/`RightName`, `LeftHearts`/`RightHearts`, `RoundWinner` and `MatchWinner`.

## Adding a ball

1. Add an entry to `src/shared/Brainrots.luau`: stats, rarity, ability name, icon, a one- or two-word hint, color, hit word and look. The look is a list of parts around the ball's center, facing -Z.
2. If it needs a new ability, add `src/server/Skills/<Name>.luau` with whichever hooks it needs. The existing ones are short examples.

The lobby adds a statue for every ball automatically.
