# Brainrot VS Brainrot

A Roblox physics auto-battler, based on the viral "ball vs ball" simulation videos and laid out like the popular Ball VS Ball games. Players walk around a lobby as their normal R15 avatars and step up to a duel station to play someone. The station's big screen becomes the arena: an upright box the balls bounce around in, with both players floating beside it. Each player picks a ball from their collection, aims it, and lets go. The balls bounce around on their own, slam into each other, set off their abilities and lose health until one breaks. Lose a round and you lose a heart; everyone has 3.

Between matches, players collect balls, flyers and explosions, level up, do daily quests and trade.

## How a match works

1. **Lobby**: the lobby is a floating platform over the ocean, with glowing arrows down the middle and 8 duel stations along the sides. Each station has a big VS screen, two squares in front of it (pink for left, blue for right), and a sign showing "0/2 PLAYERS" and "Win 100".
2. **Join**: press **E Join** at a square, or **Play** in the HUD (it joins someone who's waiting, or a free station), or **Join** in the Quick Join panel. You wait in the square. Your face shows on the screen, and the HUD reads "Waiting For Opponent", with **Invite** (invite a friend) and **Leave** buttons. If nobody comes within 15 seconds, a robot takes the other side.
3. **Draft (25s)**: "CHOOSE YOUR BALL". Pick one of three random balls from your collection. **All Balls** swaps them for three from every ball: free once a day, or every round with the game pass. Both players float beside the box on hover pads, with hearts over their heads, and the camera turns to face the box.
4. **Aim (6s)**: a line shows where your ball will go, bouncing off the walls. Point and lock in.
5. **Battle (up to 45s)**: both balls launch at once and fight on their own. After 30 seconds, sudden death starts: the walls close in, turn red, and every hit does 2.5× damage. If both balls survive, the one with more of its health left wins. When a ball breaks, the winner's explosion plays.
6. **Resolve**: the loser loses a heart. A draw costs nobody a heart. Repeat from the draft until someone is out of hearts. Leaving mid-match forfeits it.
7. **Rewards**: the winner gets 100 coins. Everyone gets XP, quest progress and a **reward roll**: a strip of prizes spins and stops on yours (**Skip** jumps to the end), then **Receive** it.

Both players can send **stickers** (emoji over your head) while waiting and in a match.

## Progression

All of these numbers are in `src/shared/Economy.luau`.

| | How it works |
|---|---|
| **Coins** | 100 per win, 100 per daily quest, and from gifts and reward rolls. Spend them at the Ball Machine. |
| **Gems** | From levels, gifts, reward rolls, or Robux. Spend them at the Flyer and Explosion Machines. |
| **XP and levels** | 60 XP for a win, 25 for a loss; **x2 EXP** boosts (15 minutes) come from reward rolls. Every level has a reward; the HUD shows the next one ("Lv 3 Reward"). |
| **Daily Quests** | Duel with a friend, Win 3 times, Play 10 times. Each pays 100 coins; they reset at midnight UTC. **Undone** turns into **Claim** when a quest is done. |
| **Gifts** | The 🎁 in the top bar: gifts that unlock after 2 to 40 minutes of play in a visit. |
| **Store** | The 🎰 button, or the gumball machine by the spawn. Three machines roll one random thing each, rarer ones less likely: a ball (250 coins), a flyer (30 gems) or an explosion (30 gems). Flyer and explosion rolls only give ones you don't have. |
| **Inventory** | Tabs for **Balls** (how many of each you own, and 🔒 to stop one being traded or fused; **View All** shows each ball's Ball Machine odds), **Explosions** and **Flyers** (equip them) and **Fusion** (3 of one ball make a random ball one rarity up). |
| **Flyers** | Ride them around the lobby (you sit on them, a little higher up), and float on them beside the arena. |
| **Explosions** | Play when your ball knocks the other one out. |
| **Trade** | The Trade tab lists everyone in the server. Send a request; if they accept, you each add balls, press **Ready**, and after a 3-second countdown the balls swap. Any change cancels the countdown. Locked balls can't be traded, and nobody can trade down below 3 balls. |
| **Invite** | A friend who joins from your invite gets you a free ball. |
| **Emotes** | The Emotes button or **R** opens Roblox's emote wheel. |
| **Settings** | The ⚙️ in the top bar: sound effects, camera shake and damage numbers. |

New players start with Chimpanzini Bananini, Lirilì Larilà and Tung Tung Tung Sahur.

## Saving

Each player's data saves to a DataStore (`src/server/Data.luau`): every 2 minutes, when they leave, and when the server shuts down. If loading fails, the player gets a fresh profile that is never saved, so a hiccup can't overwrite real progress.

Studio can't reach DataStores until you turn on **Game Settings → Security → Enable Studio Access to API Services**. Until then everything works, but nothing saves between tests.

## Robux

Gem packs, a limited 12-hour gem pack, and the All Balls game pass are ready to go but hidden. To turn them on, create them on the Creator Dashboard (**Monetization → Developer Products** and **Passes**) and paste their ids into `GEM_PRODUCTS`, `OFFER` and `ALL_BALLS_PASS` in `src/shared/Economy.luau`. Purchases are only confirmed after they've saved.

## The balls

| Brainrot | Rarity | Ability | What it does |
|---|---|---|---|
| 🍌 Chimpanzini Bananini | Common | Bananas | Leaves a banana every 3s. Touching your own heals 15%; the other ball touching one makes it explode for 120. |
| 🌵 Lirilì Larilà | Common | Blades | Spikes orbit it, one more after every wall bounce (up to 6). Each spike hits for 25, once a second. |
| 🐪 Frigo Camelo | Common | Frost | Hitting the other ball freezes it in ice, slowing it to a quarter speed for 1.5s. |
| 🪵 Tung Tung Tung Sahur | Rare | Charge | Grows 2% bigger and heavier every second. Each wall bounce adds +5% to its next hit (up to 10). |
| 🦐 Trippi Troppi | Rare | Laser | Every 3s, fires a laser ahead that bounces off the walls twice and hits for 70. |
| 🐸 Boneca Ambalabu | Rare | Lightning | Every 4s, lightning strikes the other ball for 70. |
| 🦈 Tralalero Tralala | Epic | Vampire | Heals 35% of the damage it deals, then gets a 15% speed boost for 2s. |
| 🌳 Brr Brr Patapim | Epic | Vines | Each wall bounce stretches a vine back to its last bounce point. The other ball crossing a vine is slowed 60% and takes 40 damage a second. |
| 💃 Ballerina Cappuccina | Epic | Dice | Every wall bounce rolls a die: heal 40, a burst of speed, or a double-damage next hit. |
| 🐊 Bombardiro Crocodilo | Legendary | Cannon | Wall bounces plant turrets (up to 3) that fire a homing shot for 65 every 1.5s. |
| 🐄 La Vaca Saturno Saturnita | Legendary | Shackles | Hitting the other ball chains it for 2s, dragging it close for 20 damage a second (then 4s to recharge). |
| ☕ Cappuccino Assassino | Mythic | Black Hole | Below 25% health, opens a black hole for 3s that pulls the other ball in and switches off its ability. |

Collision damage for each ball is `relative speed × its impact power × (its mass ÷ the other's mass, between 0.5 and 2) × 3.6 + 25`. Every wall bounce also chips 10 health. These numbers are in `src/shared/Config.luau` and `src/shared/Brainrots.luau`.

## Not built yet

2v2, the design doc's once-per-match Collection Pick, and music. The sounds are Roblox built-ins; swap in better ones in `Config.Sounds`.

## Setup

This project uses [Rojo](https://rojo.space) to sync code from this folder into Roblox Studio. Rojo's version is pinned in `aftman.toml` (7.7.0-rc.1).

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder.
2. Install the Rojo plugin in Studio, either with `rojo plugin install` or from the Creator Store. **The plugin version must match the server version**, or Studio will refuse to connect. If `rojo --version` doesn't print 7.7.0-rc.1, an older Rojo earlier in your PATH is winning. Run `~/.aftman/bin/rojo serve`, or put `~/.aftman/bin` first in your PATH.
3. Run `rojo serve` in this folder.
4. In Studio, open a place and go to **Plugins → Rojo → Connect**.
5. Delete anything left over from older versions of this project: `StarterPlayer.StarterCharacter`, `ServerStorage.Maps`, `ReplicatedStorage.MatchState`. The server also removes `StarterCharacter` when it starts, so everyone gets their own avatar, and it removes leftovers in Workspace. It makes its own `ReplicatedStorage.Remotes`.
6. In **Game Settings → Avatar**, make sure the avatar type is R15.

Sync only goes one way, from files to Studio. Edit scripts here, not in Studio.

## Testing

Press **Play**, then press **Play** in the HUD (or walk to a station and press **E Join**). After 15 seconds a robot joins. For a real 1v1, use **Test → Clients and Servers** with 2 players and join the same station. To test trading, use 2 players and the Trade tab. To try touch controls, use Studio's device emulator (**Test → Device**).

## Controls

The lobby uses normal Roblox avatar controls, plus the HUD's buttons (mouse, touch, or a gamepad's UI selection). **E** (or the prompt's button on touch and gamepad) joins a station, and **R** opens emotes. In a match, avatar controls are switched off, so on touch screens the thumbstick and jump button go away, leaving the screen free for aiming. Then:

| | Mouse | Touch | Gamepad | Keyboard |
|---|---|---|---|---|
| Pick a ball | Click a card | Tap a card | Select a card, A | |
| Aim | Move the mouse | Drag | Left stick | W/S or Up/Down (higher or lower) |
| Lock in | Click | Let go | A | Space or Enter |

## Project layout

| Path | Syncs to | What it does |
|---|---|---|
| `src/shared/Config.luau` | ReplicatedStorage.Shared | Match timings, arena and ball size, sudden death, damage formula, rarity odds, side colors, sounds. |
| `src/shared/Economy.luau` | | Rewards, prices, levels, quests, gifts, Store machines, the reward roll, Robux ids. |
| `src/shared/Brainrots.luau`, `Cosmetics.luau` | | The balls (stats, rarity, ability, description, look), and the flyers and explosions. |
| `src/shared/Looks.luau`, `AimMath.luau`, `Remotes.luau` | | Building models from part lists, aim and bounce math in the arena's plane, and the remotes (created by the server). |
| `src/server/Data.luau` | ServerScriptService.Server | Loading, saving and sending each player's profile. |
| `src/server/Rewards.luau`, `Shop.luau`, `Trading.luau` | | Handing out rewards, XP, quests and gifts; Store machines, fusion and Robux; trading. |
| `src/server/Actions.luau` | | Every request the HUD can make, checked before it's done. |
| `src/server/Avatars.luau` | | Flyers on avatars, and stickers over heads. |
| `src/server/MatchService.luau` | | Joining and leaving stations, the bot, and the Draft → Aim → Battle → Resolve loop. |
| `src/server/Battle.luau` | | One round's fight: server-owned physics in the box's upright plane with gravity cancelled, constant-speed bouncing, damage, ability hooks, sudden death. |
| `src/server/Skills/` | | One module per ability, using the hooks `onStart`, `onTick`, `onWallHit`, `onEnemyHit` and `onLowHealth`. |
| `src/server/World/` | | The lobby (`Lobby`), the duel stations (`Station`), the upright box arena in each one (`Arena`), the bot's body (`Robot`), and `Builder` helpers. |
| `src/client/Profile.luau`, `Action.luau` | StarterPlayerScripts.Client | Your data as the server sent it, and asking the server to do things. |
| `src/client/Camera.luau` | | Glides to face your arena during a match, framing the box and both players, and switches your avatar's controls off. |
| `src/client/AimController.luau` | | Aiming on every device, and the bouncing aim line. |
| `src/client/Visuals.luau`, `Flyer.luau` | | Ball looks, hit and ability effects, knockout explosions, the lobby arrows, and the sitting pose on flyers. |
| `src/client/UI/` | | The lobby HUD and windows (Store, Inventory, Gifts, Settings, Profile, Trade), the waiting and match HUD, the draft, stickers and reward popups. `Widgets` has the shared look; `Windows` shows one window at a time. |

Clients follow a match through attributes. On each player: `WaitingAt` and `WaitingSide` while waiting at a station, then `MatchId` (the arena's name), `Side`, `DraftOptions`, `DraftPick` and `AllBallsUsed`. On the arena's `State`: `WaitingLeft`/`WaitingRight` (user ids) between matches, and `Phase` (empty between matches), `EndsAt`, `Round`, `SuddenDeath`, `LeftName`/`RightName`, `LeftUserId`/`RightUserId` (0 for the bot), `LeftHearts`/`RightHearts`, `LeftPick`/`RightPick`, `RoundWinner` and `MatchWinner` during one.

## Adding a ball

1. Add an entry to `src/shared/Brainrots.luau`: stats, rarity, ability name, icon, a short hint and description, color, hit word and look. The look is a list of parts around the ball's center, facing -Z, drawn for a 7-stud ball (`DESIGN_SIZE`); it's scaled down to `Config.BALL_SIZE` in battle.
2. If it needs a new ability, add `src/server/Skills/<Name>.luau` with whichever hooks it needs. The existing ones are short examples.

The lobby adds a statue for every ball, and the Store, Inventory and trading pick it up automatically.
