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
const Campaign := preload("res://scripts/campaign.gd")
const QuizUtil := preload("res://tests/quiz_util.gd")

func _run() -> void:
	for day in 3:
		var seen := {}
		for i in 7:
			seen[Lessons.subject_at(day + 1, i)] = true
		check(seen.size() == 7, "day %d has 7 different subjects" % (day + 1))
	for subject in Lessons.SUBJECTS:
		check(Lessons.quiz(subject).size() == 3, subject + " quiz has 3 questions")
		for q: Array in Lessons.SUBJECTS[subject][3]:
			check(q[1].size() == 4 and q[2] >= 0 and q[2] < 4, subject + " question well-formed")
		check(Lessons.TEACHER_NAMES.has(Lessons.teacher_of(subject)), subject + " has a known teacher")

	# Typed answers: case, spaces and accents are ignored, extra variants count, empty or wrong text does not.
	check(Lessons.normalize("  Arany  JÁNOS ") == "aranyjanos" and Lessons.normalize("2x") == "2x", "normalize folds case, spaces and accents")
	var qa: Array = Lessons.SUBJECTS["Literature"][3][2]
	check(Lessons.is_correct(qa, "arany janos") and Lessons.is_correct(qa, "Arany") and Lessons.is_correct(qa, "János Arany"), "extra accepted answers match")
	check(not Lessons.is_correct(qa, "") and not Lessons.is_correct(qa, "Jókai Mór"), "empty and wrong answers fail")
	var qm: Array = Lessons.SUBJECTS["Maths"][3][1]
	check(Lessons.is_correct(qm, "x = 11") and Lessons.is_correct(qm, "11") and not Lessons.is_correct(qm, "x = 9"), "maths answers")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.3).timeout
	var subject: String = Lessons.subject_at(1, 0)
	var room_pos: Vector3 = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject))
	check(not main._player_in_room(subject), "player starts outside the lesson room")
	main.player.global_position = room_pos + Vector3(0, 0.1, 0)
	check(main._player_in_room(subject), "teleported into the room")

	# Esc must pause when no quiz is open (so the quiz check below is not vacuous).
	var esc0 := InputEventKey.new()
	esc0.keycode = KEY_ESCAPE
	esc0.physical_keycode = KEY_ESCAPE
	esc0.pressed = true
	main._unhandled_input(esc0)
	check(paused, "Esc pauses when no quiz is open")
	main._resume()
	check(not paused, "resumed")
	main.daynight.minutes = 451.0
	await create_timer(0.3).timeout
	check(QuizUtil.is_open(main) and not main.choice_ui.visible, "paper answer sheet opens when the player is in the room at the bell")
	check(not main.entity.visible, "entity is asleep during the quiz")
	check(not main.player.controls_enabled, "controls disabled during the quiz")
	check(not main.daynight.running, "clock stopped during the quiz")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	main._unhandled_input(esc)
	check(not paused, "Esc does not pause under the quiz")
	QuizUtil.answer(main)
	check(main.lesson_ui.visible and main.answer_sheet.visible, "sheet stays open between questions")
	QuizUtil.answer(main, false)
	QuizUtil.answer(main)
	await create_timer(0.3).timeout
	check(main.campaign.attended == 1 and main.campaign.total == 3 and not main.answer_sheet.visible, "typed result recorded, sheet closed")
	check(main.daynight.minutes >= Campaign.lesson_end(0), "clock jumped to the end of the lesson")
	check(not main.choice_ui.visible, "choice ui closed")
	check(main.player.controls_enabled, "controls enabled after the quiz")
	# Key repeat must not answer questions.
	main.campaign._resolved[1] = false
	main.choice_ui.ask("t", "b", ["a", "b", "c", "d"])
	var rep_key := InputEventKey.new()
	rep_key.keycode = KEY_1
	rep_key.pressed = true
	rep_key.echo = true
	var got := [0]
	main.choice_ui.chosen.connect(func(_i: int) -> void: got[0] += 1)
	main.choice_ui._unhandled_input(rep_key)
	check(got[0] == 0, "echo key ignored")
	rep_key.echo = false
	main.choice_ui._unhandled_input(rep_key)
	check(got[0] == 1, "fresh key accepted")
	main.choice_ui.close()

	# Lesson end bell stations the next lesson's teacher.
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	main.campaign._ended[0] = false
	main.daynight.minutes = Campaign.lesson_end(0) + 1.0
	await create_timer(0.3).timeout
	var next_subject: String = Lessons.subject_at(1, 1)
	var tid: String = Lessons.teacher_of(next_subject)
	var found := false
	for t: Node in main.get_tree().get_nodes_in_group("teachers"):
		if t.npc_id == tid:
			found = true
			check(t._station.is_finite(), "next lesson teacher has a station")
	check(found, "teacher node found")

	# Ending guards.
	main.campaign._end(3)
	var mins: float = main.daynight.minutes
	main.campaign.finish_lesson(1, 3, 3)
	check(not main.daynight.running, "finish_lesson after an ending leaves clock stopped")
	var b: int = main.campaign.blackouts
	main.campaign.record_blackout()
	check(main.campaign.blackouts == b, "no blackout after ending")
	check(main.daynight.minutes == mins, "clock untouched after ending")
