extends RefCounted
## Subjects, their rooms and teachers, quiz questions and the 3 school-day timetables. Data only.

const TEACHER_NAMES := {
	"karpati": "Kárpáti Lajos", "szentgyorgyi": "Dr. Szentgyörgyi Aranka", "halmos": "Halmos Ervin",
	"voros": "Vörös Ildikó", "pasztor": "Pásztor Margit", "onodi": "Ónodi Bence",
	"fekete": "Fekete Zsombor", "lazar": "Lázár Tivadar",
}
## Accusation order. All of them are invented; none appears in the staff roster.
const SUSPECT_IDS := ["karpati", "szentgyorgyi", "halmos", "voros", "pasztor", "onodi", "fekete", "lazar"]

## subject -> [room label, floor, teacher id (or [ids] rotating by day), [[question, [4 options], correct index, [extra accepted answers]], ...]]
## Typed answers match the correct option or any extra answer after `normalize`; the options are only shown in choice mode.
const SUBJECTS := {
	"Maths": ["23", 0, ["karpati", "szentgyorgyi"], [
		["What is 7 x 8?", ["54", "56", "63", "48"], 1, []],
		["Solve: x + 9 = 20", ["x = 9", "x = 11", "x = 29", "x = 10"], 1, ["11"]],
		["What is 15% of 200?", ["15", "20", "30", "25"], 2, []],
		["Derivative of x squared?", ["x", "2x", "x squared", "2"], 1, []]]],
	"Literature": ["113", 1, "voros", [
		["Who wrote 'The Raven'?", ["Poe", "Petőfi", "Dickens", "Wilde"], 0, ["Edgar Allan Poe", "Edgar Poe"]],
		["A comparison using 'like' or 'as' is a...", ["metaphor", "simile", "rhyme", "pun"], 1, []],
		["Who wrote 'Toldi'?", ["Arany János", "Jókai Mór", "Ady Endre", "Kosztolányi"], 0, ["Arany", "János Arany"]],
		["How many lines does a sonnet have?", ["10", "12", "14", "16"], 2, ["fourteen"]]]],
	"Programming": ["GT11-12", 0, "onodi", [
		["Which loop runs while a condition holds?", ["for-each", "while", "switch", "try"], 1, ["while loop"]],
		["What does 'int x = 5 / 2;' store in C#?", ["2.5", "3", "2", "0"], 2, []],
		["Which is NOT a loop keyword?", ["for", "while", "foreach", "when"], 3, []],
		["An array index usually starts at...", ["0", "1", "-1", "2"], 0, ["zero"]]]],
	"Physics": ["28", 0, "halmos", [
		["Unit of force?", ["Joule", "Newton", "Watt", "Pascal"], 1, ["N", "newtons"]],
		["Speed of light is about...", ["300 km/s", "3000 km/s", "300 000 km/s", "30 000 km/s"], 2, ["300000", "299792", "299792 km/s"]],
		["Ohm's law: U = ?", ["I / R", "I x R", "R / I", "I + R"], 1, ["R x I", "I * R", "R * I", "I times R", "IR"]],
		["What does a fuse protect against?", ["Cold", "Overcurrent", "Noise", "Rust"], 1, ["over current", "too much current", "excess current", "overload", "short circuit"]]]],
	"History": ["109", 1, "lazar", [
		["Year of the Hungarian 1848 revolution?", ["1818", "1848", "1867", "1914"], 1, []],
		["Who was the first king of Hungary?", ["Saint Stephen", "Matthias", "Árpád", "Louis I"], 0, ["Stephen", "Szent István", "István", "St. Stephen", "Stephen I"]],
		["The Battle of Mohács was in...", ["1456", "1526", "1686", "1241"], 1, []],
		["The Compromise (Kiegyezés) was in...", ["1848", "1867", "1920", "1900"], 1, []]]],
	"English": ["121", 1, "pasztor", [
		["Past tense of 'go'?", ["goed", "went", "gone", "going"], 1, []],
		["'Their', 'there' or 'they're': '___ going home.'", ["Their", "There", "They're", "Theyre"], 2, ["they are"]],
		["Plural of 'child'?", ["childs", "childes", "children", "child"], 2, []],
		["Which is a question word?", ["because", "where", "under", "while"], 1, []]]],
	"Networks": ["GT2", 0, "fekete", [
		["Default port of HTTP?", ["21", "80", "443", "25"], 1, ["port 80"]],
		["What does DNS do?", ["Encrypts data", "Names to addresses", "Sends mail", "Blocks ads"], 1, ["name to address", "names to IP addresses", "translates names to addresses", "domain names to IP addresses"]],
		["An IPv4 address has how many bytes?", ["2", "4", "6", "8"], 1, ["four"]],
		["Which device connects different networks?", ["Switch", "Hub", "Router", "Cable"], 2, ["a router"]]]],
}

const ACCENTS := {
	"á": "a", "é": "e", "í": "i", "ó": "o", "ö": "o", "ő": "o", "ú": "u", "ü": "u", "ű": "u", "ä": "a", "ß": "ss",
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


## Lower case, accents folded, only letters, digits and + - * / = ^ kept: "Arany  János" and "arany janos" match, "I x R" and "I / R" do not.
static func normalize(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		c = ACCENTS.get(c, c)
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or "+-*/=^".contains(c):
			out += c
	return out


## True when `typed` is the correct option or one of the question's extra accepted answers.
static func is_correct(question: Array, typed: String) -> bool:
	var given := normalize(typed)
	if given.is_empty():
		return false
	var accepted: Array = [question[1][question[2]]]
	if question.size() > 3:
		accepted.append_array(question[3])
	for answer: String in accepted:
		if normalize(answer) == given:
			return true
	return false
