class_name Door
extends StaticBody3D
## Hinged door. The node origin is the hinge; the panel extends along local +X.
## Opened by the player (interact) or by the entity (set_open). Layer 8, so the entity walks through it.
## A locked door needs the player's key.

const SoundBank := preload("res://scripts/sound_bank.gd")

signal unlocked

@export var width := 1.25
@export var height := 2.2
@export var open_angle := 100.0
@export var open_sign := 1.0        ## +1/-1: swing direction.
@export var panel_material: Material
@export var locked := false
@export var key_id := "storage_key"                  ## Inventory item that unlocks it.
@export var locked_message := "Locked. You need a key."  ## Shown when the player has no matching key.
@export var master_key_ok := false                   ## Only today's locked after-hours door: the master key card opens it.

var is_open := false
var prompt: String:
	get:
		if locked:
			return "Locked"
		return "Close door" if is_open else "Open door"

var _closed_yaw := 0.0
var _tween: Tween
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("doors")
	collision_layer = 8
	collision_mask = 0
	_closed_yaw = rotation.y

	var size := Vector3(width, height, 0.06)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = panel_material
	mesh.mesh = box
	mesh.position = Vector3(width * 0.5, height * 0.5, 0.0)
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = mesh.position
	add_child(shape)

	_audio = AudioStreamPlayer3D.new()
	_audio.position = mesh.position
	_audio.max_distance = 25.0
	add_child(_audio)


func interact(by: Node = null) -> void:
	if locked and master_key_ok and by and by.has_item("master_key"):
		by.remove_item("master_key")
		locked = false
		master_key_ok = false
		unlocked.emit()
		by.inspected.emit("The card beeps. The door clicks open.")
		set_open(true)
		return
	if locked:
		if by and by.has_item(key_id):
			locked = false
			unlocked.emit()
			by.inspected.emit("You unlocked the door.")
		else:
			_play(SoundBank.knock())
			if by:
				by.inspected.emit(locked_message)
			return
	set_open(not is_open)


func set_open(open: bool) -> void:
	if open == is_open or (locked and open):
		return
	is_open = open
	_play(SoundBank.door_creak())
	if _tween:
		_tween.kill()
	var target := _closed_yaw + (deg_to_rad(open_angle) * open_sign if open else 0.0)
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "rotation:y", target, 0.45)


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()
