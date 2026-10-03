extends RefCounted
## Subjects, their rooms and teachers, quiz questions and the 3 school-day timetables. Data only.

const TEACHER_NAMES := {
	"karpati": "Kárpáti Lajos", "szentgyorgyi": "Dr. Szentgyörgyi Aranka", "halmos": "Halmos Ervin",
	"voros": "Vörös Ildikó", "pasztor": "Pásztor Margit", "onodi": "Ónodi Bence",
	"fekete": "Fekete Zsombor", "lazar": "Lázár Tivadar",
}
## Accusation order. All of them are invented; none appears in the staff roster.
const SUSPECT_IDS := ["karpati", "szentgyorgyi", "halmos", "voros", "pasztor", "onodi", "fekete", "lazar"]

## subject -> [room label, floor, teacher id (or [ids] rotating by day), [[question, [4 options], correct index], ...]]
const SUBJECTS := {
	"Maths": ["23", 0, ["karpati", "szentgyorgyi"], [
		["What is 7 x 8?", ["54", "56", "63", "48"], 1],
		["Solve: x + 9 = 20", ["x = 9", "x = 11", "x = 29", "x = 10"], 1],
		["What is 15% of 200?", ["15", "20", "30", "25"], 2],
		["Derivative of x squared?", ["x", "2x", "x squared", "2"], 1]]],
	"Literature": ["113", 1, "voros", [
		["Who wrote 'The Raven'?", ["Poe", "Petőfi", "Dickens", "Wilde"], 0],
		["A comparison using 'like' or 'as' is a...", ["metaphor", "simile", "rhyme", "pun"], 1],
		["Who wrote 'Toldi'?", ["Arany János", "Jókai Mór", "Ady Endre", "Kosztolányi"], 0],
		["How many lines does a sonnet have?", ["10", "12", "14", "16"], 2]]],
	"Programming": ["GT11-12", 0, "onodi", [
		["Which loop runs while a condition holds?", ["for-each", "while", "switch", "try"], 1],
		["What does 'int x = 5 / 2;' store in C#?", ["2.5", "3", "2", "0"], 2],
		["Which is NOT a loop keyword?", ["for", "while", "foreach", "when"], 3],
		["An array index usually starts at...", ["0", "1", "-1", "2"], 0]]],
	"Physics": ["28", 0, "halmos", [
		["Unit of force?", ["Joule", "Newton", "Watt", "Pascal"], 1],
		["Speed of light is about...", ["300 km/s", "3000 km/s", "300 000 km/s", "30 000 km/s"], 2],
		["Ohm's law: U = ?", ["I / R", "I x R", "R / I", "I + R"], 1],
		["What does a fuse protect against?", ["Cold", "Overcurrent", "Noise", "Rust"], 1]]],
	"History": ["109", 1, "lazar", [
		["Year of the Hungarian 1848 revolution?", ["1818", "1848", "1867", "1914"], 1],
		["Who was the first king of Hungary?", ["Saint Stephen", "Matthias", "Árpád", "Louis I"], 0],
		["The Battle of Mohács was in...", ["1456", "1526", "1686", "1241"], 1],
		["The Compromise (Kiegyezés) was in...", ["1848", "1867", "1920", "1900"], 1]]],
	"English": ["121", 1, "pasztor", [
		["Past tense of 'go'?", ["goed", "went", "gone", "going"], 1],
		["'Their', 'there' or 'they're': '___ going home.'", ["Their", "There", "They're", "Theyre"], 2],
		["Plural of 'child'?", ["childs", "childes", "children", "child"], 2],
		["Which is a question word?", ["because", "where", "under", "while"], 1]]],
	"Networks": ["GT2", 0, "fekete", [
		["Default port of HTTP?", ["21", "80", "443", "25"], 1],
		["What does DNS do?", ["Encrypts data", "Names to addresses", "Sends mail", "Blocks ads"], 1],
		["An IPv4 address has how many bytes?", ["2", "4", "6", "8"], 1],
		["Which device connects different networks?", ["Switch", "Hub", "Router", "Cable"], 2]]],
}

const TIMETABLES := [
	["Maths", "Literature", "Programming", "Physics", "History", "English", "Networks"],
	["Programming", "Maths", "English", "History", "Networks", "Physics", "Literature"],
	["Physics", "English", "Maths", "Networks", "Literature", "Programming", "History"],
]


static func subject_at(day: int, lesson: int) -> String:
	return TIMETABLES[clampi(day, 1, 3) - 1][lesson]


static func room_of(subject: String) -> String:
	return SUBJECTS[subject][0]


static func floor_of(subject: String) -> int:
	return SUBJECTS[subject][1]


## A subject's teacher id; a subject with two teachers alternates by day (1: first, 2: second, 3: first).
static func teacher_of(subject: String, day := 1) -> String:
	var teacher: Variant = SUBJECTS[subject][2]
	if teacher is Array:
		return teacher[(day - 1) % teacher.size()]
	return teacher


static func quiz(subject: String, count := 3) -> Array:
	var pool: Array = SUBJECTS[subject][3].duplicate()
	pool.shuffle()
	return pool.slice(0, count)
