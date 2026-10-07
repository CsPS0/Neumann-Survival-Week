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

const Clues := preload("res://scripts/clues.gd")
const Lessons := preload("res://scripts/lessons.gd")

func _run() -> void:
	for id in Lessons.TEACHER_NAMES:
		var seen := {}
		for k in 9:
			var t := Clues.text(id, k)
			check(t != "", "%s clue %d exists" % [id, k])
			seen[t] = true
		check(seen.size() == 9, id + " has 9 distinct clues")
	for a in Lessons.TEACHER_NAMES:
		for b in Lessons.TEACHER_NAMES:
			if a != b:
				check(Clues.text(a, 0) != Clues.text(b, 0), "teachers differ")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	check(get_nodes_in_group("clue").size() == 3, "3 clues on day 1")
	# Locked after-hours door on day 1, no key.
	var door: Node = main._room_doors.get("2:205")
	check(door != null and door.locked, "day 1 after-hours door locked")
	# Note pool never overlaps reserved rooms, lessons or Gazd.
	var FloorData := load("res://scripts/floor_data.gd")
	for room in main._clue_rooms if not main._clue_rooms.is_empty() else main._note_pool:
		var label: String = FloorData.FLOORS[room[0]]["rooms"][room[1]][0]
		check(not main.RESERVED_ROOMS.has(label), "pool room %s not reserved" % label)
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign.daynight.minutes = 826.0
	await create_timer(0.3).timeout
	check(not door.locked, "last bell unlocks day 1 room")
	main.campaign.start_day(2)
	await create_timer(0.3).timeout
	check(get_nodes_in_group("clue").size() == 3, "day 2 replaces the clues, no duplicates")
	var d2: Node = main._room_doors.get("2:GT8")
	check(d2 != null and d2.locked, "day 2 after-hours door locked")
	var culprit: String = main.campaign.culprit
	var innocent := ""
	for id in Lessons.TEACHER_NAMES:
		if id != culprit:
			innocent = id
	check(main.campaign.dialogue(culprit).size() > main.campaign.dialogue(innocent).size(), "the culprit says something extra")
	var clue: Node = get_nodes_in_group("clue")[0]
	clue.interact(main.player)
	check(main.campaign.clues.size() == 1, "taking a clue records it exactly once")
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	check(get_nodes_in_group("clue").size() == 0, "no clues on hunt days")
	var office: Node = main._room_doors.get("2:205")
	check(office != null and not office.locked, "Igazgatói open on hunt day")
	# Reachability: every day's 3 clues, first interact-ray hit from 1.5 m away is the clue itself.
	var bodies_before: int = get_nodes_in_group("doors").size()
	for d in 3:
		main.campaign.start_day(d + 1)
		await create_timer(0.4).timeout
		for c in get_nodes_in_group("clue"):
			var ok := false
			for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				var from: Vector3 = c.global_position + dir * 1.5 + Vector3(0, 0.85, 0)
				var q := PhysicsRayQueryParameters3D.create(from, c.global_position, 57)
				var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.get("collider") == c:
					ok = true
			check(ok, "day %d %s reachable" % [d + 1, c.item_id])
	check(main._clue_spots.size() == 9, "9 precomputed clue spots")
