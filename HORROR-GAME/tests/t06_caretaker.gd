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

## Fresh game on day 1, past the lessons so the skip limit cannot end the run.
func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	return main

func _run() -> void:
	# Scenario A: the caretaker appears after hours and catching the player is expulsion.
	var main: Node = await _fresh()
	check(get_nodes_in_group("caretaker").is_empty(), "no caretaker during school")
	check(get_nodes_in_group("teachers").size() == 8, "eight teachers during school")
	main.daynight.minutes = 860.0   # last bell + 35 min
	await create_timer(0.5).timeout
	var care := get_nodes_in_group("caretaker")
	check(care.size() == 1, "one caretaker after hours")
	check(get_nodes_in_group("teachers").size() <= 8 and not get_nodes_in_group("teachers").has(care[0]), "caretaker is not a teacher")
	check(main.ending_screen.current_id == 0, "not ended yet")
	care[0].global_position = main.player.global_position + Vector3(0.5, 0, 0)
	await create_timer(0.5).timeout
	check(main.ending_screen.current_id == 3, "caught by the caretaker: ending 3 (got %d)" % main.ending_screen.current_id)
	main.free()
	await create_timer(0.3).timeout
	check(get_nodes_in_group("caretaker").is_empty() and get_nodes_in_group("teachers").is_empty(), "scene A fully gone")

	# Scenario B (Review Focus 4): a new day clears yesterday's caretaker and respawns the teachers.
	var m2: Node = await _fresh()
	m2.daynight.minutes = 860.0
	await create_timer(0.5).timeout
	var old_care: Node = null
	for c in get_nodes_in_group("caretaker"):
		old_care = c
	check(old_care != null, "B: caretaker present on day 1 evening")
	var old_teachers := get_nodes_in_group("teachers")
	m2.campaign.use_front_door()
	await create_timer(0.5).timeout
	check(m2.campaign.day == 2, "B: day 2")
	check(not is_instance_valid(old_care) or old_care.is_queued_for_deletion(), "B: yesterday's caretaker is freed")
	check(get_nodes_in_group("caretaker").is_empty(), "B: no stale caretaker on day 2")
	var teachers := get_nodes_in_group("teachers")
	check(teachers.size() == 8, "B: exactly eight teachers on day 2 (got %d)" % teachers.size())
	check(teachers.all(func(t: Node) -> bool: return not old_teachers.has(t)), "B: the teachers are new nodes")
	check(get_nodes_in_group("clue").size() == 3, "B: three clues on day 2 (got %d)" % get_nodes_in_group("clue").size())
	# A just-spawned teacher accepts day-start stationing and still walks.
	await create_timer(3.0).timeout
	var karpati: Node = null
	for t in get_nodes_in_group("teachers"):
		if t.npc_id == "karpati":
			karpati = t
	check(karpati != null and karpati._ready_to_walk, "B: respawned teacher is walking")
	m2.free()
