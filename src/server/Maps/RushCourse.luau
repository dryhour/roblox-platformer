local Builder = require(script.Parent.Builder)

local SKY = Color3.fromRGB(125, 185, 235)
local GROUND = Color3.fromRGB(44, 50, 62)
local PLATFORM = Color3.fromRGB(240, 240, 245)
local MOVING = Color3.fromRGB(80, 150, 255)

-- Platform Rush: a left-to-right obstacle course, about 480 studs long. The camera follows
-- each player. Ground tops are at y = 0 unless noted; falling into a pit kills.
return function(): Model
	local b = Builder.new()
	b.model:SetAttribute("KillY", -25)

	local camera = b:camera(0, 12, 100)
	camera:SetAttribute("Follow", true)
	camera:SetAttribute("MinX", -5)
	camera:SetAttribute("MaxX", 410)
	camera:SetAttribute("MaxY", 40)
	b:backdrop(-70, -30, 480, 90, SKY)

	-- Start
	b:block(-56, -20, -50, 70, GROUND)
	b:block(-50, -20, 25, 0, GROUND, "Ground")
	for x = -40, -10, 6 do
		b:marker("Spawn", x, 0)
	end

	-- 1. A pit, then a step up
	b:block(37, -20, 64, 0, GROUND, "Ground")
	b:block(52, 0, 64, 5, GROUND, "Ground")

	-- 2. A lava field crossed on platforms
	b:block(64, -20, 124, 0, GROUND, "Ground")
	b:hazard(64, 0, 124, 1.5)
	b:platform(68, 78, 6, PLATFORM)
	b:platform(86, 96, 9, PLATFORM)
	b:platform(104, 114, 6, PLATFORM)
	b:block(124, -20, 150, 0, GROUND, "Ground")
	b:checkpoint(132, 0)

	-- 3. Moving platforms over a pit, out of step with each other
	b:move(b:platform(155, 165, 0, MOVING), Vector3.new(20, 0, 0), 4)
	b:move(b:platform(190, 200, 0, MOVING), Vector3.new(12, 0, 0), 3.2, math.pi)
	b:block(220, -20, 250, 0, GROUND, "Ground")
	b:checkpoint(228, 0)

	-- 4. Crumbling platforms over a pit
	b:crumbling(256, 266, 0)
	b:crumbling(273, 283, 3)
	b:crumbling(290, 300, 0)
	b:crumbling(307, 317, 3)
	b:block(324, -20, 462, 0, GROUND, "Ground")
	b:checkpoint(330, 0)

	-- 5. A wall too tall to jump, a launch pad to get over it, then a sprint past lava spikes
	b:jumpPad(338, 346, 0, 75)
	b:block(352, 0, 360, 22, GROUND)
	b:speedPad(366, 378, 0, 48, 2.5)
	b:hazard(390, 0, 393, 3)
	b:hazard(406, 0, 409, 3)
	b:finishLine(430, 0)
	b:block(456, -20, 462, 70, GROUND)

	return b:build("RushCourse")
end
