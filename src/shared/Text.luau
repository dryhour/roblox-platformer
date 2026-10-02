-- Formatting helpers for text shown to players.
local Text = {}

-- 83.2 -> "1:24"
function Text.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Text
