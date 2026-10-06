extends Node
## The neu_mecha feed: one post per day (days 1-5), each hides a mecha chameleon at a spot in an open room. Posts are
## invented. The photo is a one-off render of the hiding spot taken at the start of the day (null if the render fails).

signal post_added(day: int)

const Finds := preload("res://scripts/finds.gd")
const FloorData := preload("res://scripts/floor_data.gd")

var campaign: Node
var main: Node
var found: Dictionary = {}                 ## day -> true
var _photos: Dictionary = {}               ## day -> ImageTexture


func _ready() -> void:
	add_to_group("neu_mecha")   # Not "mecha": that group holds the figure in the world.


func posts() -> Array:
	var out: Array = []
	for m: Dictionary in Finds.MECHA:
		if int(m["day"]) <= campaign.day:
			out.append({"day": m["day"], "caption": m["caption"], "found": found.has(m["day"]), "photo": _photos.get(m["day"])})
	return out


func found_count() -> int:
	return found.size()


func photo_for(day: int) -> Texture2D:
	return _photos.get(day)


func mark_found(day: int) -> void:
	if found.has(day):
		return
	found[day] = true
	if found.size() == Finds.MECHA.size():
		campaign.event.emit("mecha_master", {})


## Called by main at the start of every day: replace yesterday's figure with today's and start the photo render.
func on_day_started(day: int) -> void:
	for old: Node in get_tree().get_nodes_in_group("mecha"):
		old.remove_from_group("mecha")   # Gone from the group now, not at the end of the frame.
		old.queue_free()
	if day < 1 or day > Finds.MECHA.size():
		return
	var spot: Dictionary = Finds.MECHA[day - 1]
	var pos: Vector3 = main.find_spot(spot["id"])
	var fig: Node3D = main.spawn_find("mecha", spot["id"], "mecha chameleon", pos, "")
	fig.add_to_group("mecha")
	fig.taken.connect(func(_id: String) -> void:
		mark_found(day)
		_reward(spot["reward"]))
	post_added.emit(day)
	var centre := FloorData.room_rect(spot["floor"], spot["room"]).get_center()
	_render_photo(day, pos, (Vector3(centre.x, pos.y, centre.y) - pos).normalized())


func _reward(kind: String) -> void:
	var player: Node = main.player
	var text := "A tiny mecha chameleon! It is warm, like a phone. neu_mecha post: found.\n"
	if kind == "biscuit" and not player.has_item("biscuit"):
		player.give_item("biscuit", "Dog biscuit", text + "A dog biscuit was hidden under the chameleon.")
		return
	if kind == "page":
		for p: Dictionary in Finds.PAGES:
			if not main.finds.found.has(p["id"]):
				main.finds.mark(p["id"])
				for f: Node in get_tree().get_nodes_in_group("find"):
					if f.get("item_id") == p["id"]:
						f.queue_free()
				player.inspected.emit(text + "A page was folded under it. %s\n%s" % [p["title"], p["text"]])
				return
	# Battery, and the fallback for a biscuit already in the pocket or no page left to find.
	player.add_battery(35.0)
	player.inspected.emit(text + "It had a battery taped to its belly. Battery +35%.")


## One-off 256x192 render of `pos` from 2 m towards the room centre. Never blocks: it waits two process frames.
func _render_photo(day: int, pos: Vector3, towards: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return   # Nothing renders headless: the feed shows the caption-only fallback.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 192)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.world_3d = main.get_world_3d()
	var camera := Camera3D.new()
	camera.fov = 60.0
	viewport.add_child(camera)
	var flash := OmniLight3D.new()   # The phone's flash: the rooms are dark at 06:00.
	flash.light_energy = 1.5
	flash.omni_range = 4.0
	camera.add_child(flash)
	main.add_child(viewport)
	camera.global_position = pos + towards * 2.0 + Vector3(0.0, 0.8, 0.0)
	camera.look_at(pos, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(viewport):
		return
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		_photos[day] = ImageTexture.create_from_image(image)
	viewport.queue_free()


## The mecha chameleon: green body, a gear on its back, a curled tail. Procedural.
static func build_model() -> Node3D:
	var root := Node3D.new()
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.2, 0.85, 0.35)
	green.emission_enabled = true
	green.emission = Color(0.1, 0.6, 0.2)
	green.emission_energy_multiplier = 0.5
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.6, 0.62, 0.68)
	steel.metallic = 0.9
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.04
	capsule.height = 0.16
	capsule.material = green
	body.mesh = capsule
	body.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.material = green
	head.mesh = sphere
	head.position = Vector3(0, 0.01, -0.1)
	root.add_child(head)
	var gear := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 0.012
	cyl.material = steel
	gear.mesh = cyl
	gear.position = Vector3(0, 0.05, 0.0)
	root.add_child(gear)
	var tail := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.012
	torus.outer_radius = 0.04
	torus.material = green
	tail.mesh = torus
	tail.position = Vector3(0, 0.0, 0.12)
	tail.rotation_degrees = Vector3(0, 90, 0)
	root.add_child(tail)
	for mesh: MeshInstance3D in root.get_children():
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
