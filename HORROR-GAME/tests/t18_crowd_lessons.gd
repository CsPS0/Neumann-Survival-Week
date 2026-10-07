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
func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	return main

const Classes := preload("res://scripts/classes.gd")
const Lessons := preload("res://scripts/lessons.gd")
const CampaignScript := preload("res://scripts/campaign.gd")
const FloorData := preload("res://scripts/floor_data.gd")

func _run() -> void:
	seed(42)
	var main: Node = await _fresh()
	var crowd: Node = main.crowd
	check(crowd != null and crowd.MAX_CROWD == 150, "crowd exists with the cap")
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.daynight.minutes = 380.0
	crowd.sync_now()
	check(crowd.seated_count() == 0, "no seated students before school")

	var subject: String = Lessons.subject_at(1, 0)
	main.daynight.minutes = CampaignScript.lesson_start(0) + 5.0
	var centre: Vector3 = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject)) + Vector3(0, 0.1, 0)
	main.player.global_position = centre
	crowd.sync_now()
	check(crowd.seated_count() >= 20, "classmates are seated, got %d" % crowd.seated_count())
	check(crowd.shown_count() <= crowd.MAX_CROWD, "cap respected: %d" % crowd.shown_count())
	# Nobody in the camera, inside a table, or outside a room.
	var rect: Rect2 = FloorData.room_rect(Lessons.floor_of(subject), Lessons.room_of(subject))
	var own := 0
	for slot: Dictionary in crowd._drawn:
		var p: Vector3 = slot["pos"]
		check(Vector2(p.x - centre.x, p.z - centre.z).length() >= 1.0 or absf(p.y - centre.y) > 2.0, "nobody within 1 m of the player")
		for t: Vector3 in main._clue_spots:
			check(absf(t.y - p.y) > 2.0 or Vector2(p.x - t.x, p.z - t.z).length() >= 0.9, "nobody on a table")
		if rect.has_point(Vector2(p.x, p.z)) and absf(p.y - (centre.y - 0.1)) < 1.0:
			own += 1
	check(own >= 20, "own class seated inside the room rect: %d" % own)

	main.player.global_position = main._room_centre(2, "229") + Vector3(0, 0.1, 0)
	crowd.sync_now()
	check(crowd.shown_count() <= crowd.MAX_CROWD, "cap respected on the top floor")

	main.daynight.minutes = CampaignScript.LAST_BELL + 10.0
	crowd.sync_now()
	check(crowd.shown_count() == 0, "no students after the last bell")
	main.daynight.minutes = CampaignScript.lesson_start(1) + 5.0
	var s1: String = Lessons.subject_at(1, 1)
	main.player.global_position = main._room_centre(Lessons.floor_of(s1), Lessons.room_of(s1)) + Vector3(0, 0.1, 0)
	crowd.sync_now()
	check(crowd.seated_count() > 0, "students return for the next lesson, got %d" % crowd.seated_count())

	# Stress: a crowded spot (many classes in range) hits the cap but never exceeds it, and seats stay stable.
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)
	crowd.sync_now()
	check(crowd.shown_count() >= 140 and crowd.shown_count() <= crowd.MAX_CROWD, "crowded corridor spot: %d shown, cap %d" % [crowd.shown_count(), crowd.MAX_CROWD])
	var first: Vector3 = crowd._slots[0]["pos"]
	main.player.global_position += Vector3(0.5, 0, 0)
	crowd.sync_now()
	check(crowd._slots[0]["pos"] == first, "seats do not shift when the player moves")

	# Hunt days: show students at a lesson time first, so the empty result below cannot pass by default.
	main.daynight.minutes = CampaignScript.lesson_start(1) + 5.0
	crowd.sync_now()
	check(crowd.shown_count() > 0, "students are shown at a school hour before the hunt day")
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	main.daynight.minutes = CampaignScript.lesson_start(1) + 5.0
	crowd.sync_now()
	check(crowd.shown_count() == 0, "no students on hunt days")
	DirAccess.remove_absolute(main.profile.path)
	main.queue_free()
