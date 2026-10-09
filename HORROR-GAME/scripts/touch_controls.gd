extends CanvasLayer
## On-screen controls for phones and tablets: a floating stick on the left half, a look area on the right half and
## buttons for every key the game uses. The buttons are drawn here and hit-tested by hand, because Godot only turns
## the first finger into a mouse click and the stick finger would block every button press.
## The overlay shows on Android (or with `-- --touch`) and hides while a menu, a dialog or the safe keypad is open.

const LOOK_SCALE := 1.4
const STICK_RADIUS := 60.0
const REPEAT_DELAY := 0.35
const REPEAT_EVERY := 0.12
const GAP := 10.0
const PAD := 24.0
## Keys that tell the overlay a physical keyboard is in use (the Back and volume keys do not count).
const HARDWARE_KEYS: Array[int] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_F, KEY_Q, KEY_TAB, KEY_SPACE, KEY_SHIFT,
		KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER]

var bridge: Node
var player: Node
var main: Node

var _canvas := Control.new()
var _buttons: Array[Dictionary] = []
var _held := {}   ## Finger index -> button it pressed.
var _joy_id := -1
var _look_id := -1
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _was_active := false
var _face := StyleBoxFlat.new()
var _face_down := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	main = get_parent()
	bridge = get_tree().get_first_node_in_group("input_bridge")
	if bridge == null:
		push_error("TouchControls requires InputBridge")
		set_process(false)
		set_process_input(false)
		return
	for style: StyleBoxFlat in [_face, _face_down]:
		style.set_corner_radius_all(14)
		style.set_border_width_all(2)
		style.border_color = Color(1.0, 1.0, 1.0, 0.45)
	_face.bg_color = Color(0.0, 0.0, 0.0, 0.38)
	_face_down.bg_color = Color(1.0, 1.0, 1.0, 0.35)
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	_build_buttons()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_canvas.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and bridge != null:
		bridge.trigger_pause()   # The Android Back button pauses and goes back through the menus.


# --- Buttons -------------------------------------------------------------------

func _build_buttons() -> void:
	var playing := func() -> bool: return not player.is_hiding
	var phone_up := func() -> bool: return not player.is_hiding and player.phone.raised
	var hiding := func() -> bool: return player.is_hiding
	var hunt_days := func() -> bool: return not player.is_hiding and main.campaign.day > main.campaign.LAST_SCHOOL_DAY
	var online := func() -> bool: return NetSession.is_multiplayer_active()
	# Bottom right: use, light, phone. While hiding: exit and hold breath.
	_add("E", "E\nUse", "br", Vector2(PAD, PAD), Vector2(120.0, 120.0), bridge.trigger_interact, Callable())
	_add("F", "F\nLight", "br", Vector2(PAD + 136.0, PAD), Vector2(84.0, 84.0), bridge.trigger_flashlight, playing)
	_add("Q", "Q\nPhone", "br", Vector2(PAD + 18.0, PAD + 136.0), Vector2(84.0, 84.0), bridge.trigger_phone, playing)
	_add("Breath", "Hold\nbreath", "br", Vector2(PAD + 136.0, PAD), Vector2(100.0, 100.0), Callable(), hiding, &"hold_breath")
	# Top right: pause, inventory and hands.
	var small := Vector2(64.0, 64.0)
	var names := ["Esc", "Tab", "Hands", "Bag", "Swap", "Stow"]
	var taps: Array[Callable] = [bridge.trigger_pause, bridge.trigger_phone_tab, bridge.trigger_phone_hands,
			bridge.trigger_bag, bridge.trigger_swap_hand, bridge.trigger_stow]
	var labels := ["Pause", "Tab", "Hands", "Bag", "Swap", "Stow"]
	for i in names.size():
		_add(names[i], labels[i], "tr", Vector2(PAD + (small.x + GAP) * i, 16.0), small, taps[i],
				Callable() if i == 0 else playing)
	_add("Name", "G\nName", "tr", Vector2(PAD, 16.0 + small.y + GAP), small, func() -> void: main._open_accusation(), hunt_days)
	_add("Ping", "Ping", "tr", Vector2(PAD + small.x + GAP, 16.0 + small.y + GAP), small,
			func() -> void: PingSystem.ping_at_crosshair(), online)
	# Phone: map floor, zoom and pan (the arrows repeat while held).
	var row := 16.0 + (small.y + GAP) * 2.0
	var step := small.x + GAP
	_add("Fl-", "Floor\n-", "tr", Vector2(PAD + step * 3.0, row), small, func() -> void: bridge.trigger_phone_floor(-1), phone_up)
	_add("Fl+", "Floor\n+", "tr", Vector2(PAD + step * 2.0, row), small, func() -> void: bridge.trigger_phone_floor(1), phone_up)
	_add("Z+", "Zoom\n+", "tr", Vector2(PAD + step, row), small, func() -> void: bridge.trigger_phone_zoom(true), phone_up, &"", true)
	_add("Z-", "Zoom\n-", "tr", Vector2(PAD, row), small, func() -> void: bridge.trigger_phone_zoom(false), phone_up, &"", true)
	var pad_row := row + step
	_add("Up", "^", "tr", Vector2(PAD + step * 2.0, pad_row), small, func() -> void: bridge.trigger_phone_view(Vector2i.UP), phone_up, &"", true)
	_add("Left", "<", "tr", Vector2(PAD + step * 3.0, pad_row + step), small, func() -> void: bridge.trigger_phone_view(Vector2i.LEFT), phone_up, &"", true)
	_add("Right", ">", "tr", Vector2(PAD + step, pad_row + step), small, func() -> void: bridge.trigger_phone_view(Vector2i.RIGHT), phone_up, &"", true)
	_add("Down", "v", "tr", Vector2(PAD + step * 2.0, pad_row + step * 2.0), small, func() -> void: bridge.trigger_phone_view(Vector2i.DOWN), phone_up, &"", true)


