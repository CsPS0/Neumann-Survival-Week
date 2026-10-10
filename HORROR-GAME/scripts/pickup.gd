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

static var _paper_cache := {}   ## seed -> ImageTexture, shared by every paper pickup.


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


func interact(by: Node = null) -> void:
	if by == null:
		return
	if kind == "biscuit" and by.has_item("biscuit"):
		by.inspected.emit("Your pocket already holds a biscuit.")
		return
	if kind not in ["battery", "mecha"] and by.has_method(&"can_carry") and not by.can_carry():
		by.inspected.emit("Your hand and pockets are full, and the bag is full or on the floor.")
		return
	if kind == "battery":
		by.add_battery(battery_amount)
		by.inspected.emit("Battery +%d%%" % int(battery_amount))
	elif kind != "mecha":   # The chameleon is no inventory item: mecha.gd shows the message and the reward.
		by.give_item(item_id, display_name, message)
	taken.emit(item_id)
	
	if NetSession.is_multiplayer_active():
		NetSession.rpc("sync_pickup_taken", item_id, kind)
		
	var sound := AudioStreamPlayer3D.new()
	sound.stream = SoundBank.chime()
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.finished.connect(sound.queue_free)
	sound.play()
	queue_free()


func _build_model() -> void:
	var brass := _material(Color(0.78, 0.6, 0.2), 0.6, 0.4)
	match kind:
		"mecha":
			_model.add_child(Mecha.build_model())
		"key":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.03
			ring.outer_radius = 0.07
			_add(ring, Vector3.ZERO, Vector3(90, 0, 0), brass)
			_cylinder(0.012, 0.22, Vector3(0, 0, 0.15), Vector3(90, 0, 0), brass)
			for z in [0.22, 0.18]:
				_box(Vector3(0.05, 0.02, 0.025), Vector3(0.03, 0, z), brass)
		"salt":
			_cylinder(0.07, 0.16, Vector3.ZERO, Vector3.ZERO, _material(Color(0.92, 0.92, 0.95), 0.0, 0.6))
			_cylinder(0.072, 0.05, Vector3(0, 0.02, 0), Vector3.ZERO, _material(Color(0.2, 0.3, 0.7), 0.0, 0.6))
			_cylinder(0.05, 0.03, Vector3(0, 0.1, 0), Vector3.ZERO, _material(Color(0.6, 0.6, 0.65), 0.5, 0.4))
		"vial":
			var glass := _material(Color(0.55, 0.7, 0.85, 0.75), 0.0, 0.1)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cylinder(0.045, 0.14, Vector3.ZERO, Vector3.ZERO, glass)
			_cylinder(0.02, 0.07, Vector3(0, 0.1, 0), Vector3.ZERO, glass)
			_cylinder(0.025, 0.03, Vector3(0, 0.15, 0), Vector3.ZERO, _material(Color(0.4, 0.25, 0.1), 0.0, 0.8))
		"bell":
			var bell := CylinderMesh.new()
			bell.top_radius = 0.025
			bell.bottom_radius = 0.1
			bell.height = 0.16
			_add(bell, Vector3.ZERO, Vector3.ZERO, brass)
			var clapper := SphereMesh.new()
			clapper.radius = 0.025
			clapper.height = 0.05
			_add(clapper, Vector3(0, -0.09, 0), Vector3.ZERO, brass)
		"note":
			_box(Vector3(0.18, 0.003, 0.24), Vector3.ZERO, _paper_material(Color(0.95, 0.92, 0.8), 1))
			_model.rotation.y = randf() * TAU
		"page":
			_box(Vector3(0.18, 0.003, 0.24), Vector3.ZERO, _paper_material(Color(0.97, 0.95, 0.88), 2))
			_box(Vector3(0.18, 0.001, 0.003), Vector3(0, 0.002, 0.118), _material(Color(0.55, 0.5, 0.42), 0.0, 0.9))
			_model.rotation.y = randf() * TAU
		"form":
			_box(Vector3(0.21, 0.003, 0.29), Vector3.ZERO, _paper_material(Color(0.97, 0.97, 0.95), 3))
			_box(Vector3(0.05, 0.004, 0.05), Vector3(0.06, 0, 0.1), _material(Color(0.7, 0.1, 0.1), 0.0, 0.7))
			_model.rotation.y = randf() * TAU
		"secret":
			_build_secret()
		"card":
			_box(Vector3(0.09, 0.003, 0.13), Vector3.ZERO, brass)
			_box(Vector3(0.078, 0.004, 0.118), Vector3.ZERO, _paper_material(Color(0.93, 0.91, 0.86), 4))
			_model.rotation.y = randf() * TAU
		"key_card":
			_box(Vector3(0.09, 0.003, 0.055), Vector3.ZERO, _material(Color(0.9, 0.9, 0.88), 0.0, 0.5))
			_box(Vector3(0.09, 0.004, 0.012), Vector3(0, 0, -0.015), _material(Color(0.12, 0.12, 0.14), 0.0, 0.6))
			_box(Vector3(0.016, 0.005, 0.014), Vector3(-0.025, 0, 0.01), brass)
			_model.rotation.y = randf() * TAU
		"biscuit":
			var brown := _material(Color(0.6, 0.38, 0.18), 0.0, 0.9)
			_cylinder(0.018, 0.1, Vector3.ZERO, Vector3(0, 0, 90), brown)
			for x in [-0.055, 0.055]:
				var knob := SphereMesh.new()
				knob.radius = 0.03
				knob.height = 0.06
				_add(knob, Vector3(x, 0, 0), Vector3.ZERO, brown)
			_model.rotation.y = randf() * TAU
		"fuse":
			var body := _material(Color(0.8, 0.8, 0.82), 0.4, 0.4)
			_cylinder(0.025, 0.1, Vector3.ZERO, Vector3(0, 0, 90), _material(Color(0.9, 0.9, 0.85), 0.0, 0.6))
			_cylinder(0.03, 0.02, Vector3(0.055, 0, 0), Vector3(0, 0, 90), body)
			_cylinder(0.03, 0.02, Vector3(-0.055, 0, 0), Vector3(0, 0, 90), body)
		"battery":
			_cylinder(0.04, 0.14, Vector3.ZERO, Vector3(90, 0, 0), _material(Color(0.12, 0.38, 0.17), 0.3, 0.5))
			_cylinder(0.041, 0.04, Vector3(0, 0, 0.03), Vector3(90, 0, 0), _material(Color(0.1, 0.1, 0.1), 0.2, 0.6))
			_cylinder(0.02, 0.03, Vector3(0, 0, -0.085), Vector3(90, 0, 0), _material(Color(0.7, 0.7, 0.72), 0.7, 0.35))
			_model.rotation.y = randf() * TAU


