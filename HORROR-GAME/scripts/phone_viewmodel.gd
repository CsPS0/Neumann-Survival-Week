extends Node3D
## First-person phone held in the left hand. toggle() raises it into view (animated) with a live map
## on the screen, or lowers it again. Child of the camera, sibling of the Torch viewmodel.

const MapScript := preload("res://scripts/phone_map.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")

const LOWERED_POSITION := Vector3(-0.14, -0.62, -0.33)
const LOWERED_ROTATION := Vector3(-70.0, 8.0, 0.0)
const RAISED_POSITION := Vector3(-0.05, -0.08, -0.27)
const RAISED_ROTATION := Vector3(-11.0, 9.0, 0.0)

const SKIN := Color(0.72, 0.55, 0.47)

var raised := false
var page := 0                   ## 0 = map, 1 = tasks, 2 = clues, 3 = finds, 4 = neu_mecha, 5 = e-Kréten, 6 = Diákhirdetmények.

var _map: Control
var _viewport: SubViewport
var _glow: OmniLight3D
var _click: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.04, 0.04, 0.05)
	body_material.metallic = 0.7
	body_material.roughness = 0.35
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN
	skin.emission_enabled = true
	skin.emission = SKIN * 0.12

	_add_box(Vector3.ZERO, Vector3(0.076, 0.156, 0.009), body_material)
	# Hand gripping the back of the phone, forearm running down and away.
	_add_box(Vector3(0.0, -0.045, -0.02), Vector3(0.07, 0.07, 0.03), skin)
	_add_box(Vector3(-0.041, -0.04, -0.006), Vector3(0.01, 0.05, 0.014), skin)  # Thumb resting along the side from behind.
	var forearm := CylinderMesh.new()
	forearm.top_radius = 0.035
	forearm.bottom_radius = 0.035
	forearm.height = 0.45
	var forearm_node := _add(forearm, Vector3(0.0, -0.27, -0.12), skin)
	forearm_node.rotation_degrees = Vector3(60.0, 0.0, 0.0)


	_viewport = SubViewport.new()
	_viewport.size = Vector2i(450, 840)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_map = Control.new()
	_map.set_script(MapScript)
	_map.size = Vector2(_viewport.size)
	_viewport.add_child(_map)
	add_child(_viewport)

	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = _viewport.get_texture()
	var screen_mesh := QuadMesh.new()
	screen_mesh.size = Vector2(0.068, 0.134)
	_add(screen_mesh, Vector3(0.0, 0.0, 0.0051), screen_material)

	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.5, 0.7, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 1.2
	_glow.position = Vector3(0.0, 0.0, -0.14)
	add_child(_glow)

	_click = AudioStreamPlayer.new()
	_click.stream = SoundBank.click()
	_click.volume_db = -6.0
	add_child(_click)

	scale = Vector3.ONE * 1.7
	position = LOWERED_POSITION
	rotation_degrees = LOWERED_ROTATION
	visible = false


func toggle() -> void:
	set_raised(not raised)


func toggle_page() -> void:
	page = (page + 1) % MapScript.PAGE_COUNT
	_map.set_page(page)
	_click.play()


## Left / Right: the floor on the map, the section in e-Kréten, the list position on the notice board.
func change_floor(delta: int) -> void:
	match page:
		0:
			_map.reset_map(clampi(_map.floor_view + delta, 0, 2))
		5:
			_map.set_section(_map.section + delta)
		6:
			_map.scroll_by(delta)
	_click.play()


## Map: zoom in (factor above 1) or out. Other pages scroll their list one row, up for zoom in.
func zoom(factor: float) -> void:
	if page == 0:
		_map.zoom_by(factor)
	else:
		_map.scroll_by(-1 if factor > 1.0 else 1)


## I / J / K / L: pan the map, or scroll the list of the open page (up and down only).
func move_view(dir: Vector2) -> void:
	if page == 0:
		_map.pan_by(dir)
	elif dir.y != 0.0:
		_map.scroll_by(int(signf(dir.y)))


func set_raised(on: bool) -> void:
	if on == raised:
		return
	raised = on
	_click.play()
	if _tween:
		_tween.kill()
	var torch := get_node_or_null("../Torch")
	if on:
		_map.reset_map(0)
		_map.set_page(page)
		_map.refresh_settings()
		visible = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_glow.light_energy = 0.35
		if torch and torch.get("left_hand"):
			torch.left_hand.visible = false  # The phone brings its own hand.
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK if on else Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
	_tween.tween_property(self, "position", RAISED_POSITION if on else LOWERED_POSITION, 0.5)
	_tween.tween_property(self, "rotation_degrees", RAISED_ROTATION if on else LOWERED_ROTATION, 0.5)
	if not on:
		_tween.chain().tween_callback(_finish_lowering.bind(torch))


func _finish_lowering(torch: Node) -> void:
	visible = false
	_glow.light_energy = 0.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if torch and torch.get("left_hand"):
		torch.left_hand.visible = true


func _add(mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _add_box(pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(mesh, pos, material)
