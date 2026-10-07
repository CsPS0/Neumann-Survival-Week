extends SceneTree
## Full inventory. player.give_item documents that story items are never refused (they end up in the hand when
## everything is full), and a week of play collects far more than the 11 slots (9 clues, finds, keys, the form).
## pickup.gd refuses every pickup when can_carry() is false, so this test FAILS while that soft-lock exists.
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
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	var p: Node = main.player
	var slots := 0
	for place: int in p.items.slots:
		slots += p.items.capacity(place)
	print("slots: %d" % slots)
	for i in slots:
		p.give_item("filler_%d" % i, "Filler %d" % i)
	check(not p.can_carry(), "every slot is taken")

	var salt: Node = null
	var clue: Node = null
	for n in get_nodes_in_group("pickup"):
		if n.item_id == "salt":
			salt = n
		elif n.item_id.begins_with("clue_") and clue == null:
			clue = n
	salt.interact(p)
	check(p.has_item("salt"), "a story item (salt) can be taken with a full inventory")
	clue.interact(p)
	check(p.has_item(clue.item_id), "a clue (needed for ending 4) can be taken with a full inventory")
	var path: String = main.profile.path
	main.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
