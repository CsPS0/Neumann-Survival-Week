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

const Rooms := preload("res://scripts/rooms.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const Lessons := preload("res://scripts/lessons.gd")
const Classes := preload("res://scripts/classes.gd")

func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	return main
func _cleanup(main: Node) -> void:
	var p: String = main.profile.path
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	main.queue_free()

func _run() -> void:
	var normal := ["5", "14", "23", "24", "28", "33", "35", "42", "43", "44", "45", "46", "109", "113", "114", "121", "125",
			"129", "133", "120", "205", "225", "229", "233"]
	for l in normal:
		check(Rooms.type_of(l) == "normal", l + " is normal")
	for l in ["GT1", "GT2", "GT3", "GT4", "GT5", "GT6", "GT7", "GT8", "GT9", "GT10", "GT11-12", "GT47"]:
		check(Rooms.type_of(l) == "computer", l + " is computer")
	check(Rooms.type_of("WC") == "wc", "WC")
	check(Rooms.type_of("27") == "gym" and Rooms.type_of("Tornaterem") == "gym", "gym rooms")
	check(Rooms.type_of("Bejárat") == "entrance" and Rooms.type_of("Porta") == "entrance", "entrance rooms")
	for l in ["Konyha", "Ebédlő", "Könyvtár", "Igazgatói", "Tanári", "Tárgyaló", "Gazd.", "Raktár", "Büfé", "Cisco", "3", "20", "21", "", "108"]:
		check(Rooms.type_of(l) == "other" and not Rooms.is_open(l), "'%s' is closed in the demo" % l)

	# Every label on the plans has a type (nothing falls through).
	var seen := {}
	for f in 3:
		for room: Array in FloorData.FLOORS[f]["rooms"]:
			seen[room[0]] = Rooms.type_of(room[0])
	for l in seen:
		check(["normal", "computer", "wc", "gym", "entrance", "other"].has(seen[l]), "typed: " + l)

	# Lessons are in open classrooms (not the gym, not closed rooms): Review Focus 2.
	for s in Lessons.SUBJECTS:
		var t := Rooms.type_of(Lessons.room_of(s))
		check(t == "normal" or t == "computer", "%s is taught in an open classroom (%s)" % [s, Lessons.room_of(s)])
	check(Lessons.room_of("Programming") == "GT11-12" and Lessons.room_of("Networks") == "GT2", "computer lessons in GT rooms")
	check(Classes.PLAYER_CLASS == "11.a" and Classes.size_of("11.a") == 25, "you are in 11.a")
	for r in Classes.classrooms():
		var t2 := Rooms.type_of(r[1])
		check(t2 == "normal" or t2 == "computer", "classroom pool has only open classrooms: " + r[1])
	check(Classes.classrooms().size() >= 22, "enough classrooms for 21 classes")

	var main: Node = await _fresh()
	# Closed rooms: locked door with the demo message (also doorless openings are blocked).
	var closed_doors := 0
	for door in get_nodes_in_group("doors"):
		if door.key_id == "__demo__":
			closed_doors += 1
			check(door.locked and door.locked_message == Rooms.DEMO_MESSAGE, "closed door message")
	check(closed_doors > 20, "many doors are demo-locked: %d" % closed_doors)
	check(get_nodes_in_group("demo_barrier").size() >= 1, "doorless closed openings have a barrier")
	check(main.get_node_or_null("GardenDoor") != null, "garden door exists")
	var msgs: Array = []
	main.player.inspected.connect(func(t: String) -> void: msgs.append(t))
	main.get_node("GardenDoor").interact(main.player)
	check(msgs.size() == 1 and msgs[0].contains("not available in the demo"), "garden says not available")
	msgs.clear()
	get_nodes_in_group("demo_barrier")[0].interact(main.player)
	check(msgs.size() == 1 and msgs[0] == Rooms.DEMO_MESSAGE, "barrier says not available")
	# A demo door never opens, even for a player holding every kind of key (Review Focus 1).
	for id in ["storage_key", "key_14", "master_key", "__after__"]:
		main.player.give_item(id, id)
	var demo_door: Node = null
	for door in get_nodes_in_group("doors"):
		if door.key_id == "__demo__":
			demo_door = door
			break
	demo_door.interact(main.player)
	check(demo_door.locked and not demo_door.is_open, "keys never open a demo door")
	demo_door.set_open(true)
	check(not demo_door.is_open, "NPCs (set_open) never open a demo door")

	# Story objects live in open rooms.
	check(Rooms.type_of(main.quest.red_room_label) in ["normal", "computer"], "red room is open: " + main.quest.red_room_label)
	for r in main._note_rooms:
		var lab: String = FloorData.FLOORS[r[0]]["rooms"][r[1]][0]
		check(Rooms.type_of(lab) in ["normal", "computer"] and not Lessons.SUBJECTS.keys().any(func(s: String) -> bool: return Lessons.room_of(s) == lab), "note room open and not a lesson room: " + lab)
	for after in main.AFTER_HOURS_ROOMS:
		check(Rooms.type_of(after[1]) == "normal" or Rooms.type_of(after[1]) == "computer", "after-hours room open type: " + after[1])
	check(main.AFTER_HOURS_ROOMS == [[2, "205"], [2, "GT8"], [1, "114"]], "after-hours rooms")
	# Fixed story objects sit inside their (open) rooms: fuse box 24, safe 229, staff clue 33, lab 14 (Review Focus 2).
	var story_spots := {"fuse box 24": [0, "24", main._fuse_box.global_position], "safe 229": [2, "229", main._safe.global_position],
			"staff clue 33": [0, "33", main._clue_spots[1]], "lab vial 14": [0, "14", main._room_centre(0, "14")]}
	for k in story_spots:
		var e: Array = story_spots[k]
		check(Rooms.is_open(e[1]) and FloorData.room_rect(e[0], e[1]).has_point(Vector2(e[2].x, e[2].z)) and absf(e[2].y - e[0] * 4.0) < 2.0, k + " inside its room")
	for c in main._clue_spots:
		var inside := ""
		for f in 3:
			if absf(c.y - f * 4.0) < 2.0:
				for room: Array in FloorData.FLOORS[f]["rooms"]:
					if FloorData.room_rect(f, room[0]).has_point(Vector2(c.x, c.z)):
						inside = room[0]
		check(Rooms.is_open(inside) and inside != "", "clue spot in an open room: '%s'" % inside)

	# Reachability (Review Focus 1 + 2). The navmesh has no route through a closed room (doors and doorless openings
	# of closed rooms are carved out), so a navmesh path is a path the player can walk.
	var map: RID = main.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var open_checked := 0
	var closed_checked := 0
	for f in 3:
		var origin: Vector2 = FloorData.FLOORS[f]["origin"]
		var sc: float = FloorData.FLOORS[f]["scale"]
		for room: Array in FloorData.FLOORS[f]["rooms"]:
			var label: String = room[0]
			var a := (Vector2(room[1], room[2]) - origin) * sc
			var rect := Rect2(a, (Vector2(room[3], room[4]) - origin) * sc - a)
			var inner := rect.grow(-0.5)
			var centre := Vector3(rect.get_center().x, f * 4.0, rect.get_center().y)
			var path := NavigationServer3D.map_get_path(map, main._spawn_point, centre, true)
			var end: Vector3 = path[path.size() - 1] if path.size() > 0 else main._spawn_point
			var reached := absf(end.y - f * 4.0) < 1.5 and inner.has_point(Vector2(end.x, end.z))
			if Rooms.is_open(label):
				open_checked += 1
				check(reached, "open room %d:%s reachable on the navmesh (end %s)" % [f, label, end])
				var door: Node = main._room_doors.get("%d:%s" % [f, label])
				if door and rect.grow(0.5).has_point(Vector2(door.global_position.x, door.global_position.z)):
					var panel: Vector3 = door.global_position + door.global_basis.x * door.width * 0.5 + Vector3(0, 1.1, 0)
					var out: Vector3 = door.global_basis.z * 1.5
					if rect.has_point(Vector2(panel.x + out.x, panel.z + out.z)):
						out = -out
					var q := PhysicsRayQueryParameters3D.create(panel + out, panel, 1 | 8)
					var hit := space.intersect_ray(q)
					check(hit.get("collider") == door, "door of %d:%s is not walled in (hit %s)" % [f, label, hit.get("collider")])
					var floor_pt := Vector3(panel.x, f * 4.0, panel.z)
					check(NavigationServer3D.map_get_closest_point(map, floor_pt).distance_to(floor_pt) < 1.0, "door of %d:%s on the navmesh" % [f, label])
			else:
				closed_checked += 1
				check(not reached, "closed room %d:'%s' is not reachable (end %s)" % [f, label, end])
	print("reachability: %d open, %d closed rooms checked" % [open_checked, closed_checked])
	_cleanup(main)
