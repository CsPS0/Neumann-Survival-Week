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

const CampaignScript := preload("res://scripts/campaign.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")

func _run() -> void:
	check(SoundBank.scream().get_length() > 0.2, "scream sound exists")
	var main: Node = await _fresh()
	var crowd: Node = main.crowd
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.player.global_position = main._room_centre(0, "Bejárat") + Vector3(0, 0.1, 0)

	# A break: students walk the corridors near the player.
	main.daynight.minutes = CampaignScript.lesson_end(0) + 1.0
	crowd.sync_now()
	check(crowd.flow_count() > 20, "a crowd walks the corridors in a break, got %d" % crowd.flow_count())
	check(crowd.shown_count() <= crowd.MAX_CROWD, "cap respected in a break")
	var before: Vector3 = crowd._slots[0]["pos"]
	crowd._process(1.0)
	crowd._advance(1.0)
	check(crowd._slots[0]["pos"] != before, "students move along the corridor")
	# Walkers keep their place when the player walks a little (no rebuild, no pop).
	var keep: Vector3 = crowd._slots[0]["pos"]
	main.player.global_position += Vector3(3.0, 0, 0)
	crowd.sync_now()
	check(crowd._slots[0]["pos"] == keep, "walkers are not rebuilt when the player moves")
	main.player.global_position -= Vector3(3.0, 0, 0)
	crowd.sync_now()

	# Before school the corridors are almost empty.
	main.daynight.minutes = 380.0
	crowd.sync_now()
	var early: int = crowd.flow_count()
	check(early > 0 and early < 40, "few students before school: %d" % early)

	# Panic: an awake entity near students hides them; a sleeping or hidden entity does nothing.
	main.daynight.minutes = CampaignScript.lesson_end(0) + 1.0
	crowd.sync_now()
	crowd._advance(0.0)
	var calm: int = crowd.shown_count()
	check(crowd.panicked_count() == 0, "nobody panics while the entity sleeps")
	main.scare.cooldown_left = 9999.0   # the scare flash would hide the crowd; this test covers per-student panic
	main.entity.encounter(false, main.player.global_position + Vector3(4, 0, 0), 30.0)   # a frozen glimpse: visible, cannot attack
	crowd._advance(0.0)
	check(crowd.panicked_count() > 0 and crowd.shown_count() < calm, "students near an awake entity vanish")
	check(crowd._scream.playing or crowd._screamed, "they scream once")
	main.entity.sleep()
	crowd._advance(0.0)
	check(crowd.panicked_count() == 0 and crowd.shown_count() == calm, "they return when it sleeps")
	var saved: Node = crowd.entity
	crowd.entity = null
	crowd._advance(0.1)   # must not crash
	crowd.entity = saved

	# Last bell: the corridors empty; the next day starts clean.
	main.daynight.minutes = CampaignScript.LAST_BELL + 5.0
	crowd.sync_now()
	check(crowd.shown_count() == 0, "empty after the last bell")
	DirAccess.remove_absolute(main.profile.path)
	main.queue_free()
