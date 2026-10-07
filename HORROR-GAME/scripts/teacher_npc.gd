extends CharacterBody3D
## Daytime teacher: walks a routine between waypoints, talks when you press E, and leaves the
## building at dusk. Navigates with the shared navmesh; passes through doors (layer 8) and opens them.

const SoundBank := preload("res://scripts/sound_bank.gd")
static var Staff: GDScript = preload("res://scripts/staff_source.gd").roster()

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
var sick := false                       ## Ill from day 2: green skin, stooped, stands still and coughs.
var gender := ""                        ## "f" / "m"; empty = Staff.gender_of(npc_name) when the body is built.

var _nav := NavigationAgent3D.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _index := 0
var _wait := 0.0
var _leaving := false
var _line := -1
var _swing := 0.0
var _arms: Array[Node3D] = []   ## Shoulder pivots (the dog in csoki.gd reuses _legs for its four legs).
var _legs: Array[Node3D] = []   ## Hip pivots.
var _knees: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _hips: Node3D
var _upper: Node3D
var _head_node: Node3D
var _amp := 0.0                 ## Smoothed walk amount, 0 = standing, 1 = normal walk.
var _phase := 0.0               ## Walk cycle angle.
var _clock := 0.0
var _stoop := 0.0               ## Forward lean in radians (ill teachers).
var _blink := 3.0
var _look_seed := 0.0
var _step_accum := 0.0
var _footsteps := AudioStreamPlayer3D.new()
var _ready_to_walk := false
var _target_set := false
var _walk_time := 0.0
var _station := Vector3.INF
var _cough := 0.0


func _ready() -> void:
	add_to_group("ambient_staff" if ambient else "teachers")
	prompt = npc_name if ambient else "Talk to %s" % npc_name
	collision_layer = 32
	collision_mask = 1
	wall_min_slide_angle = 0.0   # Slide round a wall corner the path grazes instead of halting against it.
	if gender == "":
		gender = Staff.gender_of(npc_name)
	_build_body()
	if sick:
		_stoop = deg_to_rad(14.0)   # Stooped.
		_cough = randf_range(2.0, 8.0)
	_clock = randf() * 20.0
	_look_seed = randf() * TAU
	_blink = randf_range(1.5, 5.0)

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
	if sick and chase_target == null and not _leaving:
		_stand_ill(delta)
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

