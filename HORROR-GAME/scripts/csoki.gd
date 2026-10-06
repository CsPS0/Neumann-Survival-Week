extends "res://scripts/teacher_npc.gd"
## Csoki, the caretaker's dog. Wanders the ground-floor hall (the same agent as the teachers), barks when the entity is
## visible or the caretaker is close, and can be petted. A dog biscuit makes it follow the player for 3 game hours.
## It cannot be hurt and never blocks the player: collision layer 16 (interact-only, nothing collides with it).

signal barked

const WARN_RANGE := 20.0
const BARK_COOLDOWN := 6.0
const FOLLOW_MINUTES := 180.0
const FOLLOW_RANGE := 30.0   ## Entity bark range while following.
const FOLLOW_NEAR := 3.0     ## Stops walking this close to the player.
const FOLLOW_BEHIND := 2.0

var entity: Node3D
var campaign: Node
var daynight: Node
var player: Node3D
var is_following := false
var _follow_until := 0.0     ## Game minutes.
var _follow_start := 0.0
var _follow_day := 0
var _repath := 0.0
var _cooldown := 0.0
var _bark := AudioStreamPlayer3D.new()


func _ready() -> void:
	body_height = 0.6
	body_radius = 0.22
	_index = 1   # It spawns on route[0]; head for the next marker.
	super._ready()
	remove_from_group("teachers")
	add_to_group("csoki")
	collision_layer = 16
	npc_name = "Csoki"
	prompt = "Pet Csoki"
	_bark.stream = SoundBank.bark()
	_bark.max_distance = 45.0
	_bark.unit_size = 5.0
	add_child(_bark)


func _physics_process(delta: float) -> void:
	if is_following and not _follow_valid():
		is_following = false
		set_station(Vector3.INF)   # Back to the hall route.
	if is_following and _ready_to_walk:
		_follow_step(delta)
	else:
		super._physics_process(delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown == 0.0 and (campaign == null or campaign.ending_id == 0) and _danger_near():
		_cooldown = BARK_COOLDOWN
		_bark.play()
		barked.emit()


## Follows the player for `minutes` game minutes; a new day or (if started before it) the last bell ends it.
func follow(minutes: float) -> void:
	is_following = true
	_follow_start = daynight.minutes
	_follow_until = daynight.minutes + minutes
	_follow_day = campaign.day
	_repath = 0.0


func _follow_valid() -> bool:
	if player == null or daynight == null or campaign == null or campaign.day != _follow_day:
		return false
	if campaign.ending_id != 0:
		return false
	if daynight.minutes >= _follow_until:
		return false
	var bell: float = campaign.LAST_BELL
	return not (campaign.day <= campaign.LAST_SCHOOL_DAY and _follow_start < bell and daynight.minutes >= bell)


func _follow_step(delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.5
		_nav.target_position = player.global_position + player.global_transform.basis.z * FOLLOW_BEHIND
	var gap := global_position.distance_to(player.global_position)
	var direction := Vector3.ZERO
	if gap > FOLLOW_NEAR:
		direction = _nav.get_next_path_position() - global_position
		direction.y = 0.0
		direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.ZERO
		_open_nearby_doors()
	var speed := minf(1.5 + gap, 6.0)   # Catches up after a sprint.
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if direction.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 8.0 * delta)
	_animate(delta, direction.length() * speed)


func _danger_near() -> bool:
	if entity != null and is_instance_valid(entity) and entity.visible \
			and entity.global_position.distance_to(global_position) < (FOLLOW_RANGE if is_following else WARN_RANGE):
		return true
	for caretaker: Node3D in get_tree().get_nodes_in_group("caretaker"):
		if is_instance_valid(caretaker) and not caretaker.is_queued_for_deletion() \
				and caretaker.global_position.distance_to(global_position) < WARN_RANGE:
			return true
	return false


func interact(by: Node = null) -> void:
	if by == null:
		return
	if by.has_item("biscuit"):
		if is_following:
			by.inspected.emit("Csoki is already with you.")
			return
		by.remove_item("biscuit")
		follow(FOLLOW_MINUTES)
		by.inspected.emit("Csoki gobbles the biscuit and trots after you.")
		return
	by.inspected.emit("Csoki wags its tail.")
	if campaign:
		campaign.event.emit("good_boy", {})


func _build_body() -> void:
	var fur := _material(Color(0.55, 0.38, 0.22))
	var dark := _material(Color(0.2, 0.14, 0.1))
	var torso := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.2, 0.55)
	box.material = fur
	torso.mesh = box
	torso.position = Vector3(0.0, 0.36, 0.0)
	add_child(torso)
	_sphere(self, 0.11, Vector3(0.0, 0.46, -0.34), fur)
	_sphere(self, 0.045, Vector3(0.0, 0.43, -0.45), dark)   # snout
	for corner in [Vector2(-0.08, -0.2), Vector2(0.08, -0.2), Vector2(-0.08, 0.2), Vector2(0.08, 0.2)]:
		var leg := Node3D.new()
		leg.position = Vector3(corner.x, 0.28, corner.y)
		add_child(leg)
		_cylinder(leg, 0.03, 0.28, Vector3(0.0, -0.14, 0.0), dark)
		_legs.append(leg)
	var tail := Node3D.new()
	tail.position = Vector3(0.0, 0.42, 0.28)
	tail.rotation.x = 0.7
	add_child(tail)
	_cylinder(tail, 0.02, 0.22, Vector3(0.0, 0.11, 0.0), fur)
