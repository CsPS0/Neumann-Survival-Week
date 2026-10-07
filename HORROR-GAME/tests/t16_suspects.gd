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

const Lessons := preload("res://scripts/lessons.gd")
const Clues := preload("res://scripts/clues.gd")
static var Staff: GDScript = preload("res://scripts/staff_source.gd").roster()
const SU := preload("res://tests/staff_util.gd")

func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	return main

func _find(id: String) -> Node:
	for p in get_nodes_in_group("pickup"):
		if p.item_id == id:
			return p
	return null

func _run() -> void:
	check(Lessons.TEACHER_NAMES.size() == 8 and Lessons.SUSPECT_IDS.size() == 8, "8 suspects")
	var surnames := {}
	for p: Array in Staff.ROSTER:
		surnames[SU.surname(p[0])] = true
	for id: String in Lessons.SUSPECT_IDS:
		var name: String = Lessons.TEACHER_NAMES[id]
		check(not SU.is_real_name(name), "%s is not a roster name" % name)
		check(not surnames.has(SU.surname(name)), "%s shares no surname with the roster" % name)
		var seen := {}
		for k in 9:
			var t := Clues.text(id, k)
			check(t != "", "%s clue %d" % [id, k])
			seen[t] = true
		check(seen.size() == 9, id + " has 9 distinct clues")
		check(Clues.chat(id).begins_with(name + ":"), id + " small talk is in the suspect's own name")
	for a: String in Lessons.SUSPECT_IDS:
		for b: String in Lessons.SUSPECT_IDS:
			if a != b:
				for k in 9:
					check(Clues.text(a, k) != Clues.text(b, k), "clue %d differs between %s and %s" % [k, a, b])
	for day in range(1, 4):
		for lesson in 7:
			var subject: String = Lessons.subject_at(day, lesson)
			check(Lessons.SUSPECT_IDS.has(Lessons.teacher_of(subject, day)), "day %d lesson %d is taught by a suspect" % [day, lesson])
	check(Lessons.teacher_of("Maths", 1) == "karpati" and Lessons.teacher_of("Maths", 2) == "szentgyorgyi" and Lessons.teacher_of("Maths", 3) == "karpati", "maths alternates")

	var main: Node = await _fresh()
	check(main.TEACHER_ORDER == Lessons.SUSPECT_IDS, "accusation order is the suspect list")
	check(main.campaign.culprit in Lessons.SUSPECT_IDS, "culprit is a suspect")
	var live := {}
	for t in get_nodes_in_group("teachers"):
		live[t.npc_id] = true
	check(live.size() == 8, "8 suspect teachers spawn, got %d" % live.size())
	for id: String in Lessons.SUSPECT_IDS:
		check(live.has(id), id + " spawned")
	var key_item := _find("salt")   # The storage key now comes from the Porta (Task 6); the salt is a story pickup.
	check(key_item != null and not key_item.visible, "story items hidden before the hunt")
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	check(main.choice_ui.visible, "accusation opens on day 4")
	check(main.choice_ui._count == 9, "8 names plus Not yet")
	var culprit: String = main.campaign.culprit
	main.choice_ui.chosen.emit(main.TEACHER_ORDER.find(culprit))
	await create_timer(0.3).timeout
	await process_frame
	check(main.campaign.hunt_active and key_item.visible and key_item.collision_layer == 16, "correct accusation reveals the story items")
	var left := get_nodes_in_group("teachers")
	check(left.size() == 7 and left.all(func(t: Node) -> bool: return t.npc_id != culprit), "culprit teacher node removed, 7 remain")
	main.campaign.start_day(5)
	await create_timer(0.3).timeout
	await process_frame
	var again := get_nodes_in_group("teachers")
	check(again.all(func(t: Node) -> bool: return t.npc_id != culprit), "culprit not respawned on day 5")
	check(again.size() == 7, "7 teachers on day 5, got %d" % again.size())
	main.queue_free()
	await create_timer(0.3).timeout

	main = await _fresh()
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign.start_day(4)
	await create_timer(0.3).timeout
	var wrong := 0
	for i in main.TEACHER_ORDER.size():
		if main.TEACHER_ORDER[i] != main.campaign.culprit:
			wrong = i
			break
	main.choice_ui.chosen.emit(wrong)
	await create_timer(0.3).timeout
	check(main.ending_screen.current_id == 8, "wrong accusation is ending 8")
	main.queue_free()
	await create_timer(0.3).timeout
	var dir := DirAccess.open("user://")
	for f in dir.get_files():
		if f.begins_with("neu_test_"):
			dir.remove(f)
