extends SceneTree
var fails := 0
var cur: Node
var paths: Array[String] = []
var samples := 0
var max_teachers := 0
var max_crowd := 0
var max_ambient := 0
const QuizUtil := preload("res://tests/quiz_util.gd")
const Campaign := preload("res://scripts/campaign.gd")
const Lessons := preload("res://scripts/lessons.gd")
const FloorData := preload("res://scripts/floor_data.gd")
static var Staff: GDScript = preload("res://scripts/staff_source.gd").roster()
const SU := preload("res://tests/staff_util.gd")

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)

func _initialize() -> void:
	await _run()
	for p in paths:
		DirAccess.remove_absolute(p)
	print("SAMPLES: %d max teachers %d, max ambient %d, max crowd %d" % [samples, max_teachers, max_ambient, max_crowd])
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

func _fresh(day := 1) -> Node:
	if cur:
		cur.queue_free()
		await create_timer(0.3).timeout
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_t22_%d.cfg" % Time.get_ticks_msec()
	paths.append(main.profile.path)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	cur = main
	if day != 1:
		main.campaign.start_day(day)
		await create_timer(0.3).timeout
	return main

func _live(group: String) -> int:
	var n := 0
	for t in get_nodes_in_group(group):
		if not t.is_queued_for_deletion():
			n += 1
	return n

func _sample(m: Node, tag: String) -> void:
	samples += 1
	var teachers := _live("teachers") + _live("ambient_staff")
	max_teachers = maxi(max_teachers, teachers)
	max_ambient = maxi(max_ambient, _live("ambient_staff"))
	max_crowd = maxi(max_crowd, m.crowd.shown_count())
	check(teachers <= 16, "%s: teachers %d <= 16" % [tag, teachers])
	check(_live("ambient_staff") <= 8, "%s: ambient %d <= 8" % [tag, _live("ambient_staff")])
	check(m.crowd.shown_count() <= 150, "%s: crowd %d <= 150" % [tag, m.crowd.shown_count()])
	check(_live("csoki") == 1, "%s: exactly one Csoki, got %d" % [tag, _live("csoki")])
	var ids := {}
	for id: String in Lessons.SUSPECT_IDS:
		ids[id] = true
	check(ids.size() == 8, "%s: 8 distinct suspect ids" % tag)
	var names := {}
	for id: String in Lessons.SUSPECT_IDS:
		names[Lessons.TEACHER_NAMES[id]] = true
	check(names.size() == 8, "%s: 8 distinct suspect names" % tag)
	var suspects := 0
	for t in get_nodes_in_group("teachers"):
		if not t.is_queued_for_deletion() and Lessons.SUSPECT_IDS.has(t.npc_id):
			suspects += 1
	check(suspects <= 8, "%s: at most 8 suspect nodes" % tag)

func _attend(main: Node, i: int) -> void:
	var subject: String = Lessons.subject_at(main.campaign.day, i)
	main.player.global_position = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject)) + Vector3(0, 0.1, 0)
	await create_timer(0.1).timeout
	main.daynight.minutes = Campaign.lesson_start(i) + 0.5
	await create_timer(0.25).timeout
	check(QuizUtil.is_open(main), "lesson %d quiz opened" % i)
	QuizUtil.answer_all(main)
	await create_timer(0.15).timeout

