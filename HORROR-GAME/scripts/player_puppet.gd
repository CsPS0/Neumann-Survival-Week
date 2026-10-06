class_name PlayerPuppet extends StaticBody3D

@onready var body = $Body
@onready var head = $Head
@onready var flashlight = $Head/Flashlight
@onready var nametag = $Nametag

var target_position := Vector3.ZERO
var target_rotation := 0.0
var target_flashlight := false
var is_sprinting := false

func _ready() -> void:
	target_position = global_position
	target_rotation = rotation.y
	flashlight.visible = target_flashlight

var prompt = "Revive"
var _revive_timer = 0.0

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, 15.0 * delta)
	rotation.y = lerp_angle(rotation.y, target_rotation, 15.0 * delta)
	flashlight.visible = target_flashlight
	
	if is_sprinting:
		# Simple run animation
		var t = Time.get_ticks_msec() / 1000.0
		body.position.y = 0.75 + sin(t * 15.0) * 0.05
	else:
		var t = Time.get_ticks_msec() / 1000.0
		body.position.y = 0.75 + sin(t * 5.0) * 0.02
		
	# Re-orient nametag manually if billboard isn't enough, but billboard=1 handles it in scene
	
	var main = get_tree().current_scene
	if rotation.x != 0 and main and main.name == "Main" and main.player:
		var ray = main.player.interact_ray
		if ray.is_colliding() and ray.get_collider() == self:
			if Input.is_action_pressed("interact") and not main.player.is_downed:
				_revive_timer += delta
				prompt = "Reviving... " + str(int((_revive_timer / 3.0) * 100)) + "%"
				if _revive_timer >= 3.0:
					NetSession.rpc("revive_player", name.to_int())
					_revive_timer = 0.0
			else:
				_revive_timer = 0.0
				prompt = "Revive"
		else:
			_revive_timer = 0.0
			prompt = "Revive"

func interact(player: Node) -> void:
	pass # Handled in process


@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector3, yaw: float, sprint: bool) -> void:
	target_position = pos
	target_rotation = yaw
	is_sprinting = sprint

@rpc("any_peer", "reliable")
func sync_flashlight(on: bool) -> void:
	target_flashlight = on

@rpc("any_peer", "reliable")
func sync_name(player_name: String) -> void:
	if nametag:
		nametag.text = player_name
