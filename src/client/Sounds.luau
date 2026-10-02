local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Plays the sounds listed in Config.Sounds, for this player only.
local Sounds = {}

local VOLUME = 0.6

local loaded: { [string]: Sound } = {}

function Sounds.play(name: string)
	local id = Config.Sounds[name]
	if not id then
		return
	end
	local sound = loaded[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Volume = VOLUME
		sound.Parent = SoundService
		loaded[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

return Sounds
