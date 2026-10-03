extends Node
## Campaign state: day, school schedule, bells, quiz and clue stats, who the entity is, and which ending the run
## reached. Pure logic: main.gd connects it to the world (room check, UI, teachers, entity).

signal day_started(day: int)
signal bell(kind: String, index: int)       ## "lesson_end" (a break starts), "last_bell", "caretaker".
signal lesson_started(index: int)           ## The player is in the room in time: run the quiz.
signal lesson_missed(index: int)
signal hunt_started
signal ending(id: int)
signal event(name: String, data: Dictionary)  ## Feeds achievements.
signal stats_changed

const Lessons := preload("res://scripts/lessons.gd")
const Clues := preload("res://scripts/clues.gd")

const OPEN := 360.0
const FIRST_BELL := 450.0
const LESSON_LEN := 45.0
const BREAK_LEN := 10.0
const LESSONS := 7
const GRACE := 2.0
const LAST_BELL := 825.0
const CARETAKER_DELAY := 30.0
const NIGHT_OWL := 1080.0
const CLOSING := 1320.0
const LAST_SCHOOL_DAY := 3
const FINAL_DAY := 5
const SKIP_LIMIT := 6
const PACE_PRE := 0.5
const PACE_BREAK := 0.133
const PACE_SKIPPED := 1.0
const PACE_FREE := 2.0
const ENCOUNTERS := {
	1: {1: "glimpse", 4: "glimpse"},
	2: {0: "glimpse", 2: "chase", 3: "glimpse", 5: "chase"},
	3: {0: "chase", 2: "chase", 3: "glimpse", 4: "chase"},
}

var day := 1
var player: Node
var daynight: Node
var quest: Node
var room_check := Callable()    ## (lesson index) -> bool: is the player inside that lesson's room?
var culprit := ""               ## npc id of the teacher who is the entity.
var hunt_active := false
var ending_id := 0
var attended := 0
var skipped := 0
var right := 0
var total := 0
var clues: Array[String] = []
var blackouts := 0

var _resolved: Array[bool] = []
var _ended: Array[bool] = []
var _last_bell_sent := false
var _caretaker_sent := false
var _early_sent := false
var _day_attended := 0
var _day_perfect := true
var _blackout_pending := false
var _attended_today: Array[int] = []


func _ready() -> void:
	add_to_group("campaign")
	culprit = Lessons.TEACHER_NAMES.keys().pick_random()


static func lesson_start(i: int) -> float:
	return FIRST_BELL + i * (LESSON_LEN + BREAK_LEN)


static func lesson_end(i: int) -> float:
	return lesson_start(i) + LESSON_LEN


## Index of the lesson running at `m`, or -1.
static func lesson_at(m: float) -> int:
	for i in LESSONS:
		if m >= lesson_start(i) and m < lesson_end(i):
			return i
	return -1


static func phase_at(m: float, on_day: int) -> String:
	if on_day > LAST_SCHOOL_DAY:
		return "hunt"
	if m >= CLOSING:
		return "closed"
	if m >= LAST_BELL:
		return "after"
	if m < FIRST_BELL:
		return "pre"
	return "lesson" if lesson_at(m) >= 0 else "break"


static func fmt(m: float) -> String:
	var t := int(m) % 1440
	return "%02d:%02d" % [t / 60, t % 60]


## `m` is only needed for "lesson": the attendance grace after a bell runs at break pace (GRACE = about 15 real s).
func _pace(phase: String, m := 0.0) -> float:
	match phase:
		"pre": return PACE_PRE
		"break": return PACE_BREAK
		"lesson":
			var i := lesson_at(m)
			return PACE_BREAK if i >= 0 and not _resolved[i] and m < lesson_start(i) + GRACE else PACE_SKIPPED
	return PACE_FREE


func lethal() -> bool:
	return day > LAST_SCHOOL_DAY


## What the entity does in the break that follows lesson `break_index` (0..5): "", "glimpse" or "chase".
static func encounter_for(on_day: int, break_index: int) -> String:
	return ENCOUNTERS.get(on_day, {}).get(break_index, "")


func chase_speed() -> float:
	return [3.0, 3.6, 4.0][day - 1] if day <= LAST_SCHOOL_DAY else 4.2


func quiz_ratio() -> float:
	return float(right) / float(total) if total > 0 else 0.0


func start_day(n: int) -> void:
	day = n
	_resolved.assign(_flags())
	_ended.assign(_flags())
	_last_bell_sent = false
	_caretaker_sent = false
	_early_sent = false
	_day_attended = 0
	_day_perfect = true
	_attended_today.clear()
	daynight.start_day()
	daynight.minutes_per_second = _pace("hunt" if n > LAST_SCHOOL_DAY else "pre")
	day_started.emit(n)
	event.emit("day_started", {"day": n})
	stats_changed.emit()


func _flags() -> Array[bool]:
	var flags: Array[bool] = []
	flags.resize(LESSONS)
	flags.fill(false)
	return flags


func _process(_delta: float) -> void:
	if ending_id != 0 or not daynight.running:
		return
	var m: float = daynight.minutes
	daynight.minutes_per_second = _pace(phase_at(m, day), m)
	if day <= LAST_SCHOOL_DAY:
		_tick_school(m)
	if ending_id == 0 and m >= CLOSING:
		_close_day()


