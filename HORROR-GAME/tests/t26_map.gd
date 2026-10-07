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

const PhoneMap := preload("res://scripts/phone_map.gd")
const FloorData := preload("res://scripts/floor_data.gd")

func _run() -> void:
	# fit(): the whole plan fits the area and stays centred.
	for f in 3:
		var data: Dictionary = FloorData.FLOORS[f]
		var area := Rect2(10, 60, 430, 700)
		var fit: Dictionary = PhoneMap.fit(data["rect"], area)
		var r: Rect2 = data["rect"]
		var a: Vector2 = r.position * fit["scale"] + fit["offset"]
		var b: Vector2 = r.end * fit["scale"] + fit["offset"]
		check(a.x >= area.position.x - 0.5 and a.y >= area.position.y - 0.5, "floor %d top-left inside" % f)
		check(b.x <= area.end.x + 0.5 and b.y <= area.end.y + 0.5, "floor %d bottom-right inside" % f)
		check(absf((a + b).x * 0.5 - area.get_center().x) < 1.0, "floor %d centred in x" % f)

	var main: Node = await _fresh()
	var phone: Node = main.player.phone
	var map: Control = phone._map
	check(map.size.x == 450.0 and map.size.y == 840.0, "phone viewport is 450x840")
	check(not map.easy and not map.shows_marker(), "marker off by default")
	check(map.floor_view == 0, "map starts on floor 0")
	main.player.global_position = Vector3(0, 8.1, 0)
	check(map.floor_view == 0, "the map does not follow the player")
	phone.set_raised(true)
	await create_timer(0.2).timeout
	phone.change_floor(1)
	check(map.floor_view == 1, "right arrow switches floor")
	phone.change_floor(1)
	phone.change_floor(1)
	check(map.floor_view == 2, "clamped at the top floor")
	phone.change_floor(-5)
	check(map.floor_view == 0, "clamped at floor 0")
	phone.set_raised(false)
	await create_timer(0.7).timeout
	phone.set_raised(true)
	check(map.floor_view == 0, "raising the phone resets to floor 0")
	main.profile.set_setting("easy_map", true)
	map.refresh_settings()
	check(map.easy and map.shows_marker(), "easy map shows the marker")
	main.profile.set_setting("easy_map", false)
	map.refresh_settings()
	check(not map.shows_marker(), "easy map off again")
	check(InputMap.has_action(&"phone_floor_prev") and InputMap.has_action(&"phone_floor_next"), "floor actions registered")
	_cleanup(main)
