class_name Player
extends CharacterBody3D
## First-person controller: WASD + sprint, mouse-look, head bob with footsteps, battery-limited
## flashlight (F), phone map (Q), RayCast interaction (E).

const SoundBank := preload("res://scripts/sound_bank.gd")

signal inspected(text: String)          ## Messages for the HUD (inspect text, "Locked", ...).
signal flashlight_toggled(is_on: bool)
signal battery_changed(percent: float)  ## 0.0 - 1.0
signal item_added(item_id: String)
signal prompt_changed(text: String)     ## What E would do on the object under the crosshair ("" = nothing).
signal stamina_changed(fraction: float)
signal exhausted_changed(is_exhausted: bool)
signal caught                           ## Fired by on_caught() (called by the entity).

@export_group("Movement")
@export var walk_speed := 3.0
@export var sprint_speed := 5.5
@export var acceleration := 12.0
@export var mouse_sensitivity := 0.0025

@export_group("Head Bob")
@export var bob_frequency := 2.2        ## Radians of bob phase per metre/sec travelled.
@export var bob_amplitude := 0.045
@export var bob_reset_speed := 8.0

@export_group("Flashlight")
@export var battery_max := 100.0
@export var battery_drain_per_sec := 0.3
@export var flicker_threshold := 0.2    ## Below this battery fraction the light flickers.

@export_group("Interaction")
@export var interact_action := &"interact"

const ACTION_KEYS := {
	&"move_forward": KEY_W,
	&"move_back": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"sprint": KEY_SHIFT,
	&"flashlight": KEY_F,
	&"interact": KEY_E,
	&"phone": KEY_Q,
	&"phone_page": KEY_TAB,
	&"phone_floor_prev": KEY_LEFT,
	&"phone_floor_next": KEY_RIGHT,
	&"hold_breath": KEY_SPACE,
}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var torch: Node3D = $Head/Camera3D/Torch
@onready var phone: Node3D = $Head/Camera3D/Phone

const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 20.0     ## About 5 s of sprint.
const STAMINA_REGEN := 12.5     ## About 8 s to refill.
const STAMINA_DELAY := 1.0
const STAMINA_RESUME := 30.0    ## Exhausted until it is back to this much.

var battery := battery_max
var stamina := STAMINA_MAX
var exhausted := false
var exhausted_count := 0
var _stamina_delay := 0.0
var _breath := AudioStreamPlayer.new()
var controls_enabled := true
var invert_y := false
var inventory := {}
var is_downed := false
var is_hiding := false
var is_holding_breath := false
var _current_hiding_spot: Node = null
var _pre_hide_pos := Vector3.ZERO
var _hide_yaw := 0.0
var _peek_yaw := 0.0
var _peek_pitch := 0.0
var _heartbeat_audio := AudioStreamPlayer.new()
var _heartbeat_timer := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0
var _step_index := 0
var _flashlight_base_energy: float
var _step_audio := AudioStreamPlayer.new()
var _look_target: Node3D
var _light_before_phone := true
var _last_prompt := ""
var _torch_tween: Tween



