extends RefCounted
## Data behind the phone app e-Kréten, a copy of the e-Kréta school system. Pure functions and invented text only:
## nothing here names a real person. Section names follow the real app, the body text is English like the rest of the game.

const Lessons := preload("res://scripts/lessons.gd")

const SECTIONS := ["Órarend", "Értékelések", "Mulasztások", "Üzenetek"]
const STUDENT := "Class 11.A"
const SCHOOL := "Neumann school"

## Messages by the day they arrive: [day, sender, subject, text]. Senders are roles, never people.
const MESSAGES := [
	[1, "Headmaster's office", "Welcome back",
		"A new school week starts today. Timetables are in e-Kréten. Lessons start at 07:30. Please be on time."],
	[1, "Porta", "Keys and the board",
		"Classroom keys are signed out at the Porta against the time of the day. Return them the same day. Room 14 is not lent to students."],
	[1, "Class teacher", "Csoki",
		"The school dog has been seen near the Tornaterem again. Do not feed him from the canteen. Rubber toys are welcome."],
	[2, "Headmaster's office", "Substitute lessons",
		"Several colleagues and students are ill today. Check the timetable before every break: lessons may be taught by a substitute."],
	[2, "Caretaker", "Lab 14",
		"Lab 14 stays sealed after yesterday's incident. Whoever opens it without permission answers for it."],
	[2, "Secretariat", "Chemistry club",
		"The chemistry club has no meeting this week. The club's equipment has not been counted yet."],
	[3, "Headmaster's office", "Test day",
		"Every lesson today ends with a test. The grade counts double and is entered in e-Kréten the same day."],
	[3, "Porta", "New student cards",
		"New cards are handed out at the Porta today and the old ones expire at midnight. Bring a signed form from a first floor classroom."],
	[3, "Class teacher", "Please stay in groups",
		"Several of you reported noises and lights after the lessons. Do not walk the corridors alone."],
	[4, "Headmaster's office", "Extraordinary break",
		"Lessons are suspended until further notice. Students must leave the building. The attendance sheet is not kept."],
	[4, "Secretariat", "Missing persons list",
		"Three colleagues have not signed in for two days. Do not call their mobile numbers."],
	[5, "Headmaster's office", "(no subject)",
		"The server is down. This message was composed before the outage. It reached 11.A by mistake. Please ignore it."],
]


## Hungarian 1 to 5 scale from a quiz or test result: all right is 5, none right is 1.
static func grade_for(correct: int, total: int) -> int:
	if total <= 0:
		return 1
	return clampi(1 + roundi(4.0 * float(correct) / float(total)), 1, 5)


## "Témazáró" for the day 3 test (counts double), "Röpdolgozat" for the short quizzes of days 1 and 2.
static func kind_of(entry: Dictionary, test_day: int) -> String:
	return "Témazáró" if int(entry["day"]) == test_day else "Röpdolgozat"


## Grade average with the test counted double. Returns 0.0 without grades.
static func average(grades: Array, test_day: int) -> float:
	var sum := 0.0
	var weight := 0.0
	for entry: Dictionary in grades:
		var w := 2.0 if int(entry["day"]) == test_day else 1.0
		sum += w * grade_for(int(entry["correct"]), int(entry["total"]))
		weight += w
	return sum / weight if weight > 0.0 else 0.0


## Messages that have arrived by `day`, newest first.
static func messages(day: int) -> Array:
	var out: Array = []
	for m: Array in MESSAGES:
		if int(m[0]) <= day:
			out.append(m)
	out.reverse()
	return out


## Today's lessons as dictionaries: {time, subject, room, teacher, status}. `status` is "done", "missed",
## "cancelled" or "" (still ahead or running). Empty on days without lessons.
static func timetable(campaign: Node) -> Array:
	var rows: Array = []
	if campaign.day > campaign.LAST_SCHOOL_DAY:
		return rows
	var attended: Array = campaign.attended_lessons()
	var missed: Array = []
	for a: Dictionary in campaign.absences:
		if int(a["day"]) == campaign.day:
			missed.append(int(a["lesson"]))
	for i in campaign.LESSONS:
		var subject: String = Lessons.subject_at(campaign.day, i)
		var teacher_id: String = Lessons.teacher_of(subject, campaign.day)
		var status := ""
		if attended.has(i):
			status = "done"
		elif missed.has(i):
			status = "missed"
		elif campaign.incident and campaign.day == campaign.INCIDENT_DAY and i > campaign.INCIDENT_BREAK:
			status = "cancelled"
		rows.append({
			"time": campaign.fmt(campaign.lesson_start(i)), "subject": subject, "room": Lessons.room_of(subject),
			"teacher": Lessons.TEACHER_NAMES[teacher_id], "status": status,
			"sick": campaign.sick.has(teacher_id),
		})
	return rows
