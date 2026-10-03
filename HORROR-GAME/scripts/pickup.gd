extends StaticBody3D
## A collectable item with a small procedural model. Layer 16: the interact ray sees it, nothing collides with it.
## kind: key, salt, vial, bell, note, fuse, battery, page, secret, card, form, key_card, biscuit, mecha

const SoundBank := preload("res://scripts/sound_bank.gd")
const Mecha := preload("res://scripts/mecha.gd")

signal taken(item_id: String)

var item_id := ""
var display_name := ""
var kind := "key"
var message := ""            ## Shown on pickup instead of "You took X" (used by notes).
var battery_amount := 35.0
var prompt := "Take"

var _model := Node3D.new()


func _ready() -> void:
	add_to_group("pickup")
	prompt = "Take %s" % display_name
	collision_layer = 16
	collision_mask = 0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	shape.shape = box
	add_child(shape)

	add_child(_model)
	_build_model()

	var glow := OmniLight3D.new()
	glow.light_color = _glow_colour()
	glow.light_energy = 0.7
	glow.omni_range = 3.0
	add_child(glow)


func _process(delta: float) -> void:
	if kind not in ["note", "page", "card", "form", "key_card"]:
		_model.rotation.y += delta * (0.5 if kind == "mecha" else 1.4)
	_model.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.03


func interact(by: Node = null) -> void:
	if by == null:
		return
	if kind == "biscuit" and by.has_item("biscuit"):
		by.inspected.emit("Your pocket already holds a biscuit.")
		return
	if kind == "battery":
		by.add_battery(battery_amount)
		by.inspected.emit("Battery +%d%%" % int(battery_amount))
	elif kind != "mecha":   # The chameleon is no inventory item: mecha.gd shows the message and the reward.
		by.give_item(item_id, display_name, message)
	taken.emit(item_id)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = SoundBank.chime()
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.finished.connect(sound.queue_free)
	sound.play()
	queue_free()


func _glow_colour() -> Color:
	match kind:
		"vial": return Color(0.3, 0.6, 1.0)
		"salt": return Color(0.9, 0.9, 1.0)
		"battery": return Color(0.4, 1.0, 0.4)
		"fuse": return Color(1.0, 0.4, 0.2)
		"note": return Color(1.0, 1.0, 0.8)
		"page": return Color(1.0, 0.95, 0.75)
		"secret": return Color(0.2, 0.9, 0.8)
		"card": return Color(1.0, 0.8, 0.3)
		"form": return Color(1.0, 0.9, 0.85)
		"key_card": return Color(0.2, 0.9, 0.85)
		"biscuit": return Color(0.85, 0.55, 0.25)
		"mecha": return Color(0.3, 1.0, 0.45)
		_: return Color(1.0, 0.8, 0.3)


