class_name HorrorEntity
extends CharacterBody3D
## Roaming horror entity. States: IDLE -> PATROL (roam) -> CHASE -> ATTACK.
## Roams between random points on the navmesh (any floor, any room) and fixed waypoints, investigates
## loud noises (sprinting), hunts on sight. Requires a baked NavigationRegion3D and the player in group "player".

const SoundBank := preload("res://scripts/sound_bank.gd")

signal state_changed(new_state: State)
signal player_caught
signal appeared   ## A scripted encounter made it visible.
signal spotted    ## It started chasing (not counting attack to chase).

enum State { IDLE, PATROL, CHASE, ATTACK }

@export_group("Movement")
@export var patrol_speed := 1.9
@export var chase_speed := 4.2
@export var turn_speed := 6.0
@export var path_height_offset := 0.5   ## Baked navmesh paths float this far above the floor.

@export_group("Roaming")
@export var patrol_points: Array[NodePath]  ## Fixed waypoints (resolved relative to this node); optional.
@export var waypoint_bias := 0.35       ## Chance to pick a fixed waypoint instead of a random navmesh point.
@export var roam_min_distance := 10.0   ## New roam targets are at least this far away.
@export var idle_time := 3.0            ## Maximum pause between roam legs.

@export_group("Detection")
@export var sight_range := 15.0
@export_range(10.0, 360.0) var sight_fov_degrees := 90.0
@export var proximity_range := 2.5      ## Spotted inside this range regardless of facing (still needs line of sight).
@export var hearing_range := 12.0       ## Sprinting within this range (same floor) makes it investigate.
@export var lose_sight_time := 4.0      ## Seconds without sight before giving up the chase.
@export_flags_3d_physics var sight_mask := 11  ## Layers that block sight (world 1, doors 8) + the player's layer (2).

@export_group("Attack")
@export var attack_range := 1.4
@export var attack_duration := 1.5      ## Time spent in ATTACK before re-evaluating.

@export_group("Audio")
@export var footstep_sounds: Array[AudioStream]  ## Defaults to generated steps when empty.
@export var step_distance := 1.6        ## Metres travelled per footstep (faster movement = faster cadence).
@export var chase_step_boost_db := 6.0

const SIGHT_TARGET_HEIGHT := 1.4
const REPATH_INTERVAL := 0.15
const STUCK_CHECK_INTERVAL := 1.0

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: Node3D = $Eyes
@onready var footsteps: AudioStreamPlayer3D = $Footsteps
@onready var chase_sting: AudioStreamPlayer3D = $ChaseSting
@onready var model: Node3D = $Model

var state := State.IDLE
var player: Node3D
var force_hunt := false    ## True during the ritual: it always knows where the player is.

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _state_time := 0.0
var _idle_duration := 2.0
var _pending_target := Vector3.ZERO
var _has_pending_target := false
var _last_known_position := Vector3.ZERO
var _time_since_seen := 0.0
var _repath_timer := 0.0
var _step_accum := 0.0
var _sees_player := false
var _stuck_timer := 0.0
var _stuck_reference := Vector3.ZERO
var _jumpscare := AudioStreamPlayer.new()
var _encounter_id := 0


func _ready() -> void:
	add_to_group("entity")
	player = get_tree().get_first_node_in_group("player") as Node3D
	nav.path_height_offset = path_height_offset
	if footstep_sounds.is_empty():
		footstep_sounds.assign([SoundBank.footstep(0, true), SoundBank.footstep(1, true), SoundBank.footstep(2, true)])
	footsteps.max_distance = 32.0
	footsteps.unit_size = 4.0
	chase_sting.stream = SoundBank.sting()
	chase_sting.max_distance = 40.0
	_jumpscare.stream = SoundBank.jumpscare()
	_jumpscare.volume_db = 4.0
	add_child(_jumpscare)

	# The navigation map is empty until the first physics frame has synced.
	set_physics_process(false)
	await get_tree().physics_frame
	set_physics_process(true)
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_sees_player = _can_see_player()

	match state:
		State.IDLE: _tick_idle()
		State.PATROL: _tick_patrol(delta)
		State.CHASE: _tick_chase(delta)
		State.ATTACK: _tick_attack()

	if process_mode == Node.PROCESS_MODE_DISABLED:
		return   # A catch handler can put it to sleep mid-tick; its body is out of the physics space then.
	_move(delta)
	_tick_footsteps(delta)


# --- State logic -----------------------------------------------------------

func _tick_idle() -> void:
	if _sees_player or force_hunt:
		_set_state(State.CHASE)
	elif _hears_player():
		_investigate(player.global_position)
	elif _state_time >= _idle_duration:
		_set_state(State.PATROL)


func _tick_patrol(delta: float) -> void:
	if _sees_player or force_hunt:
		_set_state(State.CHASE)
		return
	if _hears_player() and _last_known_position.distance_to(player.global_position) > 4.0:
		_investigate(player.global_position)
		return
	# Grace period: the agent reports "finished" until its new path has been computed.
	if _state_time > 0.25 and nav.is_navigation_finished():
		_set_state(State.IDLE)
		return
	# Never stay wedged on geometry: if it hasn't made progress for a second, pick a new target.
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_INTERVAL:
		_stuck_timer = 0.0
		if global_position.distance_to(_stuck_reference) < 0.25:
			_set_state(State.PATROL)
		_stuck_reference = global_position


func _tick_chase(delta: float) -> void:
	if _sees_player or force_hunt:
		_last_known_position = player.global_position
		_time_since_seen = 0.0
		if global_position.distance_to(player.global_position) <= attack_range:
			_set_state(State.ATTACK)
			return
	else:
		_time_since_seen += delta
		if _time_since_seen >= lose_sight_time:
			_set_state(State.IDLE)
			return

	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		nav.target_position = _last_known_position


