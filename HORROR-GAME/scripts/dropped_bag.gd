extends StaticBody3D
## The bag after the player drops it. Layer 16 like the pickups: the interact ray sees it, nothing collides with it.
## The items stay in the player's inventory but cannot be reached until the bag is worn again.

var prompt := "Pick up your bag"


func _ready() -> void:
	add_to_group("dropped_bag")
	collision_layer = 16
	collision_mask = 0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.5, 0.3)
	shape.shape = box
	add_child(shape)

	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.12, 0.2, 0.14)
	cloth.roughness = 0.95
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.4, 0.46, 0.25)
	body_mesh.material = cloth
	body.mesh = body_mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)

	var pocket := MeshInstance3D.new()
	var pocket_mesh := BoxMesh.new()
	pocket_mesh.size = Vector3(0.3, 0.18, 0.06)
	pocket_mesh.material = cloth
	pocket.mesh = pocket_mesh
	pocket.position = Vector3(0.0, -0.08, 0.15)
	pocket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pocket)


func interact(by: Node = null) -> void:
	if by != null and by.has_method(&"pick_up_bag"):
		by.pick_up_bag(self)
