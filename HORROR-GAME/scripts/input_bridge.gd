class_name InputBridge
extends Node

enum Mode { DESKTOP, TOUCH, XR }
var current_mode: Mode = Mode.DESKTOP

var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var is_sprinting := false

## True on phones and tablets, or with `-- --touch` on the command line (to try the overlay on a desktop).
var touch_capable := false
## With `-- --touch` the overlay stays on, whatever mouse or keyboard is used.
var touch_forced := false

func _ready() -> void:
	add_to_group("input_bridge")
	touch_forced = OS.get_cmdline_user_args().has("--touch")
	touch_capable = touch_forced or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if touch_capable:
		current_mode = Mode.TOUCH

## A real keyboard or mouse showed up on a touch device: hide the overlay and read the input map again.
func use_hardware_input() -> void:
	if current_mode == Mode.TOUCH and not touch_forced:
		current_mode = Mode.DESKTOP
		move_vector = Vector2.ZERO
		is_sprinting = false

## A finger touched the screen again: bring the overlay back.
func use_touch_input() -> void:
	if current_mode == Mode.DESKTOP and touch_capable:
		current_mode = Mode.TOUCH

func is_touch() -> bool:
	return current_mode == Mode.TOUCH

func feed_move_vector(v: Vector2) -> void:
	move_vector = v

func feed_look_delta(v: Vector2) -> void:
	look_delta += v

func get_move_vector() -> Vector2:
	if current_mode == Mode.TOUCH or current_mode == Mode.XR:
		return move_vector
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")

func get_is_sprinting() -> bool:
	if current_mode == Mode.TOUCH or current_mode == Mode.XR:
		return is_sprinting
	return Input.is_action_pressed(&"sprint")

func consume_look_delta() -> Vector2:
	var delta := look_delta
	look_delta = Vector2.ZERO
	return delta

func trigger_interact() -> void:
	_trigger_action(&"interact")

func trigger_flashlight() -> void:
	_trigger_action(&"flashlight")

func trigger_flash() -> void:
	_trigger_action(&"flash")

func trigger_phone() -> void:
	_trigger_action(&"phone")

func trigger_phone_tab() -> void:
	_trigger_action(&"phone_page")

func trigger_phone_hands() -> void:
	_trigger_action(&"phone_hands")

func trigger_bag() -> void:
	_trigger_action(&"bag")

func trigger_swap_hand() -> void:
	_trigger_action(&"swap_hand")

func trigger_stow() -> void:
	_trigger_action(&"stow")

func trigger_pause() -> void:
	_trigger_action(&"ui_cancel")

## Presses or releases an action that is held, such as holding the breath while hiding.
func hold_action(action_name: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	Input.parse_input_event(ev)

func trigger_phone_floor(step: int) -> void:
	_trigger_action(&"phone_floor_next" if step > 0 else &"phone_floor_prev")

func trigger_phone_zoom(zoom_in: bool) -> void:
	_trigger_action(&"phone_zoom_in" if zoom_in else &"phone_zoom_out")

func trigger_phone_view(direction: Vector2i) -> void:
	if direction == Vector2i.UP:
		_trigger_action(&"phone_view_up")
	elif direction == Vector2i.DOWN:
		_trigger_action(&"phone_view_down")
	elif direction == Vector2i.LEFT:
		_trigger_action(&"phone_view_left")
	else:
		_trigger_action(&"phone_view_right")

func _trigger_action(action_name: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	Input.parse_input_event(ev)
	
	var ev_rel := InputEventAction.new()
	ev_rel.action = action_name
	ev_rel.pressed = false
	Input.parse_input_event(ev_rel)
