extends Node
## Runs one lesson: the teacher's line, then 3 questions (4 on test day). Emits finished(correct, total).
## Questions are written on the paper answer sheet; `typed` off (VR has no keyboard) falls back to the option list.

const Lessons := preload("res://scripts/lessons.gd")

signal finished(correct: int, total: int)

var choice_ui: CanvasLayer
var sheet: CanvasLayer
var typed := true
var visible := false

var _questions: Array = []
var _index := 0
var _correct := 0
var _subject := ""
var _teacher := ""
var _test := false


func _ready() -> void:
	choice_ui.chosen.connect(_on_chosen)
	sheet.submitted.connect(_on_submitted)


func run(subject: String, teacher_name: String, test := false) -> void:
	_subject = subject
	_teacher = teacher_name
	_test = test
	_questions = Lessons.quiz(subject, 4 if test else 3)
	_index = 0
	_correct = 0
	visible = true
	_ask()


func _ask() -> void:
	var q: Array = _questions[_index]
	var teacher_line := "%s: %s" % [_teacher, "Today is the test." if _test else "Pop quiz."]
	if typed:
		sheet.ask("%s, question %d of %d" % [_subject, _index + 1, _questions.size()], teacher_line, q[0],
				"Press Enter to hand in the answer.")
	else:
		choice_ui.ask("%s (%d/%d)" % [_subject, _index + 1, _questions.size()], "%s\n\n%s" % [teacher_line, q[0]], q[1])


func _on_chosen(picked: int) -> void:
	if visible and not typed:
		_mark(picked == _questions[_index][2])


func _on_submitted(text: String) -> void:
	if visible and typed:
		_mark(Lessons.is_correct(_questions[_index], text))


func _mark(right: bool) -> void:
	if right:
		_correct += 1
	_index += 1
	if _index < _questions.size():
		_ask()
		return
	visible = false
	if typed:
		sheet.close()
	else:
		choice_ui.close()
	finished.emit(_correct, _questions.size())
