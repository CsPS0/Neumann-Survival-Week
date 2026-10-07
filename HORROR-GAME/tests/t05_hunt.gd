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

func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	return main

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _find(id: String) -> Node:
	for p in get_nodes_in_group("pickup"):
		if p.item_id == id:
			return p
	return null

func _run() -> void:
	var main: Node = await _fresh()
	var key_item := _find("salt")   # The storage key now comes from the Porta (Task 6); the salt is a story pickup.
	check(key_item != null and not key_item.visible, "story items hidden before the hunt")
	check(key_item.collision_layer == 0, "hidden story item is not hit by the interact ray")
	var clues := get_nodes_in_group("clue")
	check(clues.size() == 3 and clues.all(func(c: Node) -> bool: return c.visible and c.collision_layer == 16), "clues stay usable")
	var battery: Node = null
	for p in get_nodes_in_group("pickup"):
		if p.kind == "battery":
			battery = p
	check(battery != null and battery.visible and battery.collision_layer == 16, "batteries stay usable")
	check(not battery.is_in_group("story") and not clues[0].is_in_group("story"), "batteries and clues are not story items")

	# Night on a school day: the entity stays asleep. Quiz answers never accuse.
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.daynight.night_fell.emit()
	await create_timer(0.2).timeout
	check(not main.entity.visible, "day 1 night does not wake the entity")
	main.choice_ui.ask("quiz", "x", ["a", "b"])
	main.choice_ui.chosen.emit(0)
	await create_timer(0.2).timeout
	check(main.campaign.ending_id == 0 and not main.campaign.hunt_active, "a quiz-style pick never accuses")
	main.choice_ui.close()
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	check(main.choice_ui.visible, "day 4 opens the accusation")
	main.choice_ui.chosen.emit(main.TEACHER_ORDER.size())   # "Not yet"	main.queue_free()
	await create_timer(0.3).timeout

	main = await _fresh()
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	check(main.choice_ui.visible and main.player.controls_enabled == false, "accusation open, controls off")
	main.campaign.expel()
	await create_timer(0.2).timeout
	check(not main.choice_ui.visible and not main.player.controls_enabled, "ending closes the overlay, controls stay off")
	main.choice_ui.chosen.emit(0)
	await create_timer(0.2).timeout
	check(not main.player.controls_enabled and not main.campaign.hunt_active and main.campaign.ending_id == 3, "late pick changes nothing")
