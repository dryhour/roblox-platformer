local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Movement = require(script.Parent.Movement)

-- Map parts that each client runs for itself, so they respond instantly for the player:
--   * parts with a MoveOffset attribute slide back and forth (see Builder.move on the server)
--   * parts with a Spin attribute spin around the vertical axis (coins)
--   * JumpPad parts launch the local character; SpeedPad parts speed it up
local MapEffects = {}

-- Seconds before the same player can be launched by a pad again.
local PAD_COOLDOWN = 0.4

type Mover = { origin: CFrame, offset: Vector3, period: number, phase: number }
type Spinner = { origin: CFrame, speed: number }

function MapEffects.start()
	local player = Players.LocalPlayer
	local movers: { [BasePart]: Mover } = {}
	local spinners: { [BasePart]: Spinner } = {}
	local lastPadAt = -math.huge

	local function isLocalCharacter(part: BasePart): boolean
		local character = player.Character
		return character ~= nil and part:IsDescendantOf(character)
	end

	local function track(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local part = instance

		local offset = part:GetAttribute("MoveOffset")
		if typeof(offset) == "Vector3" then
			movers[part] = {
				origin = part.CFrame,
				offset = offset,
				period = part:GetAttribute("MovePeriod") or 4,
				phase = part:GetAttribute("MovePhase") or 0,
			}
		end

		local spin = part:GetAttribute("Spin")
		if typeof(spin) == "number" then
			spinners[part] = { origin = part.CFrame, speed = spin }
		end

		if part.Name == "JumpPad" then
			part.Touched:Connect(function(hit)
				if isLocalCharacter(hit) and os.clock() - lastPadAt > PAD_COOLDOWN then
					lastPadAt = os.clock()
					Movement.launch(part:GetAttribute("Power") or 80)
				end
			end)
		elseif part.Name == "SpeedPad" then
			part.Touched:Connect(function(hit)
				if isLocalCharacter(hit) then
					Movement.boost(part:GetAttribute("Speed") or 45, part:GetAttribute("Duration") or 2.5)
				end
			end)
		end
	end

	local function watch(child: Instance)
		if child.Name == "Map" then
			for _, descendant in child:GetDescendants() do
				track(descendant)
			end
			child.DescendantAdded:Connect(track)
		end
	end
	workspace.ChildAdded:Connect(watch)
	for _, child in workspace:GetChildren() do
		watch(child)
	end

	RunService.PreSimulation:Connect(function()
		-- Server time keeps every client's platforms in the same place.
		local now = workspace:GetServerTimeNow()
		for part, mover in movers do
			if not part.Parent then
				movers[part] = nil
				continue
			end
			local angularSpeed = 2 * math.pi / mover.period
			local angle = angularSpeed * now + mover.phase
			part.CFrame = mover.origin + mover.offset * ((1 - math.cos(angle)) / 2)
			-- Moving the part by CFrame doesn't carry characters standing on it; velocity does.
			part.AssemblyLinearVelocity = mover.offset * (math.sin(angle) * angularSpeed / 2)
		end
		for part, spinner in spinners do
			if not part.Parent then
				spinners[part] = nil
				continue
			end
			part.CFrame = CFrame.new(spinner.origin.Position)
				* CFrame.Angles(0, now * spinner.speed, 0)
				* spinner.origin.Rotation
		end
	end)
end

return MapEffects
