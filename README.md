# roblox-platformer

A 2D party platformer for Roblox, inspired by *Together* and Mario Party. 3–6 players play a series of short minigames (1–2 minutes each, 5 by default). The winner of each game gets points, and whoever has the most points at the end wins.

The first planned minigame: one player is the attacker and tries to eliminate the others with beam attacks before time runs out. Points go to the attacker for eliminations and to survivors for how long they last.

## Current state

The core 2D movement is in place; there are no minigames, lobby or scoring yet.

- A fixed side-on camera looking at a test map.
- Players are blocks locked to a 2D plane. They face only left or right.
- Floaty movement: faster walking, higher jumps and lower gravity. Tapping jump gives a short hop; holding it gives a full jump.

## Setup

This project uses [Rojo](https://rojo.space) to sync code from this folder into Roblox Studio. Rojo's version is pinned in `aftman.toml` (7.7.0-rc.1).

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder.
2. Install the Rojo plugin in Studio, either with `rojo plugin install` or from the Creator Store. **The plugin version must match the server version**, or Studio will refuse to connect.
3. Run `rojo serve` in this folder.
4. In Studio, open a place, go to **Plugins → Rojo → Connect**.
5. If the place came from the Baseplate template, delete its `Baseplate` and `SpawnLocation` from Workspace.

Sync only goes one way, from files to Studio. Edit scripts here, not in Studio.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A / D or ← / → | Left stick |
| Jump | Space, W or ↑ | A |

Mobile uses the default thumbstick and jump button.

## Project layout

| Path | Syncs to | What it does |
|---|---|---|
| `src/server/` | ServerScriptService | Locks each character to the 2D plane and sets up left/right facing. |
| `src/client/` | StarterPlayerScripts | Fixed camera, left/right-only movement, facing and variable jump height. |
| `src/shared/` | ReplicatedStorage | Modules shared by server and client. |
| `src/character/StarterCharacter.model.json` | StarterPlayer | The block character. |
| `src/map/Map.model.json` | Workspace | The test map. |

## Tuning

- **Gravity**: `Gravity` in `default.project.json`.
- **Walk speed and jump height**: `WalkSpeed` and `JumpHeight` on the Humanoid in `src/character/StarterCharacter.model.json`.
- **Short-hop strength**: `JUMP_CUT_MULTIPLIER` in `src/client/init.client.luau`. Set it to 1 to turn short hops off.
- **Camera flatness**: `FIELD_OF_VIEW` in `src/client/init.client.luau`. Lower is flatter; move `CameraPart` farther back to compensate.

## Making maps

A map is a Model named `Map` in Workspace. It needs:

- Everything players stand on centered at **Z = 0**, with some thickness (the test map uses 10 studs).
- At least one `SpawnLocation` at Z = 0.
- An invisible, non-colliding part named `CameraPart` in front of the map, with its front face pointing at it. The camera copies this part's position and angle.

Building maps in Studio is easier than editing JSON. Rojo overwrites anything in `Workspace.Map` that isn't in the file, so either remove `Map` from `default.project.json` and keep the map in the place file, or save it from Studio as `src/map/Map.rbxm` and point `$path` at that file.
