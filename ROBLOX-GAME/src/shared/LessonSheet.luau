--!strict
-- The test paper of one lesson: which tasks a student gets, what the client is shown and how an answer is marked.
-- Pure rules shared by the server (src/server/Campaign/Lessons.luau) and the tests.
--   choice  - tick one of the options (Literature, History, English; every written subject on Easy)
--   written - write the answer on the paper (Maths, Physics)
--   code    - write a small program on the PC (Programming)
--   network - cable the devices on the desk (Networks)

local LessonSheet = {}

-- Shared modules use no `require` (AGENTS.md): whoever uses this hands it the checkers once.
local Answers: any, CodeCheck: any, NetCheck: any = nil, nil, nil
function LessonSheet.init(answers: any, codeCheck: any, netCheck: any)
	Answers, CodeCheck, NetCheck = answers, codeCheck, netCheck
end

LessonSheet.MAX_WRITTEN = 120

-- How this subject is answered at this difficulty ("choice" | "typed" quiz mode from Difficulty).
function LessonSheet.kindFor(subjectKind: string, quizMode: string): string
	if subjectKind == "choice" or (subjectKind == "written" and quizMode == "choice") then
		return "choice"
	end
	return subjectKind
end

-- `count` tasks for a subject, shuffled with `random(n)` (math.random). Returns the kind and the tasks.
function LessonSheet.build(subject: any, quizMode: string, count: number, random: (number) -> number): (string, { any })
	local kind = LessonSheet.kindFor(subject.kind or "choice", quizMode)
	local pool: { any }
	if kind == "code" and subject.code then
		pool = table.clone(subject.code)
	elseif kind == "network" and subject.network then
		pool = table.clone(subject.network)
	else
		kind = if kind == "code" or kind == "network" then "choice" else kind
		pool = table.clone(subject.questions)
	end
	for k = #pool, 2, -1 do
		local j = random(k)
		pool[k], pool[j] = pool[j], pool[k]
	end
	local tasks = {}
	for k = 1, math.min(count, #pool) do
		tasks[k] = pool[k]
	end
	return kind, tasks
end

-- What the student sees of a task (never the answer of a choice or written question).
function LessonSheet.shown(kind: string, task: any): any
	if kind == "choice" then
		return { text = task.text, options = task.options }
	elseif kind == "written" then
		return { text = task.text }
	elseif kind == "code" then
		return { text = task.text, expect = task.expect, starter = task.starter or "" }
	end
	return { text = task.text, devices = task.devices }
end

-- Is `answer` (from a client: any value) right for the task?
function LessonSheet.check(kind: string, task: any, answer: any): boolean
	if kind == "choice" then
		return type(answer) == "number" and answer == task.correct
	elseif kind == "written" then
		return type(answer) == "string" and #answer <= LessonSheet.MAX_WRITTEN and Answers.isCorrect(task, answer)
	elseif kind == "code" then
		return type(answer) == "string" and #answer <= 2000 and CodeCheck.grade(task.expect, answer)
	elseif kind == "network" then
		return NetCheck.grade(task.devices, task.links, answer)
	end
	return false
end

-- How an answer is written on the physical paper on the desk (what others see).
function LessonSheet.written(kind: string, task: any, answer: any): string
	if kind == "choice" and type(answer) == "number" and task.options and task.options[answer] then
		return task.options[answer]
	elseif (kind == "written" or kind == "code") and type(answer) == "string" then
		local line = string.split(answer, "\n")[1] or ""
		return if #line > 40 then string.sub(line, 1, 40) .. "..." else line
	elseif kind == "network" and type(answer) == "table" then
		return `{#answer} cables`
	end
	return "?"
end

return LessonSheet
