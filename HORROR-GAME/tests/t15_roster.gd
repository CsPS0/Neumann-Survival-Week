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

static var Staff: GDScript = preload("res://scripts/staff_source.gd").roster()
const SU := preload("res://tests/staff_util.gd")

func _run() -> void:
	var real: bool = SU.has_real_file()
	check(Staff.ROSTER.size() > 0 and (not real or Staff.ROSTER.size() == 79), "roster size (79 with the real file)")
	var roles := {}
	for p: Array in Staff.ROSTER:
		roles[p[1]] = int(roles.get(p[1], 0)) + 1
		check(p.size() == 4 and String(p[0]) != "", "well-formed row " + String(p[0]))
	if real:
		check(roles == {"director": 1, "deputy": 4, "specialist": 36, "teacher": 31, "support": 7}, "role counts: %s" % str(roles))
	var homerooms := {}
	for p: Array in Staff.ROSTER:
		if String(p[3]) != "":
			homerooms[p[3]] = p[0]
	if real:
		check(homerooms.size() == 21, "21 homeroom classes, got %d" % homerooms.size())
		check(Staff.homeroom_teacher("9.a") == "Kiss Renáta", "9.a homeroom")
		check(Staff.homeroom_teacher("9.ny") == "Erdős Gábor", "NYEK homeroom")
		check(SU.is_real_name("Simon Tibor"), "is_real_name")
	else:
		check(homerooms.size() > 0, "placeholder has homeroom classes")
		for id: String in homerooms:
			check(Staff.homeroom_teacher(id) == homerooms[id], id + " homeroom")
	check(Staff.homeroom_teacher("99.z") == "", "unknown class")
	check(SU.surname("Dr Farkas József") == "Farkas" and SU.surname("Dr. Kiss Eleonóra") == "Kiss", "titles stripped")
	check(SU.surname("Kiss Renáta") == "Kiss", "surname first")
	check(not SU.is_real_name("Nobody Atall"), "is_real_name rejects strangers")
	# No contact data in the data file (names policy).
	var text := FileAccess.get_file_as_string(SU.REAL if real else "res://scripts/staff_placeholder.gd")
	check(not text.contains("@") and not text.contains("+36") and not text.contains("njszg"), "no contact details in the roster script")
	if FileAccess.file_exists("res://docs/data/staff-roster.txt"):
		var raw := FileAccess.get_file_as_string("res://docs/data/staff-roster.txt")
		check(not raw.contains("@") and not raw.contains("+36"), "no contact details in the roster source")
