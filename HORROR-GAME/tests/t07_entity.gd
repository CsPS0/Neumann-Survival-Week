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

const Campaign := preload("res://scripts/campaign.gd")

func _run() -> void:
	check(Campaign.encounter_for(1, 1) == "glimpse", "day 1 glimpse after lesson 2")
	check(Campaign.encounter_for(1, 0) == "", "day 1 quiet after lesson 1")
	check(Campaign.encounter_for(2, 2) == "chase", "day 2 chase")
	check(Campaign.encounter_for(3, 0) == "chase" and Campaign.encounter_for(3, 4) == "chase", "day 3 chases")
	check(Campaign.encounter_for(4, 0) == "", "no scripted encounters on hunt days")
	check(Campaign.encounter_for(1, 6) == "" and Campaign.encounter_for(9, 0) == "", "unknown keys are quiet")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	check(main.entity.chase_speed < 4.2 and is_equal_approx(main.entity.chase_speed, 3.0), "day 1 entity is slower")
	check(not main.entity.visible, "entity asleep at day start")

	# Chase catch -> blackout.
	var before: float = main.daynight.minutes
	main.entity.encounter(true, main.player.global_position + Vector3(0.5, 0, 0), 5.0)
	await create_timer(0.8).timeout
	check(main.ending_screen.visible == false, "day 1 catch is not an ending")
	check(main.campaign.ending_id == 0, "no ending id")
	check(main.campaign.blackouts == 1 and main.daynight.minutes >= before + 20.0, "blackout costs 20 minutes")
	check(main.player.controls_enabled, "player wakes up")
	check(not main.entity.visible, "entity is gone after the blackout")
	check(main.entity.process_mode == Node.PROCESS_MODE_DISABLED, "entity inert after the blackout")
	await create_timer(2.5).timeout
	check(is_equal_approx(main._flash.color.r, 0.7) and main._flash.color.a == 0.0, "flash tint restored to red")
	check(main.player.controls_enabled, "still in control after the fade")

	# Glimpse: visible, frozen, cannot catch; wake() re-enables processing.
	var blackouts: int = main.campaign.blackouts
	main.entity.encounter(false, main.player.global_position + Vector3(0.5, 0, 0), 1.0)
	await create_timer(0.5).timeout
	check(main.entity.visible and main.entity.process_mode == Node.PROCESS_MODE_DISABLED, "glimpse is visible and frozen")
	check(main.campaign.blackouts == blackouts, "a glimpse cannot catch")
	await create_timer(1.0).timeout
	check(not main.entity.visible, "glimpse ends asleep")
	main.entity.wake(main.player.global_position + Vector3(10, 0, 0))
	check(main.entity.process_mode == Node.PROCESS_MODE_INHERIT and main.entity.visible, "wake re-enables processing")
	main.entity.sleep()

	# A manual sleep()/wake() cancels a pending encounter timer; encounter while awake is safe.
	main.entity.encounter(true, main.player.global_position + Vector3(20, 0, 0), 1.0)
	main.entity.sleep()
	main.entity.wake(main.player.global_position + Vector3(20, 0, 0))
	main.entity.encounter(false, main.player.global_position + Vector3(20, 0, 0), 3.0)
	await create_timer(1.4).timeout
	check(main.entity.visible, "the cancelled timer did not put it to sleep")
	await create_timer(2.2).timeout
	check(not main.entity.visible and main.entity.process_mode == Node.PROCESS_MODE_DISABLED, "the live encounter sleeps it")

	# Bell at the end of lesson 2 (day 1: glimpse) starts the entity, then it sleeps again.
	main._on_bell("lesson_end", 1)
	await create_timer(0.3).timeout
	check(main.entity.visible, "bell glimpse: entity visible")
	check(main.entity.global_position.distance_to(main.player.global_position) > 5.0, "bell glimpse: it is away from the player")
	await create_timer(6.2).timeout
	check(not main.entity.visible, "bell glimpse: entity sleeps again")
	main._on_bell("lesson_end", 0)
	await create_timer(0.3).timeout
	check(not main.entity.visible, "no encounter after lesson 1 on day 1")

	# No encounter while a quiz is open.
	main.choice_ui.visible = true
	main._on_bell("lesson_end", 1)
	await create_timer(0.3).timeout
	check(not main.entity.visible, "no encounter during a quiz")
	main.choice_ui.visible = false

	# Review Focus 3: no blackout while an ending screen is up.
	main.campaign.start_day(4)
	check(is_equal_approx(main.entity.chase_speed, 4.2), "day 4 chase speed")
	main.campaign.player_killed()
	check(main.campaign.ending_id == 1, "killed on day 4")
	blackouts = main.campaign.blackouts
	main._on_player_caught()
	check(main.campaign.blackouts == blackouts, "a catch during an ending does nothing")
