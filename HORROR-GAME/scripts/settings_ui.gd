extends VBoxContainer
## Settings rows bound to Profile. Changes apply live; they are saved when a drag ends, a key nudges a slider or a toggle flips.

const GraphicsSettings := preload("res://scripts/graphics.gd")

var _profile: Node
var _controls := {}   ## setting key -> its control, so a preset can move them all.
var _preset: OptionButton
var _on_change: Callable
var _dragging := false


func setup(profile: Node, on_change: Callable) -> void:
	_profile = profile
	_on_change = on_change
	add_theme_constant_override("separation", 8)
	_slider("Master volume", "volume", 0.0, 1.0, 0.05)
	_slider("Mouse sensitivity", "sensitivity", 0.001, 0.006, 0.0002)
	_slider("Field of view", "fov", 60.0, 100.0, 1.0)
	_slider("Brightness", "brightness", 0.6, 1.6, 0.05)
	_check("Invert Y axis", "invert_y")
	_check("Fullscreen", "fullscreen")
	_check("Scare flashes", "scare_flash")
	_check("Easy map (show my position)", "easy_map")
	_graphics_rows()


## Graphics: a preset on top, then every setting it sets. Changing one of them switches the preset to Custom.
func _graphics_rows() -> void:
	var heading := Label.new()
	heading.text = "Graphics (turn lamps off and lower the render scale on slow PCs)"
	add_child(heading)
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Preset"
	name_label.custom_minimum_size = Vector2(220.0, 0.0)
	row.add_child(name_label)
	_preset = OptionButton.new()
	_preset.name = "preset"
	for preset_name in GraphicsSettings.PRESET_NAMES:
		_preset.add_item(preset_name)
	_preset.add_item("Custom")
	_preset.item_selected.connect(_choose_preset)
	row.add_child(_preset)
	add_child(row)
	_slider("Render scale", "render_scale", 0.5, 1.0, 0.05)
	_check("Real-time lamps (off: flat ambient light, much faster)", "dynamic_lighting")
	_option("Shadows", "shadows", ["Off", "Sun and flashlight", "All lamps"])
	_slider("View distance (metres)", "view_distance", 40.0, 250.0, 10.0)
	_check("Ambient occlusion and volumetric fog", "effects")
	_option("Anti-aliasing", "aa", ["Off", "FXAA", "MSAA 2x"])
	_check("VSync", "vsync")
	_slider("FPS limit (0 unlimited)", "fps_cap", 0.0, 240.0, 10.0)
	_sync_preset()


func _choose_preset(index: int) -> void:
	if index >= GraphicsSettings.PRESET_NAMES.size():
		return
	_profile.set_setting("quality", index)
	var values := GraphicsSettings.preset_values(index)
	for key: String in values:
		_profile.set_setting(key, values[key])
		var control: Control = _controls[key]
		if control is Range:
			(control as Range).set_value_no_signal(float(values[key]))
		elif control is CheckBox:
			(control as CheckBox).set_pressed_no_signal(bool(values[key]))
		elif control is OptionButton:
			(control as OptionButton).select(int(values[key]))
	_profile.save()
	_on_change.call()


func _sync_preset() -> void:
	if _preset == null:
		return
	var level := GraphicsSettings.matching_preset(_profile)
	_preset.select(level)
	if level < GraphicsSettings.PRESET_NAMES.size():
		_profile.set_setting("quality", level)


func _option(label: String, key: String, choices: Array) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(220.0, 0.0)
	row.add_child(name_label)
	var button := OptionButton.new()
	button.name = key
	for choice: String in choices:
		button.add_item(choice)
	button.select(int(_profile.get_setting(key)))
	button.item_selected.connect(func(index: int) -> void: _store(key, index))
	row.add_child(button)
	_controls[key] = button
	add_child(row)


func _slider(label: String, key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(220.0, 0.0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.name = key
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(_profile.get_setting(key))
	slider.custom_minimum_size = Vector2(320.0, 0.0)
	slider.drag_started.connect(func() -> void: _dragging = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		_profile.save())
	slider.value_changed.connect(func(v: float) -> void: _store(key, v, not _dragging))
	row.add_child(slider)
	_controls[key] = slider
	add_child(row)


func _check(label: String, key: String) -> void:
	var box := CheckBox.new()
	box.name = key
	box.text = label
	box.button_pressed = bool(_profile.get_setting(key))
	box.toggled.connect(func(on: bool) -> void: _store(key, on))
	_controls[key] = box
	add_child(box)


func _store(key: String, value: Variant, save := true) -> void:
	_profile.set_setting(key, value)
	if GraphicsSettings.KEYS.has(key):
		_sync_preset()
	if save:
		_profile.save()
	_on_change.call()
