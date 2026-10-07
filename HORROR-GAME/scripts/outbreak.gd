extends RefCounted
## From day 2 people fall ill. Data and pure functions only: who is sick, and what the sick teachers say.
## The demon's host is never ill, so "who is never sick" is a clue.

const Lessons := preload("res://scripts/lessons.gd")

const FIRST_DAY := 2
const TEACHERS := {2: 2, 3: 3, 4: 4, 5: 4}
const STUDENT_RATE := {2: 0.25, 3: 0.4, 4: 0.5, 5: 0.5}


## The ill teachers on `day`. The order is fixed per culprit, so everyone who is ill on day 2 is still ill on day 3.
static func sick_teachers(culprit: String, day: int) -> Array[String]:
	var out: Array[String] = []
	if day < FIRST_DAY:
		return out
	var pool: Array[String] = []
	for id: String in Lessons.SUSPECT_IDS:
		if id != culprit:
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(culprit)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for i in mini(int(TEACHERS.get(day, 0)), pool.size()):
		out.append(pool[i])
	return out


## Share of the students who are ill on `day` (0 on school days before day 2).
static func student_rate(day: int) -> float:
	return float(STUDENT_RATE.get(day, 0.0))


static func sick_lines(id: String, day: int) -> Array[String]:
	var name: String = Lessons.TEACHER_NAMES[id]
	var lines: Array[String] = []
	lines.append("%s: *coughs* My hands are ice cold and I keep dreaming about the chemistry lab." % name)
	lines.append("%s: I was in the corridor by room 14 when it blew. Since then I cannot get warm." % name)
	lines.append("%s: Half the school is ill. Only one of us still looks perfectly well. Odd, is it not?" % name)
	if day >= 3:
		lines.append("%s: Do not talk to me too long. Whatever is in the building feeds on the sick." % name)
	return lines
