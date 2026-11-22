local Rules = require("../src/shared/Rules")

local P = {
	walk = 3,
	sprint = 5.5,
	seeker = 4.2,
	staminaMax = 100,
	staminaDrain = 20,
	staminaRegen = 12.5,
	staminaDelay = 1,
	staminaResume = 30,
}

return function(t)
	t.test("free roam starts with anyone", function()
		t.eq((Rules.canStart("freeroam", "none", 1)), true)
		t.eq((Rules.canStart("freeroam", "none", 0)), false)
	end)
	t.test("canStart", function()
		t.eq((Rules.canStart("deduction", "player", 2)), false)
		t.eq((Rules.canStart("deduction", "player", 3)), true)
		t.eq((Rules.canStart("deduction", "computer", 5)), false)
		t.eq((Rules.canStart("hideseek", "player", 1)), false)
		t.eq((Rules.canStart("hideseek", "computer", 1)), true)
		t.eq((Rules.canStart("campaign", "none", 1)), true) -- solo story
		t.eq((Rules.canStart("campaign", "none", 0)), false)
		local _, reason = Rules.canStart("deduction", "player", 2)
		t.eq(reason, "Social Deduction needs at least 3 players.")
	end)
	t.test("entityCount", function()
		t.eq(Rules.entityCount(7, 8), 1)
		t.eq(Rules.entityCount(8, 8), 2)
	end)
	t.test("hideSeekResult", function()
		t.eq(Rules.hideSeekResult({ a = "alive", b = "downed" }, false), nil)
		t.eq(Rules.hideSeekResult({ a = "downed", b = "out" }, false), "entity")
		t.eq(Rules.hideSeekResult({}, false), "entity") -- everyone left
		t.eq(Rules.hideSeekResult({ a = "alive", b = "out" }, true), "survivors")
	end)
	t.test("deductionResult", function()
		t.eq(Rules.deductionResult(0, 3, false), "crew")
		t.eq(Rules.deductionResult(1, 1, false), "entity")
		t.eq(Rules.deductionResult(2, 2, false), "entity")
		t.eq(Rules.deductionResult(1, 2, true), "crew")
		t.eq(Rules.deductionResult(1, 2, false), nil)
	end)
	t.test("tallyVotes", function()
		t.eq((Rules.tallyVotes({ a = "c", b = "c", c = "a" }, 3)), "c") -- 2 > 1.5
		t.eq((Rules.tallyVotes({ a = "c", b = "a" }, 4)), nil) -- tie, too few
		t.eq((Rules.tallyVotes({ a = "skip", b = "skip", c = "a" }, 3)), nil) -- skip never ejects
		t.eq((Rules.tallyVotes({ a = "c", b = "c" }, 3)), "c") -- a voter left: living is 3
		local _, counts = Rules.tallyVotes({ a = "skip", b = "c" }, 3)
		t.eq(counts.skip, 1)
		t.eq(counts.c, 1)
	end)
	t.test("takedown and meeting timing", function()
		t.eq(Rules.takedownReadyAt(100, nil, 20, 30), 120)
		t.eq(Rules.takedownReadyAt(100, 150, 20, 30), 180)
		t.eq(Rules.canCallMeeting(114, 100, false, 15), false)
		t.eq(Rules.canCallMeeting(115, 100, false, 15), true)
		t.eq(Rules.canCallMeeting(200, 100, true, 15), false)
	end)
	t.test("stamina", function()
		local s = Rules.newStamina(100)
		for _ = 1, 50 do
			Rules.stepStamina(s, true, true, 0.1, P)
		end
		t.near(s.value, 0, 0.01)
		t.eq(s.exhausted, true)
		t.eq(Rules.stepStamina(s, true, true, 0.1, P), false) -- exhausted: no sprint
		for _ = 1, 10 do
			Rules.stepStamina(s, false, true, 0.1, P)
		end
		t.truthy(s.value < 1.3, "delay holds regen")
		for _ = 1, 26 do
			Rules.stepStamina(s, false, true, 0.1, P)
		end
		t.eq(s.exhausted, false)
		t.truthy(s.value >= 30 and s.value < 34, "back above resume")
		t.eq(Rules.stepStamina(s, true, false, 0.1, P), false) -- standing still is not sprinting
	end)
	t.test("flashHits", function()
		local o, look = { X = 0, Y = 0, Z = 0 }, { X = 0, Y = 0, Z = -1 }
		t.eq(Rules.flashHits(o, look, { X = 0, Y = 0, Z = -8 }, 9, 35), true)
		t.eq(Rules.flashHits(o, look, { X = 0, Y = 0, Z = -10 }, 9, 35), false)
		t.eq(Rules.flashHits(o, look, { X = 6, Y = 0, Z = -6 }, 9, 35), false) -- 45 degrees off
		t.eq(Rules.flashHits(o, look, { X = 0, Y = 0, Z = 5 }, 9, 35), false) -- behind
	end)
end
