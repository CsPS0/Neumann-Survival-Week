--!strict
-- Campaign difficulty: how long and how demanding a run is. Every difficulty number lives here.

export type Level = {
	name: string,
	label: string,
	lessons: number, -- lessons held before the explosion
	quizCount: number,
	quizMode: "choice" | "typed",
	skipLimit: number, -- skips that expel a player (math.huge = never)
	clues: number,
	guidance: "exact" | "task" | "vague",
	chaseSpeed: number, -- entity, metres per second
	sight: number, -- entity sight range, metres
	hintInterval: number, -- seconds between the entity sensing its target (0 = never)
	revive: boolean, -- caught at night = downed and revivable (solo: wake at the entrance)
	caretaker: "off" | "afternoon" | "night",
	notes: number, -- notes carrying the safe code
	ritual: number, -- seconds to survive at the altar
	paceScale: number, -- multiplies the clock pace
}

local Difficulty = {}

Difficulty.LEVELS = {
	easy = {
		name = "easy", label = "Easy", lessons = 3, quizCount = 2, quizMode = "choice", skipLimit = math.huge,
		clues = 6, guidance = "exact", chaseSpeed = 3.0, sight = 10, hintInterval = 0, revive = true,
		caretaker = "off", notes = 2, ritual = 25, paceScale = 1.6,
	},
	normal = {
		name = "normal", label = "Normal", lessons = 4, quizCount = 3, quizMode = "typed", skipLimit = 3,
		clues = 9, guidance = "task", chaseSpeed = 4.2, sight = 15, hintInterval = 15, revive = false,
		caretaker = "afternoon", notes = 4, ritual = 40, paceScale = 1,
	},
	hard = {
		name = "hard", label = "Hard", lessons = 7, quizCount = 4, quizMode = "typed", skipLimit = 2,
		clues = 9, guidance = "vague", chaseSpeed = 4.6, sight = 15, hintInterval = 10, revive = false,
		caretaker = "night", notes = 4, ritual = 60, paceScale = 0.55,
	},
} :: { [string]: Level }

function Difficulty.get(name: string?): Level
	return Difficulty.LEVELS[name or "normal"] or Difficulty.LEVELS.normal
end

return Difficulty
