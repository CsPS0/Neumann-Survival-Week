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

const Profile := preload("res://scripts/profile.gd")
const Achievements := preload("res://scripts/achievements.gd")
const PATH := "user://neu_test_ach.cfg"

func _rm() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _mk() -> Array:
	var p := Profile.new()
	p.path = PATH
	root.add_child(p)
	p.load_from_disk()
	var a := Achievements.new()
	a.profile = p
	root.add_child(a)
	return [p, a]

func _run() -> void:
	_rm()
	# --- direct on_event ---
	var pa := _mk()
	var p: Node = pa[0]
	var a: Node = pa[1]
	var got: Array = []
	a.unlocked.connect(func(id: String) -> void: got.append(id))
	a.on_event("day_started", {"day": 1})
	check(got.is_empty(), "day 1 start unlocks nothing")
	a.on_event("day_started", {"day": 2})
	check(got == ["first_day"], "finishing day 1 unlocks First Day")
	a.on_event("blackout", {})
	a.on_event("nonsense", {})
	a.on_event("completionist", {})
	a.on_event("ending_1", {})
	check(got.size() == 1, "unknown / non-event names are ignored")
	a.on_event("ending", {"id": 99})
	a.on_event("ending", {})
	check(got.size() == 1 and p.endings_seen.is_empty(), "bad ending ids ignored")
	for e in ["model_student", "straight_a", "early_bird", "night_owl", "detective", "right_suspect", "close_call"]:
		a.on_event(e, {})
	check(got.size() == 8, "all event achievements unlock")
	for id in range(1, 9):
		a.on_event("ending", {"id": id})
	check(got.has("ending_1") and got.has("ending_8"), "one achievement per ending")
	check(got.count("completionist") == 1 and got.size() == 17, "all 8 endings unlock Completionist once")
	var before := got.size()
	a.on_event("ending", {"id": 3})
	check(got.size() == before, "nothing unlocks twice")
	for id in Achievements.LIST:
		check(Achievements.LIST[id].size() == 2, id + " has a title and description")
	check(FileAccess.file_exists(PATH), "unlock persisted via profile.save")
	var q := _mk()
	check(q[0].unlocked.size() == 17, "persisted unlocks reload")

	# --- completionist across two loads ---
	_rm()
	var first := _mk()
	for id in range(1, 5):
		first[1].on_event("ending", {"id": id})
	var second := _mk()
	var got2: Array = []
	second[1].unlocked.connect(func(id: String) -> void: got2.append(id))
	for id in range(4, 9):
		second[1].on_event("ending", {"id": id})
	check(got2.count("completionist") == 1, "completionist fires once across two loads: %s" % [got2])
	check(got2.has("ending_8") and not got2.has("ending_4"), "ending 4 was not re-unlocked")
	_rm()

	# --- real emission path through the scene ---
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.profile.path = PATH
	root.add_child(main)
	await create_timer(1.5).timeout
	main.profile.path = PATH
	main.profile.load_from_disk()   # test profile, not user://profile.cfg
	main._start_game()
	await create_timer(0.3).timeout
	var c: Node = main.campaign
	var ach: Node = main.achievements
	var seen: Array = []
	ach.unlocked.connect(func(id: String) -> void: seen.append(id))
	c._resolved.fill(true)
	c._ended.fill(true)
	c.start_day(1)
	check(seen.is_empty() and main.profile.unlocked.is_empty(), "starting day 1 unlocks nothing")

	# early bird: only before 07:00 in the lesson-1 room, once
	c._resolved.assign([false, false, false, false, false, false, false])
	var in_room := [true]
	c.room_check = func(i: int) -> bool: return in_room[0] and i == 0
	main.daynight.running = true
	main.daynight.minutes = 425.0
	c._process(0.0)
	check(not seen.has("early_bird"), "no early bird at 07:05")
	main.daynight.minutes = 400.0
	in_room[0] = false
	c._process(0.0)
	check(not seen.has("early_bird"), "no early bird outside the room")
	in_room[0] = true
	c._process(0.0)
	c._process(0.0)
	check(seen.count("early_bird") == 1, "early bird once")
	check(main._message_label.text == "Achievement: Early Bird", "toast shown: " + main._message_label.text)
	c._resolved.fill(true)
	c._ended.fill(true)

	# model student + straight a + close call (blackout then lesson)
	c.record_blackout()
	check(not seen.has("blackout") and seen.size() == 1, "blackout event unlocks nothing")
	for i in 7:
		c.finish_lesson(i, 3, 3)
	check(seen.has("model_student") and seen.has("straight_a") and seen.has("close_call"), "lesson events: %s" % [seen])

	# detective
	for i in 9:
		c.add_clue("c%d" % i)
	check(seen.has("detective"), "9 clues -> detective")

	# go home before 18:00: first_day, no night owl; day 2 start via the front door
	c.daynight.minutes = 900.0
	c.use_front_door()
	check(c.day == 2 and seen.has("first_day") and not seen.has("night_owl"), "going home at 15:00: first day only")
	c._resolved.fill(true)
	c._ended.fill(true)
	c.daynight.minutes = 1100.0
	c.use_front_door()
	check(c.day == 3 and seen.has("night_owl"), "going home after 18:00: night owl")

	# right suspect
	c.accuse(c.culprit)
	check(seen.has("right_suspect"), "right suspect")

	# endings through the real campaign
	for id in range(1, 9):
		c.ending_id = 0
		c._end(id)
	check(seen.has("completionist") and seen.count("completionist") == 1, "endings 1-8 -> completionist")
	check(main.profile.endings_seen.size() == 8, "profile saw 8 endings")
	check(seen.size() == 17, "17 distinct unlocks: %d" % seen.size())

	main.queue_free()
	await create_timer(0.3).timeout
	_rm()