## The five secrets each get their own object (item_id from Finds.SECRETS), all plain and unlit.
func _build_secret() -> void:
	match item_id:
		"toy":
			var rubber := _material(Color(0.7, 0.12, 0.1), 0.0, 0.55)
			_cylinder(0.018, 0.14, Vector3.ZERO, Vector3(0, 0, 90), rubber)
			for x in [-0.07, 0.07]:
				for z in [-0.018, 0.018]:
					var knob := SphereMesh.new()
					knob.radius = 0.028
					knob.height = 0.056
					_add(knob, Vector3(x, 0, z), Vector3.ZERO, rubber)
		"tape":
			_box(Vector3(0.1, 0.014, 0.065), Vector3.ZERO, _material(Color(0.12, 0.12, 0.13), 0.1, 0.6))
			_box(Vector3(0.07, 0.002, 0.03), Vector3(0, 0.007, -0.005), _paper_material(Color(0.9, 0.88, 0.8), 5))
		"drawing":
			_box(Vector3(0.14, 0.002, 0.1), Vector3.ZERO, _paper_material(Color(0.95, 0.94, 0.9), 6))
		"mirror":
			_cylinder(0.055, 0.008, Vector3.ZERO, Vector3.ZERO, _material(Color(0.75, 0.78, 0.8), 0.5, 0.25))
			_cylinder(0.062, 0.006, Vector3(0, -0.002, 0), Vector3.ZERO, _material(Color(0.25, 0.22, 0.2), 0.2, 0.6))
		"photo":
			_box(Vector3(0.13, 0.002, 0.1), Vector3.ZERO, _material(Color(0.93, 0.91, 0.86), 0.0, 0.6))
			_box(Vector3(0.11, 0.003, 0.08), Vector3.ZERO, _material(Color(0.32, 0.3, 0.27), 0.0, 0.5))
		_:
			_box(Vector3(0.12, 0.04, 0.08), Vector3.ZERO, _material(Color(0.45, 0.4, 0.35), 0.1, 0.6))
	_model.rotation.y = randf() * TAU


## Cream paper with faint ruled lines and ink dashes standing in for writing. `seed_value` varies the lines per item.
static func _paper_texture(seed_value: int) -> ImageTexture:
	if not _paper_cache.has(seed_value):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		for y in size:
			var ruled := y % 8 == 7
			for x in size:
				var shade := 1.0 - 0.04 * rng.randf()
				if ruled:
					shade -= 0.1
				var edge := minf(minf(x, size - 1 - x), minf(y, size - 1 - y))
				shade -= 0.1 * clampf(1.0 - edge / 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(shade, shade, shade))
		for line in 7:
			var x := 6
			while x < size - 8:
				var length := rng.randi_range(3, 9)
				for dx in length:
					img.set_pixel(mini(x + dx, size - 4), line * 8 + 4, Color(0.35, 0.35, 0.4))
				x += length + 3
		img.generate_mipmaps()
		_paper_cache[seed_value] = ImageTexture.create_from_image(img)
	return _paper_cache[seed_value]


func _paper_material(tint: Color, seed_value: int) -> StandardMaterial3D:
	var mat := _material(tint, 0.0, 0.9)
	mat.albedo_texture = _paper_texture(seed_value)
	return mat


func _material(colour: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.metallic = metallic
	mat.roughness = roughness
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
