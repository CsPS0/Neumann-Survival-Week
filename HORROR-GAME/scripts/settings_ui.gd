extends VBoxContainer
## Settings rows bound to Profile. Changes apply live; they are saved when a drag ends, a key nudges a slider or a toggle flips.

var _profile: Node
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
	_slider("Graphics quality (0 low, 2 high)", "quality", 0.0, 2.0, 1.0)
	_check("Invert Y axis", "invert_y")
	_check("Fullscreen", "fullscreen")
	_check("Scare flashes", "scare_flash")
	_check("Easy map (show my position)", "easy_map")


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
	add_child(row)


func _check(label: String, key: String) -> void:
	var box := CheckBox.new()
	box.name = key
	box.text = label
	box.button_pressed = bool(_profile.get_setting(key))
	box.toggled.connect(func(on: bool) -> void: _store(key, on))
	add_child(box)


func _store(key: String, value: Variant, save := true) -> void:
	_profile.set_setting(key, value)
	if save:
		_profile.save()
	_on_change.call()