## An ill teacher stays where they are and coughs now and then.
func _stand_ill(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_animate(delta, 0.0)
	_cough -= delta
	if _cough <= 0.0:
		_cough = randf_range(8.0, 16.0)
		_footsteps.stream = SoundBank.cough()
		_footsteps.play()


func _open_nearby_doors() -> void:
	for door: Node3D in get_tree().get_nodes_in_group(&"doors"):
		if door.global_position.distance_squared_to(global_position) < 4.0:
			door.set_open(true)


## Walk cycle with smooth blending: the walk amount eases in and out, so starting, stopping and the speed change
## to a chase never snap. Standing has its own idle motion (breathing, weight shift, glances, blinking).
func _animate(delta: float, speed: float) -> void:
	if _hips == null:   # Not a person (the dog in csoki.gd): plain leg swing.
		_swing += delta * speed * 4.0
		var plain := minf(speed / 1.5, 1.5)
		for i in _arms.size():
			_arms[i].rotation.x = sin(_swing + i * PI) * 0.6 * plain
		for i in _legs.size():
			_legs[i].rotation.x = sin(_swing + i * PI + PI) * 0.6 * plain
		_step_sound(speed, delta)
		return
	_clock += delta
	var ease_rate := 1.0 - exp(-7.0 * delta)
	_amp = lerpf(_amp, minf(speed / 1.5, 1.8), ease_rate)
	_phase += delta * (0.5 + _amp) * 4.6 * (1.0 if speed > 0.05 else 0.0)
	var walk := clampf(_amp, 0.0, 1.0)
	var run := clampf(_amp - 1.0, 0.0, 0.8)
	var swing := (0.5 + 0.2 * run) * minf(_amp, 1.6)
	for i in 2:
		var side := PI * i
		_legs[i].rotation.x = sin(_phase + side) * swing
		_knees[i].rotation.x = -(maxf(cos(_phase + side), 0.0) * (0.55 + 0.5 * run) * walk + 0.04)
		_arms[i].rotation.x = -sin(_phase + side) * swing * 0.8 + sin(_clock * 1.3 + i) * 0.015 * (1.0 - walk)
		_arms[i].rotation.z = (0.05 + 0.03 * sin(_clock * 0.9 + i)) * (1.0 if i == 1 else -1.0)
		_elbows[i].rotation.x = 0.18 + walk * 0.25 + run * 0.7 + (0.2 if sick else 0.0)
	var idle := 1.0 - walk
	_hips.rotation.y = -sin(_phase) * 0.12 * walk
	_upper.rotation.y = sin(_phase) * 0.1 * walk
	_upper.rotation.x = -(_stoop + 0.22 * run + 0.02 * sin(_clock * 1.6) * idle)
	_upper.scale.y = 1.0 + sin(_clock * 1.7) * 0.006 * idle
	get_node("Rig").position.y = (cos(_phase * 2.0) * 0.016 * walk) - 0.004 * idle
	get_node("Rig").rotation.z = sin(_clock * 0.45 + _look_seed) * 0.018 * idle   # Weight shift.
	_head_node.rotation.y = sin(_clock * 0.35 + _look_seed) * 0.35 * idle + sin(_phase) * -0.05 * walk
	_head_node.rotation.x = sin(_clock * 0.5 + _look_seed * 2.0) * 0.06 + (0.18 if sick else 0.0)
	_blink -= delta
	for eye in _eyes:
		eye.scale.y = 0.12 if _blink < 0.1 else 1.0
	if _blink < 0.0:
		_blink = randf_range(2.0, 5.5)
	_step_sound(speed, delta)


func _step_sound(speed: float, delta: float) -> void:
	_step_accum += speed * delta
	if _step_accum > 1.2:
		_step_accum = 0.0
		_footsteps.stream = SoundBank.footstep(randi() % 3)
		_footsteps.pitch_scale = randf_range(0.95, 1.1)
		_footsteps.play()


## Body, clothes and a procedural face, all seeded from the name (no photos, no textures). Parts are layered:
## pelvis and legs (trousers or skirt), torso (shirt, optional jacket, collar, tie), arms with elbows, neck and head.
func _build_body() -> void:
	var face := face_params(npc_name, gender)
	if sick:
		face["skin"] = (face["skin"] as Color).lerp(Color(0.6, 0.75, 0.52), 0.45)
	var female := gender == "f"
	var skin := _material(face["skin"])
	var shirt := _material(shirt_colour)
	var top := _material(face["jacket_colour"]) if face["jacket"] else shirt
	var trousers := _material(face["trousers"])
	var shoes := _material(face["shoe"])
	var hair := _material(face["hair"])
	var rig := Node3D.new()   # The collision capsule stays the same whatever the height and build.
	rig.name = "Rig"
	var height: float = face["height"] * (0.95 if female else 1.0)
	rig.scale = Vector3(face["build"] * height, height, face["build"] * height)
	add_child(rig)

	var half := 0.17 if female else 0.2
	var depth := 0.2 if female else 0.22
	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0.0, 0.92, 0.0)
	rig.add_child(_hips)
	_box(_hips, Vector3(half * 1.7 if female else half * 1.55, 0.2, depth * 0.95), Vector3.ZERO, trousers)
	if face["skirt"]:
		_cylinder(_hips, 0.17, 0.5, Vector3(0, -0.22, 0), _material(face["skirt_colour"]), 0.27).name = "Skirt"
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.085 * side, -0.02, 0.0)
		_hips.add_child(leg)
		_cylinder(leg, 0.08, 0.46, Vector3(0, -0.23, 0), skin if face["skirt"] else trousers, 0.062)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.46, 0)
		leg.add_child(knee)
		_cylinder(knee, 0.058, 0.42, Vector3(0, -0.2, 0), skin if face["skirt"] else trousers, 0.044)
		_box(knee, Vector3(0.095, 0.07, 0.27), Vector3(0, -0.405, -0.05), shoes)
		_legs.append(leg)
		_knees.append(knee)

	_upper = Node3D.new()
	_upper.name = "Upper"
	_upper.position = Vector3(0.0, 0.92, 0.0)
	rig.add_child(_upper)
	_box(_upper, Vector3(half * 1.72, 0.22, depth * 0.95), Vector3(0, 0.11, 0.0), top)
	_box(_upper, Vector3(half * 2.0, 0.4, depth), Vector3(0, 0.37, 0.0), top).name = "Torso"
	var front := -(depth * 0.5)
	if face["jacket"]:
		_box(_upper, Vector3(0.11, 0.34, 0.012), Vector3(0, 0.34, front - 0.002), shirt, false)   # Shirt under the open jacket.
	_box(_upper, Vector3(0.13, 0.035, 0.1), Vector3(0, 0.575, front * 0.4), shirt, false)         # Collar.
	if face["tie"]:
		_box(_upper, Vector3(0.05, 0.3, 0.012), Vector3(0, 0.36, front - 0.012), _material(face["tie_colour"]), false)
	for side in [-1.0, 1.0]:
		_sphere(_upper, 0.058, Vector3((half + 0.012) * side, 0.54, 0.0), top)
		var arm := Node3D.new()
		arm.position = Vector3((half + 0.05) * side, 0.52, 0.0)
		_upper.add_child(arm)
		_cylinder(arm, 0.047, 0.3, Vector3(0, -0.15, 0), top, 0.038)
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.3, 0)
		arm.add_child(elbow)
		_cylinder(elbow, 0.037, 0.26, Vector3(0, -0.13, 0), top if face["jacket"] else shirt, 0.031)
		_sphere(elbow, 0.036, Vector3(0, -0.29, 0), skin).scale = Vector3(0.9, 1.15, 0.7)
		_arms.append(arm)
		_elbows.append(elbow)
	_cylinder(_upper, 0.05, 0.1, Vector3(0, 0.63, 0), skin)

	_head_node = Node3D.new()
	_head_node.name = "Head"
	_head_node.position = Vector3(0, 0.79, 0.0)
	_upper.add_child(_head_node)
	var head := Node3D.new()
	head.scale = Vector3(face["width"], 1.0, 1.0)
	_head_node.add_child(head)
	_sphere(head, 0.11, Vector3.ZERO, skin).scale = Vector3(1.0, 1.14, 1.02)
	_sphere(head, 0.082, Vector3(0, -0.07, -0.028), skin).scale = Vector3(1.0, 0.8, 1.0)   # Jaw and chin.
	for side in [-1.0, 1.0]:
		_sphere(head, 0.026, Vector3(0.108 * side, -0.005, 0.0), skin, false).scale = Vector3(0.45, 1.0, 0.8)   # Ears.
	_build_face(head, face, hair)


