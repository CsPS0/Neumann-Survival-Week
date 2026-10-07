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

const Classes := preload("res://scripts/classes.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const Staff := preload("res://scripts/staff.gd")
const Lessons := preload("res://scripts/lessons.gd")

func _run() -> void:
	check(Classes.CLASSES.size() == 21, "21 classes")
	for id: String in Classes.CLASSES:
		var n := Classes.size_of(id)
		if id == "9.ny":
			check(n >= 15 and n <= 18, "NYEK size %d" % n)
		else:
			check(n >= 25 and n <= 30, "%s size %d" % [id, n])
		check(Staff.homeroom_teacher(id) != "", id + " has a homeroom teacher")
	check(Classes.size_of("10.b") == Classes.size_of("10.b"), "size is deterministic")

	var rooms := Classes.classrooms()
	print("classrooms: %d %s" % [rooms.size(), str(rooms)])
	check(rooms.size() >= 22, "at least 22 classrooms, got %d" % rooms.size())
	# the 7 lesson rooms must be valid classrooms
	for subject: String in Lessons.SUBJECTS:
		var pr := [Lessons.floor_of(subject), Lessons.room_of(subject)]
		check(rooms.has(pr), "lesson room %s is a classroom" % str(pr))
	var rect := FloorData.room_rect(0, "21")
	check(rect.size.x > 2.0 and rect.size.y > 5.0, "room_rect has real size: %s" % str(rect))
	var data: Dictionary = FloorData.FLOORS[0]
	var expected_w: float = (43.0) * float(data["scale"])
	check(is_equal_approx(rect.size.x, expected_w), "room 21 width follows the floor scale")
	for f in 3:
		check(FloorData.FLOORS[f].has("corridors") and FloorData.FLOORS[f]["corridors"].size() >= 2, "floor %d has corridors" % f)
	check(FloorData.FLOORS[0].has("csoki") and FloorData.FLOORS[0]["csoki"].size() >= 4, "Csoki markers on the ground floor")

	for subject: String in Lessons.SUBJECTS:
		var player_room := [Lessons.floor_of(subject), Lessons.room_of(subject)]
		for day in range(1, 4):
			for lesson in 7:
				var a := Classes.assign(day, lesson, player_room)
				check(a.size() == 21, "all classes placed")
				var used := {}
				for id: String in a:
					var key := "%d:%s" % [a[id][0], a[id][1]]
					check(not used.has(key), "no two classes share %s (day %d lesson %d)" % [key, day, lesson])
					used[key] = true
				check(a[Classes.PLAYER_CLASS] == player_room, "11.a is in the lesson room")
				check(a == Classes.assign(day, lesson, player_room), "assignment is deterministic")
	var pr2 := [Lessons.floor_of("Maths"), Lessons.room_of("Maths")]
	check(Classes.assign(1, 0, pr2) != Classes.assign(1, 1, pr2), "classes move between lessons")
