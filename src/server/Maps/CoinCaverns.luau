local Builder = require(script.Parent.Builder)

local BACKDROP = Color3.fromRGB(70, 56, 46)
local GROUND = Color3.fromRGB(34, 27, 24)
local PLATFORM = Color3.fromRGB(196, 160, 112)
local MOVING = Color3.fromRGB(80, 150, 255)

-- Coin Rush: a one-screen cave. The lower platforms can be climbed by jumping; the upper ones
-- need the lift on the left or the launch pad on the right. CoinSpawn markers are where coins
-- appear, and Risky ones roll better coins.
return function(): Model
	local b = Builder.new()
	b:camera(0, 18, 130)
	b:backdrop(-80, -20, 80, 70, BACKDROP)

	-- Ground, with a lava pit in the middle
	b:block(-62, -30, -8, 0, GROUND, "Ground")
	b:block(8, -30, 62, 0, GROUND, "Ground")
	b:block(-8, -30, 8, -6, GROUND, "Ground")
	b:hazard(-8, -6, 8, -3)
	b:wall(-66, 0, -60, 90)
	b:wall(60, 0, 66, 90)

	-- { left, right, top }
	for _, platform in {
		{ -50, -34, 8 },
		{ 34, 50, 8 },
		{ -26, -12, 14 },
		{ 12, 26, 14 },
		{ -6, 6, 20 },
		{ -48, -34, 26 },
		{ 34, 48, 26 },
		{ -22, -10, 32 },
		{ 10, 22, 32 },
		{ -4, 4, 40 },
	} do
		b:platform(platform[1], platform[2], platform[3], PLATFORM)
	end

	-- Lava on the inner ends of the y = 32 platforms guards the jump to the top.
	b:hazard(-12, 32, -10, 33.5)
	b:hazard(10, 32, 12, 33.5)

	-- The lift rides from the ground up to the left y = 26 platform.
	b:move(b:platform(-59, -53, 2, MOVING), Vector3.new(0, 24, 0), 6)
	b:jumpPad(52, 58, 0, 80)

	for _, spot in { { -40, 0 }, { -20, 0 }, { 20, 0 }, { 40, 0 } } do
		b:marker("Spawn", spot[1], spot[2])
	end

	-- { x, y, risky }. Coins appear centered on these.
	for _, spot in {
		{ -52, 3 },
		{ -34, 3 },
		{ -18, 3 },
		{ 18, 3 },
		{ 34, 3 },
		{ 46, 3 },
		{ 0, 4, true }, -- over the lava pit
		{ -42, 11 },
		{ 42, 11 },
		{ -19, 17 },
		{ 19, 17 },
		{ 0, 23 },
		{ -41, 29 },
		{ 41, 29 },
		{ -16, 35 },
		{ 16, 35 },
		{ 0, 43, true }, -- the top platform
		{ -56, 16, true }, -- in the lift's path
		{ 55, 22, true }, -- above the launch pad
	} do
		local marker = b:marker("CoinSpawn", spot[1], spot[2] - 0.5)
		if spot[3] then
			marker:SetAttribute("Risky", true)
		end
	end

	return b:build("CoinCaverns")
end
