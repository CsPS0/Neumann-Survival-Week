--!strict
-- Typed quiz answers, as lessons.gd: lower case, accents folded, only letters, digits and + - * / = ^ kept, so
-- "Arany  János" and "arany janos" match while "I x R" and "I / R" do not.

local Answers = {}

local ACCENTS = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ö"] = "o", ["ő"] = "o", ["ú"] = "u", ["ü"] = "u",
	["ű"] = "u", ["ä"] = "a", ["ß"] = "ss",
	["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ö"] = "o", ["Ő"] = "o", ["Ú"] = "u", ["Ü"] = "u",
	["Ű"] = "u",
}

function Answers.normalize(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		local c = utf8.char(code)
		c = ACCENTS[c] or string.lower(c)
		if string.match(c, "^[a-z0-9%+%-%*/=%^]$") then
			table.insert(out, c)
		end
	end
	return table.concat(out)
end

export type Question = { text: string, options: { string }, correct: number, extra: { string } }

function Answers.isCorrect(question: Question, typed: string): boolean
	local given = Answers.normalize(typed)
	if given == "" then
		return false
	end
	if Answers.normalize(question.options[question.correct]) == given then
		return true
	end
	for _, extra in question.extra do
		if Answers.normalize(extra) == given then
			return true
		end
	end
	return false
end

return Answers