## Eyes, brows, nose, mouth, hair and extras on the head (local origin = head centre, the face looks down -Z).
func _build_face(head: Node3D, face: Dictionary, hair: Material) -> void:
	var white := _material(Color(0.95, 0.95, 0.92))
	var pupil := _material(face["eyes"])
	var dark := _material(Color(0.08, 0.07, 0.07))
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.04 * side, 0.02, -0.092)
		head.add_child(eye)
		_eyes.append(eye)
		_sphere(eye, 0.024, Vector3.ZERO, white, false)
		_sphere(eye, 0.012, Vector3(0, 0, -0.018), pupil, false)
		_box(head, Vector3(0.05, face["brow"], 0.014), Vector3(0.04 * side, 0.055, -0.099), hair, false)
		if face["glasses"]:
			var ring := _torus(head, 0.027, 0.033, Vector3(0.04 * side, 0.02, -0.12), dark)
			ring.rotation.x = PI * 0.5
	if face["glasses"]:
		_box(head, Vector3(0.024, 0.006, 0.006), Vector3(0, 0.024, -0.12), dark, false)
	var skin: Color = face["skin"]
	_box(head, Vector3(0.022, 0.045, 0.03), Vector3(0, -0.008, -0.113), _material(skin.darkened(0.08)), false)
	_box(head, Vector3(0.05, 0.011, 0.01), Vector3(0, -0.05, -0.1), _material(Color(0.5, 0.18, 0.17)), false)
	if face["moustache"]:
		_box(head, Vector3(0.06, 0.016, 0.02), Vector3(0, -0.032, -0.104), hair, false)
	if face["beard"]:
		_sphere(head, 0.085, Vector3(0, -0.09, -0.035), hair).scale = Vector3(1.0, 0.75, 0.9)
	if face["style"] == "bald":
		for side in [-1.0, 1.0]:
			_box(head, Vector3(0.02, 0.07, 0.11), Vector3(0.1 * side, 0.0, 0.03), hair, false)
		_box(head, Vector3(0.19, 0.06, 0.04), Vector3(0, 0.0, 0.092), hair, false)
		return
	_sphere(head, 0.118, Vector3(0, 0.05, 0.024), hair).scale = Vector3(1.04, 0.74, 1.0)
	match face["style"]:
		"long":
			_box(head, Vector3(0.22, 0.34, 0.08), Vector3(0, -0.1, 0.08), hair)
		"bun":
			_sphere(head, 0.06, Vector3(0, 0.07, 0.12), hair)
		"short_f":
			_sphere(head, 0.12, Vector3(0, 0.01, 0.04), hair).scale = Vector3(1.05, 0.8, 0.95)