## `corner` is "br" or "tr"; `offset` is the distance from that screen corner to the nearest edges of the button.
func _add(id: String, text: String, corner: String, offset: Vector2, size: Vector2, tap: Callable, shown: Callable,
		hold := &"", repeat := false) -> void:
	_buttons.append({"id": id, "text": text, "corner": corner, "offset": offset, "size": size, "tap": tap,
			"shown": shown, "hold": hold, "repeat": repeat, "rect": Rect2(), "down": false, "timer": 0.0})


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	for b in _buttons:
		var size: Vector2 = b["size"]
		var offset: Vector2 = b["offset"]
		var y := view.y - offset.y - size.y if b["corner"] == "br" else offset.y
		b["rect"] = Rect2(Vector2(view.x - offset.x - size.x, y), size)


func _is_shown(b: Dictionary) -> bool:
	var shown: Callable = b["shown"]
	return shown.is_null() or shown.call()


# --- State ---------------------------------------------------------------------

func _active() -> bool:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	return player != null and bridge.current_mode == 1 and not get_tree().paused and player.controls_enabled


func _process(delta: float) -> void:
	var active := _active()
	if active != _was_active:
		_was_active = active
		_canvas.visible = active
		if not active:
			_release_all()
	if not active:
		return
	for index: int in _held:
		var b: Dictionary = _held[index]
		if b["repeat"]:
			b["timer"] -= delta
			if b["timer"] <= 0.0:
				b["timer"] = REPEAT_EVERY
				_fire(b)
	_canvas.queue_redraw()


func _release_all() -> void:
	for index: int in _held.keys():
		_release(index)
	_joy_id = -1
	_look_id = -1
	bridge.move_vector = Vector2.ZERO
	bridge.is_sprinting = false


# --- Input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if bridge == null:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		bridge.use_touch_input()
	elif bridge.current_mode == 1 and _is_hardware(event) and _active():
		bridge.use_hardware_input()
	if not _active():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _joy_id:
			_move_stick(event.position)
		elif event.index == _look_id:
			bridge.feed_look_delta(event.relative * LOOK_SCALE)


func _is_hardware(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	if event is InputEventKey:
		return event.pressed and not event.echo and HARDWARE_KEYS.has(event.keycode)
	return event is InputEventMouseMotion and event.relative != Vector2.ZERO


func _press(index: int, pos: Vector2) -> void:
	for b in _buttons:
		if _is_shown(b) and (b["rect"] as Rect2).grow(6.0).has_point(pos):
			_held[index] = b
			b["down"] = true
			b["timer"] = REPEAT_DELAY
			if b["hold"] != &"":
				bridge.hold_action(b["hold"], true)
			else:
				_fire(b)
			return
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if pos.x < half and _joy_id == -1:
		_joy_id = index
		_stick_center = pos
		_move_stick(pos)
	elif pos.x >= half and _look_id == -1:
		_look_id = index


func _release(index: int) -> void:
	if _held.has(index):
		var b: Dictionary = _held[index]
		b["down"] = false
		if b["hold"] != &"":
			bridge.hold_action(b["hold"], false)
		_held.erase(index)
	elif index == _joy_id:
		_joy_id = -1
		bridge.move_vector = Vector2.ZERO
		bridge.is_sprinting = false
	elif index == _look_id:
		_look_id = -1


func _fire(b: Dictionary) -> void:
	var tap: Callable = b["tap"]
	if tap.is_valid():
		tap.call()


func _move_stick(pos: Vector2) -> void:
	var offset := (pos - _stick_center).limit_length(STICK_RADIUS)
	_stick_pos = _stick_center + offset
	bridge.move_vector = offset / STICK_RADIUS
	bridge.is_sprinting = offset.length() > STICK_RADIUS * 0.85   # Push the stick to its edge to sprint.


# --- Drawing -------------------------------------------------------------------

func _paint() -> void:
	var font := ThemeDB.fallback_font
	var size := 17
	for b in _buttons:
		if not _is_shown(b):
			continue
		var rect: Rect2 = b["rect"]
		_canvas.draw_style_box(_face_down if b["down"] else _face, rect)
		var text: String = b["text"]
		var lines := text.count("\n") + 1
		var top := rect.position.y + (rect.size.y - lines * font.get_height(size)) * 0.5 + font.get_ascent(size)
		_canvas.draw_multiline_string(font, Vector2(rect.position.x, top), text, HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x, size, -1, Color(1.0, 1.0, 1.0, 0.9))
	if _joy_id != -1:
		_canvas.draw_circle(_stick_center, STICK_RADIUS, Color(1.0, 1.0, 1.0, 0.12))
		_canvas.draw_arc(_stick_center, STICK_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.4), 2.0)
		_canvas.draw_circle(_stick_pos, 26.0, Color(1.0, 1.0, 1.0, 0.45))
