extends CanvasLayer

var bridge: Node

@onready var joy_area: Control = $JoyArea
@onready var look_area: Control = $LookArea
@onready var stick: Control = $Stick
@onready var stick_knob: ColorRect = $Stick/Knob

var joy_touch_id := -1
var look_touch_id := -1
var stick_center := Vector2.ZERO
var max_stick_radius := 50.0

func _ready() -> void:
	bridge = get_tree().get_first_node_in_group("input_bridge")
	if bridge == null:
		push_error("TouchControls requires InputBridge")
		return
	
	if bridge.current_mode != 1:
		hide()
		return
		
	show()
	$Buttons/BtnF.pressed.connect(func(): bridge.trigger_flashlight())
	$Buttons/BtnQ.pressed.connect(func(): bridge.trigger_phone())
	$Buttons/BtnE.pressed.connect(func(): bridge.trigger_interact())
	$Buttons/BtnTab.pressed.connect(func(): bridge.trigger_phone_tab())
	$Buttons/BtnEsc.pressed.connect(func(): bridge.trigger_pause())

func _input(event: InputEvent) -> void:
	if bridge == null or bridge.current_mode != 1:
		return
		
	if event is InputEventScreenTouch:
		if event.pressed:
			if joy_touch_id == -1 and event.position.x < get_viewport().get_visible_rect().size.x * 0.5:
				joy_touch_id = event.index
				stick_center = event.position
				stick.position = stick_center
				stick.show()
				_update_joystick(event.position)
			elif look_touch_id == -1 and event.position.x >= get_viewport().get_visible_rect().size.x * 0.5:
				look_touch_id = event.index
		else:
			if event.index == joy_touch_id:
				joy_touch_id = -1
				stick.hide()
				bridge.move_vector = Vector2.ZERO
				bridge.is_sprinting = false
				stick_knob.position = Vector2(-20, -20)
			elif event.index == look_touch_id:
				look_touch_id = -1
				
	elif event is InputEventScreenDrag:
		if event.index == joy_touch_id:
			_update_joystick(event.position)
		elif event.index == look_touch_id:
			bridge.look_delta += event.relative

func _update_joystick(pos: Vector2) -> void:
	var offset := pos - stick_center
	var dist := offset.length()
	var dir := offset.normalized() if dist > 0 else Vector2.ZERO
	
	if dist > max_stick_radius:
		offset = dir * max_stick_radius
		dist = max_stick_radius
		
	stick_knob.position = Vector2(-20, -20) + offset
	
	bridge.move_vector = dir * (dist / max_stick_radius)
	bridge.is_sprinting = dist > (max_stick_radius * 0.8)