const SKIN := [Color(0.96, 0.8, 0.69), Color(0.92, 0.74, 0.62), Color(0.86, 0.68, 0.56), Color(0.78, 0.6, 0.48),
		Color(0.66, 0.48, 0.36), Color(0.5, 0.35, 0.25)]
const HAIR := [Color(0.07, 0.06, 0.05), Color(0.2, 0.13, 0.08), Color(0.38, 0.25, 0.14), Color(0.75, 0.62, 0.38),
		Color(0.45, 0.18, 0.09), Color(0.6, 0.6, 0.58), Color(0.82, 0.82, 0.8)]
const EYES := [Color(0.2, 0.12, 0.06), Color(0.25, 0.4, 0.55), Color(0.3, 0.38, 0.22), Color(0.1, 0.08, 0.06)]
const SHOES := [Color(0.06, 0.05, 0.05), Color(0.2, 0.12, 0.07), Color(0.12, 0.12, 0.14)]
const JACKETS := [Color(0.13, 0.14, 0.2), Color(0.25, 0.22, 0.18), Color(0.3, 0.3, 0.32), Color(0.2, 0.12, 0.14)]
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
		"height": rng.randf_range(0.95, 1.06),
		"build": rng.randf_range(0.93, 1.1),
		"shoe": SHOES[rng.randi_range(0, SHOES.size() - 1)],
		"jacket": rng.randf() < 0.45,
		"jacket_colour": JACKETS[rng.randi_range(0, JACKETS.size() - 1)],
	}
	var roll := rng.randf()
	var hue := rng.randf()
	p["style"] = ["long", "bun", "short_f"][mini(int(roll * 3.0), 2)] if female else ("bald" if roll < 0.12 else "short")
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
