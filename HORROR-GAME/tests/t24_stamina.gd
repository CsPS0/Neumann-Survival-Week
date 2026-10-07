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
func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	return main
func _cleanup(main: Node) -> void:
	var p: String = main.profile.path
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	main.queue_free()
func _run() -> void:
	var main: Node = await _fresh()
	var p: Node = main.player
	check(p.stamina == 100.0 and not p.exhausted, "starts full")
	var changes: Array = []
	p.stamina_changed.connect(func(f: float) -> void: changes.append(f))
	var ex: Array = []
	p.exhausted_changed.connect(func(e: bool) -> void: ex.append(e))
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 30:
		p._physics_process(0.1)          # 3 s of sprint: 60 stamina
	check(is_equal_approx(p.stamina, 40.0), "3 s of sprint drains 60: %f" % p.stamina)
	for i in 30:
		p._physics_process(0.1)          # 3 more seconds: empty at 2 s of the second leg
	check(p.stamina == 0.0 and p.exhausted and ex == [true], "exhausted at zero")
	check(p.exhausted_count == 1, "exhausted_count counts it")
	for i in 20:
		p._physics_process(0.1)          # still holding sprint while exhausted: no drain, no sprint speed
	check(Vector2(p.velocity.x, p.velocity.z).length() <= p.walk_speed + 0.1, "exhausted player cannot sprint")
	Input.action_release(&"sprint")
	for i in 10:
		p._physics_process(0.1)          # 1 s delay: no regen yet
	check(p.stamina == 0.0, "1 s delay before regen: %f" % p.stamina)
	for i in 30:
		p._physics_process(0.1)          # 3 s of regen: 37.5
	check(p.stamina > 30.0 and not p.exhausted and ex == [true, false], "resumes at 30")
	for i in 100:
		p._physics_process(0.1)
	check(is_equal_approx(p.stamina, 100.0), "recovers to full")
	Input.action_release(&"move_forward")

	# Standing still while holding sprint does not drain (no movement).
	Input.action_press(&"sprint")
	p.velocity = Vector3.ZERO
	for i in 20:
		p._physics_process(0.1)
	check(p.stamina == 100.0, "sprint without moving is free")
	Input.action_release(&"sprint")

	# Review Focus 4: revive() and a controls-disabled player do not stay exhausted.
	p.stamina = 0.0
	p.exhausted = true
	p.revive()
	check(p.stamina == 100.0 and not p.exhausted, "revive refills")
	check(main._stamina_bar != null, "HUD bar exists")
	var events: Array = []
	main.campaign.event.connect(func(n: String, _d: Dictionary) -> void: events.append(n))
	p.exhausted_count = 9
	p.stamina = 1.0
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 10:
		p._physics_process(0.1)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	check(events.has("out_of_breath"), "10th exhaustion emits the achievement event")
	_cleanup(main)
