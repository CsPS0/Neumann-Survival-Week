extends SceneTree
## World scale 1.25: extents, navmesh reachability on all floors, caretaker/entity paths, front door, clue pickups.
var fails := 0
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

const FloorData := preload("res://scripts/floor_data.gd")
const Lessons := preload("res://scripts/lessons.gd")

func _extent(i: int) -> Vector2:
	var d: Dictionary = FloorData.FLOORS[i]
	return (d["rect"] as Rect2).size * float(d["scale"])

func _path_ok(map: RID, from: Vector3, to: Vector3, what: String) -> void:
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty():
		check(false, "%s: no path" % what)
		return
	var end: Vector3 = path[path.size() - 1]
	var flat := Vector2(end.x - to.x, end.z - to.z).length()
	check(flat < 1.5 and absf(end.y - to.y) < 1.0, "%s: path ends %.2f m away (dy %.2f)" % [what, flat, end.y - to.y])

func _run() -> void:
	check(is_equal_approx(FloorData.WORLD_SCALE, 1.25), "WORLD_SCALE is 1.25")
	# (a) extents: old ground 77.2 x 47.5, upper floors 37.8 x 47.3 (x by z) before scaling.
	var g := _extent(0)
	check(absf(g.x - 96.5) < 0.2 and absf(g.y - 59.4) < 0.2, "ground extent %s about 96.5 x 59.4" % g)
	for i in [1, 2]:
		var e := _extent(i)
		check(absf(e.x - 47.3) < 0.2 and absf(e.y - 59.3) < 0.2, "floor %d extent %s about 47.3 x 59.3" % [i, e])

	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.profile.path = "user://neu_test_t14.cfg"
	root.add_child(main)
	await create_timer(1.5).timeout
	await physics_frame
	var map: RID = main.get_world_3d().navigation_map
	var spawn: Vector3 = main._spawn_point
	check(absf(spawn.x - -2.75 * 1.25) < 0.01 and absf(spawn.z - 17.4 * 1.25) < 0.01, "spawn scaled")
	check(main.STAIR_Z[1][1] > 17.0, "stair footprint scaled (%s)" % [main.STAIR_Z])

	# (b) reachability from the spawn to every interesting target on all floors.
	var targets := {}
	for subject in Lessons.SUBJECTS:
		targets["lesson " + subject] = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject))
	for room in main.AFTER_HOURS_ROOMS:
		targets["after-hours " + room[1]] = main._room_centre(room[0], room[1])
	targets["staff clue 33"] = main._room_centre(0, "33")
	targets["Bejarat"] = main._room_centre(0, "Bejárat")
	targets["altar"] = main._altar.global_position - Vector3(0, 0.45, 0)
	for k in main._patrol_markers.size():
		targets["patrol %d" % k] = main._patrol_markers[k].global_position
	for k in targets:
		_path_ok(map, spawn, targets[k], k)
	# Paths back down from the top floor to the spawn.
	for k in [0, 5, 6, 11, 12, 17]:
		_path_ok(map, main._patrol_markers[k].global_position, spawn, "return from patrol %d" % k)

	# (c) caretaker and entity.
	main._start_game()
	await create_timer(0.3).timeout
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.daynight.minutes = 860.0
	await create_timer(0.5).timeout
	var care := get_nodes_in_group("caretaker")
	check(care.size() == 1, "caretaker present")
	if care.size() == 1:
		var c: Node3D = care[0]
		for m in main._patrol_markers:
			if m.global_position.distance_to(c.global_position) > 20.0:
				_path_ok(map, c.global_position, m.global_position, "caretaker -> far marker")
		var start := c.global_position
		await create_timer(8.0).timeout
		check(is_instance_valid(c) and c.global_position.distance_to(start) > 1.0, "caretaker walks")
	var ent: Node3D = main.entity
	for m in main._patrol_markers:
		if m.global_position.distance_to(ent.global_position) > 20.0:
			_path_ok(map, ent.global_position, m.global_position, "entity -> far marker")

	# (d) front door inside Bejarat, next to the south wall.
	var data: Dictionary = FloorData.GROUND
	var hall: Array
	for r in data["rooms"]:
		if r[0] == "Bejárat":
			hall = r
	var a: Vector2 = (Vector2(hall[1], hall[2]) - data["origin"]) * data["scale"]
	var b: Vector2 = (Vector2(hall[3], hall[4]) - data["origin"]) * data["scale"]
	var fd: Node3D = main.get_node("FrontDoor")
	var p := Vector2(fd.global_position.x, fd.global_position.z)
	check(Rect2(a, b - a).has_point(p), "front door inside Bejarat")
	check(b.y - p.y > 0.1 and b.y - p.y < 0.5, "front door %.2f m from the south wall line" % (b.y - p.y))

	# (e) clue pickups reachable (t04 logic), days 1-3.
	for d in 3:
		main.campaign.start_day(d + 1)
		await create_timer(0.4).timeout
		for cl in get_nodes_in_group("clue"):
			var ok := false
			for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				var from: Vector3 = cl.global_position + dir * 1.5 + Vector3(0, 0.85, 0)
				var q := PhysicsRayQueryParameters3D.create(from, cl.global_position, 57)
				var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.get("collider") == cl:
					ok = true
			check(ok, "day %d %s reachable" % [d + 1, cl.item_id])
	main.free()
	DirAccess.remove_absolute("user://neu_test_t14.cfg")
