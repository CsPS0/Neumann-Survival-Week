extends SceneTree
var fails := 0
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

const Staff := preload("res://scripts/staff.gd")

func _run() -> void:
	check(Staff.ROSTER.size() == 79, "79 people")
	var roles := {}
	for p: Array in Staff.ROSTER:
		roles[p[1]] = int(roles.get(p[1], 0)) + 1
		check(p.size() == 4 and String(p[0]) != "" and p[2] is Array, "well-formed row " + String(p[0]))
	check(roles == {"director": 1, "deputy": 4, "specialist": 36, "teacher": 31, "support": 7}, "role counts: %s" % str(roles))
	var homerooms := {}
	for p: Array in Staff.ROSTER:
		if String(p[3]) != "":
			homerooms[p[3]] = p[0]
	check(homerooms.size() == 21, "21 homeroom classes, got %d" % homerooms.size())
	check(Staff.homeroom_teacher("9.a") == "Kiss Renáta", "9.a homeroom")
	check(Staff.homeroom_teacher("9.ny") == "Erdős Gábor", "NYEK homeroom")
	check(Staff.homeroom_teacher("99.z") == "", "unknown class")
	check(Staff.surname("Dr Farkas József") == "Farkas" and Staff.surname("Dr. Kiss Eleonóra") == "Kiss", "titles stripped")
	check(Staff.surname("Kiss Renáta") == "Kiss", "surname first")
	check(Staff.is_real_name("Simon Tibor") and not Staff.is_real_name("Nobody Atall"), "is_real_name")
	# No contact data in the data file (names policy).
	var text := FileAccess.get_file_as_string("res://scripts/staff.gd")
	check(not text.contains("@") and not text.contains("+36") and not text.contains("njszg"), "no contact details in staff.gd")
	var raw := FileAccess.get_file_as_string("res://docs/data/staff-roster.txt")
	check(not raw.contains("@") and not raw.contains("+36"), "no contact details in the roster source")
