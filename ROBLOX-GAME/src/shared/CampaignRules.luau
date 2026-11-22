--!strict
-- Team rules of the campaign: skips, the team quiz ratio, which ending a run reaches, votes, quest order and the
-- objective line at each guidance level.

local CampaignRules = {}

-- One more skip for a player; true when that expels them.
function CampaignRules.skip(skips: number, limit: number): (number, boolean)
	local n = skips + 1
	return n, n >= limit
end

function CampaignRules.ratio(right: number, total: number): number
	return if total > 0 then right / total else 0
end

function CampaignRules.ritualEnding(destroy: boolean, ratio: number, clues: number, cluesNeeded: number): number
	if destroy then
		return 9
	end
	return if ratio >= 0.8 and clues >= cluesNeeded then 4 else 2
end

-- The ending when nobody is left, by the way the last player went out.
function CampaignRules.allOutEnding(lastWay: string): number
	if lastWay == "caught" then
		return 1
	elseif lastWay == "expelled" then
		return 3
	end
	return 5
end

-- votes: voter -> option index. The option with more than half of the living players, or nil.
function CampaignRules.voteOutcome(votes: { [any]: number }, living: number): number?
	local counts: { [number]: number } = {}
	for _, option in votes do
		counts[option] = (counts[option] or 0) + 1
	end
	for option, n in counts do
		if n > living / 2 then
			return option
		end
	end
	return nil
end

-- At the deadline: the option with the most votes; a tie between the leaders is broken by random(n) (1..n).
function CampaignRules.voteAtDeadline(votes: { [any]: number }, random: (number) -> number): number?
	local counts: { [number]: number } = {}
	for _, option in votes do
		counts[option] = (counts[option] or 0) + 1
	end
	local best, leaders = 0, {}
	for option, n in counts do
		if n > best then
			best, leaders = n, { option }
		elseif n == best then
			table.insert(leaders, option)
		end
	end
	if #leaders == 0 then
		return nil
	end
	table.sort(leaders)
	return leaders[random(#leaders)]
end

export type QuestState = {
	haveKey: boolean,
	redOpened: boolean,
	fusePlaced: boolean,
	vialTaken: boolean,
	notes: number,
	notesNeeded: number,
	safeOpen: boolean,
	altar: { salt: boolean, vial: boolean, bell: boolean },
}

function CampaignRules.questStep(q: QuestState): string
	if not q.haveKey then
		return "redkey"
	elseif not q.redOpened then
		return "redroom"
	elseif not q.fusePlaced then
		return "fuse"
	elseif not q.vialTaken then
		return "vial"
	elseif q.notes < q.notesNeeded then
		return "notes"
	elseif not q.safeOpen then
		return "safe"
	elseif not (q.altar.salt and q.altar.vial and q.altar.bell) then
		return "altar"
	end
	return "ritual"
end

export type ObjectiveState = {
	phase: string,
	nextLesson: { subject: string, room: string }?,
	clueRoom: string?,
	cluesFound: number,
	cluesNeeded: number,
	accused: boolean,
	questStep: string?,
	questRoom: string?,
}

local QUEST_TASK = {
	redkey = "Ask the porter at the Porta for the storage key.",
	redroom = "Open the red room and take the salt and the fuse.",
	fuse = "Put the fuse in the fuse box.",
	vial = "Take the holy water from the Lab 14 cabinet.",
	notes = "Find the notes with the safe code.",
	safe = "Open the old safe with the code.",
	altar = "Place the salt, the holy water and the bell on the altar in the Aula.",
	ritual = "Start the ritual at the altar and survive it.",
}

-- The HUD and phone objective. "exact" names rooms, "task" names the task only, "vague" gives one line a phase.
function CampaignRules.objective(s: ObjectiveState, guidance: string): string
	local vague = guidance == "vague"
	local exact = guidance == "exact"
	if s.phase == "arrive" or s.phase == "break" or s.phase == "grace" or s.phase == "lesson" then
		if s.phase == "lesson" then
			return "Lesson time: be in the room, or you skip it."
		end
		if vague then
			return "Go to your lessons. Keep your eyes open."
		end
		local line = ""
		if s.nextLesson then
			line = if exact then `Next lesson: {s.nextLesson.subject}, room {s.nextLesson.room}.`
				else `Next lesson: {s.nextLesson.subject}.`
		end
		if s.cluesFound < s.cluesNeeded then
			local clue = if exact and s.clueRoom then ` Clue in room {s.clueRoom}.` else " Look for clues."
			line ..= clue
		end
		return line
	elseif s.phase == "afternoon" then
		if vague then
			return "Find out who it is."
		end
		local line = `The school emptied. Clues found: {s.cluesFound}/{s.cluesNeeded}. At 18:00, name the entity together.`
		if exact and s.clueRoom and s.cluesFound < s.cluesNeeded then
			line ..= ` Next clue: room {s.clueRoom}.`
		end
		return line
	elseif s.phase == "accusation" then
		return "Name the entity: vote together."
	elseif s.phase == "night" then
		if vague then
			return "Banish it before morning."
		end
		local task = QUEST_TASK[s.questStep or ""] or "Survive the night."
		if exact and s.questRoom then
			task ..= ` (room {s.questRoom})`
		end
		return task
	end
	return ""
end

return CampaignRules
