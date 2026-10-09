extends RefCounted
## Framed picture on the Aula wall. The photo shows real people, so it is local only (assets/photos_local/ is gitignored):
## a clone without the file gets an empty grey canvas in the same frame. The file is imported by the Godot editor;
## user://aula.jpg is a fallback for builds without it.

const IMPORTED := "res://assets/photos_local/aula.jpg"
const RAW := "user://aula.jpg"
const FRAME := Color(0.16, 0.1, 0.06)
const PLACEHOLDER := Color(0.45, 0.45, 0.43)
const THICKNESS := 0.04
const BORDER := 0.07


## Builds the frame and canvas as a child of `parent`, centred on `position`, facing along `normal` (the canvas front, +Z, points that way) (horizontal).
## `height` is the canvas height in metres, the width follows the photo's aspect ratio.
static func build(parent: Node3D, position: Vector3, normal: Vector3, height: float) -> Node3D:
	var texture := _load_texture()
	var aspect := 0.75
	if texture:
		aspect = float(texture.get_width()) / float(texture.get_height())
	var width := height * aspect

	var holder := Node3D.new()
	holder.name = "AulaPhoto"
	parent.add_child(holder)
	holder.position = position
	holder.look_at_from_position(position, position - normal, Vector3.UP)

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = FRAME
	frame_material.roughness = 0.7
	var outer := Vector3(width + BORDER * 2.0, height + BORDER * 2.0, THICKNESS)
	_add_box(holder, Vector3.ZERO, outer, frame_material)

	var canvas := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var material := StandardMaterial3D.new()
	material.roughness = 0.9
	if texture:
		material.albedo_texture = texture
		material.emission_enabled = true
		material.emission_texture = texture
		material.emission_energy_multiplier = 0.12
	else:
		material.albedo_color = PLACEHOLDER
	quad.material = material
	canvas.mesh = quad
	canvas.position = Vector3(0.0, 0.0, THICKNESS * 0.5 + 0.002)
	holder.add_child(canvas)
	return holder


static func _add_box(parent: Node3D, centre: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = centre
	parent.add_child(mesh)


static func _load_texture() -> Texture2D:
	if ResourceLoader.exists(IMPORTED):
		var imported := load(IMPORTED) as Texture2D
		if imported:
			return imported
	if FileAccess.file_exists(RAW):
		var image := Image.load_from_file(RAW)
		if image and not image.is_empty():
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)
	return null
