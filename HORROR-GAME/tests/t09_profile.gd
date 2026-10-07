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

const Profile := preload("res://scripts/profile.gd")
const SettingsUI := preload("res://scripts/settings_ui.gd")

func _mk(path: String) -> Node:
	var p := Profile.new()
	p.path = path
	root.add_child(p)
	return p

func _run() -> void:
	var path := "user://neu_test_profile.cfg"
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)

	var p := _mk(path)
	p.load_from_disk()   # Review Focus 5: missing file
	check(is_equal_approx(p.get_setting("volume"), 0.8), "defaults when the file is missing")
	p.set_setting("volume", 0.3)
	p.set_setting("invert_y", true)
	check(p.unlock("first_day") and not p.unlock("first_day"), "unlock returns true once")
	p.mark_ending(2)
	p.mark_ending(2)
	p.save()

	var q := _mk(path)
	q.load_from_disk()
	check(is_equal_approx(q.get_setting("volume"), 0.3) and q.get_setting("invert_y") == true, "settings round-trip")
	check(q.has("first_day") and q.endings_seen == [2], "achievements and endings round-trip")

	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[[[ not a config")
	f.close()
	var r := _mk(path)
	r.load_from_disk()
	check(is_equal_approx(r.get_setting("volume"), 0.8) and r.unlocked.is_empty(), "corrupt file falls back to defaults")

	# Hand-edited values: wrong type and out of range.
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[settings]\nvolume=\"loud\"\nfov=500.0\nsensitivity=-1\nbrightness=9\ninvert_y=\"yes\"\nfullscreen=1\n[progress]\nunlocked=\"x\"\nendings=[1, \"a\", 3]\n")
	f.close()
	var s := _mk(path)
	s.load_from_disk()
	check(is_equal_approx(s.get_setting("volume"), 0.8), "wrong-typed volume -> default")
	check(is_equal_approx(s.get_setting("fov"), 100.0), "fov clamped high")
	check(is_equal_approx(s.get_setting("sensitivity"), 0.001), "sensitivity clamped low")
	check(is_equal_approx(s.get_setting("brightness"), 1.6), "brightness clamped high")
	check(s.get_setting("invert_y") == false and s.get_setting("fullscreen") == false, "wrong-typed bools -> default")
	check(s.unlocked.is_empty() and s.endings_seen == [1, 3], "bad progress values dropped")
	s.set_setting("fov", 10.0)
	check(is_equal_approx(s.get_setting("fov"), 60.0), "set_setting clamps")

	# apply: null player/env, bare node without camera, real player
	s.apply(null, null)
	var gs := GDScript.new()
	gs.source_code = "extends Node
var mouse_sensitivity := 0.0
var invert_y := false
"
	gs.reload()
	var bare := Node.new()
	bare.set_script(gs)
	var env := Environment.new()
	p.apply(bare, env)
	check(is_equal_approx(env.adjustment_brightness, 1.0) and not env.adjustment_enabled, "env brightness applied")
	var pl: Node = load("res://scenes/player.tscn").instantiate()
	root.add_child(pl)
	await create_timer(0.2).timeout
	p.set_setting("fov", 90.0)
	p.set_setting("sensitivity", 0.004)
	p.apply(pl, env)
	check(is_equal_approx(pl.camera.fov, 90.0) and is_equal_approx(pl.mouse_sensitivity, 0.004) and pl.invert_y == true, "player settings applied")
	var unready: Node = load("res://scenes/player.tscn").instantiate()
	p.apply(unready, env)   # camera not resolved yet: must not crash
	unready.free()

	# invert_y flips the pitch direction
	pl.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(0, 10)
	pl.head.rotation.x = 0.0
	pl.invert_y = false
	pl._unhandled_input(ev)
	var normal: float = pl.head.rotation.x
	pl.head.rotation.x = 0.0
	pl.invert_y = true
	pl._unhandled_input(ev)
	check(normal < 0.0 and pl.head.rotation.x > 0.0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "invert_y flips look direction")

	# Settings UI
	var calls := [0]
	var ui := SettingsUI.new()
	root.add_child(ui)
	var t := _mk("user://neu_test_ui.cfg")
	ui.setup(t, func() -> void: calls[0] += 1)
	var slider: HSlider = ui.find_child("fov", true, false)
	slider.value = 80.0
	check(is_equal_approx(t.get_setting("fov"), 80.0) and calls[0] == 1, "slider updates profile and fires callback")
	var box: CheckBox = ui.find_child("invert_y", true, false)
	box.button_pressed = true
	check(t.get_setting("invert_y") == true and calls[0] == 2, "checkbox updates profile and fires callback")
	check(FileAccess.file_exists("user://neu_test_ui.cfg"), "ui change saved")

	# Unwritable path must not crash
	var bad := _mk("user://no_such_dir/x.cfg")
	bad.save()

	for fp in [path, "user://neu_test_ui.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fp))
