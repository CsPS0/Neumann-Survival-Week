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
	set_flashlight(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
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
	elif event is InputEventMouseButton and event.pressed and phone.raised and phone.page == 0 and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		phone.change_floor(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
	elif event.is_action_pressed(interact_action):
		_interact()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := (global_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var wants_sprint := controls_enabled and Input.is_action_pressed(&"sprint")
	var moving := direction.length() > 0.1
	var sprinting := wants_sprint and moving and not exhausted
	var speed := sprint_speed if sprinting else walk_speed
	_update_stamina(delta, sprinting, wants_sprint and moving)

	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()

	_update_head_bob(delta, sprinting)


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
	if _look_target:
		_look_at_target(delta)
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
