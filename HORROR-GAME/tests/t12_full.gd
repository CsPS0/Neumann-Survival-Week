extends SceneTree
var fails := 0
var cur: Node
const QuizUtil := preload("res://tests/quiz_util.gd")
const PROFILE := "user://neu_test_t12.cfg"
const Campaign := preload("res://scripts/campaign.gd")
const Lessons := preload("res://scripts/lessons.gd")

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)

func _initialize() -> void:
	await _run()
	DirAccess.remove_absolute(PROFILE)
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

func _fresh(day := 1) -> Node:
	if cur:
		cur.queue_free()
		await create_timer(0.3).timeout
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = PROFILE   # before any save; the real profile.cfg is never written
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	cur = main
	if day != 1:
		main.campaign.start_day(day)
		await create_timer(0.3).timeout
	return main

func _into_room(main: Node, i: int) -> void:
	var subject: String = Lessons.subject_at(main.campaign.day, i)
	main.player.global_position = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject)) + Vector3(0, 0.1, 0)

## Real quiz flow: stand in the room inside the 2-minute grace window, answer on the paper sheet.
func _attend(main: Node, i: int, right := true) -> void:
	_into_room(main, i)
	await create_timer(0.1).timeout
	main.daynight.minutes = Campaign.lesson_start(i) + 0.5
	await create_timer(0.25).timeout
	check(QuizUtil.is_open(main), "day %d lesson %d: quiz opened" % [main.campaign.day, i])
	QuizUtil.answer_all(main, right)
	await create_timer(0.15).timeout

func _accuse(main: Node, right := true) -> void:
	if not main._accusing:
		main._open_accusation()   # the G key; day 5 does not auto-open it
	if not main._accusing:
		main._open_accusation()   # the G key; day 5 does not auto-open it
	var idx: int = main.TEACHER_ORDER.find(main.campaign.culprit)
	main.choice_ui.chosen.emit(idx if right else (idx + 1) % 4)
	await create_timer(0.25).timeout

func _expect(main: Node, id: int, what: String) -> void:
	await create_timer(0.4).timeout
	check(main.ending_screen.current_id == id and main.campaign.ending_id == id,
			"ending %d (%s): screen %d campaign %d" % [id, what, main.ending_screen.current_id, main.campaign.ending_id])

func _catch(main: Node) -> void:
	main.entity.encounter(true, main.player.global_position + Vector3(0.5, 0, 0), 5.0)
	await create_timer(0.8).timeout

func _ritual(main: Node) -> void:
	main.quest.altar_items = {"salt": true, "vial": true, "bell": true}
	main.daynight.is_night = true
	main.quest.altar_interact(main.player)

## The finished ritual asks cure or destroy: 0 cures the teacher (ending 2 or 4), 1 destroys the host (ending 9).
func _fate(main: Node, pick := 0) -> void:
	await create_timer(0.3).timeout
	check(main._fate_open and main.choice_ui.visible, "ritual done: cure or destroy prompt")
	main.choice_ui.chosen.emit(pick)

func _home(main: Node) -> void:
	main.get_node("FrontDoor").interact(main.player)
	await create_timer(0.3).timeout

