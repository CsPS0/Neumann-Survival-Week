extends "res://scripts/teacher_npc.gd"
## After-hours caretaker: patrols the school, spots a player within 8 m in front of him and runs them down.
## Reaching the player means expulsion.

signal caught_player

const SIGHT := 8.0
const CATCH := 1.4

var player: Node3D
var _spotted := false


func _ready() -> void:
	super._ready()
	add_to_group("caretaker")
	remove_from_group("teachers")
	prompt = ""
	npc_name = "Caretaker"


func _physics_process(delta: float) -> void:
	if player and not _spotted and _sees_player():
		_spotted = true
		chase_target = player
	super._physics_process(delta)
	if player and global_position.distance_to(player.global_position) < CATCH:
		set_physics_process(false)
		caught_player.emit()


func _sees_player() -> bool:
	var to_player := player.global_position - global_position
	if to_player.length() > SIGHT:
		return false
	var forward := -global_basis.z
	if forward.angle_to(Vector3(to_player.x, 0.0, to_player.z)) > deg_to_rad(50.0):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5,
			player.global_position + Vector3.UP * 1.4, 1 | 2 | 8, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player
