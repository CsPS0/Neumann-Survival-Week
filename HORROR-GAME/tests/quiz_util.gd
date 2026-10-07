extends RefCounted
## Helpers for the typed paper answer sheet (answer_sheet.gd) that replaced the multiple choice quiz.


static func is_open(main: Node) -> bool:
	return main.lesson_ui.visible and main.answer_sheet.visible


## Hands in one answer: the correct option text, or a text that matches no answer.
static func answer(main: Node, right := true) -> void:
	var q: Array = main.lesson_ui._questions[main.lesson_ui._index]
	main.answer_sheet.submitted.emit(q[1][q[2]] if right else "no such answer")


## Answers every question of the open lesson (3 on a normal day, 4 on test day).
static func answer_all(main: Node, right := true) -> void:
	var guard := 0
	while main.lesson_ui.visible and guard < 8:
		answer(main, right)
		guard += 1
