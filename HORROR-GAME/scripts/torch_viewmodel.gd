extends Node3D
## First-person viewmodel: a torch gripped in the right hand and a bare left hand.
## Child of the camera. The torch points along -Z.

const SKIN := Color(0.72, 0.55, 0.47)

var left_hand := Node3D.new()  ## Hidden while the phone (which has its own hand) is raised.
var _lens: StandardMaterial3D


func _ready() -> void:
	var metal := _material(Color(0.07, 0.07, 0.08))
	metal.metallic = 0.8
	metal.roughness = 0.4
	var skin := _material(SKIN)
	skin.emission_enabled = true  # Faint self-light so the hands read in the dark.
	skin.emission = SKIN * 0.3
	_lens = _material(Color(1.0, 0.95, 0.8))
	_lens.emission_enabled = true
	_lens.emission = Color(1.0, 0.95, 0.75)

	# Torch body, head and glowing lens.
	_cylinder(Vector3(0.0, 0.0, 0.0), 0.03, 0.30, metal, Vector3(90.0, 0.0, 0.0))
	_cylinder(Vector3(0.0, 0.0, -0.17), 0.048, 0.08, metal, Vector3(90.0, 0.0, 0.0))
	_cylinder(Vector3(0.0, 0.0, -0.212), 0.042, 0.006, _lens, Vector3(90.0, 0.0, 0.0))

	# Right hand around the grip, forearm running back and down off-screen.
	_box(Vector3(0.0, -0.02, 0.04), Vector3(0.075, 0.085, 0.1), skin)
	_cylinder(Vector3(0.0, -0.115, 0.3), 0.035, 0.45, skin, Vector3(-72.0, 0.0, 0.0))

	# Left hand, relaxed: raised into the lower left of the view, forearm angled back and down to the left corner.
	# Torch space: the hand sits 0.54 m left of the torch (0.24 m left of the camera axis), about 0.5 m ahead of the camera.
	add_child(left_hand)
	var hand_at := Vector3(-0.54, 0.02, 0.05)
	var back := Vector3(-0.3, -0.5, 0.8).normalized()   # Hand towards the elbow.
	_box(hand_at, Vector3(0.085, 0.07, 0.11), skin, left_hand)
	var forearm_rot := Basis(Quaternion(Vector3.UP, back)).get_euler() * (180.0 / PI)
	_cylinder(hand_at + back * 0.24, 0.037, 0.45, skin, forearm_rot, left_hand)


## Lights up the lens to match the flashlight state.
func set_lit(on: bool) -> void:
	_lens.emission_energy_multiplier = 3.0 if on else 0.0


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _add(mesh: Mesh, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, parent: Node3D = self) -> void:
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation_degrees = rot_deg
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # Must not shadow the beam.
	parent.add_child(instance)


func _cylinder(pos: Vector3, radius: float, height: float, mat: Material, rot_deg: Vector3, parent: Node3D = self) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	_add(mesh, pos, mat, rot_deg, parent)


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = self) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(mesh, pos, mat, Vector3.ZERO, parent)