func _build_model() -> void:
	var gold := _material(Color(1.0, 0.8, 0.25), 0.9, 0.3, Color(1.0, 0.7, 0.1), 0.6)
	match kind:
		"mecha":
			_model.add_child(Mecha.build_model())
		"key":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.03
			ring.outer_radius = 0.07
			_add(ring, Vector3.ZERO, Vector3(90, 0, 0), gold)
			_cylinder(0.012, 0.22, Vector3(0, 0, 0.15), Vector3(90, 0, 0), gold)
			for z in [0.22, 0.18]:
				_box(Vector3(0.05, 0.02, 0.025), Vector3(0.03, 0, z), gold)
		"salt":
			_cylinder(0.07, 0.16, Vector3.ZERO, Vector3.ZERO, _material(Color(0.92, 0.92, 0.95), 0.0, 0.6))
			_cylinder(0.072, 0.05, Vector3(0, 0.02, 0), Vector3.ZERO, _material(Color(0.2, 0.3, 0.7), 0.0, 0.6))
			_cylinder(0.05, 0.03, Vector3(0, 0.1, 0), Vector3.ZERO, _material(Color(0.6, 0.6, 0.65), 0.8, 0.3))
		"vial":
			var glass := _material(Color(0.3, 0.6, 1.0), 0.0, 0.1, Color(0.2, 0.5, 1.0), 2.0)
			_cylinder(0.045, 0.14, Vector3.ZERO, Vector3.ZERO, glass)
			_cylinder(0.02, 0.07, Vector3(0, 0.1, 0), Vector3.ZERO, glass)
			_cylinder(0.025, 0.03, Vector3(0, 0.15, 0), Vector3.ZERO, _material(Color(0.4, 0.25, 0.1), 0.0, 0.8))
		"bell":
			var bell := CylinderMesh.new()
			bell.top_radius = 0.025
			bell.bottom_radius = 0.1
			bell.height = 0.16
			_add(bell, Vector3.ZERO, Vector3.ZERO, gold)
			var clapper := SphereMesh.new()
			clapper.radius = 0.025
			clapper.height = 0.05
			_add(clapper, Vector3(0, -0.09, 0), Vector3.ZERO, gold)
		"note":
			_box(Vector3(0.18, 0.003, 0.24), Vector3.ZERO, _material(Color(0.95, 0.92, 0.8), 0.0, 0.9, Color(0.4, 0.4, 0.3), 0.3))
			_model.rotation.y = randf() * TAU
		"page":
			_box(Vector3(0.18, 0.003, 0.24), Vector3.ZERO, _material(Color(0.98, 0.93, 0.7), 0.0, 0.9, Color(0.45, 0.42, 0.25), 0.3))
			_box(Vector3(0.14, 0.004, 0.012), Vector3(0, 0, -0.1), _material(Color(0.1, 0.1, 0.12), 0.0, 0.9))
			_model.rotation.y = randf() * TAU
		"form":
			_box(Vector3(0.21, 0.003, 0.29), Vector3.ZERO, _material(Color(0.97, 0.97, 0.95), 0.0, 0.9, Color(0.4, 0.4, 0.4), 0.3))
			_box(Vector3(0.05, 0.004, 0.05), Vector3(0.06, 0, 0.1), _material(Color(0.8, 0.08, 0.08), 0.0, 0.7))
			_model.rotation.y = randf() * TAU
		"secret":
			_box(Vector3(0.12, 0.04, 0.08), Vector3.ZERO, _material(Color(0.1, 0.6, 0.55), 0.2, 0.4, Color(0.1, 0.9, 0.8), 1.2))
		"card":
			_box(Vector3(0.09, 0.003, 0.13), Vector3.ZERO, gold)
			_box(Vector3(0.078, 0.004, 0.118), Vector3.ZERO, _material(Color(0.92, 0.9, 0.85), 0.0, 0.8))
			_model.rotation.y = randf() * TAU
		"key_card":
			_box(Vector3(0.09, 0.003, 0.055), Vector3.ZERO, _material(Color(0.95, 0.95, 0.95), 0.0, 0.5, Color(0.2, 0.9, 0.85), 0.4))
			_box(Vector3(0.09, 0.004, 0.012), Vector3(0, 0, -0.015), _material(Color(0.8, 0.08, 0.08), 0.0, 0.6))
			_box(Vector3(0.016, 0.005, 0.014), Vector3(-0.025, 0, 0.01), gold)
		"biscuit":
			var brown := _material(Color(0.6, 0.38, 0.18), 0.0, 0.9)
			_cylinder(0.018, 0.1, Vector3.ZERO, Vector3(0, 0, 90), brown)
			for x in [-0.055, 0.055]:
				var knob := SphereMesh.new()
				knob.radius = 0.03
				knob.height = 0.06
				_add(knob, Vector3(x, 0, 0), Vector3.ZERO, brown)
		"fuse":
			var body := _material(Color(0.8, 0.8, 0.82), 0.5, 0.4)
			_cylinder(0.025, 0.1, Vector3.ZERO, Vector3(0, 0, 90), _material(Color(0.9, 0.9, 0.85), 0.0, 0.6))
			_cylinder(0.03, 0.02, Vector3(0.055, 0, 0), Vector3(0, 0, 90), body)
			_cylinder(0.03, 0.02, Vector3(-0.055, 0, 0), Vector3(0, 0, 90), body)
		"battery":
			_cylinder(0.04, 0.14, Vector3.ZERO, Vector3(90, 0, 0), _material(Color(0.1, 0.5, 0.15), 0.3, 0.5, Color(0.1, 0.6, 0.1), 0.4))
			_cylinder(0.02, 0.03, Vector3(0, 0, -0.085), Vector3(90, 0, 0), gold)


func _material(colour: Color, metallic: float, roughness: float, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.metallic = metallic
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


func _add(mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation_degrees = rot_deg
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(instance)


func _cylinder(radius: float, height: float, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	_add(mesh, pos, rot_deg, mat)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(mesh, pos, Vector3.ZERO, mat)
