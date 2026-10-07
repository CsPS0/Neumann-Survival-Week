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

const Classes := preload("res://scripts/classes.gd")
const Rooms := preload("res://scripts/rooms.gd")
const FloorData := preload("res://scripts/floor_data.gd")

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

func _reachable(main: Node, spot: Vector3, floor_index: int) -> bool:
	var map: RID = main.get_world_3d().navigation_map
	var target := Vector3(spot.x, floor_index * 4.0 + 0.05, spot.z)
	var path := NavigationServer3D.map_get_path(map, main._spawn_point, target, true)
	if path.is_empty():
		return false
	var end: Vector3 = path[path.size() - 1]
	return absf(end.y - floor_index * 4.0) < 1.5 and Vector2(end.x - spot.x, end.z - spot.z).length() < 1.6

func _run() -> void:
	var main: Node = await _fresh()
	var porta: Node = main.porta
	var p: Node = main.player
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	check(Classes.PLAYER_CLASS == "11.a", "you are 11.a")
	check(main.tasks != null, "tasks node")
	var lines: Array = main.tasks.lines(1)
	check(lines.size() == 1 and not lines.any(func(l: String) -> bool: return l.contains("sticker") or l.contains("card")), "day 1 lists only the opening until something happens")
	var day3: Array = main.tasks.lines(3)
	check(day3.any(func(l: String) -> bool: return l.contains("student card")) and day3.any(func(l: String) -> bool: return l.contains("Lab 14")), "day-3 tasks: the new card and Lab 14")
	check(not main.tasks.is_done("card") and not main.tasks.is_done("lab"), "nothing done yet")
	# Extra: the opening is the first message and the first Tasks line.
	check(main._message_label.text == main.TasksScript.OPENING and lines[0] == main.TasksScript.OPENING, "day-1 opening shown and first on the Tasks page")

	# The sticker chain. New cards are only handed out on day 3, but the form can be picked up from day 1.
	check(porta.ask_sticker().contains("day 3"), "no sticker before day 3")
	check(not porta.card_renewed, "not renewed yet")
	var forms := get_nodes_in_group("form")
	check(forms.size() == 1, "one form on the school")
	var form: Node = forms[0]
	check(Rooms.type_of(main._form_room_label) == "normal" and main._form_room_floor == 1, "form in an open classroom upstairs: " + main._form_room_label)
	# Extra (Review Focus 2/3): the form is visible on day 1, inside its room, not a story item, and reachable.
	check(form.visible and form.collision_layer == 16 and not form.is_in_group("story"), "form active on day 1")
	check(FloorData.room_rect(main._form_room_floor, main._form_room_label).has_point(Vector2(form.global_position.x, form.global_position.z)), "form inside its room")
	check(_reachable(main, form.global_position, main._form_room_floor), "form reachable from the spawn")
	form.interact(p)
	check(porta.has_form and p.has_item("form"), "took the form")
	main.campaign.start_day(3)
	await create_timer(0.3).timeout
	check(porta.card_valid and p.has_item("form"), "the card is still valid on day 3 and the form is kept")
	check(porta.ask_sticker().contains("Stamped") and porta.card_renewed and not p.has_item("form") and not porta.has_form, "sticker given for the form")
	porta.card_renewed = false
	porta.has_form = true
	p.give_item("form", "signed form")
	# Through the porter's own menu (index 3 = Ask for the sticker).
	main.porter.interact(p)
	check(main.choice_ui.visible and main._porta_kind == "porta_menu", "porter menu opens")
	main.choice_ui.chosen.emit(3)
	check(main._message_label.text.contains("Stamped") and porta.card_renewed and not p.has_item("form"), "sticker given for the form")
	check(main.tasks.is_done("card"), "card task done")
	check(porta.ask_sticker().contains("already"), "only once")
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	check(porta.card_valid, "renewed card stays valid on day 4")
	check(not main._message_label.text.contains("expired"), "no expiry message with a renewed card")

	# Lab 14: the door needs the stolen key; the three pages complete the lab task.
	var lab_door: Node = main.quest.lab_door
	check(lab_door != null and lab_door.locked and lab_door.key_id == "key_14", "lab door needs key 14")
	lab_door.interact(p)
	check(lab_door.locked, "locked without the key")
	porta.away = true
	porta.try_steal("14")
	lab_door.interact(p)
	check(not lab_door.locked, "unlocked with the stolen key")
	for id in ["lab1", "lab2", "lab3"]:
		main.finds.mark(id)
	check(main.tasks.is_done("lab"), "lab task done after the three pages")

	# Holy water: hidden until the hunt starts AND the fuse is placed (Review Focus 2).
	var vial: Node = null
	for it in get_nodes_in_group("pickup"):
		if it.item_id == "vial":
			vial = it
	check(vial != null and not vial.visible, "holy water hidden before the hunt")
	check(FloorData.room_rect(0, "14").has_point(Vector2(vial.global_position.x, vial.global_position.z)), "vial inside Lab 14")
	check(_reachable(main, vial.global_position, 0), "the lab cabinet is reachable")
	main.quest.fuse_placed = true
	main.quest.changed.emit()
	check(not vial.visible, "fuse alone is not enough")
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	main.choice_ui.chosen.emit(main.TEACHER_ORDER.find(main.campaign.culprit))
	await create_timer(0.3).timeout
	check(vial.visible, "after the accusation and the fuse the cabinet opens")
	check(vial.collision_layer == 16, "and the vial can be taken")

	_cleanup(main)
	await create_timer(0.3).timeout

	# Missing the sticker: the card expires at the end of day 3 and day 4 refuses every key (no soft-lock, the steal path still works).
	main = await _fresh()
	porta = main.porta
	p = main.player
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign.start_day(2)
	await create_timer(0.3).timeout
	check(porta.card_valid, "the card stays valid on day 2")
	main.campaign.start_day(3)
	await create_timer(0.3).timeout
	check(porta.card_valid and porta.ask_sticker().contains("form"), "day 3: he wants the signed form first")
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	check(not porta.card_valid, "expired card")
	check(main._message_label.text.contains("Your student card expired at midnight."), "expiry message on day 4")
	check(porta.ask_key("23").contains("expired") and not main.player.has_item("key_23"), "no lending with an expired card")
	check(porta.ask_sticker().contains("expired"), "no sticker after the deadline")
	check(main.tasks.lines(4).any(func(l: String) -> bool: return l.contains("expired")), "tasks page shows the expired card")
	porta.away = true
	porta.try_steal("red")
	check(main.player.has_item("storage_key"), "the red room key can still be stolen")
	# Extra (Review Focus 3): on day 4 with an expired card the form pickup no longer exists, and the lab key can still be stolen.
	check(get_nodes_in_group("form").is_empty(), "on day 4 with an expired card the form pickup no longer exists")
	check(porta.ask_sticker().contains("expired") and not porta.card_renewed and not porta.card_valid, "a late form does not renew the card")
	porta.try_steal("14")
	check(p.has_item("key_14"), "key 14 can be stolen with an expired card")
	main.quest.lab_door.interact(p)
	check(not main.quest.lab_door.locked, "the lab still opens: the story stays completable")
	main.campaign.start_day(5)
	await create_timer(0.3).timeout
	check(not porta.card_valid and porta.ask_key("red").contains("expired"), "still expired on day 5")
	check(p.has_item("storage_key") and p.has_item("key_14"), "stolen keys survive the day rollovers")
	_cleanup(main)
