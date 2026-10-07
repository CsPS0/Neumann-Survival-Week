extends SceneTree
var fails := 0
var cur: Node
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

func _fresh(day := 5) -> Node:
	if cur:
		cur.queue_free()
		await create_timer(0.3).timeout
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign.start_day(day)
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign.hunt_active = true
	cur = main
	return main

## The ritual ends in the fate prompt: 0 cures the teacher (ending 2 or 4), 1 destroys the host (ending 9).
func _ritual(right: int, total: int, clues: int, fate := 0) -> int:
	var main: Node = await _fresh()
	main.campaign.right = right
	main.campaign.total = total
	for i in clues:
		main.campaign.clues.append("c")
	main.quest.ritual_completed.emit()
	await create_timer(0.1).timeout
	check(main.choice_ui.visible and main._fate_open and main.campaign.ending_id == 0, "ritual opens the cure or destroy prompt, no ending yet")
	main.choice_ui.chosen.emit(fate)
	await create_timer(0.2).timeout
	return main.ending_screen.current_id

func _run() -> void:
	check(await _ritual(3, 3, 9) == 4, "high quiz and all clues: ending 4")
	check(await _ritual(4, 5, 9) == 4, "0.8 exactly: ending 4")
	check(await _ritual(79, 100, 9) == 2, "0.79: ending 2")
	check(await _ritual(3, 3, 8) == 2, "8 clues: ending 2")
	check(await _ritual(0, 0, 0) == 2, "nothing: ending 2")
	check(await _ritual(3, 3, 9, 1) == 9, "destroy the host: ending 9 whatever the score")
	check(await _ritual(0, 0, 0, 1) == 9, "destroy the host with nothing: ending 9")

	var main: Node = await _fresh()
	main.quest.ritual_completed.emit()
	await create_timer(0.1).timeout
	main.choice_ui.chosen.emit(0)
	await create_timer(0.2).timeout
	check(main.ending_screen.current_id == 2 and main.campaign.ending_id == 2, "ritual: ending 2")
	main.campaign.right = 3
	main.campaign.total = 3
	for i in 9:
		main.campaign.clues.append("c")
	main.campaign.ritual_completed()
	main.campaign.make_deal()
	await create_timer(0.2).timeout
	check(main.ending_screen.current_id == 2 and main.campaign.ending_id == 2, "second ending ignored")

	# Day 5 pact, all items placed at night.
	main = await _fresh()
	main.quest.altar_items = {"salt": true, "vial": true, "bell": true}
	main.daynight.minutes = 1100.0
	main.daynight.is_night = true
	main.quest.altar_interact(main.player)
	await create_timer(0.2).timeout
	check(main.choice_ui.visible, "day 5 altar offers the pact")
	check(not main.player.controls_enabled, "controls locked while asking")
	main.choice_ui.chosen.emit(1)
	await create_timer(0.2).timeout
	check(main.ending_screen.current_id == 6, "ending 6: pact")
	check(not main.choice_ui.visible and not main.player.controls_enabled, "overlay closed, controls stay off after ending")
	check(main._deal_kind == "", "deal kind cleared")

	# Ritual choice starts the ritual, no ending.
	main = await _fresh()
	main.quest.altar_items = {"salt": true, "vial": true, "bell": true}
	main.daynight.is_night = true
	main.quest.altar_interact(main.player)
	await create_timer(0.1).timeout
	main.choice_ui.chosen.emit(0)
	await create_timer(0.1).timeout
	check(main.quest.ritual_active and main.campaign.ending_id == 0, "ritual option begins the ritual")
	check(main.player.controls_enabled and not main.choice_ui.visible, "controls back")

	# Missing items: deal-only prompt, "Not now" does nothing.
	main = await _fresh()
	main.quest.altar_interact(main.player)
	await create_timer(0.1).timeout
	check(main.choice_ui.visible and main._deal_kind == "deal", "incomplete altar: deal only")
	main.choice_ui.chosen.emit(1)
	await create_timer(0.1).timeout
	check(main.campaign.ending_id == 0 and main.player.controls_enabled and not main.choice_ui.visible, "Not now: nothing happens")

	# Mutual exclusion and no re-open.
	main.quest.altar_interact(main.player)
	await create_timer(0.1).timeout
	main._open_accusation()
	check(not main._accusing, "accusation does not open over the pact")
	main.quest.altar_interact(main.player)
	check(main._deal_kind == "deal", "second request ignored")
	main.choice_ui.close()
	main._deal_kind = ""
	main._accusing = true
	main.quest.altar_interact(main.player)
	check(main._deal_kind == "", "pact does not open during accusation")
	main._accusing = false

	# Shared choice_ui: quiz-style pick never makes a deal.
	main.choice_ui.ask("quiz", "x", ["a", "b"])
	main.choice_ui.chosen.emit(0)
	await create_timer(0.1).timeout
	check(main.campaign.ending_id == 0, "quiz pick never ends the game")
	main.choice_ui.close()

	# Day 4: original altar behaviour, no prompt.
	main = await _fresh(4)
	main.choice_ui.close()
	main._accusing = false
	main.quest.altar_items = {"salt": true, "vial": true, "bell": true}
	main.daynight.minutes = 1100.0
	main.daynight.is_night = true
	main.quest.altar_interact(main.player)
	await create_timer(0.1).timeout
	check(not main.choice_ui.visible and main.quest.ritual_active, "day 4 altar starts ritual directly %s %s %s %s" % [main.choice_ui.visible, main.quest.ritual_active, main.campaign.day, main.daynight.is_night])

	# Day 5 before the culprit is named: no pact.
	main = await _fresh()
	main.campaign.hunt_active = false
	main.quest.altar_interact(main.player)
	check(not main.choice_ui.visible, "no pact without hunt")

	# G3: Csoki stops following after an ending.
	main = await _fresh(1)
	main.player.give_item("biscuit", "Dog biscuit")
	main.csoki.interact(main.player)
	check(main.csoki.is_following, "Csoki follows before ending")
	main.campaign.make_deal()
	check(main.campaign.ending_id != 0, "ending triggered")
	await create_timer(0.1).timeout
	check(not main.csoki.is_following, "Csoki stops following after an ending")
