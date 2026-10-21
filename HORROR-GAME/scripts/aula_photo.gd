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
const COLUMNS := 5
const ROWS := 4   ## COLUMNS x ROWS = 20 pieces (Finds.PIECES).


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

	# The empty canvas, then one tile per piece on top of it. A tile shows once its piece is in the frame.
	var canvas := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var backing := StandardMaterial3D.new()
	backing.albedo_color = Color(0.1, 0.1, 0.11)
	backing.roughness = 0.95
	quad.material = backing
	canvas.mesh = quad
	canvas.position = Vector3(0.0, 0.0, THICKNESS * 0.5 + 0.002)
	holder.add_child(canvas)

	var tiles: Array[MeshInstance3D] = []
	var tile_size := Vector2(width / COLUMNS, height / ROWS)
	for index in COLUMNS * ROWS:
		var col := index % COLUMNS
		var row := index / COLUMNS
		var tile := MeshInstance3D.new()
		var tile_quad := QuadMesh.new()
		tile_quad.size = tile_size - Vector2(0.006, 0.006)
		var material := StandardMaterial3D.new()
		material.roughness = 0.9
		if texture:
			material.albedo_texture = texture
			material.emission_enabled = true
			material.emission_texture = texture
			material.emission_energy_multiplier = 0.12
			material.uv1_scale = Vector3(1.0 / COLUMNS, 1.0 / ROWS, 1.0)
			material.uv1_offset = Vector3(float(col) / COLUMNS, float(row) / ROWS, 0.0)
		else:
			material.albedo_color = PLACEHOLDER.lerp(Color(0.6, 0.58, 0.5), 0.5 * float((col + row) % 2))
			var number := Label3D.new()
			number.text = str(index + 1)
			number.font_size = 48
			number.pixel_size = 0.004
			number.modulate = Color(0.2, 0.2, 0.2)
			number.position = Vector3(0.0, 0.0, 0.002)
			tile.add_child(number)
		tile_quad.material = material
		tile.mesh = tile_quad
		tile.position = Vector3((col + 0.5) * tile_size.x - width * 0.5, height * 0.5 - (row + 0.5) * tile_size.y,
				THICKNESS * 0.5 + 0.004)
		tile.visible = false
		holder.add_child(tile)
		tiles.append(tile)
	holder.set_meta("tiles", tiles)
	holder.set_meta("size", Vector2(width, height))
	return holder


## Shows the piece `index` (0 to 19, reading order) in a frame built by `build`.
static func show_piece(holder: Node3D, index: int) -> void:
	var tiles: Array = holder.get_meta("tiles", [])
	if index >= 0 and index < tiles.size():
		tiles[index].visible = true


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
