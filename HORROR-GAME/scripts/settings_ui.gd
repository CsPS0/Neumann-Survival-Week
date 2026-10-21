extends VBoxContainer
## Settings rows bound to Profile. Changes apply live; they are saved when a drag ends, a key nudges a slider or a toggle flips.

const GraphicsSettings := preload("res://scripts/graphics.gd")

var _profile: Node
var _controls := {}   ## setting key -> its control, so a preset can move them all.
var _val_labels := {} ## setting key -> its value Label.
var _preset: OptionButton
const KEY_LIST := [
	["W A S D", "Move"], ["Shift", "Sprint"], ["Mouse", "Look"], ["E", "Interact"], ["F", "Flashlight"],
	["T", "Flash burst"], ["Q", "Phone"], ["H", "Phone: one or two hands"], ["Tab", "Inventory, or next phone app"],
	["B", "Drop or pick up the bag"], ["X", "Switch hand"], ["V", "Stow or take out the held item"],
	["Space", "Hold breath in a locker"], ["G", "Name the entity (day 4 and 5)"], ["Esc", "Pause"],
]

var _tabs: TabContainer
var _page: VBoxContainer   ## The column of the tab being built.
var _on_change: Callable
var _dragging := false


func setup(profile: Node, on_change: Callable) -> void:
	_profile = profile
	_on_change = on_change
	_tabs = TabContainer.new()
	_tabs.name = "tabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)

	_open_tab("Graphics")
	_category("DISPLAY", "", false)
	_check("Fullscreen", "fullscreen")
	_slider("Brightness", "brightness", 0.6, 1.6, 0.05, func(v: float) -> String: return "%.2fx" % v)
	_slider("Field of view", "fov", 60.0, 100.0, 1.0, func(v: float) -> String: return "%d°" % int(round(v)))
	_graphics_rows()

	_open_tab("Audio")
	_category("VOLUME", "", false)
	_slider("Master volume", "volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100.0)))

	_open_tab("Controls")
	_category("MOUSE AND LOOK", "", false)
	_slider("Mouse sensitivity", "sensitivity", 0.001, 0.006, 0.0002, func(v: float) -> String: return "%.4f" % v)
	_check("Invert Y axis", "invert_y")

	_category("KEYS")
	for row: Array in KEY_LIST:
		_key_row(row[0], row[1])

	_open_tab("Gameplay")
	_category("ASSISTS", "", false)
	_check("Easy map (show player position)", "easy_map")
	_category("COMFORT")
	_check("Scare flashes (screen blackouts & stings)", "scare_flash")

	var reset := Button.new()
	reset.name = "reset_defaults"
	reset.text = "Reset all settings to defaults"
	reset.pressed.connect(_reset_defaults)
	add_child(reset)


## Starts a tab: a scrolling column. The rows added next go into it.
func _open_tab(title: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	margin.add_child(_page)
	scroll.add_child(margin)
	_tabs.add_child(scroll)


func _category(title: String, subtitle := "", divider := true) -> void:
	var cat_box := VBoxContainer.new()
	cat_box.add_theme_constant_override("separation", 2)
	if divider:
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 12)
		cat_box.add_child(sep)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	cat_box.add_child(label)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		cat_box.add_child(sub)

	_page.add_child(cat_box)


## Graphics: a preset on top, then every setting it sets. Changing one of them switches the preset to Custom.
func _graphics_rows() -> void:
	_category("PERFORMANCE", "Lower preset, turn off lamps and reduce render scale on older school PCs.")

	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Quality preset"
	name_label.custom_minimum_size = Vector2(240.0, 0.0)
	row.add_child(name_label)
	_preset = OptionButton.new()
	_preset.name = "preset"
	for preset_name in GraphicsSettings.PRESET_NAMES:
		_preset.add_item(preset_name)
	_preset.add_item("Custom")
	_preset.item_selected.connect(_choose_preset)
	row.add_child(_preset)
	_page.add_child(row)

	_slider("Render scale", "render_scale", 0.5, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100.0)))
	_check("Real-time lamps (off uses flat ambient light, much faster)", "dynamic_lighting")
	_option("Shadows", "shadows", ["Off", "Sun and flashlight", "All lamps"])
	_slider("View distance", "view_distance", 40.0, 250.0, 10.0, func(v: float) -> String: return "%d m" % int(round(v)))
	_check("Ambient occlusion and volumetric fog", "effects")
	_option("Anti-aliasing", "aa", ["Off", "FXAA", "MSAA 2x"])
	_check("VSync", "vsync")
	_slider("FPS limit", "fps_cap", 0.0, 240.0, 10.0, func(v: float) -> String: return "Unlimited" if v <= 0.0 else ("%d FPS" % int(round(v))))
	_sync_preset()


