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
	var main: Node = await _fresh()
	var p: Node = main.player
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	var batteries := 0
	var biscuits := 0
	var cards := 0
	for it in get_nodes_in_group("pickup"):
		if it.kind == "battery":
			batteries += 1
		elif it.kind == "biscuit":
			biscuits += 1
		elif it.kind == "key_card":
			cards += 1
		check(not String(it.item_id).begins_with("__"), "no pickup carries a lock-only id (%s)" % it.item_id)   # Review Focus 1
	check(batteries == 11 and biscuits == 3 and cards == 1, "7 + 4 batteries, 3 biscuits, 1 card: %d %d %d" % [batteries, biscuits, cards])

	# Placement (Review Focus 2 + 5), same rules as the finds in t28.
	var items := get_nodes_in_group("item")
	check(items.size() == main.ITEM_SPOTS.size() and items.size() == 8, "8 item pickups in group item, got %d" % items.size())
	check(main.finds.items_total == items.size(), "items_total equals number of nodes in group item at start of run (%d == %d)" % [main.finds.items_total, items.size()])
	var map: RID = main.get_world_3d().navigation_map
	var others: Array[Vector3] = []
	others.append_array(main._clue_spots)
	others.append_array(main._find_spots.values())
	others.append_array([main._fuse_box.global_position, main._safe.global_position, main._altar.global_position, main._form_spot,
			main._room_centre(0, "5"), main._room_centre(0, "14"), main._room_centre(main._red_room[0], "", main._red_room[1])])
	for r in main._note_rooms:
		others.append(main._room_centre(r[0], "", r[1]))
	var red_key: String = "%d:%s" % [main.quest.red_room_floor, main.quest.red_room_label]
	for s: Dictionary in main.ITEM_SPOTS:
		check(Rooms.is_open(s["room"]), "%s in an open room (%s)" % [s["id"], s["room"]])
		check("%d:%s" % [s["floor"], s["room"]] != red_key, "%s not in the key-locked red room" % s["id"])
		check(not main.RESERVED_ROOMS.has(s["room"]) or s["room"] == "45" or s["room"] == "35", "%s not in a story room" % s["id"])
		var spot := Finds.spot_position(s["floor"], s["room"], s["slot"])
		var flat := Vector2(spot.x, spot.z)
		check(FloorData.room_rect(s["floor"], s["room"]).grow(-0.8).has_point(flat), "%s table inside %s, clear of the walls" % [s["id"], s["room"]])
		for o in others:
			if absf(o.y - spot.y) < 2.0:
				check(Vector2(o.x, o.z).distance_to(flat) > 1.0, "%s at least 1 m from other objects (%s)" % [s["id"], o])
		for t: Dictionary in main.ITEM_SPOTS:
			if t != s:
				check(Finds.spot_position(t["floor"], t["room"], t["slot"]).distance_to(spot) > 1.0, "%s and %s apart" % [s["id"], t["id"]])
		var door: Node = main._room_doors.get("%d:%s" % [s["floor"], s["room"]])
		if door:
			check(Vector2(door.global_position.x, door.global_position.z).distance_to(flat) > 1.9, "%s clear of the door swing" % s["id"])
		var floor_pt := spot + Vector3(0.0, 0.05, 0.0)
		var closest := NavigationServer3D.map_get_closest_point(map, floor_pt)
		check(Vector2(closest.x, closest.z).distance_to(flat) > 0.45, "%s table carved out of the navmesh" % s["id"])
		var path := NavigationServer3D.map_get_path(map, main._spawn_point, floor_pt, true)
		var end: Vector3 = path[path.size() - 1] if path.size() > 0 else main._spawn_point
		check(absf(end.y - spot.y) < 1.5 and Vector2(end.x, end.z).distance_to(flat) < 1.5, "%s reachable on the navmesh" % s["id"])
	for it in items:
		check(not it.is_in_group("story") and not it.is_in_group("find"), "items are not story items or finds: " + it.item_id)
		var reachable := false
		for off in [Vector3(1.2, 0.5, 0), Vector3(-1.2, 0.5, 0), Vector3(0, 0.5, 1.2), Vector3(0, 0.5, -1.2)]:
			var r: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(it.global_position + off, it.global_position, 57))
			if not r.is_empty() and r["collider"] == it:
				reachable = true
		check(reachable, "item reachable by ray: " + it.item_id)
	# The red room picker never lands on an item room (300 re-rolls).
	var bad := 0
	for i in 300:
		main._choose_story_rooms()
		for s: Dictionary in main.ITEM_SPOTS:
			if s["floor"] == main.quest.red_room_floor and s["room"] == main.quest.red_room_label:
				bad += 1
	check(bad == 0, "red room never hosts an item (%d)" % bad)

	# Master key card: opens the day's locked after-hours clue room once, never a demo door.
	p.give_item("master_key", "Master key card")
	var after_door: Node = main._room_doors.get("%d:%s" % [main.AFTER_HOURS_ROOMS[0][0], main.AFTER_HOURS_ROOMS[0][1]])
	check(after_door.locked, "after-hours room locked before the last bell")
	after_door.interact(p)
	check(not after_door.locked and not p.has_item("master_key"), "card opens the locked room once and is used up")
	p.give_item("master_key", "Master key card")
	var demo_doors := 0
	for d in get_nodes_in_group("doors"):
		if d.key_id == "__demo__":
			demo_doors += 1
			d.interact(p)
			check(d.locked and not d.is_open and p.has_item("master_key"), "the card never opens a demo door and is not used up")      # Review Focus 1
			check(not d.master_key_ok, "demo door never accepts the card")
	check(demo_doors > 0, "there are demo doors to test")
	var lab_door: Node = main.quest.lab_door
	lab_door.interact(p)
	check(lab_door.locked and p.has_item("master_key"), "the card does not open Lab 14")
	# Other after-hours rooms (not locked today) never take the card either.
	for k in range(1, main.AFTER_HOURS_ROOMS.size()):
		var other: Node = main._room_doors.get("%d:%s" % [main.AFTER_HOURS_ROOMS[k][0], main.AFTER_HOURS_ROOMS[k][1]])
		if other:
			check(not other.master_key_ok, "only today's locked after-hours door takes the card")
	# After the last bell unlocks the room, the flag is cleared.
	main._set_after_hours_lock(main.AFTER_HOURS_ROOMS[0], false)
	check(not after_door.master_key_ok, "unlocking the after-hours room clears the card flag")
	p.remove_item("master_key")

	# Dog biscuit: Csoki follows for 3 game hours.
	var dog: Node = main.csoki
	p.give_item("biscuit", "Dog biscuit")
	dog.interact(p)
	check(dog.is_following and not p.has_item("biscuit"), "Csoki follows after a biscuit")
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, -6)   # Brief said +5: that is outside the front door (the player falls out of the world).
	await create_timer(6.0).timeout
	check(dog.global_position.distance_to(main.player.global_position) < 6.0, "Csoki keeps up (%.1f m)" % dog.global_position.distance_to(main.player.global_position))
	check(dog.is_in_group("csoki") and not dog.is_in_group("teachers") and dog.collision_layer == 16, "Csoki stays csoki-only, layer 16")
	main.daynight.minutes += 181.0
	await create_timer(0.5).timeout
	check(not dog.is_following, "the follow ends after 3 game hours")
	# No biscuit: petting as before (achievement event still emitted).
	var seen: Array = []
	p.inspected.connect(func(t: String) -> void: seen.append(t))
	dog.interact(p)
	check(seen.size() == 1 and seen[0].contains("Csoki"), "petting without a biscuit")
	# Last bell ends the follow.
	p.give_item("biscuit", "Dog biscuit")
	dog.interact(p)
	main.daynight.minutes = main.campaign.LAST_BELL + 1.0
	await create_timer(0.5).timeout
	check(not dog.is_following, "the last bell sends Csoki back to the hall")
	# Following dog and the day rollover: it returns to the hall (no soft-lock, nothing stuck).
	main.daynight.minutes = 700.0
	p.give_item("biscuit", "Dog biscuit")
	dog.interact(p)
	check(dog.is_following, "follows again")
	main.campaign.start_day(2)
	await create_timer(0.5).timeout
	check(not dog.is_following, "a new day ends the follow")
	# A second biscuit cannot be picked up while holding one (no lost biscuit).
	p.give_item("biscuit", "Dog biscuit")
	var pick: Node = null
	for it in get_nodes_in_group("item"):
		if is_instance_valid(it) and it.kind == "biscuit":
			pick = it
	pick.interact(p)
	check(is_instance_valid(pick) and not pick.is_queued_for_deletion(), "a biscuit stays on its table while one is held")

	# G2: feeding twice keeps the second biscuit in inventory.
	dog.interact(p)
	check(dog.is_following and not p.has_item("biscuit"), "first biscuit consumed, dog follows")
	p.give_item("biscuit", "Dog biscuit")
	var fed_msgs: Array = []
	var on_inspected := func(t: String) -> void: fed_msgs.append(t)
	p.inspected.connect(on_inspected)
	dog.interact(p)
	p.inspected.disconnect(on_inspected)
	check(dog.is_following, "dog still follows")
	check(p.has_item("biscuit"), "second biscuit is kept in inventory while already following")
	check(fed_msgs.size() == 1 and fed_msgs[0] == "Csoki is already with you.", "message when second biscuit is offered: %s" % str(fed_msgs))
	_cleanup(main)
