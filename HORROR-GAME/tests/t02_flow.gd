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

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	var campaign: Node = main.campaign
	check(campaign != null, "main has a campaign")
	main._start_game()
	await create_timer(0.3).timeout
	check(campaign.day == 1 and main.daynight.minutes < 400.0, "day 1 begins near 06:00")
	check(main.ending_screen.visible == false, "no ending screen yet")
	var door := main.get_node_or_null("FrontDoor")
	check(door != null and door.prompt.begins_with("Run away"), "front door exists")
	# door box must sit inside the Bejarat room (hall) and near the south wall
	var hall: Vector3 = main._room_centre(0, "Bejárat")
	check(door != null and absf(door.global_position.x - hall.x) < 1.0 and door.global_position.z > hall.z + 1.0 and door.global_position.z < hall.z + 1.9, "front door inside hall by south wall: %s hall %s" % [door.global_position, hall])
	# room test: standing at the Maths room (23) centre
	var c: Vector3 = main._room_centre(0, "23")
	main.player.global_position = c + Vector3(0, 0.1, 0)
	check(main._player_in_room("Maths"), "player in room 23")
	main.player.global_position = hall + Vector3(0, 0.1, 0)
	check(not main._player_in_room("Maths"), "player not in room 23 from hall")
	# ending 5 via door before the last bell
	campaign.ending.connect(func(id: int) -> void: print("ending ", id))
	# day 4 kill -> ending 1
	campaign.day = 4
	campaign.player_killed()
	await create_timer(0.2).timeout
	check(main.ending_screen.visible, "ending screen shows")
	check(main.ending_screen.current_id == 1, "ending 1: killed")

	# second run: front door at day 1 morning = ending 5
	var main2: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main2)
	await create_timer(1.5).timeout
	main2._start_game()
	await create_timer(0.2).timeout
	main2.get_node("FrontDoor").handler.call(main2.player)
	await create_timer(0.1).timeout
	check(main2.ending_screen.current_id == 5, "ending 5: ran away")

	# third run: ritual -> ending 2, day jump past lessons with resolved flags
	var main3: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main3)
	await create_timer(1.5).timeout
	main3._start_game()
	await create_timer(0.2).timeout
	main3.campaign._resolved.fill(true)
	main3.campaign._ended.fill(true)
	main3.daynight.minutes = 1319.0
	await create_timer(1.0).timeout
	check(main3.campaign.day == 1 and main3.ending_screen.current_id == 3, "closing time day<=3 -> expelled (ending 3), got %d" % main3.ending_screen.current_id)
	main3.campaign.day = 5
	main3.campaign.ending_id = 0
	main3.campaign.ritual_completed()
	check(main3.campaign.ending_id == 2, "ritual -> ending 2")
