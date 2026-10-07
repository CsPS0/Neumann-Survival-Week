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
	var scare: Node = main.scare
	check(scare != null, "scare node exists")
	check(main.profile.get_setting("scare_flash") == true, "setting defaults on")
	check(main.profile.get_setting("easy_map") == false, "easy_map defaults off")
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)

	check(scare.trigger(), "first trigger fires")
	check(scare.npcs_hidden, "NPCs are hidden during the flash")
	var hidden_teachers := 0
	for t in get_nodes_in_group("teachers"):
		if not t.visible:
			hidden_teachers += 1
	check(hidden_teachers == get_nodes_in_group("teachers").size(), "all suspect teachers hidden")
	check(main.csoki.visible == false and main.crowd.hidden, "Csoki and the crowd hidden")
	check(scare.overlay.color.a > 0.9, "screen is black right after the trigger")
	check(not scare.trigger(), "cooldown blocks a second flash")
	check(scare.cooldown_left > 15.0, "cooldown is about 20 s")
	await create_timer(0.8).timeout
	check(scare.overlay.color.a < 0.05, "the screen is back after the flash")
	main.entity.encounter(false, main.player.global_position + Vector3(8, 0, 0), 30.0)
	check(scare.npcs_hidden, "still hidden while the entity is around")
	main.entity.sleep()
	await create_timer(2.5).timeout
	check(not scare.npcs_hidden and main.csoki.visible and not main.crowd.hidden, "NPCs return after the entity is gone")
	for t in get_nodes_in_group("teachers"):
		check(t.visible, "suspect visible again")
	# G7: hide a teacher manually, trigger and end a flash, the teacher must still be hidden.
	var test_teacher: Node3D = get_nodes_in_group("teachers")[0] as Node3D
	test_teacher.visible = false
	scare.cooldown_left = 0.0
	check(scare.trigger(), "flash triggered with manually hidden teacher")
	main.entity.sleep()
	await create_timer(2.5).timeout
	check(not scare.npcs_hidden, "flash ended")
	check(not test_teacher.visible, "teacher hidden before flash remains hidden after restore")
	test_teacher.visible = true
	scare.cooldown_left = 0.0
	main.choice_ui.ask("x", "y", ["a"])
	check(not scare.trigger(), "no flash during a quiz/choice overlay")
	main.choice_ui.close()
	main.profile.set_setting("scare_flash", false)
	scare.cooldown_left = 0.0
	check(scare.trigger() and scare.overlay.color.a < 0.05, "setting off: NPCs vanish but no black frame")
	main.profile.set_setting("scare_flash", true)
	main.entity.sleep()
	await create_timer(2.5).timeout
	scare.cooldown_left = 0.0
	main.campaign.start_day(4)
	main.campaign.player_killed()
	await create_timer(0.2).timeout
	check(not scare.trigger(), "no flash behind an ending card")
	check(scare.overlay.color.a < 0.05 and not scare.npcs_hidden, "ending leaves no black frame or hidden NPCs")
	# A hand-written bad config value falls back to the default.
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "scare_flash", 5)
	cfg.save(main.profile.path)
	main.profile.load_from_disk()
	check(main.profile.get_setting("scare_flash") == true, "scare_flash=5 loads as default true")
	_cleanup(main)
