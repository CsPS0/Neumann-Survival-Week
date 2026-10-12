extends StaticBody3D
## A crew member the entity took down (Social Deduction). Looking at it and pressing E reports it and starts a meeting.

var victim := 0
var prompt := "Report body"


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.08, 0.08)
	material.roughness = 0.9
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.22
	mesh.height = 1.6
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.rotation.x = PI / 2.0
	visual.position.y = 0.22
	add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.5, 1.7)
	shape.shape = box
	shape.position.y = 0.25
	add_child(shape)


func interact(_by: Node) -> void:
	Match.report_body(victim)