func _run() -> void:
	# Names policy, re-asserted.
	var surnames := {}
	for p: Array in Staff.ROSTER:
		surnames[SU.surname(p[0])] = true
	for id: String in Lessons.SUSPECT_IDS:
		var n: String = Lessons.TEACHER_NAMES[id]
		check(not SU.is_real_name(n) and not surnames.has(SU.surname(n)), "%s not in the roster, no shared surname" % n)
	# The culprit is always a suspect over 20 fresh campaigns.
	for k in 20:
		var c := Campaign.new()
		c._ready()
		check(Lessons.SUSPECT_IDS.has(c.culprit), "campaign %d culprit %s is a suspect" % [k, c.culprit])
		c.free()

	# Day 1 through the real flow: sample after every lesson and every break.
	var m: Node = await _fresh()
	m.scare.cooldown_left = 99999.0   # the scare flash would hide the crowd; this test covers per-student panic
	m.daynight.minutes = 400.0
	await create_timer(1.2).timeout
	_sample(m, "pre-school")
	for i in 3:   # Day 1 ends with the explosion after lesson 3: lessons 4 to 7 are cancelled.
		await _attend(m, i)
		if i != 1:
			m.entity.sleep()   # scripted break chases would catch the teleporting player
		else:
			# Lesson 2: the campaign's own lesson_end bell starts the glimpse; crowd near it hides, then returns.
			await create_timer(0.4).timeout
			check(m.entity.visible, "glimpse: entity visible")
			await create_timer(0.6).timeout
			var during: int = m.crowd.shown_count()
			var panicked: int = m.crowd.panicked_count()
			print("glimpse: shown %d panicked %d" % [during, panicked])
			check(panicked > 0, "glimpse: students near the entity vanish (panicked %d)" % panicked)
			_sample(m, "glimpse")
			await create_timer(6.0).timeout
			check(not m.entity.visible, "glimpse over: entity asleep")
			await create_timer(0.7).timeout
			check(m.crowd.panicked_count() == 0, "students return after the entity sleeps")
			check(m.crowd.shown_count() >= during, "crowd not smaller after the glimpse (%d vs %d)" % [m.crowd.shown_count(), during])
		await create_timer(1.2).timeout
		_sample(m, "after lesson %d" % i)
	check(m.campaign.attended == 3 and m.campaign.skipped == 0 and m.campaign.incident, "3 lessons attended, then the explosion")

	# Clock sweep every 10 game minutes over the school day (lessons resolved so the clock may jump).
	m = await _fresh()
	m.campaign._resolved.fill(true)
	m.campaign._ended.fill(true)
	m.entity.sleep()
	var minute := 360.0
	while minute <= 830.0:
		m.daynight.minutes = minute
		await create_timer(1.1).timeout
		m.entity.sleep()
		_sample(m, "clock %s" % Campaign.fmt(minute))
		minute += 10.0
	# Last bell, then going home: stale ambient teachers and crowd must be gone, day 2 starts clean.
	m.daynight.minutes = 860.0
	await create_timer(0.3).timeout
	var old_ambient: Array = get_nodes_in_group("ambient_staff").duplicate()
	m.get_node("FrontDoor").interact(m.player)
	for t in old_ambient:
		check(not is_instance_valid(t) or t.is_queued_for_deletion() or not t.is_in_group("ambient_staff"), "day 2: stale ambient teacher is gone")
	check(m.campaign.day == 2, "went home: day 2")
	check(m.crowd.shown_count() <= 150 and m.staff_manager.ambient_count() <= 8, "day 2: caps hold at once")
	await create_timer(1.2).timeout
	_sample(m, "day 2 start")
	check(m.crowd.shown_count() <= 150, "day 2: crowd within cap")

	# Day 4: correct accusation empties the people layer; Csoki stays and stays quiet.
	m.campaign._resolved.fill(true)
	m.campaign._ended.fill(true)
	m.campaign.start_day(4)
	await create_timer(0.3).timeout
	var culprit: String = m.campaign.culprit
	m.choice_ui.chosen.emit(m.TEACHER_ORDER.find(culprit))
	await create_timer(1.6).timeout
	check(m.campaign.hunt_active, "day 4: hunt started")
	check(m.crowd.shown_count() == 0, "day 4: crowd is empty (%d)" % m.crowd.shown_count())
	check(m.staff_manager.ambient_count() == 0, "day 4: no ambient teachers")
	for t in get_nodes_in_group("teachers"):
		check(t.npc_id != culprit, "day 4: culprit node is gone")
	check(is_instance_valid(m.csoki) and _live("csoki") == 1, "day 4: Csoki exists")
	var barks := [0]
	m.csoki.barked.connect(func() -> void: barks[0] += 1)
	m.entity.sleep()
	for care in get_nodes_in_group("caretaker"):
		care.queue_free()
	m.csoki.global_position = m.csoki.route[0] + Vector3(0, 0.1, 0)
	await create_timer(2.0).timeout
	check(barks[0] == 0, "day 4: Csoki does not bark when nothing is near (%d)" % barks[0])
	_sample(m, "day 4")
	m.campaign.start_day(5)
	await create_timer(1.2).timeout
	check(is_instance_valid(m.csoki) and _live("csoki") == 1, "day 5: Csoki exists")
	check(m.crowd.shown_count() == 0 and m.staff_manager.ambient_count() == 0, "day 5: nobody but the hunt")
	_sample(m, "day 5")
	if cur:
		cur.queue_free()
		await create_timer(0.3).timeout
