extends CanvasLayer
## A sheet of paper with one question and a line to write the answer on. Emits submitted(text) on Enter.
## The lesson quiz and the day 3 test use it; choice_ui stays for decisions (accusation, altar, Porta lists).

signal submitted(text: String)

const PAPER := Color(0.94, 0.91, 0.82)
const INK := Color(0.1, 0.12, 0.25)
const MARGIN := Color(0.75, 0.3, 0.3)

var _heading := Label.new()
var _question := Label.new()
var _hint := Label.new()
var _line := LineEdit.new()
var _paper := PanelContainer.new()
var _hand_in := Button.new()   ## Touch only: the on-screen keyboard has no reliable Enter.


func _ready() -> void:
	layer = 55
	visible = false
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(shade)

	var paper := _paper
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.grow_horizontal = Control.GROW_DIRECTION_BOTH
	paper.grow_vertical = Control.GROW_DIRECTION_BOTH
	paper.custom_minimum_size = Vector2(640.0, 0.0)
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = PAPER
	sheet.border_color = MARGIN
	sheet.border_width_left = 4
	sheet.set_content_margin_all(28.0)
	sheet.content_margin_left = 40.0
	sheet.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sheet.shadow_size = 14
	paper.add_theme_stylebox_override("panel", sheet)
	add_child(paper)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	paper.add_child(box)
	_style(_heading, 22, Color(INK, 0.7))
	box.add_child(_heading)
	_style(_question, 28, INK)
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_question)

	var ruled := StyleBoxFlat.new()
	ruled.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ruled.border_color = INK
	ruled.border_width_bottom = 2
	ruled.content_margin_bottom = 4.0
	for state in ["normal", "focus", "read_only"]:
		_line.add_theme_stylebox_override(state, ruled)
	_line.add_theme_font_size_override("font_size", 28)
	_line.add_theme_color_override("font_color", INK)
	_line.add_theme_color_override("caret_color", INK)
	_line.add_theme_color_override("font_placeholder_color", Color(INK, 0.35))
	_line.placeholder_text = "Write your answer"
	_line.max_length = 60
	_line.text_submitted.connect(func(text: String) -> void: submitted.emit(text))
	box.add_child(_line)
	_style(_hint, 16, Color(INK, 0.6))
	box.add_child(_hint)
	_hand_in.text = "Hand in"
	_hand_in.add_theme_font_size_override("font_size", 24)
	_hand_in.custom_minimum_size = Vector2(0.0, 52.0)
	_hand_in.pressed.connect(func() -> void: submitted.emit(_line.text))
	box.add_child(_hand_in)


func _style(label: Label, size: int, colour: Color) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)


func ask(heading: String, teacher_line: String, question: String, hint: String) -> void:
	_heading.text = heading
	_question.text = "%s\n\n%s" % [teacher_line, question]
	_hint.text = hint
	_line.text = ""
	var bridge := get_tree().get_first_node_in_group("input_bridge")
	var touch: bool = bridge != null and bridge.is_touch()
	_hand_in.visible = touch
	if touch:   # The sheet sits at the top so the on-screen keyboard does not cover it.
		_hint.text = "Type the answer, then tap Hand in."
		_paper.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_paper.offset_top = 16.0
		_paper.grow_vertical = Control.GROW_DIRECTION_END
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_line.grab_focus.call_deferred()


func close() -> void:
	visible = false
	_line.release_focus()
	DisplayServer.virtual_keyboard_hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
