extends SceneTree
## Task 10: the whole demo end to end through the real scene API (day 1 story, lessons, days 2-3, hunt, ending),
## plus a second run that skips the sticker and still finishes by stealing.
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
const Lessons := preload("res://scripts/lessons.gd")
const Rooms := preload("res://scripts/rooms.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const Finds := preload("res://scripts/finds.gd")
const Tasks := preload("res://scripts/tasks.gd")

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

func _live(group: String) -> int:
	var n := 0
	for t in get_nodes_in_group(group):
		if not t.is_queued_for_deletion():
			n += 1
	return n

func _pickup(id: String) -> Node:
	for p in get_nodes_in_group("pickup"):
		if p.item_id == id and not p.is_queued_for_deletion():
			return p
	return null

## Type of the room (by its own rect, so duplicate labels are fine) that holds `pos`, or "" outside every room.
func _room_type_at(pos: Vector3) -> String:
	var f := clampi(roundi(pos.y / 4.0 - 0.2), 0, FloorData.FLOORS.size() - 1)
	var data: Dictionary = FloorData.FLOORS[f]
	for room: Array in data["rooms"]:
		var a: Vector2 = (Vector2(room[1], room[2]) - data["origin"]) * data["scale"]
		var b: Vector2 = (Vector2(room[3], room[4]) - data["origin"]) * data["scale"]
		if Rect2(a, b - a).abs().has_point(Vector2(pos.x, pos.z)):
			return Rooms.type_of(room[0])
	return ""

## Sample-point invariants (Review Focus 1, 2 and the caps).
func _invariants(main: Node, at: String) -> void:
	var demo := 0
	for key: String in main._room_doors:
		var door: Node = main._room_doors[key]
		if Rooms.type_of(key.split(":")[1]) == "other":
			demo += 1
			if not (door.locked and door.key_id == "__demo__" and not door.master_key_ok and not door.is_open):
				check(false, "%s: other door %s is demo-locked" % [at, key])
	check(demo > 20, "%s: demo doors checked (%d)" % [at, demo])
	var objects: Array = []
	for g in ["story", "find", "item", "mecha", "form", "clue"]:
		for n in get_nodes_in_group(g):
			if not n.is_queued_for_deletion():
				objects.append(n)
	objects.append_array([main._fuse_box, main._safe, main._altar, main._vial])
	for n in objects:
		if is_instance_valid(n) and _room_type_at(n.global_position) == "other":
			check(false, "%s: %s sits in a closed room" % [at, n.name if not "item_id" in n else n.item_id])
	var teachers := _live("teachers") + _live("ambient_staff")
	check(teachers <= 16 and _live("ambient_staff") <= 8 and main.crowd.shown_count() <= 150,
			"%s: caps hold (teachers %d, ambient %d, crowd %d)" % [at, teachers, _live("ambient_staff"), main.crowd.shown_count()])
	check(_live("csoki") == 1 and _live("porta") == 1, "%s: one Csoki (%d), one porter (%d)" % [at, _live("csoki"), _live("porta")])

func _attend(main: Node, i: int) -> void:
	var subject: String = Lessons.subject_at(main.campaign.day, i)
	var room: String = Lessons.room_of(subject)
	check(Rooms.is_open(room), "day %d lesson %d room %s is open" % [main.campaign.day, i, room])
	main.player.global_position = main._room_centre(Lessons.floor_of(subject), room) + Vector3(0, 0.1, 0)
	await create_timer(0.1).timeout
	check(main._player_in_room(subject), "in the room of %s" % subject)
	main.daynight.minutes = Campaign.lesson_start(i) + 0.5
	await create_timer(0.25).timeout
	check(main.lesson_ui.visible and main.choice_ui.visible, "day %d lesson %d: quiz opened" % [main.campaign.day, i])
	for q in 3:
		main.choice_ui.chosen.emit(main.lesson_ui._questions[main.lesson_ui._index][2])
	await create_timer(0.15).timeout

func _take_clues(main: Node) -> void:
	for c in get_nodes_in_group("clue"):
		if not c.is_queued_for_deletion():
			c.interact(main.player)

func _home(main: Node) -> void:
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.daynight.minutes = maxf(main.daynight.minutes, Campaign.LAST_BELL + 1.0)
	await create_timer(0.15).timeout
	main.get_node("FrontDoor").interact(main.player)
	await create_timer(0.3).timeout

## Stand in front of the board and wait until the porter (sent away) is out of sight, then pick `label` on the board UI.
func _steal(main: Node, label: String) -> bool:
	main.player.global_position = main._room_centre(0, "Porta") + Vector3(-0.6, 0.1, -0.9)
	var waited := 0.0
	while (main._porter_sees_player() or not main.porta.away) and waited < 25.0:
		await create_timer(0.25).timeout
		waited += 0.25
	main.get_node("KeyBoard").interact(main.player)
	if main._porta_kind != "porta_board":
		return false
	main.choice_ui.chosen.emit(main._porta_labels.find(label))
	return main.player.has_item(main.porta.key_item(label))

## Day 4 accusation, then the hunt chain through the fixed story rooms. `borrow`: the red key comes from the porter.
func _hunt(main: Node, borrow: bool) -> void:
	var p: Node = main.player
	var quest: Node = main.quest
	check(main.choice_ui.visible and main._accusing, "day 4: accusation opens")
	main.choice_ui.chosen.emit(main.TEACHER_ORDER.find(main.campaign.culprit))
	await create_timer(0.3).timeout
	check(main.campaign.hunt_active, "culprit named, the hunt is on")
	main.entity.sleep()
	_invariants(main, "hunt day %d" % main.campaign.day)
	if borrow:
		main.porter.interact(p)
		main.choice_ui.chosen.emit(0)
		main.choice_ui.chosen.emit(main._porta_labels.find("red"))
		check(p.has_item("storage_key") and main._message_label.text.contains("storage room"), "borrowed the red room key")
	check(p.has_item("storage_key"), "holding the red room key")
	var red_door: Node = main._room_doors["%d:%s" % [quest.red_room_floor, quest.red_room_label]]
	check(red_door.locked, "red room locked")
	red_door.interact(p)
	check(not red_door.locked and quest.red_room_opened, "red room opened with the key")
	var salt := _pickup("salt")
	var fuse := _pickup("fuse")
	check(salt != null and salt.visible and fuse != null and fuse.visible, "salt and fuse on the red room table")
	check(_room_type_at(salt.global_position) != "other" and _room_type_at(salt.global_position) != "", "red room is an open room")
	salt.interact(p)
	fuse.interact(p)
	check(p.has_item("salt") and p.has_item("fuse"), "took salt and fuse")
	var vial: Node = main._vial
	check(not vial.visible and vial.collision_layer == 0, "vial waits for the fuse")
	check(FloorData.room_rect(0, Rooms.STORY_ROOMS["fuse"]).has_point(Vector2(main._fuse_box.global_position.x, main._fuse_box.global_position.z)), "fuse box in room 24")
	main._fuse_box.interact(p)
	check(quest.fuse_placed and not p.has_item("fuse"), "fuse in the fuse box")
	await create_timer(0.1).timeout
	check(vial.visible and vial.collision_layer == 16, "vial available after the fuse")
	if quest.lab_door.locked:
		quest.lab_door.interact(p)
	check(not quest.lab_door.locked, "lab open")
	vial.interact(p)
	check(p.has_item("vial"), "took the holy water")
	for i in 4:
		var note := _pickup("note_%d" % i)
		check(note != null and note.visible, "note %d there" % i)
		if note:
			note.interact(p)
	check(quest.notes_found.all(func(b: bool) -> bool: return b), "all four notes")
	check(FloorData.room_rect(2, Rooms.STORY_ROOMS["safe"]).has_point(Vector2(main._safe.global_position.x, main._safe.global_position.z)), "safe in room 229")
	main._safe.interact(p)
	check(main._code_open, "safe code lock opens")
	for d: int in quest.code + [-1]:
		var ev := InputEventKey.new()
		ev.keycode = (KEY_0 + d) if d >= 0 else KEY_ENTER
		ev.pressed = true
		main._handle_code_input(ev)
	check(quest.safe_open and p.has_item("bell") and not main._code_open, "safe opened, bell taken")
	main._altar.interact(p)
	check(quest.altar_items.values().all(func(b: bool) -> bool: return b), "salt, water and bell on the altar")

func _run() -> void:
	var main: Node = await _fresh()
	var p: Node = main.player
	var porta: Node = main.porta
	_invariants(main, "day 1 start")

	# --- Day 1 story ------------------------------------------------------------
	check(main._message_label.text == Tasks.OPENING, "opening shown")
	check(main.tasks.lines(1)[0] == Tasks.OPENING, "opening is the first task line")
	# Stamina: sprinting drains it, resting refills it.
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await create_timer(1.5).timeout
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	var low: float = p.stamina
	check(low < p.STAMINA_MAX - 15.0, "stamina drains while sprinting (%.1f)" % low)
	await create_timer(2.5).timeout
	check(p.stamina > low + 10.0, "stamina refills after resting (%.1f -> %.1f)" % [low, p.stamina])
	p.global_position = main._spawn_point
	# The sticker: ask, find the form, give it.
	main.porter.interact(p)
	main.choice_ui.chosen.emit(3)
	check(main._message_label.text.contains("signed form") and main._message_label.text.contains("1st floor"), "the porter wants the signed form from the 1st floor")
	check(main.tasks.lines(1).any(func(l: String) -> bool: return l.contains("1st floor")), "tasks say where the form is")
	check(main.quest.hint().contains("Ask the porter"), "valid card: ask the porter for the red key")
	var form: Node = get_nodes_in_group("form")[0]
	check(Rooms.is_open(main._form_room_label), "form in an open room")
	form.interact(p)
	main.porter.interact(p)
	main.choice_ui.chosen.emit(3)
	check(porta.card_renewed and main.tasks.is_done("card"), "card renewed with the form")
	# Take a key.
	main.porter.interact(p)
	main.choice_ui.chosen.emit(0)
	main.choice_ui.chosen.emit(main._porta_labels.find("23"))
	check(p.has_item("key_23"), "borrowed key 23")
	# Lessons 1-2; the break-2 bell starts the day-1 glimpse and sends the porter to the WC.
	await _attend(main, 0)
	main.entity.sleep()
	await _attend(main, 1)
	await create_timer(0.3).timeout
	check(main.entity.visible, "day-1 glimpse after lesson 2")
	check(main.scare.npcs_hidden and _live("teachers") > 0 and get_nodes_in_group("teachers").all(func(t: Node) -> bool: return not t.visible),
			"scare flash during the glimpse hides the teachers")
	check(main.crowd.hidden and not main.csoki.visible and not main.porter.visible, "crowd, Csoki and the porter hidden too")
	check(porta.away, "break 2: the porter walks to the WC")
	check(await _steal(main, "14"), "stole key 14 while he was away")
	check(porta.stolen_14, "key 14 stolen")
	await create_timer(7.0).timeout   # The glimpse ends, the NPCs come back.
	check(not main.entity.visible and not main.scare.npcs_hidden, "glimpse over, NPCs restored")
	check(get_nodes_in_group("teachers").all(func(t: Node) -> bool: return t.visible) and main.csoki.visible and not main.crowd.hidden, "teachers, Csoki and crowd visible again")
	_invariants(main, "day 1 break 2")
	# Lab 14 and its pages.
	var lab_door: Node = main.quest.lab_door
	lab_door.interact(p)
	check(not lab_door.locked, "key 14 opens Lab 14")
	for id in ["lab1", "lab2", "lab3", "photo"]:
		var n := _pickup(id)
		check(n != null and n.visible, "%s in the lab" % id)
		if n:
			n.interact(p)
	check(main.tasks.is_done("lab"), "lab task done after the three pages")
	# At least one find of each kind.
	for n in get_nodes_in_group("find"):
		if Finds.kind_of(n.item_id) == "card" and not n.is_queued_for_deletion():
			n.interact(p)
			break
	var kinds := {}
	for id: String in main.finds.found:
		kinds[Finds.kind_of(id)] = true
	check(kinds.has("page") and kinds.has("secret") and kinds.has("card"), "a find of each kind read: %s" % str(kinds.keys()))
	check(main.finds.count("page") + main.finds.count("secret") + main.finds.count("card") == main.finds.found.size() and main.finds.found.size() == 5, "five finds, each counted once (%d)" % main.finds.found.size())
	# A biscuit for Csoki, and the day's neu_mecha figure.
	for it in get_nodes_in_group("item"):
		if it.kind == "biscuit" and not it.is_queued_for_deletion():
			it.interact(p)
			break
	check(p.has_item("biscuit"), "took a biscuit")
	main.csoki.interact(p)
	check(main.csoki.is_following and not p.has_item("biscuit"), "Csoki fed and following")
	var figs := get_nodes_in_group("mecha")
	check(figs.size() == 1, "one mecha figure on day 1")
	figs[0].interact(p)
	check(main.mecha.found_count() == 1, "mecha figure taken")
	# Fail one steal: he is back at his desk and sees the board. The board stays locked for the rest of the day.
	main.porter.return_to_desk(true)
	await create_timer(0.3).timeout
	check(not porta.away, "porter back at the desk")
	p.global_position = main._room_centre(0, "Porta") + Vector3(-0.6, 0.1, -0.9)
	await create_timer(0.1).timeout
	main.get_node("KeyBoard").interact(p)
	main.choice_ui.chosen.emit(main._porta_labels.find("35"))
	check(main._message_label.text.contains("Put that back") and porta.is_board_locked() and not p.has_item("key_35"), "caught at the board")
	# The rest of the day's lessons.
	for i in range(2, 7):
		await _attend(main, i)
		main.entity.sleep()
	check(main.campaign.attended == 7 and main.campaign.skipped == 0, "day 1: all seven lessons attended")
	_take_clues(main)
	await _home(main)

	# --- Days 2 and 3 -------------------------------------------------------------
	check(main.campaign.day == 2 and porta.card_valid, "day 2: card valid")
	check(not porta.is_board_locked(), "the board lock was only for day 1")
	check(main.mecha.posts().size() == 2 and _live("mecha") == 1, "day 2: mecha post 2")
	_invariants(main, "day 2")
	for d in [2, 3]:
		check(main.campaign.day == d, "day %d" % d)
		for i in 7:
			await _attend(main, i)
			main.entity.sleep()
		_take_clues(main)
		await _home(main)
	check(main.campaign.day == 4 and main.campaign.clues.size() == 9, "day 4 with %d clues" % main.campaign.clues.size())
	check(main.campaign.skipped == 0 and main.campaign.attended == 21, "21 lessons attended")
	check(p.stamina > 0.0 and not p.exhausted, "not exhausted at day 4")

	# --- Day 4 hunt, day 5 ritual --------------------------------------------------
	await _hunt(main, true)
	main.daynight.minutes = 1321.0
	await create_timer(0.4).timeout
	check(main.campaign.day == 5 and main.campaign.ending_id == 0, "day 5")
	main.entity.sleep()
	main.daynight.is_night = true
	main._altar.interact(p)
	check(main.choice_ui.visible, "day 5 altar prompt")
	main.choice_ui.chosen.emit(0)
	await create_timer(0.1).timeout
	check(main.quest.ritual_active, "ritual started")
	main.quest.ritual_left = 0.05
	await create_timer(0.5).timeout
	var expected := 4 if main.campaign.clues.size() == 9 and main.campaign.quiz_ratio() >= 0.8 else 2
	check(main.ending_screen.current_id == expected and main.campaign.ending_id == expected, "ending %d (got %d)" % [expected, main.ending_screen.current_id])
	print("RUN 1: clues=%d quiz=%d/%d finds=%d mecha=%d ending=%d" % [main.campaign.clues.size(), main.campaign.right,
			main.campaign.total, main.finds.found.size(), main.mecha.found_count(), main.ending_screen.current_id])
	_cleanup(main)
	await create_timer(0.3).timeout

	# --- Second run: no sticker. Day 2 refuses, stealing still finishes the story ----------
	main = await _fresh()
	p = main.player
	porta = main.porta
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	await _home(main)
	check(main.campaign.day == 2 and not porta.card_valid, "day 2: card expired without the sticker")
	check(main._message_label.text.contains("expired"), "day 2 expiry message")
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	check(porta.ask_key("23").contains("expired") and porta.ask_key("red").contains("expired"), "no lending on day 2")
	check(porta.ask_sticker().contains("expired"), "no sticker on day 2")
	check(main.quest.hint().contains("board"), "expired card: the hint points to the board, not the porter")
	main.porter.interact(p)
	main.choice_ui.chosen.emit(1)   # "There is a leak in the WC"
	check(porta.away, "distraction works without a card")
	check(await _steal(main, "red"), "stole the red room key")
	check(porta.try_steal("14").contains("pocket") and p.has_item("key_14"), "stole key 14")
	await _home(main)
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	await _home(main)
	check(main.campaign.day == 4 and not porta.card_valid, "day 4, card still expired")
	await _hunt(main, false)
	main.daynight.minutes = 1321.0
	await create_timer(0.4).timeout
	main.entity.sleep()
	main.daynight.is_night = true
	main._altar.interact(p)
	main.choice_ui.chosen.emit(0)
	await create_timer(0.1).timeout
	main.quest.ritual_left = 0.05
	await create_timer(0.5).timeout
	check(main.campaign.ending_id in [2, 4], "run 2 ends with the ritual (ending %d)" % main.campaign.ending_id)
	_cleanup(main)
	await create_timer(0.3).timeout
