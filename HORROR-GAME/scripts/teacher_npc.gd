extends CharacterBody3D
## Daytime teacher: walks a routine between waypoints, talks when you press E, and leaves the
## building at dusk. Navigates with the shared navmesh; passes through doors (layer 8) and opens them.

const SoundBank := preload("res://scripts/sound_bank.gd")
const Staff := preload("res://scripts/staff.gd")

var npc_name := "Teacher"
var shirt_colour := Color(0.3, 0.3, 0.5)
var route: Array[Vector3] = []          ## World-space waypoints.
var exit_point := Vector3.ZERO          ## Where to walk at dusk before disappearing.
var dialogue_provider: Callable         ## (npc_id: String) -> Array of lines
var npc_id := ""
var prompt := "Talk"
var path_offset := 0.3                  ## Set by the world builder (navmesh paths float above the floor).
var chase_target: Node3D                ## While set, ignore the routine and run at this node.
var chase_speed := 3.3
var ambient := false                    ## Background roster teacher: never talks, not a suspect (group "ambient_staff").
var role_label := "teacher"
var body_height := 1.75
var body_radius := 0.3
var gender := ""                        ## "f" / "m"; empty = Staff.gender_of(npc_name) when the body is built.

var _nav := NavigationAgent3D.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _index := 0
var _wait := 0.0
var _leaving := false
var _line := -1
var _swing := 0.0
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _step_accum := 0.0
var _footsteps := AudioStreamPlayer3D.new()
var _ready_to_walk := false
var _target_set := false
var _walk_time := 0.0
var _station := Vector3.INF


func _ready() -> void:
	add_to_group("ambient_staff" if ambient else "teachers")
	prompt = npc_name if ambient else "Talk to %s" % npc_name
	collision_layer = 32
	collision_mask = 1
	wall_min_slide_angle = 0.0   # Slide round a wall corner the path grazes instead of halting against it.
	if gender == "":
		gender = Staff.gender_of(npc_name)
	_build_body()

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = body_radius
	capsule.height = body_height
	shape.shape = capsule
	shape.position = Vector3(0.0, body_height * 0.5, 0.0)
	add_child(shape)

	_nav.path_height_offset = path_offset
	_nav.path_desired_distance = 0.25   # Wider skips wall-corner waypoints (door jambs) and the body jams on the corner.
	_nav.target_desired_distance = 0.8
	_nav.radius = 0.4
	add_child(_nav)

	_footsteps.max_distance = 18.0
	_footsteps.volume_db = -8.0
	add_child(_footsteps)

	await get_tree().physics_frame  # The navmesh syncs on the first physics frame.
	_ready_to_walk = true
	_wait = randf_range(0.5, 3.0)


func interact(by: Node = null) -> void:
	if ambient and by != null:
		by.inspected.emit("%s, %s" % [npc_name, role_label])
		return
	if by == null or not dialogue_provider.is_valid():
		return
	var lines: Array = dialogue_provider.call(npc_id)
	if lines.is_empty():
		return
	_line = (_line + 1) % lines.size()
	by.inspected.emit(lines[_line])


## Called at dusk: head for the exit and vanish.
func leave() -> void:
	_leaving = true
	_target_set = false
	_wait = 0.0


## Lessons: walk to `pos` and stay there. Vector3.INF returns to the normal routine.
func set_station(pos: Vector3) -> void:
	_station = pos
	_target_set = false
	_wait = 0.0


func _physics_process(delta: float) -> void:
	if not _ready_to_walk:
		return
	var direction := Vector3.ZERO
	if chase_target:
		_nav.target_position = chase_target.global_position
		var step := _nav.get_next_path_position() - global_position
		step.y = 0.0
		direction = step.normalized()
		_open_nearby_doors()
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		if direction.length_squared() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 8.0 * delta)
		_animate(delta, chase_speed)
		return
	if _wait > 0.0:
		_wait -= delta
	else:
		if not _target_set:
			_nav.target_position = exit_point if _leaving else (_station if _station.is_finite() else route[_index])
			_target_set = true
			_walk_time = 0.0
		_walk_time += delta
		# Grace period: the agent reports "finished" until its path has been computed.
		if _walk_time > 0.3 and _nav.is_navigation_finished():
			if _leaving:
				queue_free()
				return
			_target_set = false
			if _station.is_finite():
				_wait = 1.0   # Stay put in the classroom.
			else:
				_wait = randf_range(3.0, 8.0)
				_index = (_index + 1) % route.size()
		else:
			direction = _nav.get_next_path_position() - global_position
			direction.y = 0.0
			direction = direction.normalized()
			_open_nearby_doors()

	var speed := 2.2 if _leaving else 1.5
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

	if direction.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 6.0 * delta)
	_animate(delta, direction.length() * speed)

