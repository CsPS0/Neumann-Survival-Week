extends SceneTree
var fails := 0
var cur: Node
const TMP := "user://neu_test_t13.cfg"
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	for f in ["neu_test_t13.cfg", "neu_test_t13_bad.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

## Fresh game on day 1. `resolve` marks every lesson handled so the clock can be jumped.
func _fresh(resolve := true) -> Node:
	if cur:
		cur.queue_free()
		await create_timer(0.3).timeout
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = TMP
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	main.campaign.incident = true   # The day 1 explosion would cancel lessons 4 to 7 as soon as the clock jumps past lesson 3.
	if resolve:
		main.campaign._resolved.fill(true)
		main.campaign._ended.fill(true)
	cur = main
	return main

func _day(n: int) -> Node:
	var main: Node = await _fresh()
	main.campaign.start_day(n)
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.choice_ui.close()
	main._accusing = false
	main.player.controls_enabled = true
	return main

func _run() -> void:
	# I1: the exposed culprit does not come back on day 5.
	var main: Node = await _day(4)
	var culprit: String = main.campaign.culprit
	check(main.campaign.accuse(culprit), "I1: correct accusation")
	await create_timer(0.2).timeout
	main.campaign.start_day(5)
	await create_timer(0.3).timeout
	var ids := []
	for t in get_nodes_in_group("teachers"):
		ids.append(t.npc_id)
	check(not ids.has(culprit) and ids.size() == 7, "I1: day 5 has the other 7 teachers only (%s)" % [ids])

	# I2: a blackout is not a skipped lesson; real skips still count.
	main = await _fresh(false)
	var c: Node = main.campaign
	c._resolved[0] = true
	c._ended[0] = true
	c.finish_lesson(0, 3, 3)
	c.daynight.minutes = c.lesson_end(0) + 3.0
	c.record_blackout()
	await create_timer(0.4).timeout
	check(c.skipped == 0, "I2: blackout in a break skips nothing (skipped %d)" % c.skipped)
	check(c._resolved[1] and not c._resolved[2], "I2: only the jumped lesson is excused")
	c._resolved.fill(true)
	c._resolved[4] = false
	c.daynight.minutes = c.lesson_start(4) + 3.0
	await create_timer(0.3).timeout
	check(c.skipped == 1, "I2: a genuinely missed lesson counts (skipped %d)" % c.skipped)
	main = await _fresh(false)
	main.campaign.daynight.minutes = main.campaign.lesson_start(6) + 3.0
	await create_timer(0.3).timeout
	check(main.campaign.ending_id == 3 and main.campaign.skipped == 6, "I2: 6 real skips still expel (ending %d, skipped %d)" % [main.campaign.ending_id, main.campaign.skipped])

	# I3: the grace lasts about 15 real seconds.
	main = await _fresh(false)
	c = main.campaign
	check(c._pace("lesson", c.lesson_start(0) + 0.5) == c.PACE_BREAK, "I3: pace in the grace is the break pace")
	check(c._pace("lesson", c.lesson_start(0) + 2.5) == c.PACE_SKIPPED, "I3: pace after the grace is 1.0")
	c.daynight.minutes = c.lesson_start(0) - 0.2
	await create_timer(3.0).timeout
	check(c.daynight.minutes >= c.lesson_start(0) and not c._resolved[0] and c.skipped == 0, "I3: 3 s after the bell lesson 0 is still attendable (m=%.2f)" % c.daynight.minutes)
	c.room_check = func(_i: int) -> bool: return true
	await create_timer(0.3).timeout
	check(c._resolved[0] and c.skipped == 0 and c.attended == 0 and main.lesson_ui.visible, "I3: arriving 3 s late starts the lesson")
	main = await _fresh(false)
	c = main.campaign
	c.daynight.minutes = c.lesson_start(0) + c.GRACE + 0.01
	await create_timer(0.3).timeout
	check(c.skipped == 1, "I3: unattended after the grace is a skip")

	# I4: the caretaker spawns far from the player and announces himself.
	main = await _fresh()
	var worst := 1e9
	for i in 12:
		main.player.global_position = main._patrol_markers.pick_random().global_position + Vector3(0, 0.1, 0)
		main._message_label.text = ""
		main._spawn_caretaker()
		var care: Node3D = main.get_child(main.get_child_count() - 1)
		check(care.is_in_group("caretaker"), "I4: last child is the caretaker")
		worst = minf(worst, care.global_position.distance_to(main.player.global_position))
	check(worst >= 20.0, "I4: caretaker never within 20 m (closest %.1f)" % worst)
	check("keys" in main._message_label.text, "I4: message shown (%s)" % main._message_label.text)

	# I5: the front door prompt tells the truth.
	main = await _fresh()
	main.daynight.minutes = 420.0
	main._process(0.0)
	check(main._front_door.get("prompt") == "Run away (ends the run)", "I5: day 1 07:00 run away")
	main.daynight.minutes = 840.0
	main._process(0.0)
	check(main._front_door.get("prompt") == "Go home (next day)", "I5: day 1 14:00 go home")
	main = await _day(4)
	main.daynight.minutes = 840.0
	main._process(0.0)
	check(main._front_door.get("prompt") == "Run away (ends the run)", "I5: day 4 14:00 run away")

	# M1: an ending with the keypad open.
	main = await _fresh()
	main._open_code_lock()
	check(main._code_open and not main.player.controls_enabled, "M1: keypad open")
	main.campaign.expel()
	await create_timer(0.2).timeout
	check(not main._code_open and not main._code_panel.visible, "M1: keypad closed by the ending")
	check(main._game_over and not main.player.controls_enabled, "M1: controls stay off")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	main._unhandled_input(esc)
	check(not main.player.controls_enabled, "M1: Esc does not re-enable controls")
	# R now reaches the restart branch (not swallowed by the keypad handler).
	check(not main._code_open and main._game_over, "M1: R path open")

	# M3: a ritual running at the day-4 rollover is interrupted.
	main = await _day(4)
	main.campaign.hunt_active = true
	main.quest.begin_ritual(main.player)
	check(main.quest.ritual_active and main.entity.force_hunt, "M3: ritual running")
	var count := [0]
	main.quest.ritual_interrupted.connect(func() -> void: count[0] += 1)
	main.campaign.start_day(5)
	await create_timer(0.2).timeout
	check(not main.quest.ritual_active and count[0] == 1, "M3: ritual interrupted once (%d)" % count[0])
	check(not main.entity.force_hunt and not main._altar_candles[0].visible, "M3: hunt and candles off")

	# M4: relocking closes the door.
	main = await _fresh()
	var room: Array = main.AFTER_HOURS_ROOMS[0]
	var door: Node = main._room_doors.get("%d:%s" % [room[0], room[1]])
	main._set_after_hours_lock(room, false)
	door.set_open(true)
	check(door.is_open, "M4: door opened")
	main._set_after_hours_lock(room, true)
	check(not door.is_open and door.locked, "M4: relock closes the door")

	# M5: one Gazd. table, nine working spots.
	main = await _fresh()
	check(main._clue_spots.size() == 9, "M5: nine clue spots")
	check(main._clue_spots[1] == main._clue_spots[4] and main._clue_spots[4] == main._clue_spots[7], "M5: Gazd. spot is the same each day")
	var spot: Vector3 = main._clue_spots[1]
	var tables := 0
	for n in main._region.get_children():
		if n is Node3D and absf(n.position.x - spot.x) < 0.01 and absf(n.position.z - spot.z) < 0.01 and absf(n.position.y - (spot.y - 0.03 - 0.375)) < 0.01:
			tables += 1
	check(tables == 1, "M5: exactly one table at the Gazd. spot (%d)" % tables)

	# M8: day-5 daylight altar hints at darkness; ritual_or_deal has "Not now".
	main = await _day(5)
	main.campaign.hunt_active = true
	main.quest.altar_items = {"salt": true, "vial": true, "bell": true}
	main.daynight.is_night = false
	main._message_label.text = ""
	var before: float = main.daynight.minutes
	main.quest.altar_interact(main.player)
	await create_timer(0.1).timeout
	check("needs darkness" in main._message_label.text, "M8: darkness hint (%s)" % main._message_label.text)
	check(main.choice_ui.visible and main._deal_kind == "deal" and main.daynight.minutes < before + 5.0, "M8: deal prompt, clock not skipped")
	main.choice_ui.chosen.emit(1)
	main = await _day(5)
	main.campaign.hunt_active = true
	main.quest.altar_items = {"salt": true, "vial": true, "bell": true}
	main.daynight.is_night = true
	main.quest.altar_interact(main.player)
	await create_timer(0.1).timeout
	check(main._deal_kind == "ritual_or_deal" and main.choice_ui.visible, "M8: night offers ritual or deal")
	main.choice_ui.chosen.emit(2)
	await create_timer(0.1).timeout
	check(not main.choice_ui.visible and main.player.controls_enabled and main.campaign.ending_id == 0 and not main.quest.ritual_active, "M8: Not now closes it, nothing happens")

	# M10: profile hardening with a hand-written bad file.
	main = await _fresh()
	var bad := "user://neu_test_t13_bad.cfg"
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("[settings]\nvolume=nan\nfov=inf\nbrightness=1.2\n[progress]\nunlocked=[\"first_day\", \"bogus\", 5, \"first_day\", \"ending_3\"]\nendings=[0, 9, 3, 3, -1, 8, 1000]\n")
	f.close()
	var p: Node = main.profile
	p.path = bad
	p.load_from_disk()
	check(p.get_setting("volume") == 0.8 and p.get_setting("fov") == 75.0 and is_equal_approx(p.get_setting("brightness"), 1.2), "M10: nan/inf fall back to defaults")
	check(Array(p.unlocked) == ["first_day", "ending_3"], "M10: unlocked filtered (%s)" % [p.unlocked])
	check(Array(p.endings_seen) == [9, 3, 8], "M10: endings filtered (%s)" % [p.endings_seen])
	p.mark_ending(0)
	p.mark_ending(9)
	p.mark_ending(5)
	check(Array(p.endings_seen) == [9, 3, 8, 5], "M10: mark_ending accepts only 1..9 (%s)" % [p.endings_seen])
	p.set_setting("volume", INF)
	p.set_setting("sensitivity", NAN)
	check(p.get_setting("volume") == 0.8 and p.get_setting("sensitivity") == 0.0025, "M10: set_setting rejects non-finite")
	p.path = TMP
