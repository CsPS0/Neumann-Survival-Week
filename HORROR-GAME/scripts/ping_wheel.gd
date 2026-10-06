extends CanvasLayer

var _ping_container: Node3D

func _ready() -> void:
	layer = 40
	_ping_container = Node3D.new()
	_ping_container.name = "PingMarkers"
	get_tree().root.call_deferred("add_child", _ping_container)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		if NetSession.is_multiplayer_active():
			var main = get_tree().current_scene
			if main and main.name == "Main" and main.player:
				var target = main.player.interact_ray.get_collider()
				var pos = main.player.interact_ray.get_collision_point()
				if main.player.interact_ray.is_colliding():
					var msg = "Ping!"
					if target and target.has_method("interact"):
						msg = "Item here!"
					rpc("spawn_ping", pos, msg)

@rpc("any_peer", "call_local")
func spawn_ping(pos: Vector3, msg: String) -> void:
	# Add a simple marker visually
	var marker = Label3D.new()
	marker.text = msg
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.pixel_size = 0.01
	marker.font_size = 32
	marker.outline_size = 4
	marker.modulate = Color(1.0, 0.8, 0.2)
	marker.global_position = pos
	_ping_container.add_child(marker)
	
	# Add audio cue
	var audio = AudioStreamPlayer3D.new()
	# Just use breath or something for now, or don't set stream if not available
	marker.add_child(audio)
	
	# Destroy after 5 seconds
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(func(): marker.queue_free())
	marker.add_child(timer)
	timer.start()
