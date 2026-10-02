local Builder = require(script.Parent.Builder)

local BACKDROP = Color3.fromRGB(58, 52, 82)
local GROUND = Color3.fromRGB(24, 22, 32)
local PLATFORM = Color3.fromRGB(205, 200, 225)
local COVER = Color3.fromRGB(120, 108, 160)

-- Beam Attack: a one-screen arena. The Attacker starts on the top platform; platforms and the
-- two low walls block beams, so Survivors can hide behind them.
return function(): Model
	local b = Builder.new()
	b:camera(0, 18, 130)
	b:backdrop(-80, -20, 80, 70, BACKDROP)
	b:block(-62, -30, 62, 0, GROUND, "Ground")
	b:wall(-66, 0, -60, 90)
	b:wall(60, 0, 66, 90)

	b:block(-24, 0, -20, 6, COVER, "Cover")
	b:block(20, 0, 24, 6, COVER, "Cover")

	-- { left, right, top }. Each row is 8 studs above the last, within jumping height.
	for _, platform in {
		{ -52, -36, 8 },
		{ -8, 8, 8 },
		{ 36, 52, 8 },
		{ -34, -18, 16 },
		{ 18, 34, 16 },
		{ -56, -44, 24 },
		{ -10, 10, 24 },
		{ 44, 56, 24 },
		{ -30, -16, 32 },
		{ 16, 30, 32 },
		{ -6, 6, 40 },
	} do
		b:platform(platform[1], platform[2], platform[3], PLATFORM)
	end

	for _, spot in { { -50, 0 }, { 50, 0 }, { -44, 8 }, { 44, 8 }, { -26, 16 }, { 26, 16 } } do
		b:marker("Spawn", spot[1], spot[2])
	end
	b:marker("AttackerSpawn", 0, 40)

	return b:build("BeamArena")
end