func _ready() -> void:
	add_to_group("player")  # The entity looks the player up by this group.
	_register_actions()
	_flashlight_base_energy = flashlight.light_energy
	_step_audio.volume_db = -9.0
	add_child(_step_audio)
	_breath.stream = SoundBank.breath()
	_breath.volume_db = -4.0
	add_child(_breath)
	_heartbeat_audio.volume_db = -10.0
	add_child(_heartbeat_audio)
	set_flashlight(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if is_hiding:
		if event.is_action_pressed(interact_action):
			exit_hiding()
			return
		elif event.is_action_pressed(&"hold_breath"):
			is_holding_breath = true
			return
		elif event.is_action_released(&"hold_breath"):
			is_holding_breath = false
			return
		elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_peek_yaw = clampf(_peek_yaw - event.relative.x * mouse_sensitivity, deg_to_rad(-45.0), deg_to_rad(45.0))
			_peek_pitch = clampf(_peek_pitch - event.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0), deg_to_rad(-25.0), deg_to_rad(25.0))
			rotation.y = _hide_yaw + _peek_yaw
			head.rotation.x = _peek_pitch
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0))
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event.is_action_pressed(&"flashlight"):
		if phone.raised:
			_lower_phone()  # One thing in hand at a time: grabbing the torch puts the phone away.
			set_flashlight(true)
		else:
			set_flashlight(not flashlight.visible)
	elif event.is_action_pressed(&"phone"):
		if phone.raised:
			_lower_phone()
			set_flashlight(_light_before_phone)
		else:
			_raise_phone()
	elif event.is_action_pressed(&"phone_page") and phone.raised:
		phone.toggle_page()
	elif event.is_action_pressed(&"phone_floor_prev") and phone.raised:
		phone.change_floor(-1)
	elif event.is_action_pressed(&"phone_floor_next") and phone.raised:
		phone.change_floor(1)
	elif event is InputEventMouseButton and event.pressed:
		if phone.raised and phone.page == 0:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				phone.change_floor(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				phone.change_floor(1)
	elif event.is_action_pressed(interact_action):
		_interact()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if is_hiding:
		velocity = Vector3.ZERO
		if is_holding_breath:
			_update_stamina(delta, true, true)
			if stamina <= 0.0 or exhausted:
				is_holding_breath = false
		else:
			_update_stamina(delta, false, false)
		return

	var input_dir := Vector2.ZERO
	var wants_sprint := false
	if controls_enabled:
		var bridge := get_tree().get_first_node_in_group("input_bridge")
		if bridge:
			input_dir = bridge.get_move_vector()
			wants_sprint = bridge.get_is_sprinting()
		else:
			input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
			wants_sprint = Input.is_action_pressed(&"sprint")
			
	var direction := (global_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var moving := direction.length() > 0.1
	var sprinting := wants_sprint and moving and not exhausted
	var speed := sprint_speed if sprinting else walk_speed
	_update_stamina(delta, sprinting, wants_sprint and moving)

	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()

	_update_head_bob(delta, sprinting)
	
	if NetSession.is_multiplayer_active():
		NetSession.rpc("update_player_transform", global_position, rotation.y, sprinting)


func _update_stamina(delta: float, sprinting: bool, straining: bool) -> void:
	var before := stamina
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		_stamina_delay = STAMINA_DELAY
		if stamina <= 0.0 and not exhausted:
			exhausted = true
			exhausted_count += 1
			_breath.play()
			exhausted_changed.emit(true)
	else:
		# Holding sprint while exhausted restarts the regen delay.
		_stamina_delay = STAMINA_DELAY if straining else maxf(_stamina_delay - delta, 0.0)
		if _stamina_delay <= 0.0:
			stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if exhausted and stamina >= STAMINA_RESUME:
			exhausted = false
			exhausted_changed.emit(false)
	if stamina != before:
		stamina_changed.emit(stamina / STAMINA_MAX)


func _process(delta: float) -> void:
	_update_prompt()
	_update_heartbeat(delta)
	if _look_target:
		_look_at_target(delta)
	
	if controls_enabled:
		var bridge := get_tree().get_first_node_in_group("input_bridge")
		if bridge and bridge.current_mode == 1:
			var look_delta = bridge.consume_look_delta()
			if look_delta != Vector2.ZERO:
				if is_hiding:
					_peek_yaw = clampf(_peek_yaw - look_delta.x * mouse_sensitivity, deg_to_rad(-45.0), deg_to_rad(45.0))
					_peek_pitch = clampf(_peek_pitch - look_delta.y * mouse_sensitivity * (-1.0 if invert_y else 1.0), deg_to_rad(-25.0), deg_to_rad(25.0))
					rotation.y = _hide_yaw + _peek_yaw
					head.rotation.x = _peek_pitch
				else:
					rotate_y(-look_delta.x * mouse_sensitivity)
					head.rotate_x(-look_delta.y * mouse_sensitivity * (-1.0 if invert_y else 1.0))
					head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
				
	if not flashlight.visible:
		return
	battery = maxf(battery - battery_drain_per_sec * delta, 0.0)
	battery_changed.emit(battery / battery_max)
	if battery <= 0.0:
		set_flashlight(false)
		return
	var fraction := battery / battery_max
	var energy := _flashlight_base_energy
	if fraction < flicker_threshold:
		# Random dropouts, more frequent as the battery approaches zero.
		if randf() < (1.0 - fraction / flicker_threshold) * 0.25 + 0.03:
			energy *= randf_range(0.0, 0.4)
	flashlight.light_energy = energy


## Turns the light on/off. Refuses to turn on with an empty battery.
func set_flashlight(on: bool) -> void:
	if on and battery <= 0.0:
		return
	flashlight.visible = on
	flashlight.light_energy = _flashlight_base_energy
	torch.set_lit(on)
	flashlight_toggled.emit(on)
	if NetSession.is_multiplayer_active():
		NetSession.rpc("update_player_flashlight", on)


func add_battery(amount: float) -> void:
	battery = minf(battery + amount, battery_max)
	battery_changed.emit(battery / battery_max)


func has_item(id: String) -> bool:
	return inventory.has(id)


func give_item(id: String, display_name: String, message := "") -> void:
	inventory[id] = display_name
	item_added.emit(id)
	inspected.emit(message if message != "" else "You took the %s." % display_name)


func remove_item(id: String) -> void:
	inventory.erase(id)


## Resets the player after being caught (inventory is kept).
func revive() -> void:
	controls_enabled = true
	_look_target = null
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	stamina = STAMINA_MAX
	_stamina_delay = 0.0
	if exhausted:
		exhausted = false
		exhausted_changed.emit(false)
	stamina_changed.emit(1.0)
	set_flashlight(true)


## Called by the horror entity on a successful attack: freeze and stare at it.
func on_caught(source: Node3D = null) -> void:
	if not controls_enabled:
		return
	controls_enabled = false
	_look_target = source
	_lower_phone()
	set_flashlight(false)
	caught.emit()


func _raise_phone() -> void:
	_light_before_phone = flashlight.visible
	set_flashlight(false)
	_move_torch(true)
	phone.set_raised(true)


func _lower_phone() -> void:
	if not phone.raised:
		return
	phone.set_raised(false)
	_move_torch(false)


func _move_torch(away: bool) -> void:
	if _torch_tween:
		_torch_tween.kill()
	_torch_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_torch_tween.tween_property(torch, "position:y", -0.75 if away else -0.28, 0.4)


func _update_prompt() -> void:
	if is_hiding:
		var text := "[E] Kilépés | [Space] Lélegzet-visszatartás"
		if text != _last_prompt:
			_last_prompt = text
			prompt_changed.emit(text)
		return
	var text := ""
	if controls_enabled and interact_ray.is_colliding():
		var target := interact_ray.get_collider() as Node
		if target and target.has_method(&"interact"):
			var prompt = target.get("prompt")
			text = "[E] " + str(prompt) if prompt != null else "[E] Use"
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text)


func _look_at_target(delta: float) -> void:
	var to_target := _look_target.global_position + Vector3.UP * 2.0 - head.global_position
	var yaw := atan2(-to_target.x, -to_target.z)
	var pitch := atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	rotation.y = lerp_angle(rotation.y, yaw, 10.0 * delta)
	head.rotation.x = lerpf(head.rotation.x, pitch, 10.0 * delta)
	camera.h_offset = randf_range(-0.04, 0.04)  # Shake.
	camera.v_offset = randf_range(-0.04, 0.04)


func _update_head_bob(delta: float, sprinting: bool) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.1:
		_bob_time += delta * horizontal_speed
		var phase := _bob_time * bob_frequency
		camera.position.y = sin(phase) * bob_amplitude
		camera.position.x = cos(phase * 0.5) * bob_amplitude * 0.5
		var step := int(floorf(phase / PI))  # One footfall per half bob cycle.
		if step != _step_index:
			_step_index = step
			_step_audio.stream = SoundBank.footstep(randi() % 3)
			_step_audio.volume_db = -3.0 if sprinting else -9.0
			_step_audio.pitch_scale = randf_range(0.92, 1.08)
			_step_audio.play()
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, bob_reset_speed * delta)


