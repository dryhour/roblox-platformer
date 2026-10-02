# CLAUDE.md

## Show, don't tell

People play Roblox for fun, not to read instructions. On-screen UI and written explanations are the **last resort**.

- Teach through the game world first: colors, glowing pads, shapes, where things are placed, and what happens when you touch them. For example, players get ready by walking into the green zone, not by clicking a "Ready" button.
- When something has to be on screen, use icons, numbers, colors and bars instead of words. Any words should be one or two short ones, like "GO!" or "OUT".
- Aim for something a toddler could understand without reading.

## Every device

Everything must work on keyboard and mouse, gamepad, and touch (phones and tablets). Movement and actions go through `src/client/Input.luau`, which also draws the touch buttons. Don't depend on Roblox's default PlayerModule controls.
