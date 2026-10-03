extends CanvasLayer
## Modal list of choices. Number keys 1-4 also pick. Emits chosen(index); the caller decides what happens next.

signal chosen(index: int)

var _title := Label.new()
var _body := Label.new()
var _buttons := GridContainer.new()   ## One column; long lists (the Porta keys) wrap into five.
var _count := 0


func _ready() -> void:
	layer = 55
	visible = false
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(680.0, 0.0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 20)
	box.add_child(_body)
	box.add_child(_buttons)


func ask(title: String, body: String, options: Array) -> void:
	_title.text = title
	_body.text = body
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_count = options.size()
	var long := options.size() > 8
	_buttons.columns = 5 if long else 1
	for i in options.size():
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, options[i]]
		button.add_theme_font_size_override("font_size", 16 if long else 22)
		button.custom_minimum_size = Vector2(0.0, 30.0 if long else 42.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: chosen.emit(i))
		_buttons.add_child(button)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed) or event.echo:
		return
	var index: int = event.keycode - KEY_1   # Only 1-9: letter keycodes lie above KEY_9 (E would be "option 21").
	if index >= 0 and index < mini(_count, 9):
		chosen.emit(index)
		get_viewport().set_input_as_handled()
