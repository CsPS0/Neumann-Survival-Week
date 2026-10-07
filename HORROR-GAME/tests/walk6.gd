extends SceneTree
const OUT := "C:/Users/solti/AppData/Local/Temp/neu-tests/"
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.daynight.minutes = 860.0
	await create_timer(0.5).timeout
	var care: Node = get_nodes_in_group("caretaker")[0]
	care.player = null   # patrol only for now
	print("offset ", care.path_offset, " start ", care.global_position)
	# Patrol: sample position for 20 s.
	var last: Vector3 = care.global_position
	var travelled := 0.0
	var reversals := 0
	var last_dir := Vector3.ZERO
	var moving_samples := 0
	for i in 80:
		await create_timer(0.25).timeout
		var d: Vector3 = care.global_position - last
		d.y = 0.0
		if d.length() > 0.05:
			moving_samples += 1
			if last_dir != Vector3.ZERO and d.normalized().dot(last_dir) < -0.8:
				reversals += 1
			last_dir = d.normalized()
		travelled += d.length()
		last = care.global_position
	print("patrol: travelled %.1f m in 20 s, moving samples %d/80, reversals %d, now %s" % [travelled, moving_samples, reversals, care.global_position])
	# Cross-floor chase: bait on the 2nd floor.
	var bait := Node3D.new()
	main.add_child(bait)
	bait.global_position = main._room_centre(2, "Igazgatói")
	care.chase_target = bait
	var start_y: float = care.global_position.y
	var max_y := start_y
	for i in 120:
		await create_timer(0.25).timeout
		max_y = maxf(max_y, care.global_position.y)
		if care.global_position.distance_to(bait.global_position) < 2.5:
			break
	print("chase: y %.2f -> max %.2f, dist to bait %.1f at %s" % [start_y, max_y, care.global_position.distance_to(bait.global_position), care.global_position])
	# Screenshot: stand the player 3 m in front of the caretaker, looking at him.
	care.chase_target = null
	care.set_physics_process(false)
	main.player.global_position = care.global_position + Vector3(2.5, 0.1, 0.0)
	main.player.look_at(care.global_position + Vector3(0, 1.4, 0), Vector3.UP)
	main.player.rotation.x = 0.0
	main.player.rotation.z = 0.0
	main.player.set_flashlight(true)
	main.player.controls_enabled = false
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "caretaker.png")
	quit()
