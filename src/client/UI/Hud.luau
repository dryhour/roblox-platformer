local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModeInfo = require(Shared:WaitForChild("ModeInfo"))
local Text = require(Shared:WaitForChild("Text"))
local Widgets = require(script.Parent.Widgets)

-- During a game: the top bar (which game, the timer, your role and status), the rules card
-- shown before play starts, and the announcement feed.
local Hud = {}

-- Seconds an announcement stays before fading.
local ANNOUNCEMENT_TIME = 3

local ROLES = {
	Attacker = { label = "ATTACKER", intro = "You are the ATTACKER", color = Widgets.BAD },
	Survivor = { label = "SURVIVOR", intro = "You are a SURVIVOR", color = Widgets.GOOD },
	Eliminated = { label = "ELIMINATED", intro = "", color = Widgets.MUTED },
}

local CENTER = Enum.TextXAlignment.Center

function Hud.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild("MatchState")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Top bar

	local top = Widgets.panel({
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(340, 0),
		Parent = gui,
	})
	local title = Widgets.label("", 14, { LayoutOrder = 1, TextColor3 = Widgets.MUTED, TextXAlignment = CENTER, Parent = top })
	local timer = Widgets.label("", 36, { LayoutOrder = 2, TextXAlignment = CENTER, Parent = top })
	local status = Widgets.label("", 18, { LayoutOrder = 3, TextXAlignment = CENTER, Parent = top })

	-- Rules card

	local intro = Widgets.panel({
		Name = "Intro",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(480, 0),
		Parent = gui,
	})
	local introCategory = Widgets.label("", 14, { LayoutOrder = 1, TextColor3 = Widgets.ACCENT, TextXAlignment = CENTER, Parent = intro })
	local introName = Widgets.label("", 40, { LayoutOrder = 2, TextXAlignment = CENTER, Parent = intro })
	local introObjective = Widgets.label("", 20, { LayoutOrder = 3, TextXAlignment = CENTER, Parent = intro })
	local introRole = Widgets.label("", 22, { LayoutOrder = 4, TextXAlignment = CENTER, Parent = intro })
	local introRules = Widgets.label("", 15, { LayoutOrder = 5, Font = Widgets.FONT_REGULAR, Parent = intro })
	local introScoring = Widgets.label("", 15, {
		LayoutOrder = 6,
		Font = Widgets.FONT_REGULAR,
		TextColor3 = Widgets.MUTED,
		Parent = intro,
	})
	local introCountdown = Widgets.label("", 16, { LayoutOrder = 7, TextColor3 = Widgets.ACCENT, TextXAlignment = CENTER, Parent = intro })

	-- Announcements

	local feed = Widgets.stack({
		Name = "Announcements",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(520, 0),
		Parent = gui,
	}, 4)
	local announcementCount = 0
	remotes.Announce.OnClientEvent:Connect(function(message: string)
		announcementCount += 1
		local line = Widgets.label(message, 20, {
			LayoutOrder = announcementCount,
			TextXAlignment = CENTER,
			TextStrokeTransparency = 0.3,
			Parent = feed,
		})
		task.delay(ANNOUNCEMENT_TIME, function()
			local fade = TweenService:Create(line, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			line:Destroy()
		end)
	end)

	local function refresh()
		local phase = state:GetAttribute("Phase")
		local info = ModeInfo.byId[state:GetAttribute("ModeId") or ""]
		top.Visible = info ~= nil and (phase == "Intro" or phase == "Playing")
		intro.Visible = info ~= nil and phase == "Intro"
		if not info then
			return
		end

		title.Text = string.format(
			"GAME %d OF %d  ·  %s",
			state:GetAttribute("GameNumber") or 1,
			state:GetAttribute("GameCount") or 1,
			string.upper(info.name)
		)

		local role = ROLES[player:GetAttribute("Role") or ""]
		local detail = player:GetAttribute("Status") or ""
		if role then
			status.Text = if detail ~= "" then `{role.label}  ·  {detail}` else role.label
			status.TextColor3 = role.color
		else
			status.Text = detail
			status.TextColor3 = Widgets.TEXT
		end
		status.Visible = status.Text ~= ""

		introCategory.Text = string.upper(info.category)
		introName.Text = info.name
		introObjective.Text = info.objective
		introRole.Text = if role then role.intro else ""
		introRole.TextColor3 = if role then role.color else Widgets.TEXT
		introRole.Visible = introRole.Text ~= ""
		introRules.Text = "•  " .. table.concat(info.rules, "\n•  ")
		introScoring.Text = info.scoring
	end

	local function tick()
		local phase = state:GetAttribute("Phase")
		local left = (state:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()
		if phase == "Playing" then
			timer.Text = Text.clock(left)
			timer.TextColor3 = if left <= 10 then Widgets.BAD else Widgets.TEXT
		elseif phase == "Intro" then
			-- Show the full game length until play starts.
			timer.Text = Text.clock(state:GetAttribute("GameTime") or 0)
			timer.TextColor3 = Widgets.TEXT
			introCountdown.Text = `Starting in {math.max(1, math.ceil(left))}`
		end
	end

	return { refresh = refresh, tick = tick }
end

return Hud
