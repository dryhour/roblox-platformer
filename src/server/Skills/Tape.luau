local Vines = require(script.Parent.Vines)

-- Backrooms Mold (the reference game's Spider Ball): each wall bounce strings yellow-and-black
-- hazard tape back to its last bounce point (up to 4, each lasting 7 seconds). The other ball
-- crossing the tape is slowed by 25% and keeps losing a little health while it's on it.
return Vines.make({
	maxLines = 4,
	lifetime = 7,
	damagePerSecond = 60,
	slow = 0.75,
	slowTime = 0.8,
	damageEvery = 0.25,
	thickness = 0.4,
	colors = { Color3.fromRGB(250, 210, 30), Color3.fromRGB(25, 25, 25) },
	material = Enum.Material.SmoothPlastic,
})
