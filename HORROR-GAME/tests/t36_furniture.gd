extends SceneTree
## Furniture: counts per open classroom / GT room / WC, clear of door swings and tables, rooms stay reachable,
## Porta, Lab 14 and demo-closed rooms untouched, the crowd sits on the chairs, stations stay free.
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
const Rooms := preload("res://scripts/rooms.gd")
const Finds := preload("res://scripts/finds.gd")
const Lessons := preload("res://scripts/lessons.gd")
const Classes := preload("res://scripts/classes.gd")
const Furniture := preload("res://scripts/furniture.gd")
const CampaignScript := preload("res://scripts/campaign.gd")

func _rect(f: int, room: Array) -> Rect2:
	var d: Dictionary = FloorData.FLOORS[f]
	var a: Vector2 = (Vector2(room[1], room[2]) - d["origin"]) * d["scale"]
	var b: Vector2 = (Vector2(room[3], room[4]) - d["origin"]) * d["scale"]
	return Rect2(a, b - a).abs()

var last_end := Vector3.ZERO
func _reach(map: RID, from: Vector3, to: Vector3, within: float) -> bool:
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty():
		last_end = Vector3.INF
		return false
	var end: Vector3 = path[path.size() - 1]
	last_end = end
	return absf(end.y - to.y) < 1.5 and Vector2(end.x - to.x, end.z - to.z).length() < within

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_t36_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	var fu: Node = main.furniture
	var map: RID = main.get_world_3d().navigation_map
	check(fu.get_parent() == main and fu.get_node_or_null("../") != null, "furniture node under main")
	var body: StaticBody3D = main._region.get_node_or_null("Furniture")
	check(body != null and body.collision_layer == 1 and body.get_child_count() > 1000, "one collision body on layer 1 under the nav region: %d shapes" % (body.get_child_count() if body else 0))
	# Tables and story objects furniture must keep clear of.
	var tables: Array[Vector3] = main._table_spots.duplicate()
	tables.append_array([main._fuse_box.global_position, main._safe.global_position, main._altar.global_position])
	# Door swings: points on the sector each panel sweeps (it opens into its own room).
	var swings := []
	for door in get_nodes_in_group("doors"):
		var pts: Array[Vector2] = []
		for k in 11:
			var yaw: float = door.rotation.y + deg_to_rad(door.open_angle * door.open_sign) * k / 10.0
			for rr: float in [0.3, 0.6, 0.9, 1.2, 1.3]:
				var w: Vector3 = door.global_position + Basis(Vector3.UP, yaw) * Vector3(rr, 0, 0)
				pts.append(Vector2(w.x, w.z))
		swings.append([roundi(door.global_position.y / 4.0), pts])
	var all_feet := []   # [floor, Rect2, kind, room]
	var totals := {}
	for f in FloorData.FLOORS.size():
		var rooms: Array = FloorData.FLOORS[f]["rooms"]
		for r in rooms.size():
			var label: String = rooms[r][0]
			var type := Rooms.type_of(label)
			var key := "%d:%d" % [f, r]
			var rect := _rect(f, rooms[r])
			if not Rooms.is_open(label) or label == "14" or not type in ["normal", "computer", "wc"]:
				check(not fu.pieces.has(key), "no furniture in %s (floor %d)" % [label, f])
				continue
			check(fu.pieces.has(key), "furniture in %s (floor %d)" % [label, f])
			var count := {}
			for item: Array in fu.pieces.get(key, []):
				count[item[0]] = count.get(item[0], 0) + 1
				totals[item[0]] = totals.get(item[0], 0) + 1
				var foot: Rect2 = item[1]
				all_feet.append([f, foot, item[0], label])
				check(rect.grow(-0.05).encloses(foot), "%s %s inside its room" % [label, item[0]])
			match type:
				"normal":
					check(count.get("teacher_desk", 0) == 1 and count.get("desk", 0) >= 12, "classroom %s: teacher desk and >= 12 desks %s" % [label, count])
				"computer":
					check(count.get("pc_desk", 0) >= 8 and count.get("teacher_desk", 0) == 1, "GT room %s: >= 8 PCs and a teacher PC %s" % [label, count])
				"wc":
					check(count.get("toilet", 0) >= 3 and count.get("sink", 0) >= 2 and count.get("mirror", 0) == 1, "WC floor %d: >= 3 toilets, >= 2 sinks, a mirror %s" % [f, count])
			var centre := Vector3(rect.get_center().x, f * 4.0, rect.get_center().y)
			if type != "wc":
				var seat_list: Array = fu.seats.get("%d:%s" % [f, label], [])
				check(seat_list.size() == count.get("desk", 0) + count.get("pc_desk", 0), "%s: one seat per desk" % label)
				# Teacher stations: the centre and the ambient fallback 1.5 m along the longer axis stay free.
				var alt := centre + (Vector3.RIGHT if rect.size.x >= rect.size.y else Vector3.BACK) * 1.5
				var centre_table := tables.any(func(t: Vector3) -> bool: return absf(t.y - centre.y) < 1.0 and Vector2(t.x - centre.x, t.z - centre.z).length() < 1.2)
				for item: Array in fu.pieces.get(key, []):
					check(Furniture._gap(item[1], Vector2(centre.x, centre.z)) >= 0.8, "%s centre free of %s" % [label, item[0]])
					if centre_table:   # staff_manager.gd stations the teacher there instead
						check(Furniture._gap(item[1], Vector2(alt.x, alt.z)) >= 0.5, "%s fallback station free of %s" % [label, item[0]])
			else:
				# A 1.2 m clear strip from the door to the far wall.
				var door: Vector2 = Finds._door_points(rooms[r], FloorData.FLOORS[f]["origin"], FloorData.FLOORS[f]["scale"])[0]
				var along_x := absf(door.y - rect.position.y) < 0.05 or absf(door.y - rect.end.y) < 0.05
				var strip := Rect2(door.x - 0.6, rect.position.y, 1.2, rect.size.y) if along_x else Rect2(rect.position.x, door.y - 0.6, rect.size.x, 1.2)
				for item: Array in fu.pieces.get(key, []):
					check(not strip.intersects(item[1]), "WC floor %d: %s clear of the door-to-wall strip" % [f, item[0]])
				var inside := Vector3(door.x, f * 4.0, door.y).lerp(centre, 0.3)
				var far := Vector3(door.x, f * 4.0, door.y) + (centre - Vector3(door.x, f * 4.0, door.y)) * 1.7
				check(_reach(map, inside, far, 0.8), "WC floor %d: door to far wall walkable" % f)
			# Reachability: spawn -> room centre, the room's door -> every table inside it.
			check(_reach(map, main._spawn_point, centre + Vector3(0, 0.05, 0), 1.5), "%s (floor %d) centre reachable from spawn (path ends %s)" % [label, f, last_end])
			var doors: Array = Finds._door_points(rooms[r], FloorData.FLOORS[f]["origin"], FloorData.FLOORS[f]["scale"])
			for t: Vector3 in tables:
				if absf(t.y - f * 4.0) > 1.0 or not rect.has_point(Vector2(t.x, t.z)):
					continue
				for dp: Vector2 in doors:
					var outside := Vector2(dp.x, dp.y) + (Vector2(dp.x, dp.y) - rect.get_center()).normalized() * 0.8
					check(_reach(map, Vector3(outside.x, f * 4.0, outside.y), Vector3(t.x, f * 4.0, t.z), 1.5),
							"%s (floor %d): table %s reachable from the door %s (path ends %s)" % [label, f, t, outside, last_end])
	print("TOTALS ", totals)
	# Nothing overlaps a door swing, a table or story object, the Porta, Lab 14 or a closed room.
	var porta := FloorData.room_rect(0, "Porta")
	var lab := FloorData.room_rect(0, "14")
	for entry: Array in all_feet:
		var f: int = entry[0]
		var foot: Rect2 = entry[1]
		var what := "%s in %s (floor %d)" % [entry[2], entry[3], f]
		for swing: Array in swings:
			if swing[0] == f:
				check(not (swing[1] as Array).any(func(q: Vector2) -> bool: return foot.grow(0.05).has_point(q)), what + " clear of a door swing")
		for t: Vector3 in tables:
			if absf(t.y - f * 4.0) < 1.5:
				check(not Rect2(t.x - 0.55, t.z - 0.55, 1.1, 1.1).intersects(foot), what + " clear of the table at %s" % t)
		if f == 0:
			check(not porta.intersects(foot) and not lab.intersects(foot), what + " not in the Porta or Lab 14")
		for room: Array in FloorData.FLOORS[f]["rooms"]:
			if not Rooms.is_open(room[0]):
				check(not _rect(f, room).grow(-0.2).intersects(foot), what + " not in closed room " + String(room[0]))
	# Finds, items and mecha tables: t28's rules still hold (corner 0.8 m off the walls, 1 m from story objects).
	for spot: Dictionary in Finds.all() + Finds.MECHA + main.ITEM_SPOTS:
		var p := Finds.spot_position(spot["floor"], spot["room"], spot["slot"])
		check(FloorData.room_rect(spot["floor"], spot["room"]).grow(-0.8).has_point(Vector2(p.x, p.z)), "%s 0.8 m off the walls" % spot["id"])
	# Porta untouched: desk, board, porter at the desk; the lab cabinet still holds the vial.
	check(main.get_node_or_null("KeyBoard") != null and main.porter.is_at_desk(), "Porta desk, board and porter in place")
	check(_reach(map, main._desk_position, main._wc_point, 1.2), "porter's WC trip still walkable")
	check(main._vial.global_position.distance_to(Vector3(FloorData.room_rect(0, "14").position.x + 0.125 + 0.3, 1.1, main._room_centre(0, "14").z)) < 0.01, "lab cabinet and vial untouched")
	# Collision: a ray straight down onto a desk hits the furniture body.
	var seat0: Dictionary = fu.seats["0:23"][0]
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(seat0["pos"] + Vector3(0, 2.0, 0), seat0["pos"] - Vector3(0, 0.5, 0), 1))
	check(not hit.is_empty() and hit["collider"] == body, "desks collide (layer 1)")
	# The crowd sits on the chairs: day 1 lesson 0 (Maths, 23), every drawn student on a chair, 24 classmates in 23.
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.daynight.minutes = CampaignScript.lesson_start(0) + 5.0
	var subject: String = Lessons.subject_at(1, 0)
	main.player.global_position = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject)) + Vector3(0, 0.1, 0)
	main.crowd.sync_now()
	var chairs := {}
	for k: String in fu.seats:
		for s: Dictionary in fu.seats[k]:
			chairs[s["pos"]] = s["yaw"]
	var on_chairs := 0
	for slot: Dictionary in main.crowd._drawn:
		if chairs.has(slot["pos"]) and is_equal_approx(chairs[slot["pos"]], slot["yaw"]):
			on_chairs += 1
	check(main.crowd.seated_count() >= 24 and on_chairs == main.crowd.seated_count(), "every seated student is on a chair facing the board: %d of %d" % [on_chairs, main.crowd.seated_count()])
	var own := 0
	var rect23 := FloorData.room_rect(0, "23")
	for slot: Dictionary in main.crowd._drawn:
		if rect23.has_point(Vector2(slot["pos"].x, slot["pos"].z)) and absf(slot["pos"].y) < 1.0:
			own += 1
	check(own == 24, "24 classmates seated in 23: %d" % own)
	# Lesson rooms seat the player's class (GT2 is the small computer room: at least 12 PCs).
	for s: String in ["Maths", "Literature", "Programming", "Physics", "History", "English"]:
		check(fu.seats["%d:%s" % [Lessons.floor_of(s), Lessons.room_of(s)]].size() >= 24, "lesson room %s seats 24" % Lessons.room_of(s))
	check(fu.seats["0:GT2"].size() >= 12, "GT2 has at least 12 PCs")
	var p: String = main.profile.path
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	main.queue_free()
