local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Profile = require(script.Parent.Profile)

-- Plays the sounds listed in Config.Sounds, for this player only, unless they've turned sound
-- effects off in Settings.
local Sounds = {}

local VOLUME = 0.6

local loaded: { [string]: Sound } = {}

function Sounds.play(name: string)
	local id = Config.Sounds[name]
	if not id or not Profile.setting("sfx") then
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
