class_name EntityModel
extends Node3D
## Procedural tall, pale, long-armed figure with glowing eyes. Forward is -Z.
## set_aggressive(true) leans it forward and raises the arms.

const SKIN := Color(0.78, 0.74, 0.68)
const CLOTH := Color(0.03, 0.03, 0.035)
const UPPER_ARM := 0.7
const FOREARM := 0.7

var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _head: Node3D
var _aggressive := false
var _t := randf() * 10.0


func _ready() -> void:
	var cloth := _material(CLOTH)
	var skin := _material(SKIN)
	var eye := _material(Color.BLACK)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.05, 0.02)
	eye.emission_energy_multiplier = 5.0

	for side in [-1.0, 1.0]:
		_cylinder(self, 0.05, 0.95, Vector3(0.1 * side, 0.475, 0.0), cloth)
		_build_arm(side, skin)
	var torso := _capsule(self, 0.17, 1.0, Vector3(0.0, 1.4, 0.0), cloth)
	torso.scale = Vector3(1.0, 1.0, 0.7)
	_cylinder(self, 0.04, 0.3, Vector3(0.0, 1.95, 0.0), skin)

	_head = Node3D.new()
	_head.position = Vector3(0.0, 2.1, 0.0)
	add_child(_head)
	var skull := _sphere(_head, 0.14, Vector3.ZERO, skin)
	skull.scale = Vector3(0.85, 1.35, 1.0)
	for side in [-1.0, 1.0]:
		_sphere(_head, 0.022, Vector3(0.05 * side, 0.04, -0.125), eye)
	var mouth := _sphere(_head, 0.03, Vector3(0.0, -0.1, -0.12), _material(Color.BLACK))
	mouth.scale = Vector3(1.0, 2.2, 0.4)

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.1, 0.05)
	glow.light_energy = 0.6
	glow.omni_range = 4.0
	glow.position = Vector3(0.0, 2.1, -0.3)
	add_child(glow)


func set_aggressive(on: bool) -> void:
	_aggressive = on


func _process(delta: float) -> void:
	_t += delta
	var raise := 1.4 if _aggressive else 0.0
	for i in _shoulders.size():
		var side := 1.0 if i == 1 else -1.0
		var sway := sin(_t * 1.3 + i * 2.1) * (0.12 if _aggressive else 0.05)
		_shoulders[i].rotation.x = lerpf(_shoulders[i].rotation.x, raise + sway, 5.0 * delta)
		_shoulders[i].rotation.z = lerpf(_shoulders[i].rotation.z, side * 0.07, 3.0 * delta)
		_elbows[i].rotation.x = lerpf(_elbows[i].rotation.x, 0.3 if _aggressive else 0.05, 4.0 * delta)
	_head.rotation.z = sin(_t * 0.6) * 0.15
	rotation.x = lerpf(rotation.x, -0.25 if _aggressive else 0.0, 4.0 * delta)


func _build_arm(side: float, skin: Material) -> void:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(0.22 * side, 1.8, 0.0)
	add_child(shoulder)
	_cylinder(shoulder, 0.035, UPPER_ARM, Vector3(0.0, -UPPER_ARM * 0.5, 0.0), skin)

	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -UPPER_ARM, 0.0)
	shoulder.add_child(elbow)
	_cylinder(elbow, 0.03, FOREARM, Vector3(0.0, -FOREARM * 0.5, 0.0), skin)

	var hand := Node3D.new()
	hand.position = Vector3(0.0, -FOREARM, 0.0)
	elbow.add_child(hand)
	var palm := MeshInstance3D.new()
	var palm_mesh := BoxMesh.new()
	palm_mesh.size = Vector3(0.08, 0.1, 0.025)
	palm_mesh.material = skin
	palm.mesh = palm_mesh
	palm.position = Vector3(0.0, -0.05, 0.0)
	hand.add_child(palm)
	for i in 5:
		var length := 0.26 if i in [1, 2, 3] else 0.18
		var finger := Node3D.new()
		finger.position = Vector3((i - 2) * 0.017, -0.1, 0.0)
		finger.rotation.z = (i - 2) * 0.16
		hand.add_child(finger)
		_cylinder(finger, 0.008, length, Vector3(0.0, -length * 0.5, 0.0), skin)

	_shoulders.append(shoulder)
	_elbows.append(elbow)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	mesh.material = mat
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(parent, mesh, pos, mat)


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _mesh(parent, mesh, pos, mat)


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh(parent, mesh, pos, mat)
