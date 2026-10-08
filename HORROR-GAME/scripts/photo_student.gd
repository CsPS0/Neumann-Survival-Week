extends StaticBody3D
## A named student in the crowd (see scripts/student_faces_source.gd): the shared crowd body animated by the same shader
## (one instance), with a photo (or generated) face wrapped over the front of the head. The face has three expressions.
## crowd.gd places it in the slot it would otherwise give to an anonymous student.

const StudentModel := preload("res://scripts/student_model.gd")
const Placeholder := preload("res://scripts/student_faces_placeholder.gd")

const STATES := ["neutral", "smile", "sad"]
const HEAD_CENTRE := Vector3(0.0, 1.67, 0.0)
const HEAD_RADII := Vector3(0.1188, 0.1355, 0.1210)   ## The head ellipsoid in student_model.gd, 8% larger so the hair cap does not cover the face.
const SPAN := Vector2(deg_to_rad(80.0), deg_to_rad(60.0))   ## Half angle of the face patch: sideways and up/down.
const GRID := 14
const ZOOM := 0.85   ## Share of the square photo that the patch shows, so the face fills the head.
const HIP := Vector3(0.0, 0.92, 0.0)
const INTERACT_LAYER := 32   ## Same layer as the teachers: the player's ray finds it.
const BODY_HEIGHT := 1.5

var student_name := ""
var look := 0.0
var shirt := Color(0.4, 0.4, 0.45)
var skin := Color(0.92, 0.77, 0.67)
var hair := Color(0.4, 0.3, 0.2)

var prompt := ""

var _visual := Node3D.new()      ## Carries the height scale; this body is never scaled.
var _mm := MultiMesh.new()
var _face := MeshInstance3D.new()
var _material := StandardMaterial3D.new()
var _textures := {}              ## state -> Texture2D
var _state := ""


## `entry`: one element of the roster's STUDENTS.
func setup(entry: Dictionary) -> void:
	student_name = entry["name"]
	prompt = student_name
	look = entry["look"]
	shirt = entry["shirt"]
	skin = entry.get("skin", skin)
	hair = entry.get("hair", hair)
	var faces: Dictionary = entry["faces"]
	for state: String in STATES:
		var path: String = faces.get(state, "")
		if path != "" and ResourceLoader.exists(path):
			_textures[state] = load(path)
		else:
			_textures[state] = Placeholder.texture(state, Color(0.9, 0.74, 0.62))


func _ready() -> void:
	add_child(_visual)
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = StudentModel.mesh()
	_mm.instance_count = 1
	_mm.set_instance_transform(0, Transform3D.IDENTITY)
	_mm.set_instance_color(0, shirt)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _mm
	instance.material_override = StudentModel.named_material(skin, hair)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 4.0, 4.0))
	_visual.add_child(instance)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	_material.roughness = 1.0
	_material.cull_mode = BaseMaterial3D.CULL_BACK
	_face.mesh = _face_mesh()
	_face.material_override = _material
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_face)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = BODY_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, BODY_HEIGHT * 0.5 + 0.1, 0.0)
	add_child(shape)
	collision_mask = 0
	set_expression("neutral")
	hide_student()


## Press E on the student: the name, as with the ambient teachers.
func interact(by: Node) -> void:
	by.inspected.emit("%s, student" % student_name)


func hide_student() -> void:
	visible = false
	collision_layer = 0


## `seated`: hips on a chair (the crowd shader folds the legs); `pos` is the chair seat height then, the floor otherwise.
func show_at(pos: Vector3, yaw: float, height: float, seated: bool, walk_speed: float, expression: String) -> void:
	visible = true
	collision_layer = INTERACT_LAYER
	position = pos + (Vector3(0.0, -0.42 * height, 0.0) if seated else Vector3.ZERO)
	rotation = Vector3(0.0, yaw, 0.0)
	_visual.scale = Vector3(1.0, height, 1.0)
	_mm.set_instance_custom_data(0, Color(look, 1.0 if seated else 0.0, look * TAU, walk_speed))
	# The shader leans the upper body forward about the hips when seated: the face follows it.
	var lean := -0.1 if seated else 0.0
	var rot := Basis(Vector3.RIGHT, lean)
	_face.transform = Transform3D(rot, HIP - rot * HIP)
	set_expression(expression)


func set_expression(state: String) -> void:
	if state == _state or not _textures.has(state):
		return
	_state = state
	_material.albedo_texture = _textures[state]


## The front of the head as a grid on the head ellipsoid, UV 0..1 over the patch (the photo is a square crop).
static func _face_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in GRID + 1:
		for i in GRID + 1:
			var u := float(i) / GRID
			var v := float(j) / GRID
			var theta := (1.0 - u * 2.0) * SPAN.x    # u runs to the viewer's right, which is -X (forward is -Z).
			var phi := (1.0 - v * 2.0) * SPAN.y      # Positive: up.
			var unit := Vector3(sin(theta) * cos(phi), sin(phi), -cos(theta) * cos(phi))   # Forward is -Z.
			verts.append(HEAD_CENTRE + unit * HEAD_RADII)
			normals.append((unit / HEAD_RADII).normalized())
			uvs.append(Vector2(0.5 + (u - 0.5) * ZOOM, 0.5 + (v - 0.5) * ZOOM))
	for j in GRID:
		for i in GRID:
			var a := j * (GRID + 1) + i
			var b := a + 1
			var c := a + GRID + 1
			var d := c + 1
			# Seen from the front the grid runs left to right and top to bottom: a-b-c is clockwise, which Godot treats as front-facing.
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
