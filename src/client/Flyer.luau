local Players = game:GetService("Players")

-- While your avatar has a flyer under it (the server welds one on; see src/server/Avatars.luau),
-- plays Roblox's sitting pose so you ride it instead of walking on it.
local Flyer = {}

local SIT_ANIMATION = "rbxassetid://2506281703" -- the R15 sit pose from Roblox's Animate script

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if not animator or not animator:IsA("Animator") then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = SIT_ANIMATION
	local track: AnimationTrack? = nil

	local function refresh()
		local riding = character:FindFirstChild("Flyer") ~= nil
		if riding and not track then
			local newTrack = animator:LoadAnimation(animation)
			newTrack.Priority = Enum.AnimationPriority.Action
			newTrack.Looped = true
			newTrack:Play()
			track = newTrack
		elseif not riding and track then
			track:Stop()
			track = nil
		end
	end
	character.ChildAdded:Connect(refresh)
	character.ChildRemoved:Connect(refresh)
	refresh()
end

function Flyer.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return Flyer
