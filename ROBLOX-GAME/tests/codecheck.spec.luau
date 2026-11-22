local CodeCheck = require("../src/shared/CodeCheck")
local NetCheck = require("../src/shared/NetCheck")
local LessonSheet = require("../src/shared/LessonSheet")
LessonSheet.init(require("../src/shared/Answers"), CodeCheck, NetCheck)
local CampaignData = require("../src/shared/CampaignData")

return function(t)
	t.test("hello world in either quotes", function()
		t.eq(CodeCheck.grade("Hello, World!", 'print("Hello, World!")'), true)
		t.eq(CodeCheck.grade("Hello, World!", "print('Hello, World!')"), true)
		t.eq(CodeCheck.grade("Hello, World!", 'print("Hello World")'), false, "the comma matters")
		t.eq(CodeCheck.grade("Hello, World!", 'Print("Hello, World!")'), false, "Python is case sensitive")
	end)

	t.test("numbers print like Python", function()
		local out = CodeCheck.run("print(2 + 3)\nprint(7 / 2)\nprint(4 / 2)\nprint(7 // 2, 7 % 3, 2 ** 5)")
		t.eq(out and table.concat(out, "|"), "5|3.5|2.0|3 1 32")
	end)

	t.test("variables, += and str()", function()
		t.eq(CodeCheck.grade("42", "x = 7\nprint(x * 6)"), true)
		t.eq(CodeCheck.grade("Score: 10", 's = 4\ns += 6\nprint("Score: " + str(s))'), true)
		local out, err = CodeCheck.run('print("a" + 1)')
		t.eq(out, nil)
		t.truthy(err and string.find(err, "str()", 1, true), err)
	end)

	t.test("for loops with range", function()
		t.eq(CodeCheck.grade("1\n2\n3\n4\n5", "for i in range(1, 6):\n    print(i)"), true)
		t.eq(CodeCheck.grade("0\n2\n4", "for i in range(0, 6, 2):\n\tprint(i)"), true)
		t.eq(CodeCheck.grade("15", "total = 0\nfor i in range(1, 6):\n    total += i\nprint(total)"), true)
	end)

	t.test("mistakes give a message, never run anything", function()
		local _, err = CodeCheck.run("print(\"hi\"")
		t.truthy(err, "missing )")
		_, err = CodeCheck.run("import os")
		t.truthy(err)
		_, err = CodeCheck.run("print(y)")
		t.truthy(err and string.find(err, "not defined", 1, true), err)
		_, err = CodeCheck.run("for i in range(1000000):\n    print(i)")
		t.truthy(err, "endless loops stop")
		_, err = CodeCheck.run("    print(1)")
		t.truthy(err and string.find(err, "indent", 1, true), err)
		_, err = CodeCheck.run('x = "ab"\nfor i in range(40):\n    x = x + x\nprint(x)')
		t.truthy(err and string.find(err, "too long", 1, true), "strings cannot grow without end")
		_, err = CodeCheck.run('x = "ab" * 1000000')
		t.truthy(err and string.find(err, "too long", 1, true), err)
		_, err = CodeCheck.run("for i in range(3):\nprint(i)")
		t.truthy(err and string.find(err, "body", 1, true), err)
	end)

	t.test("cables: ports and end devices", function()
		local devices = { { id = "PC1", kind = "pc" }, { id = "PC2", kind = "pc" }, { id = "Switch", kind = "switch" },
			{ id = "Router", kind = "router" } }
		t.eq((NetCheck.canLink(devices, {}, "PC1", "PC2")), false, "PCs need a switch")
		t.eq((NetCheck.canLink(devices, { { "PC1", "Switch" } }, "PC1", "Router")), false, "one port on a PC")
		t.eq((NetCheck.canLink(devices, { { "PC1", "Switch" } }, "Switch", "PC1")), false, "no double cable")
		local required = { { "PC1", "Switch" }, { "PC2", "Switch" }, { "Switch", "Router" } }
		t.eq(NetCheck.grade(devices, required, { { "Router", "Switch" }, { "Switch", "PC2" }, { "PC1", "Switch" } }), true)
		t.eq(NetCheck.grade(devices, required, { { "PC1", "Switch" }, { "PC2", "Switch" } }), false, "one missing")
		t.eq(NetCheck.grade(devices, required, "nonsense"), false)
		t.eq(NetCheck.grade(devices, required, { { "PC1", 5 } }), false)
	end)

	-- A model answer for every programming task: the tasks must be solvable with what the checker knows.
	local SOLUTIONS = {
		["Hello, World!"] = 'print("Hello, World!")',
		["42"] = "x = 7\nprint(x * 6)",
		["1\n2\n3\n4\n5"] = "for i in range(1, 6):\n    print(i)",
		["Hello, Neumann"] = 'name = "Neumann"\nprint("Hello, " + name)',
		["55"] = "total = 0\nfor i in range(1, 11):\n    total += i\nprint(total)",
	}
	t.test("every programming task has a working model answer", function()
		for _, task in CampaignData.SUBJECTS.Programming.code or {} do
			t.truthy(SOLUTIONS[task.expect], task.text)
			t.eq(LessonSheet.check("code", task, SOLUTIONS[task.expect]), true, task.text)
		end
	end)

	t.test("every network task's own cables are valid and right", function()
		for _, task in CampaignData.SUBJECTS.Networks.network or {} do
			t.eq(LessonSheet.check("network", task, task.links), true, task.text)
			t.eq(LessonSheet.check("network", task, {}), false)
		end
	end)

	t.test("answer kinds per subject and difficulty", function()
		t.eq(LessonSheet.kindFor("written", "typed"), "written")
		t.eq(LessonSheet.kindFor("written", "choice"), "choice", "Easy ticks")
		t.eq(LessonSheet.kindFor("choice", "typed"), "choice", "Literature always ticks")
		t.eq(LessonSheet.kindFor("code", "choice"), "code")
		local kind, tasks = LessonSheet.build(CampaignData.SUBJECTS.Maths, "typed", 3, function(n)
			return n
		end)
		t.eq(kind, "written")
		t.eq(#tasks, 3)
		t.eq(LessonSheet.shown(kind, tasks[1]).options, nil, "no options on a written paper")
		local maths = CampaignData.SUBJECTS.Maths.questions[1]
		t.eq(LessonSheet.check("written", maths, "56"), true)
		t.eq(LessonSheet.check("choice", maths, 2), true)
		t.eq(LessonSheet.check("choice", maths, "2"), false)
		t.eq(LessonSheet.check("written", maths, string.rep("5", 500)), false, "too long")
	end)
end
