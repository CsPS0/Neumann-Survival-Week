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

func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	return e

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.profile.path = "user://neu_test_t11.cfg"
	root.add_child(main)
	await create_timer(1.5).timeout
	check(main.menu.is_open(), "menu open at boot")
	var labels: Array[String] = []
	for b in main.menu.find_children("*", "Button", true, false):
		labels.append(b.text)
	for expected in ["New game", "Achievements", "Endings", "Settings", "How to play", "Quit", "Resume", "Restart"]:
		check(labels.has(expected), "has a '%s' button" % expected)
	main.menu.profile.mark_ending(2)
	main.menu._refresh_lists()
	check(main.menu._endings_text().contains("Banished") and main.menu._endings_text().contains("???"), "gallery shows seen endings and ???")
	check(not main.menu._endings_text().contains("Caught"), "unseen ending hidden")
	main.profile.unlock("detective")
	main.menu._refresh_lists()
	check(main.menu._ach_label.text.contains("[x] Detective"), "unlocked achievement shown")

	# Title scene: camera dolly moves while paused, entity frozen and visible.
	check(paused, "tree paused on title")
	check(main._menu_camera.current, "menu camera current")
	var x0: float = main._menu_camera.position.x
	var ent_pos: Vector3 = main.entity.global_position
	await create_timer(1.0).timeout
	check(main._menu_camera.position.x > x0 + 0.1, "dolly moves while paused")
	check(main.entity.visible and main.entity.process_mode == Node.PROCESS_MODE_DISABLED, "entity visible and frozen")
	check(main.entity.global_position.is_equal_approx(ent_pos), "entity did not move")

	# Esc rules.
	main.menu._unhandled_input(_esc())
	check(main.menu._pages["title"].visible, "Esc on title does nothing")
	main.menu._open("settings")
	check(main.menu._pages["settings"].visible, "settings page opens")
	main.menu._unhandled_input(_esc())
	check(main.menu._pages["title"].visible, "Esc on settings returns to title")
	main.menu._open("endings")
	main.menu._unhandled_input(_esc())
	check(main.menu._pages["title"].visible, "Esc on endings returns to title")

	# Settings slider: live apply, save on drag end only.
	var applied := [0]
	main.menu.on_settings_changed = func() -> void: applied[0] += 1
	var ui: Node = main.menu.find_children("*", "VBoxContainer", true, false).filter(func(n): return n.get_script() != null)[0]
	var fov: HSlider = ui.find_child("fov", true, false)
	FileAccess.open("user://neu_test_t11.cfg", FileAccess.WRITE)  # fresh file marker
	DirAccess.remove_absolute("user://neu_test_t11.cfg")
	fov.drag_started.emit()
	fov.value = 90.0
	check(applied[0] == 1 and main.profile.get_setting("fov") == 90.0, "slider applies live")
	check(not FileAccess.file_exists("user://neu_test_t11.cfg"), "no save during drag")
	fov.drag_ended.emit(true)
	check(FileAccess.file_exists("user://neu_test_t11.cfg"), "saved on drag end")
	main.profile.settings["brightness"] = 1.0
	main.profile.apply(main.player, main.get_node("WorldEnvironment").environment)
	check(not main.get_node("WorldEnvironment").environment.adjustment_enabled, "adjustment off at brightness 1.0")

	# Pause.
	main._start_game()
	await create_timer(0.3).timeout
	check(not main.menu.is_open(), "menu closed in game")
	check(main.player.camera.current, "player camera current after start")
	check(not main.entity.visible, "entity hidden after start")
	main._unhandled_input(_esc())
	check(main.menu._pages["pause"].visible and main.menu.is_open(), "Esc opens pause")
	main.menu._open("settings")
	main.menu._unhandled_input(_esc())
	check(main.menu._pages["pause"].visible, "Esc on settings returns to pause")
	main.menu._unhandled_input(_esc())
	check(not main.menu.is_open() and not paused, "Esc on pause resumes")
	main.menu.show_pause()
	check(main.menu._pages["pause"].visible, "pause page opens")
	main.menu.hide_all()
	check(not main.menu.is_open(), "hide_all closes")
	DirAccess.remove_absolute("user://neu_test_t11.cfg")
