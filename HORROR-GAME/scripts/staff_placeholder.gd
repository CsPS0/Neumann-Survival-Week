extends RefCounted
## Stand-in for the gitignored scripts/staff.gd (see scripts/staff_source.gd). Every name here is invented and shares no
## surname with the suspects in lessons.gd. Same shape as the real file: [name, role, subjects, homeroom class].

const ROSTER := [
	["Bárdos Kinga", "director", "matematika", ""],
	["Csányi Lőrinc", "deputy", "angol nyelv", ""],
	["Dombi Réka", "deputy", "magyar nyelv, irodalom", ""],
	["Erdős Tamás", "specialist", "szakmai tárgyak", "11.a"],
	["Gombos Viola", "specialist", "szakmai tárgyak", "9.c"],
	["Hegyi Áron", "specialist", "szakmai tárgyak", ""],
	["Juhász Nóra", "teacher", "történelem", "10.b"],
	["Kende Balázs", "teacher", "fizika", ""],
	["Lengyel Dóra", "teacher", "matematika", "9.a"],
	["Mohácsi Gergő", "teacher", "testnevelés", ""],
	["Nemes Panna", "teacher", "német nyelv", "11.c"],
	["Orbán Csaba", "teacher", "informatika", ""],
	["Rácz Emese", "teacher", "biológia", ""],
	["Sárközi Dávid", "teacher", "kémia", ""],
	["Tóth Lilla", "support", "", ""],
	["Vincze Ottó", "support", "", ""],
]

## Gender tags for the invented names above and the eight suspects in lessons.gd.
const GENDER := {
	"Bárdos Kinga": "f", "Csányi Lőrinc": "m", "Dombi Réka": "f", "Erdős Tamás": "m", "Gombos Viola": "f",
	"Hegyi Áron": "m", "Juhász Nóra": "f", "Kende Balázs": "m", "Lengyel Dóra": "f", "Mohácsi Gergő": "m",
	"Nemes Panna": "f", "Orbán Csaba": "m", "Rácz Emese": "f", "Sárközi Dávid": "m", "Tóth Lilla": "f",
	"Vincze Ottó": "m",
	"Kárpáti Lajos": "m", "Dr. Szentgyörgyi Aranka": "f", "Halmos Ervin": "m", "Vörös Ildikó": "f",
	"Pásztor Margit": "f", "Ónodi Bence": "m", "Fekete Zsombor": "m", "Lázár Tivadar": "m",
}


## The homeroom teacher of the class, or "" when it has none.
static func homeroom_teacher(class_id: String) -> String:
	for p: Array in ROSTER:
		if p[3] == class_id:
			return p[0]
	return ""


## "f" or "m" for a known name, else a stable guess from the name.
static func gender_of(person: String) -> String:
	if GENDER.has(person):
		return GENDER[person]
	return "f" if person.hash() % 2 == 0 else "m"
