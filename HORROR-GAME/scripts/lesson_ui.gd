extends Node
## Runs one lesson: the teacher's line, then 3 questions. Emits finished(correct, total).

const Lessons := preload("res://scripts/lessons.gd")

signal finished(correct: int, total: int)

var choice_ui: CanvasLayer
var visible := false

var _questions: Array = []
var _index := 0
var _correct := 0
var _subject := ""
var _teacher := ""


func _ready() -> void:
	choice_ui.chosen.connect(_on_chosen)


func run(subject: String, teacher_name: String) -> void:
	_subject = subject
	_teacher = teacher_name
	_questions = Lessons.quiz(subject)
	_index = 0
	_correct = 0
	visible = true
	_ask()


func _ask() -> void:
	var q: Array = _questions[_index]
	choice_ui.ask("%s (%d/%d)" % [_subject, _index + 1, _questions.size()],
			"%s: Pop quiz.\n\n%s" % [_teacher, q[0]], q[1])


func _on_chosen(picked: int) -> void:
	if not visible:
		return
	if picked == _questions[_index][2]:
		_correct += 1
	_index += 1
	if _index < _questions.size():
		_ask()
		return
	visible = false
	choice_ui.close()
	finished.emit(_correct, _questions.size())
