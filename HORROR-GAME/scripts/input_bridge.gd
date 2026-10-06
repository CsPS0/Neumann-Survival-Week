class_name InputBridge
extends Node

enum Mode { DESKTOP, TOUCH, XR }
var current_mode: Mode = Mode.DESKTOP

var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var is_sprinting := false

func _ready() -> void:
	add_to_group("input_bridge")
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		current_mode = Mode.TOUCH

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

func trigger_phone() -> void:
	_trigger_action(&"phone")

func trigger_phone_tab() -> void:
	_trigger_action(&"phone_page")

func trigger_pause() -> void:
	_trigger_action(&"ui_cancel")

func _trigger_action(action_name: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	Input.parse_input_event(ev)
	
	var ev_rel := InputEventAction.new()
	ev_rel.action = action_name
	ev_rel.pressed = false
	Input.parse_input_event(ev_rel)