func _open_nearby_doors() -> void:
	for door: Node3D in get_tree().get_nodes_in_group(&"doors"):
		if door.global_position.distance_squared_to(global_position) < 4.0:
			door.set_open(true)


func _animate(delta: float, speed: float) -> void:
	_swing += delta * speed * 4.0
	var amount := minf(speed / 1.5, 1.5)
	for i in _arms.size():
		_arms[i].rotation.x = sin(_swing + i * PI) * 0.6 * amount
	for i in _legs.size():
		_legs[i].rotation.x = sin(_swing + i * PI + PI) * 0.6 * amount
	_step_accum += speed * delta
	if _step_accum > 1.2:
		_step_accum = 0.0
		_footsteps.stream = SoundBank.footstep(randi() % 3)
		_footsteps.pitch_scale = randf_range(0.95, 1.1)
		_footsteps.play()


## Male or female body and a procedural face, all seeded from the name (no photos, no textures).
func _build_body() -> void:
	var face := face_params(npc_name, gender)
	var female := gender == "f"
	var skin := _material(face["skin"])
	var shirt := _material(shirt_colour)
	var trousers := _material(face["trousers"])
	var hair := _material(face["hair"])
	var rig := Node3D.new()   # Women are drawn at 0.95x; the collision capsule stays the same.
	rig.name = "Rig"
	rig.scale = Vector3.ONE * (0.95 if female else 1.0)
	add_child(rig)

	var half := 0.18 if female else 0.21
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.09 * side, 0.85, 0.0)
		rig.add_child(leg)
		_cylinder(leg, 0.065, 0.85, Vector3(0, -0.425, 0), trousers)
		_legs.append(leg)

		var arm := Node3D.new()
		arm.position = Vector3((half + 0.02) * side, 1.5, 0.0)
		rig.add_child(arm)
		_cylinder(arm, 0.04, 0.6, Vector3(0, -0.3, 0), shirt)
		_sphere(arm, 0.05, Vector3(0, -0.62, 0), skin)
		_arms.append(arm)

	_box(rig, Vector3(half * 2.0, 0.62, 0.2 if female else 0.22), Vector3(0.0, 1.2, 0.0), shirt).name = "Torso"
	if face["skirt"]:
		_cylinder(rig, 0.17, 0.5, Vector3(0, 0.68, 0), _material(face["skirt_colour"]), 0.27).name = "Skirt"
	if face["tie"]:
		_box(rig, Vector3(0.05, 0.36, 0.012), Vector3(0, 1.3, -0.115), _material(face["tie_colour"]), false)
	_cylinder(rig, 0.05, 0.1, Vector3(0, 1.55, 0), skin)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.68, 0)
	head.scale = Vector3(face["width"], 1.0, 1.0)
	rig.add_child(head)
	_sphere(head, 0.12, Vector3.ZERO, skin)
	_build_face(head, face, hair)


## Eyes, brows, nose, mouth, hair and extras on the head (local origin = head centre, the face looks down -Z).
func _build_face(head: Node3D, face: Dictionary, hair: Material) -> void:
	var white := _material(Color(0.95, 0.95, 0.92))
	var pupil := _material(face["eyes"])
	var dark := _material(Color(0.08, 0.07, 0.07))
	for side in [-1.0, 1.0]:
		_sphere(head, 0.026, Vector3(0.042 * side, 0.02, -0.1), white, false)
		_sphere(head, 0.013, Vector3(0.042 * side, 0.02, -0.119), pupil, false)
		_box(head, Vector3(0.05, face["brow"], 0.014), Vector3(0.042 * side, 0.056, -0.108), hair, false)
		if face["glasses"]:
			var ring := _torus(head, 0.027, 0.033, Vector3(0.042 * side, 0.02, -0.13), dark)
			ring.rotation.x = PI * 0.5
	if face["glasses"]:
		_box(head, Vector3(0.024, 0.006, 0.006), Vector3(0, 0.024, -0.13), dark, false)
	var skin: Color = face["skin"]
	_box(head, Vector3(0.024, 0.045, 0.03), Vector3(0, -0.005, -0.125), _material(skin.darkened(0.08)), false)
	_box(head, Vector3(0.05, 0.012, 0.01), Vector3(0, -0.05, -0.112), _material(Color(0.5, 0.18, 0.17)), false)
	if face["moustache"]:
		_box(head, Vector3(0.06, 0.016, 0.02), Vector3(0, -0.032, -0.116), hair, false)
	if face["beard"]:
		_sphere(head, 0.09, Vector3(0, -0.095, -0.04), hair).scale = Vector3(1.0, 0.75, 0.9)
	_sphere(head, 0.125, Vector3(0, 0.055, 0.03), hair).scale = Vector3(1.04, 0.72, 1.0)
	match face["style"]:
		"long":
			_box(head, Vector3(0.24, 0.34, 0.08), Vector3(0, -0.1, 0.08), hair)
		"bun":
			_sphere(head, 0.06, Vector3(0, 0.07, 0.13), hair)
		"short_f":
			_sphere(head, 0.128, Vector3(0, 0.01, 0.04), hair).scale = Vector3(1.05, 0.8, 0.95)