func _tick_attack() -> void:
	if _state_time >= attack_duration:
		_set_state(State.CHASE)


func _investigate(target: Vector3) -> void:
	_pending_target = target
	_has_pending_target = true
	_last_known_position = target
	_set_state(State.PATROL)


func _set_state(new_state: State) -> void:
	var previous := state
	state = new_state
	_state_time = 0.0

	match new_state:
		State.IDLE:
			_idle_duration = randf_range(1.0, idle_time)
		State.PATROL:
			nav.target_position = _pending_target if _has_pending_target else _pick_roam_target()
			_has_pending_target = false
			_stuck_timer = 0.0
			_stuck_reference = global_position
		State.CHASE:
			_time_since_seen = 0.0
			_repath_timer = 0.0
			if _sees_player:
				_last_known_position = player.global_position
			if previous != State.ATTACK:
				chase_sting.play()
			if previous != State.CHASE and previous != State.ATTACK:
				spotted.emit()
		State.ATTACK:
			_jumpscare.play()
			player_caught.emit()
			if player and player.has_method(&"on_caught"):
				player.on_caught(self)

	model.set_aggressive(new_state == State.CHASE or new_state == State.ATTACK)
	state_changed.emit(new_state)


## Daytime: invisible and inert. Night: wake() it somewhere far from the player.
func sleep() -> void:
	_encounter_id += 1   # Cancels the pending end of any scripted encounter.
	force_hunt = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func wake(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_set_state(State.IDLE)


## Scripted day encounter: a glimpse (stands still, visible, cannot attack) or a chase. Sleeps again after `seconds`.
func encounter(chase: bool, at: Vector3, seconds: float) -> void:
	_encounter_id += 1
	var id := _encounter_id
	wake(at)
	force_hunt = chase
	appeared.emit()
	if not chase:
		process_mode = Node.PROCESS_MODE_DISABLED
		var look := Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if look.distance_to(global_position) > 0.1:
			look_at(look, Vector3.UP)
	await get_tree().create_timer(seconds).timeout
	if id == _encounter_id:
		sleep()


## Mix of fixed waypoints and random navmesh points (so it also wanders into rooms and other floors).
func _pick_roam_target() -> Vector3:
	var map := nav.get_navigation_map()
	var candidate := global_position
	for attempt in 6:
		if not patrol_points.is_empty() and randf() < waypoint_bias:
			candidate = (get_node(patrol_points.pick_random()) as Node3D).global_position
		else:
			candidate = NavigationServer3D.map_get_random_point(map, nav.navigation_layers, true)
		if candidate.distance_to(global_position) >= roam_min_distance:
			break
	return candidate


# --- Perception ------------------------------------------------------------

func _hears_player() -> bool:
	if player == null:
		return false
	if player.get("is_hiding"):
		if not player.get("is_holding_breath"):
			var dist := global_position.distance_to(player.global_position)
			return dist < 2.5
		return false
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if horizontal_speed <= player.walk_speed + 0.5:
		return false
	var offset := player.global_position - global_position
	return absf(offset.y) < 3.0 and offset.length() < hearing_range


func _can_see_player() -> bool:
	if player == null:
		return false
	if player.get("is_hiding"):
		return false
	var target := player.global_position + Vector3.UP * SIGHT_TARGET_HEIGHT
	var to_target := target - eyes.global_position
	var distance := to_target.length()
	var effective_sight := sight_range
	var fl: Node = player.get_node_or_null("Head/Camera3D/Flashlight")
	if fl and fl.visible:
		effective_sight *= 1.35
	if distance > effective_sight:
		return false

	# Cone check only applies while not already hunting, so turning doesn't drop the chase.
	if state != State.CHASE and distance > proximity_range:
		var forward := -global_basis.z
		if forward.angle_to(to_target) > deg_to_rad(sight_fov_degrees * 0.5):
			return false

	var query := PhysicsRayQueryParameters3D.create(
		eyes.global_position, target, sight_mask, [get_rid()]
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


# --- Movement & audio ------------------------------------------------------

func _move(delta: float) -> void:
	var speed := 0.0
	match state:
		State.PATROL: speed = patrol_speed
		State.CHASE: speed = chase_speed

	if speed > 0.0:
		_open_nearby_doors()

	var direction := Vector3.ZERO
	if speed > 0.0 and not nav.is_navigation_finished():
		direction = nav.get_next_path_position() - global_position
		direction.y = 0.0
		direction = direction.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

	var facing := direction
	if state == State.ATTACK and player:
		facing = player.global_position - global_position
		facing.y = 0.0
	if facing.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), turn_speed * delta)


## Doors sit on a layer the entity doesn't collide with; it just swings them open as it passes.
func _open_nearby_doors() -> void:
	for door: Node3D in get_tree().get_nodes_in_group(&"doors"):
		if door.global_position.distance_squared_to(global_position) < 6.25:
			door.set_open(true)


func _tick_footsteps(delta: float) -> void:
	if footstep_sounds.is_empty() or not is_on_floor():
		return
	_step_accum += Vector2(velocity.x, velocity.z).length() * delta
	if _step_accum < step_distance:
		return
	_step_accum -= step_distance
	footsteps.stream = footstep_sounds.pick_random()
	footsteps.pitch_scale = randf_range(0.9, 1.1)
	footsteps.volume_db = chase_step_boost_db if state == State.CHASE else 0.0
	footsteps.play()
