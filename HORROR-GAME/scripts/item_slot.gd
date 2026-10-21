extends PanelContainer
## One square of the hotbar or the inventory grid: a coloured tile with the item's initials, an optional caption and a
## highlighted border for the selected slot.

const EMPTY_BORDER := Color(0.55, 0.55, 0.6, 0.8)
const SELECTED_BORDER := Color(1.0, 0.85, 0.35)

var _style := StyleBoxFlat.new()
var _icon := Label.new()
var _caption: Label
var tag := Label.new()
var _show_names := false


func setup(side: float, tag_text: String, show_names: bool) -> void:
	_show_names = show_names
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.bg_color = Color(0.05, 0.05, 0.07, 0.72)
	_style.set_border_width_all(2)
	_style.border_color = EMPTY_BORDER
	_style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", _style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88, 0.85))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag)
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.add_theme_font_size_override("font_size", int(side * 0.3))
	_icon.add_theme_color_override("font_shadow_color", Color.BLACK)
	box.add_child(_icon)
	if show_names:
		_caption = Label.new()
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_caption.custom_minimum_size = Vector2(side - 8.0, 0.0)
		_caption.add_theme_font_size_override("font_size", 11)
		box.add_child(_caption)
	add_child(box)

	tag.text = tag_text
	set_item("", "")


func set_selected(selected: bool) -> void:
	_style.border_color = SELECTED_BORDER if selected else EMPTY_BORDER
	_style.set_border_width_all(4 if selected else 2)


## `id` is the inventory id, `label` its display name. An empty id clears the slot.
func set_item(id: String, label: String) -> void:
	if id == "":
		_icon.text = ""
		if _caption:
			_caption.text = ""
		_style.bg_color = Color(0.05, 0.05, 0.07, 0.72)
		return
	_icon.text = initials(id, label)
	if _caption:
		_caption.text = label
	var hue := float(hash(id) % 360) / 360.0
	_style.bg_color = Color.from_hsv(0.12 if is_key(id) else hue, 0.45, 0.45, 0.9)


## Shows free text (such as the bag count) instead of an item.
func set_text(text: String, dim: bool) -> void:
	_icon.text = text
	if _caption:
		_caption.text = ""
	_style.bg_color = Color(0.2, 0.2, 0.24, 0.55 if dim else 0.9)


static func is_key(id: String) -> bool:
	return id.begins_with("key_") or id == "storage_key" or id == "master_key"


static func initials(id: String, label: String) -> String:
	if is_key(id):
		return "KEY"
	var words := label.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[words.size() - 1].left(1)).to_upper()
	return label.left(2).capitalize() if not words.is_empty() else "?"