const SKIN := [Color(0.96, 0.8, 0.69), Color(0.92, 0.74, 0.62), Color(0.86, 0.68, 0.56), Color(0.78, 0.6, 0.48),
		Color(0.66, 0.48, 0.36), Color(0.5, 0.35, 0.25)]
const HAIR := [Color(0.07, 0.06, 0.05), Color(0.2, 0.13, 0.08), Color(0.38, 0.25, 0.14), Color(0.75, 0.62, 0.38),
		Color(0.45, 0.18, 0.09), Color(0.6, 0.6, 0.58), Color(0.82, 0.82, 0.8)]
const EYES := [Color(0.2, 0.12, 0.06), Color(0.25, 0.4, 0.55), Color(0.3, 0.38, 0.22), Color(0.1, 0.08, 0.06)]
const TROUSERS := [Color(0.12, 0.12, 0.16), Color(0.2, 0.18, 0.15), Color(0.1, 0.13, 0.2)]


## Deterministic look for a person: same name, same face on every run (own RNG, never the global one).
static func face_params(person: String, sex: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(person)
	var female := sex == "f"
	var p := {
		"skin": SKIN[rng.randi_range(0, SKIN.size() - 1)],
		"hair": HAIR[rng.randi_range(0, HAIR.size() - 1)],
		"eyes": EYES[rng.randi_range(0, EYES.size() - 1)],
		"trousers": TROUSERS[rng.randi_range(0, TROUSERS.size() - 1)],
		"width": rng.randf_range(0.9, 1.1),
		"brow": rng.randf_range(0.009, 0.02),
		"glasses": rng.randf() < 0.35,
	}
	var roll := rng.randf()
	var hue := rng.randf()
	p["style"] = ["long", "bun", "short_f"][mini(int(roll * 3.0), 2)] if female else "short"
	p["skirt"] = female and rng.randf() < 0.5
	p["skirt_colour"] = Color.from_hsv(hue, 0.35, 0.3)
	p["tie"] = not female and rng.randf() < 0.5
	p["tie_colour"] = Color.from_hsv(hue, 0.6, 0.45)
	p["moustache"] = not female and rng.randf() < 0.3
	p["beard"] = not female and rng.randf() < 0.12
	return p


## Shared materials and meshes (one per colour / size for all NPCs).
static var _mats := {}
static var _meshes := {}


func _material(colour: Color) -> StandardMaterial3D:
	if not _mats.has(colour):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = 0.9
		_mats[colour] = mat
	return _mats[colour]


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, bottom := -1.0) -> MeshInstance3D:
	var key := "c%.3f/%.3f/%.3f" % [radius, height, bottom]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius if bottom < 0.0 else bottom
		mesh.height = height
		mesh.radial_segments = 10
		_meshes[key] = mesh
	return _add_mesh(parent, _meshes[key], pos, mat, true)


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var key := "s%.3f" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 14
		mesh.rings = 7
		_meshes[key] = mesh
	return _add_mesh(parent, _meshes[key], pos, mat, shadow)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var key := "b%s" % size
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _add_mesh(parent, _meshes[key], pos, mat, shadow)


func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var key := "t%.3f/%.3f" % [inner, outer]
	if not _meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 16
		mesh.ring_segments = 6
		_meshes[key] = mesh
	return _add_mesh(parent, _meshes[key], pos, mat, false)


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, shadow: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	if not shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
