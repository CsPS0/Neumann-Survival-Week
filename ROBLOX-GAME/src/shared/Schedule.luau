--!strict
-- The campaign day in game minutes after midnight (campaign.gd, docs/2026-11-22-campaign-story-design.md): arrive,
-- lessons and breaks, the explosion after the last lesson and the 20 minute time slip, the afternoon (everyone is
-- sent home, the guard searches), and the night from 18:00 until 06:00 the next morning.

local Schedule = {}

Schedule.OPEN = 390 -- 06:30
Schedule.FIRST_BELL = 450 -- 07:30
Schedule.LESSON = 45
Schedule.BREAK = 10
Schedule.GRACE = 2
Schedule.AFTERNOON = 780 -- 13:00, after the explosion
Schedule.SLIP = 20 -- the minutes nobody remembers after the explosion
Schedule.DUSK = 1080 -- 18:00, nightfall
Schedule.END = 1800 -- 06:00 next day

-- Game minutes per real second (before the difficulty scale).
local PACE = {
	arrive = 0.6,
	grace = 0.12,
	lesson = 0.8,
	["break"] = 0.12,
	afternoon = 1.2,
	night = 0.75,
	over = 0,
}

function Schedule.lessonStart(i: number): number
	return Schedule.FIRST_BELL + i * (Schedule.LESSON + Schedule.BREAK)
end

function Schedule.lessonEnd(i: number): number
	return Schedule.lessonStart(i) + Schedule.LESSON
end

-- Lab 14 explodes when the last lesson ends.
function Schedule.explosionAt(count: number): number
	return Schedule.lessonEnd(count - 1)
end

-- The first `count` subjects of a timetable row (CampaignData.TIMETABLES[n]).
function Schedule.pickLessons(row: { string }, count: number): { string }
	local out = {}
	for i = 1, math.min(count, #row) do
		out[i] = row[i]
	end
	return out
end

function Schedule.lessonAt(m: number, count: number): number?
	for i = 0, count - 1 do
		if m >= Schedule.lessonStart(i) and m < Schedule.lessonEnd(i) then
			return i
		end
	end
	return nil
end

function Schedule.phaseAt(m: number, count: number, exploded: boolean): string
	if m >= Schedule.END then
		return "over"
	end
	if exploded then
		return if m >= Schedule.DUSK then "night" else "afternoon"
	end
	if m < Schedule.FIRST_BELL then
		return "arrive"
	end
	local i = Schedule.lessonAt(m, count)
	if i then
		return if m < Schedule.lessonStart(i) + Schedule.GRACE then "grace" else "lesson"
	end
	return "break"
end

function Schedule.pace(phase: string, scale: number): number
	return (PACE[phase] or 1) * scale
end

-- "07:30"
function Schedule.format(m: number): string
	local t = math.floor(m) % 1440
	return string.format("%02d:%02d", t // 60, t % 60)
end

return Schedule
