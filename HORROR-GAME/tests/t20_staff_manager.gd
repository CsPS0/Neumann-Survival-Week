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

const CampaignScript := preload("res://scripts/campaign.gd")
const Staff := preload("res://scripts/staff.gd")
const Lessons := preload("res://scripts/lessons.gd")

func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	return main

func _live() -> int:
	var n := 0
	for g in ["teachers", "ambient_staff"]:
		for t in get_nodes_in_group(g):
			if not t.is_queued_for_deletion():
				n += 1
	return n

func _run() -> void:
	var main: Node = await _fresh()
	var mgr: Node = main.staff_manager
	check(mgr != null and mgr.MAX_AMBIENT == 8, "manager with the cap")
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)

	main.daynight.minutes = CampaignScript.lesson_end(0) + 1.0   # a break
	mgr.sync_now()
	await create_timer(0.3).timeout
	var n: int = mgr.ambient_count()
	check(n > 0 and n <= mgr.MAX_AMBIENT, "ambient teachers in a break, got %d" % n)
	check(_live() <= 16, "at most 16 teachers alive, got %d" % _live())
	for t in get_nodes_in_group("ambient_staff"):
		check(Staff.is_real_name(t.npc_name), "ambient teacher uses a roster name: " + t.npc_name)
		check(not Lessons.TEACHER_NAMES.values().has(t.npc_name), "no suspect among the ambient")
		check(t.is_in_group("ambient_staff") and not t.is_in_group("teachers"), "separate group from the suspects")
	var names := {}
	for t in get_nodes_in_group("ambient_staff"):
		check(not names.has(t.npc_name), "no duplicates: " + t.npc_name)
		names[t.npc_name] = true

	var first: Node = get_nodes_in_group("ambient_staff")[0]
	var seen: Array = []
	main.player.inspected.connect(func(text: String) -> void: seen.append(text))
	first.interact(main.player)
	check(seen.size() == 1 and seen[0].contains(first.npc_name), "E shows the name")
	check(first.prompt == first.npc_name, "ambient prompt is the name")

	# Movement: over ~20 s of break time at least one ambient teacher moves.
	var start := {}
	for t in get_nodes_in_group("ambient_staff"):
		start[t] = t.global_position
	main.daynight.minutes = CampaignScript.lesson_end(0) + 1.0
	await create_timer(20.0).timeout
	var moved := 0
	var report := ""
	for t in start:
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			var d: float = t.global_position.distance_to(start[t])
			report += " %.1f" % d
			if d > 2.0:
				moved += 1
	print("MOVE distances:", report)
	check(moved > 0, "an ambient teacher moved over 20 s (moved=%d)" % moved)

	main._station_teachers(1)
	check(_live() <= 16, "cap after stationing suspects")

	# Lesson: stationed teachers in nearby classrooms.
	main.player.global_position = main._room_centre(1, "Tanári") + Vector3(0, 0.1, 0) if false else main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)
	main.daynight.minutes = CampaignScript.lesson_start(1) + 5.0
	mgr.sync_now()
	await create_timer(0.3).timeout
	check(mgr.ambient_count() <= mgr.MAX_AMBIENT, "cap in lesson")
	check(_live() <= 16, "16 cap in lesson, got %d" % _live())

	main.player.global_position = main._room_centre(2, "229") + Vector3(0, 0.1, 0)
	mgr.sync_now()
	await create_timer(0.3).timeout
	check(mgr.ambient_count() <= mgr.MAX_AMBIENT, "cap after moving")

	main.daynight.minutes = CampaignScript.LAST_BELL + 5.0
	mgr.sync_now()
	await create_timer(0.3).timeout
	check(mgr.ambient_count() == 0, "ambient teachers leave after the last bell")
	main.campaign.start_day(2)
	await create_timer(0.5).timeout
	check(mgr.ambient_count() <= mgr.MAX_AMBIENT, "day 2 starts within the cap")
	main.campaign.start_day(4)
	await create_timer(0.5).timeout
	check(mgr.ambient_count() == 0, "no ambient teachers on hunt days")
	main.queue_free()