## Doors/props expose `interact(player)`. Anything else with "inspect_text" meta is just read.
func _interact() -> void:
	if not interact_ray.is_colliding():
		return
	var target := interact_ray.get_collider() as Node
	if target == null:
		return
	if target.has_method(&"interact"):
		target.interact(self)
	elif target.has_meta(&"inspect_text"):
		inspected.emit(str(target.get_meta(&"inspect_text")))


## Registers default key bindings so the scene works without InputMap setup.
func _register_actions() -> void:
	for action: StringName in ACTION_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = ACTION_KEYS[action]
		InputMap.action_add_event(action, key)


func enter_hiding(spot: Node) -> void:
	if is_hiding:
		return
	is_hiding = true
	_current_hiding_spot = spot
	_pre_hide_pos = global_position
	_hide_yaw = spot.global_rotation.y
	_peek_yaw = 0.0
	_peek_pitch = 0.0
	if spot.has_method(&"get_peek_position"):
		global_position = spot.get_peek_position() - Vector3(0.0, 1.4, 0.0)
	elif spot.has_node("PeekPos"):
		global_position = spot.get_node("PeekPos").global_position - Vector3(0.0, 1.4, 0.0)
	else:
		global_position = spot.global_position
	rotation.y = _hide_yaw
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	set_flashlight(false)
	prompt_changed.emit("[E] Kilépés | [Space] Lélegzet-visszatartás")


func exit_hiding() -> void:
	if not is_hiding:
		return
	is_hiding = false
	is_holding_breath = false
	var spot := _current_hiding_spot
	_current_hiding_spot = null
	if spot:
		if spot.has_method(&"get_exit_position"):
			global_position = spot.get_exit_position()
		else:
			global_position = _pre_hide_pos
		if spot.get("occupant") == self and spot.has_method(&"exit"):
			spot.exit(self)
	prompt_changed.emit("")


func _update_heartbeat(delta: float) -> void:
	var entity: Node3D = get_tree().get_first_node_in_group("entity") as Node3D
	if entity == null or not is_instance_valid(entity):
		return
	if entity.process_mode == Node.PROCESS_MODE_DISABLED or not entity.visible:
		return
	
	var dist := global_position.distance_to(entity.global_position)
	var state = entity.get("state")
	var is_hunting: bool = (state == 2 or state == 3 or entity.get("force_hunt") == true)
	
	if dist > 20.0 and not is_hunting:
		return
		
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		var factor := clampf((dist - 3.0) / 17.0, 0.0, 1.0)
		_heartbeat_timer = lerpf(0.45, 1.25, factor)
		
		_heartbeat_audio.stream = SoundBank.heartbeat()
		_heartbeat_audio.volume_db = lerpf(-4.0, -18.0, factor)
		_heartbeat_audio.pitch_scale = lerpf(1.15, 0.95, factor)
		_heartbeat_audio.play()
		
		var orig_fov := camera.fov
		var tween := create_tween()
		tween.tween_property(camera, "fov", orig_fov - 1.2, 0.08)
		tween.tween_property(camera, "fov", orig_fov, 0.22)

