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

const Campaign := preload("res://scripts/campaign.gd")
const DayNight := preload("res://scripts/day_night.gd")

func _run() -> void:
	check(Campaign.lesson_start(0) == 450.0, "first bell 07:30")
	check(Campaign.lesson_end(0) == 495.0, "lesson 1 ends 08:15")
	check(Campaign.lesson_start(1) == 505.0, "10 min break")
	check(Campaign.lesson_end(6) == 825.0, "last bell 13:45")
	check(Campaign.lesson_at(449.0) == -1 and Campaign.lesson_at(450.0) == 0 and Campaign.lesson_at(496.0) == -1, "lesson_at")
	check(Campaign.phase_at(400.0, 1) == "pre", "pre")
	check(Campaign.phase_at(460.0, 1) == "lesson", "lesson")
	check(Campaign.phase_at(500.0, 1) == "break", "break")
	check(Campaign.phase_at(900.0, 2) == "after", "after")
	check(Campaign.phase_at(1320.0, 2) == "closed", "closed")
	check(Campaign.phase_at(400.0, 4) == "hunt", "hunt")
	check(Campaign.fmt(825.0) == "13:45", "fmt")

	var dn := DayNight.new()
	var c := Campaign.new()
	root.add_child(dn)
	root.add_child(c)
	c.daynight = dn
	await create_timer(0.2).timeout
	var bells: Array = []
	c.bell.connect(func(kind: String, i: int) -> void: bells.append(kind + str(i)))
	var endings: Array = []
	c.ending.connect(func(id: int) -> void: endings.append(id))

	c.room_check = func(i: int) -> bool: return i == 1   # the player is only ever in lesson 2's room
	c.start_day(1)
	check(c.day == 1 and dn.minutes == 360.0 and dn.running, "day 1 starts at 06:00")
	dn.minutes = 453.0
	c._process(0.0)
	check(c.skipped == 1, "lesson 1 skipped after the 2 min grace")
	check(dn.minutes_per_second == Campaign.PACE_SKIPPED, "skipped lesson pace")
	dn.minutes = 506.0
	var started: Array = []
	c.lesson_started.connect(func(i: int) -> void: started.append(i))
	c._process(0.0)
	check(started == [1], "lesson 2 starts when the player is in the room")
	check(bells.has("lesson_end0"), "break bell after lesson 1")
	c.finish_lesson(1, 2, 3)
	check(c.attended == 1 and c.right == 2 and c.total == 3, "quiz stats")
	check(dn.minutes >= Campaign.lesson_end(1) and dn.running, "time jumps to the end of the lesson")
	check(is_equal_approx(c.quiz_ratio(), 2.0 / 3.0), "quiz ratio")

	c._resolved.fill(true)
	c._ended.fill(true)
	dn.minutes = 826.0
	c._process(0.0)
	check(bells.has("last_bell-1"), "last bell")
	check(not c.lethal(), "not lethal on day 1")
	c.use_front_door()
	check(c.day == 2 and dn.minutes == 360.0, "going home after the last bell starts day 2")
	c.start_day(3)
	c.use_front_door()                      # mid-day, before the last bell
	check(endings == [5], "leaving mid-day is ending 5")
	c.player_killed()
	check(endings == [5], "a second ending is ignored")   # Review Focus 1

	var c2 := Campaign.new()
	root.add_child(c2)
	c2.daynight = dn
	await create_timer(0.1).timeout
	var e2: Array = []
	c2.ending.connect(func(id: int) -> void: e2.append(id))
	c2.start_day(3)
	c2._resolved.fill(true)
	c2._ended.fill(true)
	dn.minutes = 1320.0
	c2._process(0.0)
	check(e2 == [3], "still inside at 22:00 on day 3 is ending 3")
	var c3 := Campaign.new()
	root.add_child(c3)
	c3.daynight = dn
	await create_timer(0.1).timeout
	var e3: Array = []
	c3.ending.connect(func(id: int) -> void: e3.append(id))
	c3.start_day(4)
	check(c3.lethal(), "lethal on day 4")
	dn.minutes = 1320.0
	c3._process(0.0)
	check(c3.day == 5 and e3.is_empty(), "22:00 on day 4 rolls to day 5")
	dn.minutes = 1320.0
	c3._process(0.0)
	check(e3 == [7], "22:00 on day 5 is overtime")
	var c4 := Campaign.new()
	root.add_child(c4)
	c4.daynight = dn
	await create_timer(0.1).timeout
	c4.start_day(1)
	c4.skipped = Campaign.SKIP_LIMIT - 1
	var e4: Array = []
	c4.ending.connect(func(id: int) -> void: e4.append(id))
	dn.minutes = 453.0
	c4.room_check = func(_i: int) -> bool: return false
	c4._process(0.0)
	check(e4 == [3], "6th skipped lesson is ending 3")
