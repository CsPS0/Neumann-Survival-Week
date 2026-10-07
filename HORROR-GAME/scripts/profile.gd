extends Node
## Settings, unlocked achievements and seen endings, stored in user://profile.cfg. Applies settings to the game.

const Achievements := preload("res://scripts/achievements.gd")
const Endings := preload("res://scripts/endings.gd")
const DEFAULTS := {"volume": 0.8, "sensitivity": 0.0025, "invert_y": false, "fov": 75.0, "brightness": 1.0, "fullscreen": false, "easy_map": false, "scare_flash": true}
## Slider ranges, kept in step with settings_ui.gd. Hand-edited values are clamped into them.
const RANGES := {"volume": [0.0, 1.0], "sensitivity": [0.001, 0.006], "fov": [60.0, 100.0], "brightness": [0.6, 1.6]}

var path := "user://profile.cfg"
var settings := DEFAULTS.duplicate()
var unlocked: Array[String] = []
var endings_seen: Array[int] = []


func _ready() -> void:
	add_to_group("profile")


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULTS[key])


func set_setting(key: String, value: Variant) -> void:
	settings[key] = _clean(key, value)


func unlock(id: String) -> bool:
	if unlocked.has(id):
		return false
	unlocked.append(id)
	save()
	return true


func has(id: String) -> bool:
	return unlocked.has(id)


func mark_ending(id: int) -> void:
	if id >= 1 and id <= Endings.COUNT and not endings_seen.has(id):
		endings_seen.append(id)
		save()


func save() -> void:
	var file := ConfigFile.new()
	for key: String in settings:
		file.set_value("settings", key, settings[key])
	file.set_value("progress", "unlocked", unlocked)
	file.set_value("progress", "endings", endings_seen)
	var err := file.save(path)
	if err != OK:
		push_warning("Could not save %s (error %d)" % [path, err])


func load_from_disk() -> void:
	settings = DEFAULTS.duplicate()
	unlocked.clear()
	endings_seen.clear()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key: String in DEFAULTS:
		settings[key] = _clean(key, file.get_value("settings", key, DEFAULTS[key]))
	var ids: Variant = file.get_value("progress", "unlocked", [])
	if ids is Array:
		for id: Variant in ids:
			if id is String and Achievements.LIST.has(id) and not unlocked.has(id):
				unlocked.append(id)
	var seen: Variant = file.get_value("progress", "endings", [])
	if seen is Array:
		for id: Variant in seen:
			if id is int and id >= 1 and id <= Endings.COUNT and not endings_seen.has(id):
				endings_seen.append(id)


## Wrong type -> default; numbers are clamped into the slider range.
func _clean(key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[key]
	if fallback is bool:
		return value if value is bool else fallback
	if not (value is float or value is int):
		return fallback
	var bounds: Array = RANGES[key]
	return clampf(float(value), bounds[0], bounds[1]) if is_finite(float(value)) else fallback


func apply(player: Node, environment: Environment) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(get_setting("volume")), 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if get_setting("fullscreen")
				else DisplayServer.WINDOW_MODE_WINDOWED)
	if player:
		player.mouse_sensitivity = get_setting("sensitivity")
		player.invert_y = get_setting("invert_y")
		var camera: Camera3D = player.get("camera")
		if camera:
			camera.fov = get_setting("fov")
	if environment:
		environment.adjustment_enabled = float(get_setting("brightness")) != 1.0
		environment.adjustment_brightness = get_setting("brightness")