func _choose_preset(index: int) -> void:
	if index >= GraphicsSettings.PRESET_NAMES.size():
		return
	_profile.set_setting("quality", index)
	var values := GraphicsSettings.preset_values(index)
	for key: String in values:
		_profile.set_setting(key, values[key])
		_show_value(key, values[key])
	_profile.save()
	_on_change.call()


## Moves the control of `key` to `value` without firing its signal.
func _show_value(key: String, value: Variant) -> void:
	var control: Control = _controls.get(key)
	if control is Range:
		(control as Range).set_value_no_signal(float(value))
		if _val_labels.has(key):
			var fmt: Callable = _val_labels[key]["fmt"]
			_val_labels[key]["label"].text = fmt.call(float(value))
	elif control is CheckBox:
		(control as CheckBox).set_pressed_no_signal(bool(value))
	elif control is OptionButton:
		(control as OptionButton).select(int(value))


## Every setting back to the first-start values: the preset for this PC, then the plain defaults.
func _reset_defaults() -> void:
	var values: Dictionary = _profile.DEFAULTS.duplicate()
	values["quality"] = _profile.default_quality()
	values.merge(GraphicsSettings.preset_values(int(values["quality"])), true)
	for key: String in values:
		_profile.set_setting(key, values[key])
		_show_value(key, _profile.get_setting(key))
	_sync_preset()
	_profile.save()
	_on_change.call()


func _key_row(key_name: String, action: String) -> void:
	var row := HBoxContainer.new()
	var key_label := Label.new()
	key_label.text = key_name
	key_label.custom_minimum_size = Vector2(120.0, 0.0)
	key_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	row.add_child(key_label)
	var action_label := Label.new()
	action_label.text = action
	row.add_child(action_label)
	_page.add_child(row)


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
	name_label.custom_minimum_size = Vector2(240.0, 0.0)
	row.add_child(name_label)
	var button := OptionButton.new()
	button.name = key
	for choice: String in choices:
		button.add_item(choice)
	button.select(int(_profile.get_setting(key)))
	button.item_selected.connect(func(index: int) -> void: _store(key, index))
	row.add_child(button)
	_controls[key] = button
	_page.add_child(row)


func _slider(label: String, key: String, low: float, high: float, step: float, formatter: Callable = Callable()) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(240.0, 0.0)
	row.add_child(name_label)

	var cur_val := float(_profile.get_setting(key))

	var slider := HSlider.new()
	slider.name = key
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = cur_val
	slider.custom_minimum_size = Vector2(260.0, 0.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.drag_started.connect(func() -> void: _dragging = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		_profile.save())

	var val_label: Label = null
	if formatter.is_valid():
		val_label = Label.new()
		val_label.custom_minimum_size = Vector2(70.0, 0.0)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_label.text = formatter.call(cur_val)
		val_label.add_theme_font_size_override("font_size", 14)
		val_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		_val_labels[key] = {"label": val_label, "fmt": formatter}

	slider.value_changed.connect(func(v: float) -> void:
		if val_label and formatter.is_valid():
			val_label.text = formatter.call(v)
		_store(key, v, not _dragging)
	)

	row.add_child(slider)
	if val_label:
		row.add_child(val_label)

	_controls[key] = slider
	_page.add_child(row)


func _check(label: String, key: String) -> void:
	var box := CheckBox.new()
	box.name = key
	box.text = label
	box.button_pressed = bool(_profile.get_setting(key))
	box.toggled.connect(func(on: bool) -> void: _store(key, on))
	_controls[key] = box
	_page.add_child(box)


func _store(key: String, value: Variant, save := true) -> void:
	_profile.set_setting(key, value)
	if GraphicsSettings.KEYS.has(key):
		_sync_preset()
	if save:
		_profile.save()
	_on_change.call()
