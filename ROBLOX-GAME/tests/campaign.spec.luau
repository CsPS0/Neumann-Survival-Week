local Answers = require("../src/shared/Answers")
local CampaignData = require("../src/shared/CampaignData")
local CampaignRules = require("../src/shared/CampaignRules")
local Difficulty = require("../src/shared/Difficulty")
local Schedule = require("../src/shared/Schedule")

return function(t)
	t.test("difficulty levels", function()
		local e, n, h = Difficulty.get("easy"), Difficulty.get("normal"), Difficulty.get("hard")
		t.eq(e.lessons, 3)
		t.eq(n.lessons, 4)
		t.eq(h.lessons, 7)
		t.eq(e.quizMode, "choice")
		t.eq(h.quizCount, 4)
		t.eq(e.skipLimit, math.huge)
		t.eq(n.skipLimit, 3)
		t.eq(e.clues, 6)
		t.eq(e.revive, true)
		t.eq(h.ritual, 60)
		t.eq(e.notes, 2)
		t.eq(Difficulty.get("nonsense").name, "normal")
	end)

	t.test("every suspect has a look and an entity mark", function()
		for _, id in CampaignData.SUSPECTS do
			local look = CampaignData.LOOKS[id]
			t.truthy(look, "look for " .. id)
			t.eq(#look.jacket, 3, "jacket rgb " .. id)
			t.eq(#look.trousers, 3, "trousers rgb " .. id)
			t.truthy(CampaignData.ENTITY_MARKS[id], "mark for " .. id)
		end
	end)

	t.test("campaign data sizes and invented names", function()
		local ids = 0
		local seen = {}
		for id, name in CampaignData.TEACHERS do
			ids += 1
			t.truthy(not seen[name], "duplicate name " .. name)
			seen[name] = true
			t.eq(#CampaignData.TRAITS[id], 10)
			t.truthy(CampaignData.CHAT[id] ~= nil)
		end
		t.eq(ids, 8)
		t.eq(#CampaignData.SUSPECTS, 8)
		local subjects = 0
		for _, s in CampaignData.SUBJECTS do
			subjects += 1
			t.eq(#s.questions, 4)
			for _, q in s.questions do
				t.truthy(q.correct >= 1 and q.correct <= 4)
			end
		end
		t.eq(subjects, 7)
		t.eq(#CampaignData.TIMETABLES, 3)
		t.eq(#CampaignData.TIMETABLES[1], 7)
		t.eq(#CampaignData.ENDINGS, 9)
		t.eq(CampaignData.teacherOf("Maths", 1), "karpati")
		t.eq(CampaignData.teacherOf("Maths", 2), "szentgyorgyi")
	end)

	t.test("schedule times and phases", function()
		t.eq(Schedule.lessonStart(0), 450)
		t.eq(Schedule.lessonEnd(0), 495)
		t.eq(Schedule.lessonStart(1), 505)
		t.eq(Schedule.phaseAt(400, 4, false, false), "arrive")
		t.eq(Schedule.phaseAt(451, 4, false, false), "grace")
		t.eq(Schedule.phaseAt(460, 4, false, false), "lesson")
		t.eq(Schedule.phaseAt(498, 4, false, false), "break")
		t.eq(Schedule.phaseAt(800, 4, true, false), "afternoon")
		t.eq(Schedule.phaseAt(1080, 4, true, false), "accusation")
		t.eq(Schedule.phaseAt(1200, 4, true, true), "night")
		t.eq(Schedule.phaseAt(1740, 4, true, true), "over")
		t.eq(Schedule.explosionAt(4), Schedule.lessonEnd(3))
		local picked = Schedule.pickLessons(CampaignData.TIMETABLES[2], 3)
		t.eq(#picked, 3)
		t.eq(picked[1], "Programming")
		t.eq(Schedule.pace("accusation", 1), 0)
		t.near(Schedule.pace("lesson", 0.5), 0.4, 1e-9)
	end)

	t.test("typed answers like Godot", function()
		local raven = CampaignData.SUBJECTS.Literature.questions[3] -- Toldi
		t.eq(Answers.isCorrect(raven, "Arany  János"), true)
		t.eq(Answers.isCorrect(raven, "arany janos"), true)
		t.eq(Answers.isCorrect(raven, "Jókai Mór"), false)
		local ohm = CampaignData.SUBJECTS.Physics.questions[3]
		t.eq(Answers.isCorrect(ohm, "I x R"), true)
		t.eq(Answers.isCorrect(ohm, "IR"), true)
		t.eq(Answers.isCorrect(ohm, "I / R"), false)
		t.eq(Answers.isCorrect(ohm, ""), false)
		t.eq(Answers.normalize("Ő é ű!"), "oeu")
	end)

	t.test("skips and endings", function()
		local n, out = CampaignRules.skip(2, 3)
		t.eq(n, 3)
		t.eq(out, true)
		local _, never = CampaignRules.skip(10, math.huge)
		t.eq(never, false)
		t.eq(CampaignRules.ratio(0, 0), 0)
		t.eq(CampaignRules.ritualEnding(true, 1, 9, 9), 9)
		t.eq(CampaignRules.ritualEnding(false, 0.85, 9, 9), 4)
		t.eq(CampaignRules.ritualEnding(false, 0.85, 8, 9), 2)
		t.eq(CampaignRules.ritualEnding(false, 0.5, 9, 9), 2)
		t.eq(CampaignRules.allOutEnding("caught"), 1)
		t.eq(CampaignRules.allOutEnding("expelled"), 3)
		t.eq(CampaignRules.allOutEnding("ranaway"), 5)
	end)

	t.test("votes always end", function()
		t.eq(CampaignRules.voteOutcome({ a = 2, b = 2 }, 3), 2) -- votes map voter -> option
		t.eq(CampaignRules.voteOutcome({ a = 1, b = 2 }, 2), nil)
		t.eq(CampaignRules.voteOutcome({ a = 1 }, 3), nil)
		t.eq(CampaignRules.voteAtDeadline({ a = 1, b = 3, c = 3 }, function(n) return n end), 3)
		t.eq(CampaignRules.voteAtDeadline({ a = 1, b = 2 }, function() return 1 end), 1)
		t.eq(CampaignRules.voteAtDeadline({ a = 1, b = 2 }, function(n) return n end), 2)
		t.eq(CampaignRules.voteAtDeadline({}, function() return 1 end), nil)
	end)

	t.test("quest steps in order", function()
		local q = { haveKey = false, redOpened = false, fusePlaced = false, vialTaken = false, notes = 0,
			notesNeeded = 4, safeOpen = false, altar = { salt = false, vial = false, bell = false } }
		t.eq(CampaignRules.questStep(q), "redkey")
		q.haveKey = true
		t.eq(CampaignRules.questStep(q), "redroom")
		q.redOpened = true
		t.eq(CampaignRules.questStep(q), "fuse")
		q.fusePlaced = true
		t.eq(CampaignRules.questStep(q), "vial")
		q.vialTaken = true
		t.eq(CampaignRules.questStep(q), "notes")
		q.notes = 4
		t.eq(CampaignRules.questStep(q), "safe")
		q.safeOpen = true
		t.eq(CampaignRules.questStep(q), "altar")
		q.altar = { salt = true, vial = true, bell = true }
		t.eq(CampaignRules.questStep(q), "ritual")
	end)

	t.test("objective guidance levels", function()
		local s = { phase = "break", nextLesson = { subject = "Physics", room = "28" }, cluesFound = 2, cluesNeeded = 9,
			accused = false }
		t.truthy(string.find(CampaignRules.objective(s, "exact"), "28", 1, true) ~= nil)
		t.truthy(string.find(CampaignRules.objective(s, "task"), "Physics", 1, true) ~= nil)
		t.truthy(string.find(CampaignRules.objective(s, "task"), "28", 1, true) == nil)
		local night = { phase = "night", accused = true, questStep = "fuse", questRoom = "24", cluesFound = 9, cluesNeeded = 9 }
		t.truthy(string.find(CampaignRules.objective(night, "exact"), "24", 1, true) ~= nil)
		t.truthy(string.find(CampaignRules.objective(night, "vague"), "24", 1, true) == nil)
	end)
end
