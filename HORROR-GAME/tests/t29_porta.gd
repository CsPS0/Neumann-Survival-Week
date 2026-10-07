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

const Rooms := preload("res://scripts/rooms.gd")
const CampaignScript := preload("res://scripts/campaign.gd")
const Finds := preload("res://scripts/finds.gd")
const PortaScript := preload("res://scripts/porta.gd")

func _item_count(player: Node) -> int:
	var n := 0
	for place: int in player.items.slots:
		n += player.items.slots[place].size()
	return n

func _run() -> void:
	var main: Node = await _fresh()
	var porta: Node = main.porta
	var p: Node = main.player
	check(porta != null and main.porter != null and main.get_node_or_null("KeyBoard") != null, "porta, porter and key board exist")
	check(get_nodes_in_group("porta").size() == 1 and not main.porter.is_in_group("teachers"), "porter is separate from the suspects")
	check(not main.porter.npc_name.is_empty() and not preload("res://tests/staff_util.gd").is_real_name(main.porter.npc_name), "porter name is invented")
	check(preload("res://tests/staff_util.gd").roster().ROSTER.all(func(r: Array) -> bool: return preload("res://tests/staff_util.gd").surname(r[0]) != "Bakó"), "no roster surname Bakó")
	check(main.porter.path_offset == main._nav_offset, "porter uses the measured nav offset")
	check(main.porter.is_at_desk(), "porter starts at his desk")
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)

	# Lending.
	var labels: Array = porta.lendable_keys()
	check(labels.has("red") and labels.has("23") and not labels.has("14") and not labels.has("Igazgatói"), "lendable keys: open rooms + the red room, never 14, never closed rooms")
	var msg: String = porta.ask_key("23")
	check(p.has_item("key_23"), "borrowed key 23")
	check(porta.borrowed == ["23"], "borrowed list")
	check(porta.ask_key("14").contains("fourteen") or porta.ask_key("14").contains("Fourteen"), "no key for 14")
	check(not p.has_item("key_14"), "key 14 is never lent")
	check(porta.signed_out.has("23"), "key 23 is signed out with the time")
	check(porta.ask_key("red").contains("One key at a time") and not p.has_item("storage_key"), "only one key at a time")
	check(porta.ask_key("23").contains("already"), "the same key is not lent twice")
	porta.room_closed = func(_l: String) -> bool: return false
	check(porta.return_key().contains("still open") and p.has_item("key_23"), "an open room blocks the return")
	porta.room_closed = func(_l: String) -> bool: return true
	check(porta.return_key().contains("Signed back in") and not p.has_item("key_23") and porta.signed_out.is_empty(), "closed room: key signed back in")
	var events: Array = []
	main.campaign.event.connect(func(n: String, _d: Dictionary) -> void: events.append(n))
	for l in ["red", "24", "28", "33"]:
		porta.ask_key(l)
		check(p.has_item(PortaScript.key_item(l)), "borrowed " + l)
		porta.return_key()
	check(porta.borrowed.size() == 5 and events.has("key_collector"), "5 different keys: Key Collector")
	porta.ask_key("23")   # Stays signed out for the rest of the test.

	# Stealing: caught while he is at the desk.
	porta.away = false
	var caught_msg: String = porta.try_steal("14")
	check(caught_msg.contains("Put that back") and not p.has_item("key_14"), "caught at the desk")
	check(porta.board_locked_day == main.campaign.day, "board locked for the day")
	check(porta.ask_key("35").contains("locked"), "no lending while the board is locked")
	check(porta.try_steal("14").contains("locked"), "no stealing while the board is locked")
	# Next day: unlocked again (card must be valid: Task 7 sets this; here force it).
	main.campaign.start_day(2)
	await create_timer(0.3).timeout
	porta.card_valid = true
	porta.away = true                       # he stepped out
	check(porta.try_steal("14") != "" and p.has_item("key_14"), "stole key 14 while he was away")
	check(events.has("sticky_fingers"), "Sticky Fingers")
	check(main.get_node("KeyBoard").has_method("interact"), "board is interactable")

	# Distraction: once a day, the second try locks the board.
	main.campaign.start_day(3)
	await create_timer(0.3).timeout
	porta.card_valid = true
	check(p.has_item("key_14") and p.has_item("key_23") and porta.signed_out.has("23"), "stolen and signed out keys stay on you across days")   # Review Focus 3
	check(porta.distract().length() > 0 and porta.away, "distraction sends him away")
	await create_timer(0.1).timeout
	porta.away = false
	check(porta.distract().contains("believe") and porta.board_locked_day == main.campaign.day, "second distraction fails and locks the board")

	# Away windows at breaks 2, 4 and 6 (Review Focus 3: he is never stuck away).
	main.campaign.start_day(1)
	await create_timer(0.3).timeout
	check(main.porter.is_at_desk() and not porta.away, "a new day puts him back at the desk (was on a trip)")
	main._on_bell("lesson_end", 1)
	check(porta.away, "leaves at break 2")
	await create_timer(0.3).timeout
	porta.return_now()
	main._on_bell("lesson_end", 0)
	check(not porta.away, "no trip at break 1")
	# He walks to the WC and comes back on his own (short window for the test), never stuck away.
	main.porter.go_away(2.0, main._wc_point)
	porta.away = true
	await create_timer(14.0).timeout
	check(not porta.away, "he is back at the desk after the window")
	check(main.porter.global_position.distance_to(main.porter.desk_position) < 2.5, "and standing at his desk")
	# The key board and the desk are before the bake: the path from the porta door to the desk exists.
	var map: RID = main.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, main._room_centre(0, "Bejárat"), main.porter.desk_position, true)
	check(path.size() > 1, "the porter can reach his desk")
	var end: Vector3 = path[path.size() - 1] if path.size() > 0 else Vector3.INF
	check(Vector2(end.x - main._desk_position.x, end.z - main._desk_position.z).length() < 0.8, "the path really ends behind the desk (end %s)" % end)
	# The desk is carved out of the navmesh (built before the bake).
	var desk_centre: Vector3 = main._room_centre(0, "Porta") + Vector3(1.0, 0.05, -0.05)
	var closest := NavigationServer3D.map_get_closest_point(map, desk_centre)
	check(Vector2(closest.x - desk_centre.x, closest.z - desk_centre.z).length() > 0.3, "desk carved out of the navmesh")
	# A free strip of at least 1.0 m from the door to the desk (west half of the room, between board and desk).
	var c: Vector3 = main._room_centre(0, "Porta")
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.7, 3.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), Vector3(c.x - 0.6, 1.0, c.z - 0.2))
	var hits: Array = main.get_world_3d().direct_space_state.intersect_shape(q, 8)
	check(hits.is_empty(), "1 m free path from the door to the desk (hits %s)" % str(hits.map(func(h: Dictionary) -> String: return str(h.get("collider")))))

	# Review Focus 3: a porter stuck somewhere unreachable is put back at the desk.
	main.porter.return_limit = 2.0
	main.porter.go_away(0.2, main._wc_point)
	porta.away = true
	await create_timer(0.4).timeout
	main.porter.global_position = main._room_centre(0, "Büfé") + Vector3(0.0, 0.1, 0.0)   # inside a closed room next door
	await create_timer(3.5).timeout
	check(not porta.away and main.porter.global_position.distance_to(main.porter.desk_position) < 2.0, "stuck porter returns to his desk")
	main.porter.return_limit = 30.0

	# Review Focus 1: no borrowed or stolen key opens a demo-locked room.
	for l in porta.lendable_keys():
		porta.ask_key(l)
	check(porta.ask_key("Igazgatói").contains("no key") and not p.has_item("key_Igazgatói"), "no key for a closed room")
	porta.away = true
	check(porta.try_steal("Tanári").contains("no such") and not p.has_item("key_Tanári"), "no closed-room key on the board")
	porta.away = false
	var demo_doors := 0
	for door in get_nodes_in_group("doors"):
		if door.key_id == "__demo__":
			demo_doors += 1
			door.interact(p)
			check(door.locked and not door.is_open, "a demo door stays locked with every Porta key")
	check(demo_doors > 20, "demo doors checked: %d" % demo_doors)
	check(not p.has_item("__demo__") and not p.has_item("__after__"), "Porta never hands out a demo or after-hours key")

	# Review Focus 3: the board locked on the final day does not soft-lock the lab key. At night he dozes off.
	main.campaign.start_day(5)
	await create_timer(0.3).timeout
	p.remove_item("key_14")
	porta.away = false
	check(porta.try_steal("14").contains("Put that back") and porta.is_board_locked(), "caught on day 5: board locked")
	check(porta.distract().length() > 0 and porta.try_steal("14").contains("locked"), "still locked while he is away")
	main.daynight.night_fell.emit()
	await create_timer(0.3).timeout
	check(porta.asleep and not porta.is_board_locked(), "night: he dozes, the board is unguarded")
	check(porta.try_steal("14").contains("pocket") and p.has_item("key_14"), "key 14 can still be taken on the last night")
	check(porta.ask_key("23").contains("asleep"), "no lending while he sleeps")
	main.porter.interact(p)
	check(not main.choice_ui.visible, "his menu does not open while he sleeps")
	main.campaign.start_day(5)
	await create_timer(0.3).timeout
	check(not porta.asleep and not porta.away, "morning: awake at the desk")
	_cleanup(main)
	await create_timer(0.3).timeout

	# Day 1, fresh run: the menus, and Lab 14's finds (3 pages + the club photo) become reachable once key 14 is stolen.
	main = await _fresh()
	porta = main.porta
	p = main.player
	main.porter.interact(p)
	check(main.choice_ui.visible and main._porta_kind == "porta_menu", "E on the porter opens his menu")
	main.choice_ui.chosen.emit(0)
	check(main.choice_ui.visible and main._porta_kind == "porta_keys", "Ask for a key: the key list")
	main.choice_ui.chosen.emit(main._porta_labels.find("23"))
	check(not main.choice_ui.visible and p.has_item("key_23") and p.controls_enabled, "picking 23 lends it, controls back")
	# Only number keys 1-9 pick from a list: with 38 options a letter (E = KEY_1 + 20, A, D, S) must not choose anything.
	var picks: Array = []
	var on_pick := func(i: int) -> void: picks.append(i)
	main.choice_ui.chosen.connect(on_pick)
	main.get_node("KeyBoard").interact(p)
	for code in [KEY_E, KEY_A, KEY_D, KEY_S, KEY_W, KEY_0]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = true
		main.choice_ui._unhandled_input(ev)
	check(picks.is_empty() and main.choice_ui.visible and not porta.is_board_locked(), "letters never pick from the key board (picked %s)" % str(picks))
	var one := InputEventKey.new()
	one.keycode = KEY_1
	one.pressed = true
	main.choice_ui.chosen.disconnect(on_pick)
	main.choice_ui.chosen.connect(on_pick)
	main.choice_ui._unhandled_input(one)
	check(picks == [0], "KEY_1 picks option 0 (picked %s)" % str(picks))
	main.choice_ui.chosen.disconnect(on_pick)
	porta.board_locked_day = 0   # That pick was a board steal in front of him (caught); reset for the rest of day 1.
	p.remove_item("key_" + main._porta_labels[0])
	main.porter.interact(p)
	main.choice_ui.chosen.emit(5)   # Leave the porter menu.
	# "Leave" on both lists: no key, no lock, nothing caught (an accidental E on the board in front of him is harmless).
	var front: Vector3 = main._room_centre(0, "Porta") + Vector3(-0.6, 0.1, -0.9)   # in the lodge, facing the desk
	p.global_position = front
	await create_timer(0.2).timeout
	var inv_before: int = _item_count(p)
	main.get_node("KeyBoard").interact(p)
	check(main.choice_ui._count == main._porta_labels.size() + 1, "the board list ends with Leave")
	main.choice_ui.chosen.emit(main._porta_labels.size())
	check(not main.choice_ui.visible and not porta.is_board_locked() and _item_count(p) == inv_before and p.controls_enabled, "Leave on the board: no key, no lock")
	main.porter.interact(p)
	main.choice_ui.chosen.emit(0)
	check(main.choice_ui._count == main._porta_labels.size() + 1, "the key list ends with Leave")
	main.choice_ui.chosen.emit(main._porta_labels.size())
	check(not main.choice_ui.visible and not porta.is_board_locked() and _item_count(p) == inv_before, "Leave on the key list: nothing lent")

	var lab_door: Node = main.quest.lab_door
	check(lab_door.key_id == "key_14" and lab_door.locked, "lab door needs key 14")
	var lab_finds: Array = []
	for n in get_nodes_in_group("find"):
		var e: Dictionary = Finds.entry(n.item_id)
		if e.get("room", "") == "14":
			lab_finds.append(n)
	check(lab_finds.size() == 4, "lab 14 holds 3 pages + the photo (got %d)" % lab_finds.size())
	lab_door.interact(p)
	check(lab_door.locked, "locked on day 1 without the key")
	porta.distract()   # He goes to look at the "leak".
	check(porta.away and main.porter._station == main._wc_point, "the porter walks to the WC")
	check(porta.ask_key("24").contains("Nobody") and porta.distract().contains("Nobody") and not porta.is_board_locked(), "no lending or second distraction while he is away")
	await create_timer(0.5).timeout
	check(main._porter_sees_player(), "0.5 s later he is still in the lodge and sees the board")
	var waited := 0.0
	while main._porter_sees_player() and waited < 20.0:
		await create_timer(0.25).timeout
		waited += 0.25
	check(not main._porter_sees_player() and porta.away, "he is out of sight within the window (%.1f s)" % waited)
	main.get_node("KeyBoard").interact(p)
	check(main._porta_labels.back() == "red", "the key board ends with the red room")
	main.choice_ui.chosen.emit(main._porta_labels.find("14"))
	check(p.has_item("key_14") and main._message_label.text.contains("pocket"), "stolen from the board on day 1 once he is out of sight")
	lab_door.interact(p)
	check(not lab_door.locked, "the stolen key opens Lab 14")
	map = main.get_world_3d().navigation_map
	for n in lab_finds:
		check(n.visible and n.collision_layer == 16 and not n.is_in_group("story"), "%s active on day 1" % n.item_id)
		var spot: Vector3 = n.global_position
		var fp := NavigationServer3D.map_get_path(map, main._spawn_point, Vector3(spot.x, 0.05, spot.z), true)
		var fend: Vector3 = fp[fp.size() - 1] if fp.size() > 0 else main._spawn_point
		check(fend.y < 1.5 and Vector2(fend.x - spot.x, fend.z - spot.z).length() < 1.5, "%s reachable (end %s)" % [n.item_id, fend])
		n.interact(p)
		check(main.finds.found.has(n.item_id), "%s taken on day 1" % n.item_id)
	# Day 2: right after the distraction he is still in the lodge: a pick is caught (spec: within 6 m with line of sight),
	# and he will not chat for the rest of the day.
	main.campaign.start_day(2)
	await create_timer(0.3).timeout
	porta.card_valid = true
	p.global_position = front
	await create_timer(0.2).timeout
	check(porta.distract().contains("leak") and porta.away, "distracted on day 2")
	await create_timer(0.5).timeout
	main.get_node("KeyBoard").interact(p)
	check(main.choice_ui.visible and main._porta_kind == "porta_board" and main._porta_labels.has("14") and main._porta_labels.back() == "red", "the key board lists 14 before the red room")
	main.choice_ui.chosen.emit(main._porta_labels.find("35"))
	check(not p.has_item("key_35") and main._message_label.text.contains("Mr. Bakó: Put that back") and porta.is_board_locked(), "caught right after the distraction (away is not enough), he says it out loud")
	main.porter.return_to_desk(true)
	await create_timer(0.2).timeout
	main.porter.interact(p)
	main.choice_ui.chosen.emit(2)
	check(main._message_label.text.contains("Not today"), "he refuses to chat after catching you")
	main._open_accusation()
	check(not main.choice_ui.visible, "no overlay stacking")
	_cleanup(main)