func _tick_school(m: float) -> void:
	for i in LESSONS:
		if not _resolved[i] and m >= lesson_start(i):
			if m < lesson_start(i) + GRACE and room_check.is_valid() and room_check.call(i):
				_resolved[i] = true
				lesson_started.emit(i)
				return
			if m >= lesson_start(i) + GRACE:
				_resolved[i] = true
				skipped += 1
				lesson_missed.emit(i)
				stats_changed.emit()
				if skipped >= SKIP_LIMIT:
					_end(3)
					return
		if not _ended[i] and m >= lesson_end(i):
			_ended[i] = true
			bell.emit("lesson_end", i)
	if not _early_sent and m < FIRST_BELL - 30.0 and room_check.is_valid() and room_check.call(0):
		_early_sent = true
		event.emit("early_bird", {})
	if not _last_bell_sent and m >= LAST_BELL:
		_last_bell_sent = true
		bell.emit("last_bell", -1)
	if not _caretaker_sent and m >= LAST_BELL + CARETAKER_DELAY:
		_caretaker_sent = true
		bell.emit("caretaker", -1)


func _close_day() -> void:
	if day <= LAST_SCHOOL_DAY:
		_end(3)
	elif day < FINAL_DAY:
		start_day(day + 1)
	else:
		_end(7)


func finish_lesson(i: int, correct: int, n: int) -> void:
	if ending_id != 0:
		return
	attended += 1
	right += correct
	total += n
	_day_attended += 1
	_attended_today.append(i)
	_day_perfect = _day_perfect and correct == n
	if _day_attended == LESSONS:
		event.emit("model_student", {})
		if _day_perfect:
			event.emit("straight_a", {})
	if _blackout_pending:
		_blackout_pending = false
		event.emit("close_call", {})
	daynight.minutes = maxf(daynight.minutes, lesson_end(i))
	daynight.running = true
	stats_changed.emit()


## Front door: go home after the last bell on a school day, otherwise run away for good.
func use_front_door() -> void:
	if ending_id != 0:
		return
	if day <= LAST_SCHOOL_DAY and daynight.minutes >= LAST_BELL:
		if daynight.minutes >= NIGHT_OWL:
			event.emit("night_owl", {})
		start_day(day + 1)
	else:
		_end(5)


func player_killed() -> void:
	if lethal():
		_end(1)


func accuse(id: String) -> bool:
	if ending_id != 0:
		return false
	if id != culprit:
		_end(8)
		return false
	hunt_active = true
	event.emit("right_suspect", {})
	hunt_started.emit()
	return true


func ritual_completed() -> void:
	_end(4 if quiz_ratio() >= 0.8 and clues.size() >= 9 else 2)


func make_deal() -> void:
	_end(6)


func record_blackout() -> void:
	if ending_id != 0:
		return
	blackouts += 1
	_blackout_pending = true
	daynight.minutes += 20.0
	for i in LESSONS:   # Lessons lost to the blackout are excused, not skipped.
		if daynight.minutes >= lesson_start(i) + GRACE:
			_resolved[i] = true
		if daynight.minutes >= lesson_end(i):
			_ended[i] = true
	event.emit("blackout", {})
	stats_changed.emit()


func add_clue(text: String) -> void:
	clues.append(text)
	if clues.size() == 9:
		event.emit("detective", {})
	stats_changed.emit()


## Teacher dialogue: small talk on school days (the entity slips more each day), the story on hunt days.
func dialogue(id: String) -> Array[String]:
	if day > LAST_SCHOOL_DAY and quest:
		return quest.dialogue(id)
	var lines: Array[String] = [Clues.chat(id)]
	if id == culprit:
		lines.append(Clues.strange(day))
	return lines


func stats() -> Dictionary:
	return {"day": day, "right": right, "total": total, "clues": clues.size(), "skipped": skipped,
			"attended": attended, "blackouts": blackouts}


func _end(id: int) -> void:
	if ending_id != 0:
		return
	ending_id = id
	daynight.running = false
	ending.emit(id)
	event.emit("ending", {"id": id})


# --- Text for the HUD and the phone -------------------------------------------

func objective() -> String:
	var m: float = daynight.minutes
	match phase_at(m, day):
		"pre":
			return "Before school: look around. First lesson at %s (%s, room %s)." % [
				fmt(FIRST_BELL), Lessons.subject_at(day, 0), Lessons.room_of(Lessons.subject_at(day, 0))]
		"lesson":
			return "Lesson time. Be in the room, or you skip it."
		"break":
			var next := _next_lesson(m)
			return "Break: search for clues. Next: %s, room %s at %s." % [
				Lessons.subject_at(day, next), Lessons.room_of(Lessons.subject_at(day, next)), fmt(lesson_start(next))] \
				if next >= 0 else "Break: search for clues."
		"after":
			return "School is over. Go home through the front door, or stay and risk being expelled."
		"hunt":
			if not hunt_active:
				return "Press G to name the entity. Read the clues on your phone first."
			return quest.hint() if quest else ""
	return ""


func phone_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.assign(["DAY %d  timetable" % day])
	for i in LESSONS:
		var subject: String = Lessons.subject_at(day, i)
		var mark := "[x]" if _attended_today.has(i) else ("[-]" if _resolved[i] else "[ ]")
		lines.append("%s %s  %s  rm %s" % [mark, fmt(lesson_start(i)), subject, Lessons.room_of(subject)])
	lines.append("")
	lines.append("skipped %d/%d   quiz %d/%d" % [skipped, SKIP_LIMIT, right, total])
	return lines


func _next_lesson(m: float) -> int:
	for i in LESSONS:
		if lesson_start(i) > m:
			return i
	return -1


func expel() -> void:
	_end(3)
