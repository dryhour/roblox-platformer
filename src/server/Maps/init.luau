local ServerStorage = game:GetService("ServerStorage")

local Characters = require(script.Parent.Characters)

-- Loads a map into Workspace as "Map", replacing the previous one, and wires up the parts that
-- behave the same in every map (see "Making maps" in the README).
--
-- A Model in ServerStorage.Maps (from src/maps, or built in Studio) is used if it has the
-- requested name; otherwise the map is built by the module of that name in this folder.
local Maps = {}

-- Seconds a FallingPlatform holds after it's touched, and how long it stays gone.
local CRUMBLE_DELAY = 0.5
local CRUMBLE_RESPAWN = 3
local CRUMBLE_COLOR = Color3.fromRGB(255, 80, 60)

local rng = Random.new()

local function killOnTouch(part: BasePart)
	part.Touched:Connect(function(hit)
		local player = Characters.playerFromPart(hit)
		if player then
			Characters.kill(player)
		end
	end)
end

local function crumbleOnTouch(part: BasePart)
	local color = part.Color
	local busy = false
	part.Touched:Connect(function(hit)
		if busy or not Characters.playerFromPart(hit) then
			return
		end
		busy = true
		part.Color = CRUMBLE_COLOR
		task.wait(CRUMBLE_DELAY)
		part.Transparency = 1
		part.CanCollide = false
		task.wait(CRUMBLE_RESPAWN)
		part.Transparency = 0
		part.CanCollide = true
		part.Color = color
		busy = false
	end)
end

local function build(name: string): Model
	local folder = ServerStorage:FindFirstChild("Maps")
	local prebuilt = folder and folder:FindFirstChild(name)
	if prebuilt and prebuilt:IsA("Model") then
		return prebuilt:Clone()
	end
	local builder = script:FindFirstChild(name)
	assert(builder and builder:IsA("ModuleScript"), `No map named {name}`)
	return (require(builder) :: () -> Model)()
end

function Maps.load(name: string): Model
	-- Also clears a stale Map left in the place file by an older version of the project.
	for _, child in workspace:GetChildren() do
		if child.Name == "Map" then
			child:Destroy()
		end
	end

	local map = build(name)
	map.Name = "Map"
	-- Keep the whole map loaded on every client even if the place uses streaming.
	map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "Hazard" then
				killOnTouch(part)
			elseif part.Name == "FallingPlatform" then
				crumbleOnTouch(part)
			end
		end
	end
	map.Parent = workspace
	return map
end

-- Where a character should appear to stand on the bottom face of `part`, facing right.
function Maps.standAt(part: BasePart): CFrame
	local position = part.Position - Vector3.new(0, part.Size.Y / 2 - 4, 0)
	return CFrame.lookAt(position, position + Vector3.xAxis)
end

-- All parts in the map with exactly this name.
function Maps.markers(map: Model, name: string): { BasePart }
	local found = {}
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") and part.Name == name then
			table.insert(found, part)
		end
	end
	return found
end

-- Spawn positions from parts whose names start with `prefix`, in random order.
function Maps.spawnPoints(map: Model, prefix: string): { CFrame }
	local points = {}
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") and string.sub(part.Name, 1, #prefix) == prefix then
			table.insert(points, Maps.standAt(part))
		end
	end
	if #points == 0 then
		warn(`Map has no parts named {prefix}*; spawning at the origin`)
		table.insert(points, CFrame.new(0, 10, 0))
	end
	rng:Shuffle(points)
	return points
end

return Maps
