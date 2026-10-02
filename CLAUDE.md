# CLAUDE.md

## Show, don't tell

People play Roblox for fun, not to read instructions. On-screen UI and written explanations are the **last resort**.

- Teach through the game world first: colors, glowing pads, shapes, where things are placed, and what happens when you touch them. For example, players get ready by walking into the green zone, not by clicking a "Ready" button.
- When something has to be on screen, use icons, numbers, colors and bars instead of words. Any words should be one or two short ones, like "GO!" or "OUT".
- Aim for something a toddler could understand without reading.

## Every device

Everything must work on keyboard and mouse, gamepad, and touch (phones and tablets). In the lobby, players use Roblox's normal avatar controls. In a match, every input (picking a card, aiming, locking in) needs a mouse, touch, gamepad and keyboard path; see `src/client/AimController.luau` and `src/client/UI/Draft.luau`.
