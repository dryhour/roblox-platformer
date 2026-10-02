-- Formatting helpers for text shown to players.
local Text = {}

-- 1 -> "1st", 2 -> "2nd", 11 -> "11th"
function Text.ordinal(n: number): string
	local lastTwo = n % 100
	if lastTwo >= 11 and lastTwo <= 13 then
		return n .. "th"
	end
	return n .. (({ "st", "nd", "rd" })[n % 10] or "th")
end

-- 83.2 -> "1:24"
function Text.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- (1, "coin") -> "1 coin", (3, "coin") -> "3 coins"
function Text.count(n: number, noun: string): string
	return n .. " " .. noun .. (if n == 1 then "" else "s")
end

return Text
