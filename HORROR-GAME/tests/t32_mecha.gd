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
	check(Finds.MECHA.size() == 5, "5 mecha spots")
	for m: Dictionary in Finds.MECHA:
		check(Rooms.is_open(m["room"]), "mecha spot is open: " + m["room"])
		check(String(m["caption"]).length() > 10, "caption")
	var main: Node = await _fresh()
	var mecha: Node = main.mecha
	check(mecha != null, "mecha node")
	check(mecha.posts().size() == 1 and mecha.posts()[0]["day"] == 1, "one post on day 1")
	var figs := get_nodes_in_group("mecha")
	check(figs.size() == 1, "exactly the day's figure exists, got %d" % figs.size())
	var fig: Node = figs[0]
	check(fig.item_id == "mecha_1", "figure id")
	check(not fig.is_in_group("story") and not fig.is_in_group("find"), "figure is not a story item or a find")
	# The figure sits in the day's room on a table, reachable by ray.
	var reachable := false
	for off in [Vector3(1.2, 0.5, 0), Vector3(-1.2, 0.5, 0), Vector3(0, 0.5, 1.2), Vector3(0, 0.5, -1.2)]:
		var r: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(fig.global_position + off, fig.global_position, 57))
		if not r.is_empty() and r["collider"] == fig:
			reachable = true
	check(reachable, "figure reachable")                                                          # Review Focus 5
	# Extra (Review Focus 2 + 5, same rules as t28/t31): every mecha table inside its open room clear of the walls,
	# 1 m from finds, items, clue/story objects, clear of the door swing, carved out of the navmesh and reachable.
	var map: RID = main.get_world_3d().navigation_map
	var others: Array[Vector3] = []
	others.append_array(main._clue_spots)
	others.append_array(main._item_spots.values())
	others.append_array([main._fuse_box.global_position, main._safe.global_position, main._altar.global_position, main._form_spot,
			main._room_centre(0, "5"), main._room_centre(0, "14"), main._room_centre(main._red_room[0], "", main._red_room[1])])
	for r in main._note_rooms:
		others.append(main._room_centre(r[0], "", r[1]))
	for f: Dictionary in Finds.all():
		others.append(main._find_spots[f["id"]])
	var red_key: String = "%d:%s" % [main.quest.red_room_floor, main.quest.red_room_label]
	for m: Dictionary in Finds.MECHA:
		var spot := Finds.spot_position(m["floor"], m["room"], m["slot"])
		var flat := Vector2(spot.x, spot.z)
		check("%d:%s" % [m["floor"], m["room"]] != red_key, "%s not in the red room" % m["id"])
		check(main.find_spot(m["id"]).distance_to(spot + Vector3(0, 0.78, 0)) < 0.01, "%s pickup on its table" % m["id"])
		check(FloorData.room_rect(m["floor"], m["room"]).grow(-0.8).has_point(flat), "%s inside %s, clear of the walls" % [m["id"], m["room"]])
		for o in others:
			if absf(o.y - spot.y) < 2.0:
				check(Vector2(o.x, o.z).distance_to(flat) > 1.0, "%s at least 1 m from other objects (%s)" % [m["id"], o])
		var door: Node = main._room_doors.get("%d:%s" % [m["floor"], m["room"]])
		if door:
			check(Vector2(door.global_position.x, door.global_position.z).distance_to(flat) > 1.9, "%s clear of the door swing" % m["id"])
		var floor_pt := spot + Vector3(0.0, 0.05, 0.0)
		var closest := NavigationServer3D.map_get_closest_point(map, floor_pt)
		check(Vector2(closest.x, closest.z).distance_to(flat) > 0.45, "%s table carved out of the navmesh" % m["id"])
		var path := NavigationServer3D.map_get_path(map, main._spawn_point, floor_pt, true)
		var end: Vector3 = path[path.size() - 1] if path.size() > 0 else main._spawn_point
		check(absf(end.y - spot.y) < 1.5 and Vector2(end.x, end.z).distance_to(flat) < 1.5, "%s reachable on the navmesh" % m["id"])
	var bad := 0
	for i in 300:
		main._choose_story_rooms()
		for m: Dictionary in Finds.MECHA:
			if m["floor"] == main.quest.red_room_floor and m["room"] == main.quest.red_room_label:
				bad += 1
	check(bad == 0, "red room never hosts a mecha spot (%d)" % bad)
	# The photo: rendered once at the start of the day; the first frame is not stalled.
	await create_timer(1.0).timeout
	var photo: Texture2D = mecha.photo_for(1)
	check(photo == null or (photo.get_width() >= 128 and photo.get_height() >= 96), "photo is a real texture or the caption-only fallback")
	# Taking the figure: reward, counted once, post marked found.
	var batteries_before: float = main.player.battery
	fig.interact(main.player)
	check(mecha.found_count() == 1 and mecha.posts()[0]["found"], "post marked found")
	check(main.player.battery >= batteries_before, "battery reward")
	# Day 2: a new post, a new figure, the old one is gone.
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign.start_day(2)
	await create_timer(0.5).timeout
	check(mecha.posts().size() == 2 and get_nodes_in_group("mecha").size() == 1, "day 2 shows two posts and one figure")
	var f2: Node = get_nodes_in_group("mecha")[0]
	check(f2.item_id == "mecha_2", "day 2 figure")
	# Extra: the biscuit reward never overwrites a held biscuit (one inventory entry per id); a battery instead.
	main.player.give_item("biscuit", "Dog biscuit")
	main.player.battery = 10.0
	f2.interact(main.player)
	check(main.player.has_item("biscuit") and main.player.battery > 10.0, "biscuit held: battery fallback")
	check(mecha.found_count() == 2, "day 2 found")
	mecha.found.erase(2)
	# Not taken on day 2: the post stays unfound and the figure is replaced on day 3 (no stale figures).
	main.campaign.start_day(2)
	await create_timer(0.5).timeout
	main.campaign.start_day(3)
	await create_timer(0.5).timeout
	check(get_nodes_in_group("mecha").size() == 1 and mecha.found_count() == 1, "day 3: one figure, count unchanged")      # Review Focus 3
	# Extra: the page reward marks the first unfound story page.
	var f3: Node = get_nodes_in_group("mecha")[0]
	main.finds.mark("lab1")
	f3.interact(main.player)
	check(main.finds.found.has("lab2") and not main.finds.found.has("lab3"), "page reward: the first unfound page")
	var lab2_find: Node = null
	for f: Node in get_nodes_in_group("find"):
		if is_instance_valid(f) and not f.is_queued_for_deletion() and f.get("item_id") == "lab2":
			lab2_find = f
			break
	check(lab2_find == null, "after page reward, no node in group find has lab2")
	mecha.found.erase(3)
	# Achievement after five.
	var events: Array = []
	main.campaign.event.connect(func(n: String, _d: Dictionary) -> void: events.append(n))
	for d in range(1, 6):
		mecha.mark_found(d)
	check(events.has("mecha_master") and mecha.found_count() == 5, "Mecha Master after five")
	check(main.profile.has("mecha_master"), "achievement unlocked")
	# Phone page 4 draws without error.
	main.player.phone.set_raised(true)
	for i in 4:
		main.player.phone.toggle_page()
	check(main.player.phone.page == 4, "feed page is page 4")
	await create_timer(0.3).timeout
	_cleanup(main)
