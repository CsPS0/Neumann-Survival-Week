class_name HidingSpot
extends StaticBody3D
## Interactive school locker / hiding spot.
## Press [E] to hide inside or exit. While hiding, player is hidden from entity/caretaker sight and hearing.
## While inside, holding [Space] holds breath to suppress tension.

const SoundBank := preload("res://scripts/sound_bank.gd")

@export var prompt: String = "Elbújás [E]"
@export var spot_name: String = "Szekrény"

var occupant: Node = null
var exit_transform: Transform3D
var peek_transform: Transform3D

var _audio: AudioStreamPlayer3D
var _door_mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("hiding_spots")
	collision_layer = 8
	collision_mask = 0

	_build_mesh()

	_audio = AudioStreamPlayer3D.new()
	_audio.position = Vector3(0.0, 1.2, 0.0)
	_audio.max_distance = 20.0
	_audio.unit_size = 2.0
	add_child(_audio)


func _build_mesh() -> void:
	var w := 0.75
	var h := 2.2
	var d := 0.7

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.2, 0.24, 0.22)
	mat_metal.metallic = 0.65
	mat_metal.roughness = 0.45

	var mat_accent := StandardMaterial3D.new()
	mat_accent.albedo_color = Color(0.12, 0.14, 0.13)
	mat_accent.metallic = 0.8
	mat_accent.roughness = 0.3

	# Locker frame & body
	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	box.material = mat_metal

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, h * 0.5, 0.0)
	add_child(mesh_inst)

	# Door handle & louver vents
	var handle := BoxMesh.new()
	handle.size = Vector3(0.04, 0.16, 0.03)
	handle.material = mat_accent
	var handle_inst := MeshInstance3D.new()
	handle_inst.mesh = handle
	handle_inst.position = Vector3(w * 0.35, 1.1, d * 0.5 + 0.02)
	add_child(handle_inst)

	# Ventilation slits
	for i in 4:
		var slit := BoxMesh.new()
		slit.size = Vector3(w * 0.45, 0.02, 0.01)
		slit.material = mat_accent
		var slit_inst := MeshInstance3D.new()
		slit_inst.mesh = slit
		slit_inst.position = Vector3(0.0, 1.6 + i * 0.05, d * 0.5 + 0.01)
		add_child(slit_inst)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(w, h, d)
	shape.shape = box_shape
	shape.position = Vector3(0.0, h * 0.5, 0.0)
	add_child(shape)


func get_peek_position() -> Vector3:
	return global_transform * Vector3(0.0, 1.45, 0.05)


func get_exit_position() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, 0.95)


func interact(by: Node = null) -> void:
	if by == null or not by.is_in_group("player"):
		return
	if occupant == by:
		exit(by)
	elif occupant == null:
		enter(by)


func enter(by: Node) -> void:
	occupant = by
	prompt = "Kilépés [E]"
	_audio.stream = SoundBank.locker_door()
	_audio.play()
	if by.has_method(&"enter_hiding"):
		by.enter_hiding(self)


func exit(by: Node) -> void:
	if occupant == by:
		occupant = null
		prompt = "Elbújás [E]"
		_audio.stream = SoundBank.locker_door()
		_audio.play()
		if by.has_method(&"exit_hiding") and by.get("is_hiding"):
			by.exit_hiding()

