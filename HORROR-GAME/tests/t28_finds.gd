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

const Finds := preload("res://scripts/finds.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Lessons := preload("res://scripts/lessons.gd")
const FloorData := preload("res://scripts/floor_data.gd")

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
	check(Finds.PAGES.size() == 12 and Finds.SECRETS.size() == 5 and Finds.CARDS.size() == 8, "12 pages, 5 secrets, 8 cards")
	var ids := {}
	for kind in [Finds.PAGES, Finds.SECRETS, Finds.CARDS]:
		for f: Dictionary in kind:
			check(not ids.has(f["id"]), "unique id " + String(f["id"]))
			ids[f["id"]] = true
			check(Rooms.is_open(f["room"]), "%s is in an open room (%s)" % [f["id"], f["room"]])      # Review Focus 2
			check(f["slot"] >= 0 and f["slot"] <= 3, "slot range")
	for c: Dictionary in Finds.CARDS:
		check(Lessons.SUSPECT_IDS.has(c["id"].trim_prefix("card_")), "card for a suspect: " + c["id"])
		check(Lessons.TEACHER_NAMES.values().any(func(n: String) -> bool: return c["text"].begins_with(n)), "card text starts with the suspect's name")
	var text := ""
	for f: Dictionary in Finds.PAGES + Finds.SECRETS + Finds.CARDS:
		text += String(f["text"])
	check(not text.contains("@") and not text.contains("+36"), "no contact data in find texts")

	var main: Node = await _fresh()
	var fi: Node = main.finds
	check(fi != null, "finds node")
	var n := 0
	for p in get_nodes_in_group("find"):
		n += 1
	check(n == 25, "25 find pickups placed (12 + 5 + 8), got %d" % n)
	# Positions: inside the room, on a table, not overlapping each other, not on story objects.
	var positions: Array[Vector3] = []
	for p in get_nodes_in_group("find"):
		for q in positions:
			check(p.global_position.distance_to(q) > 0.7, "finds do not overlap: " + p.item_id)                 # Review Focus 5
		positions.append(p.global_position)
		for s in get_nodes_in_group("pickup"):
			if s != p and (s.is_in_group("clue") or s.is_in_group("story")):
				check(p.global_position.distance_to(s.global_position) > 0.7, "find away from story objects: " + p.item_id)
		check(not p.is_in_group("story") and not p.is_in_group("clue"), "finds are not story or clue items: " + p.item_id)
		check(p.visible and p.collision_layer == 16, "find active from day 1: " + p.item_id)
	# Extra pins (Review Focus 2 + 5): the find's table is inside its open room on its floor, at least 1 m from every
	# other table or story object (clue tables, fuse box, safe, altar, story tables), clear of the door swing,
	# carved out of the navmesh (so built before the bake) and reachable from the spawn.
	var map: RID = main.get_world_3d().navigation_map
	var others: Array[Vector3] = []
	others.append_array(main._clue_spots)
	others.append_array([main._fuse_box.global_position, main._safe.global_position, main._altar.global_position,
			main._room_centre(0, "5"), main._room_centre(0, "14"), main._room_centre(main._red_room[0], "", main._red_room[1])])
	for r in main._note_rooms:
		others.append(main._room_centre(r[0], "", r[1]))
	for f: Dictionary in Finds.all():
		var spot := Finds.spot_position(f["floor"], f["room"], f["slot"])
		var flat := Vector2(spot.x, spot.z)
		var rect := FloorData.room_rect(f["floor"], f["room"])
		check(rect.grow(-0.8).has_point(flat), "%s table inside room %s, clear of the walls" % [f["id"], f["room"]])
		for o in others:
			if absf(o.y - spot.y) < 2.0:
				check(Vector2(o.x, o.z).distance_to(flat) > 1.0, "%s at least 1 m from other objects (%s)" % [f["id"], o])
		for g: Dictionary in Finds.all():
			if g != f:
				check(Finds.spot_position(g["floor"], g["room"], g["slot"]).distance_to(spot) > 1.0, "%s and %s tables apart" % [f["id"], g["id"]])
		var door: Node = main._room_doors.get("%d:%s" % [f["floor"], f["room"]])
		if door:
			check(Vector2(door.global_position.x, door.global_position.z).distance_to(flat) > 1.9, "%s clear of the door swing" % f["id"])
		var floor_pt := spot + Vector3(0.0, 0.05, 0.0)
		var closest := NavigationServer3D.map_get_closest_point(map, floor_pt)
		check(Vector2(closest.x, closest.z).distance_to(flat) > 0.45, "%s table carved out of the navmesh (built before the bake)" % f["id"])
		var path := NavigationServer3D.map_get_path(map, main._spawn_point, floor_pt, true)
		var end: Vector3 = path[path.size() - 1] if path.size() > 0 else main._spawn_point
		check(absf(end.y - spot.y) < 1.5 and Vector2(end.x, end.z).distance_to(flat) < 1.5, "%s reachable on the navmesh (end %s)" % [f["id"], end])
	# Reachability by ray, like the clues.
	for p in get_nodes_in_group("find"):
		# A table corner can be reached from at least one of four sides:
		var reachable := false
		for off in [Vector3(1.2, 0.5, 0), Vector3(-1.2, 0.5, 0), Vector3(0, 0.5, 1.2), Vector3(0, 0.5, -1.2)]:
			var r: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.global_position + off, p.global_position, 57))
			if not r.is_empty() and r["collider"] == p:
				reachable = true
		check(reachable, "find reachable by ray: " + p.item_id)
	# Taking a find counts once, shows its text, emits the signal.
	var seen: Array = []
	var signalled: Array = []
	main.player.inspected.connect(func(t: String) -> void: seen.append(t))
	fi.found_item.connect(func(k: String, id: String) -> void: signalled.append([k, id]))
	var page: Node = null
	for p in get_nodes_in_group("find"):
		if p.item_id == "lab1":
			page = p
	page.interact(main.player)
	check(fi.count("page") == 1 and seen.size() >= 1 and seen[-1].contains("S-14"), "page read and counted")
	check(signalled == [["page", "lab1"]], "found_item emitted once: %s" % [signalled])
	check(not fi.mark("lab1"), "a find is never counted twice")
	check(fi.count("page") == 1 and signalled.size() == 1, "second mark changes nothing")
	# Phone page 3 exists and the phone cycles five pages.
	main.player.phone.set_raised(true)
	for i in 3:
		main.player.phone.toggle_page()
	check(main.player.phone.page == 3, "page 3 is the Finds page")
	await process_frame
	for i in 2:
		main.player.phone.toggle_page()
	check(main.player.phone.page == 0, "five pages then back to the map")
	# Achievements.
	var events: Array = []
	main.campaign.event.connect(func(n2: String, _d: Dictionary) -> void: events.append(n2))
	for f: Dictionary in Finds.PAGES:
		fi.mark(f["id"])
	check(events.has("archivist"), "all 12 pages: Archivist")
	for f: Dictionary in Finds.SECRETS:
		fi.mark(f["id"])
	check(events.has("everything_found"), "all 5 secrets: Everything Found")
	for f: Dictionary in Finds.CARDS:
		fi.mark(f["id"])
	check(events.has("full_deck"), "all 8 cards: Full Deck")
	check(events.count("archivist") == 1 and events.count("full_deck") == 1, "each achievement event fires once")
	for id in ["archivist", "everything_found", "full_deck"]:
		check(main.achievements.LIST.has(id) and main.profile.has(id) and main.profile.has(id), "achievement unlocked: " + id)
	_cleanup(main)
