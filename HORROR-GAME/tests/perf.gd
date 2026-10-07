extends SceneTree
## NON-headless performance probe. Run: GODOT --path . --script perf.gd
const Campaign := preload("res://scripts/campaign.gd")
const Lessons := preload("res://scripts/lessons.gd")
const BUDGET_MS := 12.0
var failed: Array[String] = []

func _initialize() -> void:
	await _run()
	print("PERF PASS" if failed.is_empty() else "PERF FAIL " + ", ".join(failed))
	quit()

func _live(group: String) -> int:
	var n := 0
	for t in get_nodes_in_group(group):
		if not t.is_queued_for_deletion():
			n += 1
	return n

func _measure(m: Node, spot: String) -> void:
	await create_timer(3.0).timeout
	var t := 0.0
	var frames := 0
	var proc := 0.0
	var phys := 0.0
	var draw := 0.0
	var worst := 0.0
	var last := Time.get_ticks_usec()
	while t < 5.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var d := (now - last) / 1000000.0
		last = now
		t += d
		frames += 1
		worst = maxf(worst, d)
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var avg_ms := t / frames * 1000.0
	var cpu_ms := (proc + phys) / frames * 1000.0
	print("SPOT %s: fps %d, avg frame %.2f ms (worst %.1f), script+physics %.2f ms (process %.2f, physics %.2f), drawcalls %d | teachers %d ambient %d crowd %d (seated %d flow %d) csoki %d" % [
		spot, Engine.get_frames_per_second(), avg_ms, worst * 1000.0, cpu_ms, proc / frames * 1000.0, phys / frames * 1000.0,
		draw / frames, _live("teachers"), _live("ambient_staff"), m.crowd.shown_count(), m.crowd.seated_count(), m.crowd.flow_count(), _live("csoki")])
	if avg_ms >= BUDGET_MS:
		failed.append("%s %.2f" % [spot, avg_ms])

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_perf.cfg"
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.entity.sleep()
	main.player.set_flashlight(false)
	# 1. Ground-floor hall in a break.
	main.daynight.minutes = Campaign.lesson_end(0) + 1.0
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)
	await _measure(main, "hall/break")
	# 2. The player's own classroom, mid-lesson.
	var subject: String = Lessons.subject_at(1, 1)
	main.daynight.minutes = Campaign.lesson_start(1) + 20.0
	main.player.global_position = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject)) + Vector3(0, 0.1, 0)
	await _measure(main, "classroom/lesson")
	# 3. A 1st-floor corridor in a break.
	main.daynight.minutes = Campaign.lesson_end(2) + 1.0
	var corridor: Array = main.FloorData.FLOORS[1]["corridors"][0]
	var data: Dictionary = main.FloorData.FLOORS[1]
	var p: Vector2 = ((corridor[0] as Vector2) + (corridor[corridor.size() - 1] as Vector2)) * 0.5
	var w: Vector2 = (p - (data["origin"] as Vector2)) * float(data["scale"])
	main.player.global_position = Vector3(w.x, 4.1, w.y)
	await _measure(main, "corridor1/break")
	DirAccess.remove_absolute(main.profile.path)
