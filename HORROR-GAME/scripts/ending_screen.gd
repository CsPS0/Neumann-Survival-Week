extends CanvasLayer
## Full-screen ending card: number, title, text and run stats. R restarts (a button on touch screens).

const Endings := preload("res://scripts/endings.gd")

var current_id := 0
var _label := Label.new()
var _shade := ColorRect.new()
var _again := Button.new()   ## Touch only: there is no R key.


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.0, 0.0, 0.0, 0.88)
	add_child(_shade)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 26)
	add_child(_label)
	_again.text = "Play again"
	_again.add_theme_font_size_override("font_size", 26)
	_again.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_again.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_again.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_again.custom_minimum_size = Vector2(240.0, 60.0)
	_again.position.y -= 40.0
	_again.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	add_child(_again)


func show_ending(id: int, stats: Dictionary) -> void:
	var data: Dictionary = Endings.LIST[id]
	current_id = id
	_label.add_theme_color_override("font_color", data["colour"])
	_label.text = "ENDING %d / %d\n\n%s\n\n%s\n\nDay %d   quiz %d/%d   clues %d/9   skipped %d\n\nPress R to play again" % [
		id, Endings.COUNT, String(data["title"]).to_upper(), data["text"], stats["day"], stats["right"],
		stats["total"], stats["clues"], stats["skipped"]]
	var bridge := get_tree().get_first_node_in_group("input_bridge")
	var touch: bool = bridge != null and bridge.is_touch()
	_again.visible = touch
	if touch:
		_label.text = _label.text.replace("Press R to play again", "")
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
