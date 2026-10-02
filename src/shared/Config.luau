local RunService = game:GetService("RunService")

-- Rules and tuning shared by the server and clients. Speeds are in studs per second.
local Config = {}

-- In Studio a round can start with one player, so you can test alone.
Config.TESTING = RunService:IsStudio()
Config.MIN_PLAYERS = if Config.TESTING then 1 else 2

-- Round timings, in seconds.
Config.LOBBY_COUNTDOWN = 5 -- once everyone is in the ready zone
Config.ROUND_COUNTDOWN = 3 -- frozen in the arena before GO
Config.ROUND_TIME = 120 -- whoever is still on the arena when time runs out shares the win
Config.WINNER_TIME = 6

-- Balls. Each brainrot's class sets its weight, speed and bounce (see Brainrots).
Config.BALL_SIZE = 7
Config.MOMENTUM_BONUS = 0.4 -- top speed grows by up to this fraction while rolling straight
Config.MOMENTUM_BUILD_TIME = 3 -- seconds of uninterrupted rolling to build full momentum
Config.AIR_CONTROL = 0.35 -- fraction of steering force available in the air
Config.IDLE_DAMPING = 0.8 -- slows a ball on the ground when nobody is steering it
Config.BRAKE_STRENGTH = 3
Config.JUMP_SPEED = 60
Config.SLAM_DIVE_SPEED = 80 -- using the ability in the air dives you down first
Config.BOOST_SPEED = 45
Config.BOOST_COST = 35 -- out of a 100-point meter
Config.BOOST_REGEN = 18 -- meter points per second
Config.BOOST_TIME = 0.6 -- collisions hit harder for this long after boosting

-- Collisions. The faster ball pushes harder; heavier classes push harder and get pushed less.
Config.MIN_IMPACT_SPEED = 10 -- approach speed below which a bump does nothing extra
Config.KNOCKBACK_SCALE = 0.9 -- knockback speed per stud/second of impact
Config.KNOCKBACK_BASE = 8
Config.KNOCKBACK_LIFT = 0.3 -- how much knockback points upward
Config.BOOST_KNOCKBACK = 1.5 -- multiplier while boosted
Config.MAX_KNOCKBACK = 170

-- The ability every brainrot has for now: a shockwave that pushes everyone nearby away.
Config.SLAM_COOLDOWN = 6
Config.SLAM_RADIUS = 22
Config.SLAM_PUSH = 75
Config.SLAM_LIFT = 35

-- Pinball bumpers, tagged "Bumper".
Config.BUMPER_PUSH = 90

-- Faster than this is treated as an exploit and the ball is put back.
Config.MAX_LEGIT_SPEED = 450

-- Built-in Roblox sounds. Swap in sound ids from the Creator Store for better ones.
Config.Sounds = {
	Jump = "rbxasset://sounds/action_jump.mp3",
	Boost = "rbxasset://sounds/swoosh.wav",
	Impact = "rbxasset://sounds/collide.wav",
	Slam = "rbxasset://sounds/impact_water.mp3",
	Eliminated = "rbxasset://sounds/action_falling.mp3",
	Beep = "rbxasset://sounds/electronicpingshort.wav",
}

return Config
