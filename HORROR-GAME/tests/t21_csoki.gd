extends SceneTree
var fails := 0
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

const SoundBank := preload("res://scripts/sound_bank.gd")
const Achievements := preload("res://scripts/achievements.gd")
const CampaignScript := preload("res://scripts/campaign.gd")

func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	return main

func _run() -> void:
	var bark := SoundBank.bark()
	check(bark.get_length() > 0.1, "bark sound exists")
	var data := bark.data
	var peak := 0.0
	for i in range(0, data.size(), 2):
		peak = maxf(peak, absf(data.decode_s16(i)) / 32768.0)
	check(peak <= 1.0 and peak > 0.1, "bark peak sane: %f" % peak)
	check(Achievements.LIST.has("good_boy") and Achievements.LIST["good_boy"][0] == "Good Boy", "achievement defined")
	var main: Node = await _fresh()
	var profile_path: String = main.profile.path
	var dog: Node = main.csoki
	check(dog != null and get_nodes_in_group("csoki").size() == 1, "exactly one Csoki")
	check(dog.is_in_group("csoki") and not dog.is_in_group("teachers") and not dog.is_in_group("ambient_staff"), "only in group csoki")
	check(dog.collision_layer == 16, "the dog is on the interact-only layer")
	var cap: CapsuleShape3D = null
	for c in dog.get_children():
		if c is CollisionShape3D:
			cap = c.shape
	check(cap != null and cap.height < 0.7 and cap.radius < 0.25, "small capsule")
	var group_dogs := get_nodes_in_group("teachers").size()
	check(group_dogs == 8, "8 suspect teachers, no dog among them: %d" % group_dogs)

	# Route reachability and walking.
	var map: RID = main.get_world_3d().navigation_map
	var minp := Vector3(INF, 0, INF)
	var maxp := Vector3(-INF, 0, -INF)
	for p: Vector3 in dog.route:
		var path := NavigationServer3D.map_get_path(map, main._spawn_point, p, true)
		check(path.size() > 1 and path[path.size() - 1].distance_to(p) < 1.5, "Csoki marker reachable: %s" % str(p))
		minp.x = minf(minp.x, p.x); minp.z = minf(minp.z, p.z)
		maxp.x = maxf(maxp.x, p.x); maxp.z = maxf(maxp.z, p.z)
	var start: Vector3 = dog.global_position
	await create_timer(6.0).timeout
	check(dog.global_position.distance_to(start) > 0.5, "Csoki walks around")

	# Interact ray and passing through.
	main.player.global_position = dog.global_position + Vector3(3, 0.1, 0)
	var eye: Vector3 = main.player.camera.global_position
	var dog_mid: Vector3 = dog.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, dog_mid, 57, [main.player.get_rid()])
	q.collide_with_areas = false
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty() and hit.collider == dog, "interact ray hits the dog first: %s" % str(hit.get("collider")))
	check(main.player.collision_mask & 16 == 0, "player mask excludes 16")
	dog.set_physics_process(false)
	var dpos: Vector3 = dog.global_position
	main.player.global_position = dpos + Vector3(2.0, 0.1, 0)
	main.player.velocity = Vector3.ZERO
	var before: float = main.player.global_position.x
	for i in 90:
		main.player.velocity.x = -2.0
		main.player.move_and_slide()
		await physics_frame
	check(main.player.global_position.x < dpos.x - 1.0, "player walked through the dog: %f vs %f" % [main.player.global_position.x, dpos.x])
	dog.set_physics_process(true)

	# Barking.
	var barks: Array = []
	dog.barked.connect(func() -> void: barks.append(1))
	main.entity.encounter(false, dog.global_position + Vector3(8, 0, 0), 30.0)
	await create_timer(1.0).timeout
	check(barks.size() == 1, "barks once when the entity is near, got %d" % barks.size())
	await create_timer(2.0).timeout
	check(barks.size() == 1, "no bark spam inside the cooldown, got %d" % barks.size())
	main.entity.sleep()
	main.entity.global_position = Vector3(500, 0, 500)
	var count: int = barks.size()
	await create_timer(7.0).timeout
	check(barks.size() == count, "silent when nothing is near")

	# Caretaker.
	main._spawn_caretaker()
	await create_timer(0.5).timeout
	for c in get_nodes_in_group("caretaker"):
		c.queue_free()
	await create_timer(0.5).timeout
	check(is_instance_valid(dog), "dog survives the caretaker leaving")

	# Dusk, night, last bell never touch it.
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main._on_bell("last_bell", 0)
	main._on_dusk()
	main._on_night()
	await create_timer(0.5).timeout
	check(is_instance_valid(dog) and not dog.is_queued_for_deletion() and not dog._leaving, "Csoki stays through bell/dusk/night")
	check(get_nodes_in_group("csoki").size() == 1, "still one dog")

	# Petting through the real chain.
	var seen: Array = []
	main.player.inspected.connect(func(text: String) -> void: seen.append(text))
	var events: Array = []
	main.campaign.event.connect(func(ev: String, _d: Dictionary) -> void: events.append(ev))
	var unlocks: Array = []
	main.achievements.unlocked.connect(func(id: String) -> void: unlocks.append(id))
	check(not main.profile.has_method("is_unlocked") or not main.profile.is_unlocked("good_boy"), "not unlocked yet")
	dog.interact(main.player)
	dog.interact(main.player)
	check(seen.size() == 2 and seen[0] == "Csoki wags its tail.", "petting shows a message")
	check(events.count("good_boy") == 2, "pet event emitted")
	check(unlocks.count("good_boy") == 1, "unlocked exactly once: %s" % str(unlocks))
	check(main.profile.unlock("good_boy") == false, "profile already has it")
	dog.interact(null)
	check(seen.size() == 2, "interact(null) is a no-op")

	# 60 s of wandering stays in the hall rectangle (+-3 m).
	var worst := 0.0
	for i in 120:
		await create_timer(0.5).timeout
		var g: Vector3 = dog.global_position
		worst = maxf(worst, maxf(maxf(minp.x - g.x, g.x - maxp.x), maxf(minp.z - g.z, g.z - maxp.z)))
	check(worst < 3.0, "Csoki stays in the hall, worst overshoot %f" % worst)
	print("hall overshoot ", worst, " rect ", minp, maxp)

	main.queue_free()
	await create_timer(0.3).timeout
	DirAccess.remove_absolute(profile_path)