func _run() -> void:
	# (a) Days 1-3 are non-lethal: a chase catch blacks out, never ends the run.
	var m: Node = await _fresh()
	for d in 3:
		if d > 0:
			m.campaign.start_day(d + 1)
			await create_timer(0.3).timeout
		check(not m.campaign.lethal(), "day %d not lethal" % (d + 1))
		await _catch(m)
		check(m.campaign.ending_id == 0 and not m.ending_screen.visible, "day %d catch is no ending" % (d + 1))
		check(m.campaign.blackouts == d + 1, "day %d blackout counted" % (d + 1))
		check(m.player.controls_enabled, "day %d player wakes up" % (d + 1))

	# (b)-(e) Day 1 through the real scene flow.
	m = await _fresh()
	await _attend(m, 0)
	check(m.campaign.attended == 1 and m.campaign.right == 3 and m.campaign.total == 3, "quiz 3/3 recorded")
	check(m.daynight.minutes >= Campaign.lesson_end(0), "clock jumped to the end of lesson 1")
	check(m.player.controls_enabled and not m.choice_ui.visible, "back in control after the quiz")
	m.entity.sleep()
	# (c) Lesson 2 on day 1: the campaign's own lesson_end bell starts the glimpse.
	await _attend(m, 1)
	check(m.campaign.attended == 2 and not m.campaign.incident, "lesson 2 attended")
	await create_timer(0.3).timeout   # the bell fires from campaign._process; nobody calls _on_bell
	check(m.entity.visible, "day-1 glimpse: entity visible")
	check(m.entity.process_mode == Node.PROCESS_MODE_DISABLED, "day-1 glimpse: entity frozen")
	check(m.campaign.blackouts == 0, "glimpse cannot catch")
	await create_timer(6.3).timeout
	check(not m.entity.visible, "glimpse: entity sleeps again")
	# (d) After the last bell: caretaker walks, going home starts day 2.
	m.campaign._resolved.fill(true)
	m.campaign._ended.fill(true)
	m.daynight.minutes = 860.0
	await create_timer(0.15).timeout
	check(get_nodes_in_group("caretaker").size() == 1, "caretaker spawned after the last bell")
	await _home(m)
	check(m.campaign.day == 2, "went home: day 2")
	check(get_nodes_in_group("caretaker").is_empty(), "caretaker gone on day 2")
	var teachers := get_nodes_in_group("teachers")
	check(teachers.size() == 8, "8 teachers respawned")
	for t in teachers:
		check(not t.is_queued_for_deletion(), "respawned teacher is live")
	# (e) Day 4: accusation opens, correct accusation reveals the story items.
	m.campaign.start_day(4)
	await create_timer(0.3).timeout
	check(m.choice_ui.visible and m._accusing, "day 4: accusation opens")
	for item in get_nodes_in_group("story"):
		check(not item.visible, "story item hidden before the accusation")
	await _accuse(m)
	check(m.campaign.hunt_active and m.campaign.lethal(), "correct accusation: hunt begins, lethal")
	var story := get_nodes_in_group("story")
	check(not story.is_empty(), "story items exist")
	for item in story:
		if item.item_id == "vial":   # Task 7: the holy water also needs the fuse in the fuse box.
			check(not item.visible and item.collision_layer == 0 and not m.quest.fuse_placed, "vial waits for the fuse")
			continue
		check(item.visible and item.collision_layer == 16, "story item revealed")
	for t in get_nodes_in_group("teachers"):
		check(t.npc_id != m.campaign.culprit, "culprit teacher is gone")

	# (f) Every ending through the real scene triggers.
	# 1: killed, day 4 and day 5.
	for d in [4, 5]:
		m = await _fresh(d)
		await _accuse(m)
		await _catch(m)
		await _expect(m, 1, "killed on day %d" % d)
	# 2: ritual on day 4 with a low quiz.
	m = await _fresh(4)
	await _accuse(m)
	await _ritual(m)
	check(m.quest.ritual_active, "day 4 ritual started")
	m.quest.ritual_left = 0.05
	await _fate(m)
	await _expect(m, 2, "ritual, low quiz")
	# 9: the same ritual, but the host is destroyed.
	m = await _fresh(4)
	await _accuse(m)
	await _ritual(m)
	m.quest.ritual_left = 0.05
	await _fate(m, 1)
	await _expect(m, 9, "ritual, destroy the host")
	# 3: caretaker catch, 22:00 inside, six skips.
	m = await _fresh()
	m.campaign._resolved.fill(true)
	m.campaign._ended.fill(true)
	m.daynight.minutes = 860.0
	await create_timer(0.15).timeout
	var care: Node = get_first_node_in_group("caretaker")
	check(care != null, "caretaker present")
	if care:
		care.global_position = m.player.global_position + Vector3(0.6, 0, 0)
	await _expect(m, 3, "caretaker catch")
	m = await _fresh()
	m.campaign._resolved.fill(true)
	m.campaign._ended.fill(true)
	m.daynight.minutes = 1321.0
	await _expect(m, 3, "22:00 inside on a school day")
	m = await _fresh()
	m.campaign.incident = true   # No day 1 explosion: the lessons have to be skipped for real.
	m.daynight.minutes = Campaign.lesson_start(5) + 3.0
	await _expect(m, 3, "six skipped lessons")
	check(m.campaign.skipped == 6, "six skips counted")
	# 4: ritual on day 5 with a perfect quiz and all 9 clues, via the pact prompt.
	m = await _fresh(5)
	await _accuse(m)
	m.campaign.right = 21
	m.campaign.total = 21
	for i in 9:
		m.campaign.clues.append("c%d" % i)
	await _ritual(m)
	check(m.choice_ui.visible, "day 5 altar prompt")
	m.choice_ui.chosen.emit(0)
	await create_timer(0.1).timeout
	check(m.quest.ritual_active, "day 5 ritual started")
	m.quest.ritual_left = 0.05
	await _fate(m)
	await _expect(m, 4, "ritual, quiz >= 0.8 and 9 clues")
	# 5: front door in the middle of the day.
	m = await _fresh()
	await _home(m)
	await _expect(m, 5, "front door mid-day")
	# 6: deal at the day-5 altar.
	m = await _fresh(5)
	await _accuse(m)
	m.quest.altar_interact(m.player)
	await create_timer(0.1).timeout
	check(m.choice_ui.visible, "altar offers the deal")
	m.choice_ui.chosen.emit(0)
	await _expect(m, 6, "deal at the altar")
	# 7: 22:00 on day 5.
	m = await _fresh(5)
	m.daynight.minutes = 1321.0
	await _expect(m, 7, "22:00 on day 5")
	# 8: wrong accusation.
	m = await _fresh(4)
	await _accuse(m, false)
	await _expect(m, 8, "wrong accusation")

	# Full-week smoke run with perfect answers, clues by real pickup, accuse, ritual on day 5. Day 1 ends with the
	# explosion after lesson 3 (4 to 7 are cancelled), day 3 is the test day with 4 questions per lesson.
	m = await _fresh()
	var lessons_done := 0
	var answers_right := 0
	for d in 3:
		check(m.campaign.day == d + 1, "smoke: day %d" % (d + 1))
		var today := 3 if d == 0 else 7
		for i in today:
			await _attend(m, i)
			m.entity.sleep()   # the scripted break chases would otherwise catch the teleporting player
		lessons_done += today
		answers_right += today * (4 if d == 2 else 3)
		if d == 0:
			check(m.campaign.incident, "smoke: the explosion happened after lesson 3")
		check(m.campaign.attended == lessons_done and m.campaign.right == answers_right and m.campaign.total == answers_right, "smoke: day %d quiz totals" % (d + 1))
		check(m.campaign.skipped == 0 and m.campaign.blackouts == 0, "smoke: nothing skipped or lost")
		var day_clues := get_nodes_in_group("clue")
		check(day_clues.size() == 3, "smoke: 3 clues on day %d" % (d + 1))
		for c in day_clues:
			c.interact(m.player)
		await _home(m)
	check(m.campaign.day == 4 and m.campaign.clues.size() == 9, "smoke: day 4 with %d clues" % m.campaign.clues.size())
	check(m.choice_ui.visible and m._accusing, "smoke: accusation open on day 4")
	await _accuse(m)
	check(m.campaign.hunt_active, "smoke: culprit named")
	m.daynight.minutes = 1321.0   # day 4 closes at 22:00 and day 5 begins
	await create_timer(0.4).timeout
	check(m.campaign.day == 5 and m.campaign.ending_id == 0, "smoke: day 5")
	await _ritual(m)
	check(m.choice_ui.visible, "smoke: day 5 altar prompt")
	m.choice_ui.chosen.emit(0)
	await create_timer(0.1).timeout
	m.quest.ritual_left = 0.05
	await _fate(m)
	await create_timer(0.5).timeout
	var expected := 4 if m.campaign.clues.size() == 9 and m.campaign.quiz_ratio() >= 0.8 else 2
	print("SMOKE: clues=%d quiz=%d/%d ending=%d" % [m.campaign.clues.size(), m.campaign.right, m.campaign.total, m.ending_screen.current_id])
	check(m.ending_screen.current_id == expected, "smoke: ending %d expected, got %d" % [expected, m.ending_screen.current_id])
	check(m.campaign.clues.size() == 9, "smoke: all 9 clues found")
	if cur:
		cur.queue_free()
		await create_timer(0.3).timeout
