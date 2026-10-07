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
const Classes := preload("res://scripts/classes.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const StaffManagerScript := preload("res://scripts/staff_manager.gd")

func _world(f: int, p: Vector2) -> Vector3:
	var data: Dictionary = FloorData.FLOORS[f]
	var w: Vector2 = (p - (data["origin"] as Vector2)) * float(data["scale"])
	return Vector3(w.x, f * 4.0, w.y)

func _run() -> void:
	var path := "user://neu_test_t23_%d.cfg" % Time.get_ticks_msec()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = path
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	var mgr: Node = main.staff_manager
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)

	# I1: labels, for every roster role, and the E message of the live ambient teachers.
	var roles := {}
	for p: Array in Staff.ROSTER:
		roles[p[1]] = true
	for r in ["director", "deputy", "specialist", "teacher"]:
		check(roles.has(r), "roster has role " + r)
	for p: Array in Staff.ROSTER:
		var label: String = StaffManagerScript.label_of(p[1])
		var msg := "%s, %s" % [p[0], label]
		check(not msg.contains("teacher teacher") and label != "", "label of " + msg)
		var words: PackedStringArray = label.split(" ")
		for i in range(1, words.size()):
			check(words[i] != words[i - 1], "no repeated word in " + msg)
		if p[1] == "specialist" or p[1] == "teacher":
			check(label == "teacher", "subject teacher label for " + p[0])
		else:
			check(label == p[1], "role label for " + p[0])
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)
	main.daynight.minutes = CampaignScript.lesson_end(0) + 1.0
	mgr.sync_now()
	await create_timer(0.3).timeout
	var seen: Array = []
	main.player.inspected.connect(func(text: String) -> void: seen.append(text))
	var live := get_nodes_in_group("ambient_staff")
	check(live.size() > 0, "ambient teachers exist for the label check")
	for t in live:
		seen.clear()
		t.interact(main.player)
		var expected: String = ""
		for p: Array in Staff.ROSTER:
			if p[0] == t.npc_name:
				expected = "%s, %s" % [p[0], StaffManagerScript.label_of(p[1])]
		check(seen.size() == 1 and seen[0] == expected and not seen[0].contains("teacher teacher"), "E message %s vs %s" % [str(seen), expected])

	# I2: every corridor segment of all three floors is free of world geometry; every vertex is on the navmesh.
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var nav_map: RID = main.get_world_3d().navigation_map
	var segs := 0
	var hits := 0
	for f in FloorData.FLOORS.size():
		for poly: Array in FloorData.FLOORS[f]["corridors"]:
			for v: Vector2 in poly:
				var w := _world(f, v)
				var q := NavigationServer3D.map_get_closest_point(nav_map, w)
				check(q.distance_to(w + Vector3(0, 0.3, 0)) <= 0.6, "floor %d vertex %s is %.2f m from the navmesh" % [f, str(v), q.distance_to(w + Vector3(0, 0.3, 0))])
			for i in range(poly.size() - 1):
				var a := _world(f, poly[i])
				var b := _world(f, poly[i + 1])
				var side := (b - a).cross(Vector3.UP).normalized()
				segs += 1
				for off in [-0.5, 0.0, 0.5]:
					for h in [0.3, 1.2]:
						var q := PhysicsRayQueryParameters3D.create(a + side * off + Vector3(0, h, 0), b + side * off + Vector3(0, h, 0), 1)
						var hit: Dictionary = space.intersect_ray(q)
						if not hit.is_empty():
							hits += 1
							check(false, "floor %d segment %s->%s offset %.1f h %.1f blocked at %s by %s" % [f, str(poly[i]), str(poly[i + 1]), off, h, str(hit["position"]), str(hit["collider"])])
	check(segs >= 12, "probed %d segments" % segs)
	print("corridor segments probed: %d, blocked rays: %d" % [segs, hits])

	# M1: the dog is silent behind an ending card, and barks again without one.
	var dog: Node = main.csoki
	var barks: Array = []
	dog.barked.connect(func() -> void: barks.append(1))
	main.campaign.ending_id = 1
	main.entity.encounter(false, dog.global_position + Vector3(8, 0, 0), 30.0)
	await create_timer(1.5).timeout
	check(barks.size() == 0, "no bark behind an ending, got %d" % barks.size())
	main.campaign.ending_id = 0
	await create_timer(1.5).timeout
	check(barks.size() >= 1, "barks once the ending is gone, got %d" % barks.size())
	main.entity.sleep()
	main.entity.global_position = Vector3(500, 0, 500)

	# M2: the player's class has 24 classmates.
	check(Classes.size_of("11.a") == 25, "11.a is the player plus 24")
	var total := 0
	for id: String in Classes.CLASSES:
		total += Classes.size_of(id)
	print("STUDENT TOTAL: %d" % total)

	# M3: stationed teachers keep off the clue tables.
	var shifted := 0
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)
	for day in [1, 2, 3]:
		main.campaign.day = day
		var spot_rooms: Array = []
		for k in 3:
			spot_rooms.append(main._clue_spots[(day - 1) * 3 + k])
		for lesson in 7:
			var subject: String = Lessons.subject_at(day, lesson)
			var assignment := Classes.assign(day, lesson, [Lessons.floor_of(subject), Lessons.room_of(subject)])
			# Visit the classroom with the clue table (and each of the others) so it is within NEAR.
			for target in [spot_rooms[0], spot_rooms[2]]:
				main.player.global_position = Vector3(target.x, floorf((target.y + 1.0) / 4.0) * 4.0 + 0.1, target.z)
				for spec: Dictionary in mgr._wanted("lesson", lesson, {}, {}):
					var st: Vector3 = spec["station"]
					for spot: Vector3 in main._clue_spots:
						if absf(spot.y - st.y) < 2.0:
							check(Vector2(spot.x - st.x, spot.z - st.z).length() >= 1.0, "day %d lesson %d station %s is on a clue table %s" % [day, lesson, str(st), str(spot)])
				# Was the fix exercised? Compare against a manager without the avoid list.
				var saved: Array[Vector3] = mgr.avoid
				var none: Array[Vector3] = []
				mgr.avoid = none
				for spec: Dictionary in mgr._wanted("lesson", lesson, {}, {}):
					var st: Vector3 = spec["station"]
					for spot: Vector3 in saved:
						if absf(spot.y - st.y) < 2.0 and Vector2(spot.x - st.x, spot.z - st.z).length() < 1.0:
							shifted += 1
				mgr.avoid = saved
	check(shifted > 0, "the test meets at least one unshifted station on a clue table: %d" % shifted)
	main.campaign.day = 1

	# M4: a break teacher on a corridor line is not freed and respawned.
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)
	main.daynight.minutes = CampaignScript.lesson_end(0) + 1.0
	mgr._last_key = ""
	mgr.sync_now()
	await create_timer(0.2).timeout
	var ids := {}
	for t in get_nodes_in_group("ambient_staff"):
		ids[t.get_instance_id()] = t.npc_name
	check(ids.size() > 0, "break teachers exist: %d" % ids.size())
	for i in 5:
		mgr.sync_now()
		await create_timer(0.1).timeout
	var after := {}
	for t in get_nodes_in_group("ambient_staff"):
		if not t.is_queued_for_deletion():
			after[t.get_instance_id()] = t.npc_name
	check(after.keys().size() == ids.keys().size() and after.keys().all(func(k: int) -> bool: return ids.has(k)), "no free/respawn churn: %s vs %s" % [str(ids), str(after)])

	DirAccess.remove_absolute(path)
	main.queue_free()
