extends PanelContainer
## The Tab inventory: equipped slots on top (hand and both pockets), the bag as a grid below it, and the weight line.
## It only shows state. Items are moved with the existing keys (B bag, X hand, V stow or take out).

const ItemSlot := preload("res://scripts/item_slot.gd")
const SLOT := 84.0
const BAG_COLUMNS := 4

var _items: RefCounted
var _hand: PanelContainer
var _pockets: Array[PanelContainer] = []
var _bag_slots: Array[PanelContainer] = []
var _bag_title := Label.new()
var _speed := Label.new()


func setup(items: RefCounted) -> void:
	_items = items
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.55, 0.6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16.0)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_heading("INVENTORY"))
	box.add_child(_heading("Equipped", 14))
	var equipped := HBoxContainer.new()
	equipped.add_theme_constant_override("separation", 6)
	_hand = _slot(equipped, "HAND")
	_pockets = [_slot(equipped, "L POCKET"), _slot(equipped, "R POCKET")]
	box.add_child(equipped)
	_bag_title.add_theme_font_size_override("font_size", 14)
	_bag_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	box.add_child(_bag_title)
	var grid := GridContainer.new()
	grid.columns = BAG_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in _items.BAG_SLOTS:
		_bag_slots.append(_slot(grid, ""))
	box.add_child(grid)
	_speed.add_theme_font_size_override("font_size", 14)
	box.add_child(_speed)
	var hint := Label.new()
	hint.text = "[B] drop or pick up the bag   [X] switch hand   [V] stow or take out   [Tab] close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	box.add_child(hint)
	add_child(box)
	refresh()


func _heading(text: String, size := 22) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _slot(parent: Control, tag: String) -> PanelContainer:
	var slot: PanelContainer = ItemSlot.new()
	slot.setup(SLOT, tag, true)
	parent.add_child(slot)
	return slot


func refresh() -> void:
	var hand_id: String = _items.hand_item()
	_hand.set_item(hand_id, _items.label_of(hand_id))
	_hand.set_selected(true)
	_hand.tag.text = "L HAND" if _items.left_handed else "R HAND"
	var places := [_items.Place.POCKET_LEFT, _items.Place.POCKET_RIGHT]
	for i in 2:
		var pocket: Array = _items.slots[places[i]]
		_pockets[i].set_item(pocket[0] if not pocket.is_empty() else "", _items.label_of(pocket[0]) if not pocket.is_empty() else "")
	var bag: Array = _items.slots[_items.Place.BAG]
	for i in _bag_slots.size():
		var id: String = bag[i] if i < bag.size() else ""
		_bag_slots[i].set_item(id, _items.label_of(id) if id != "" else "")
		_bag_slots[i].modulate.a = 1.0 if _items.bag_worn else 0.45
	if _items.bag_worn:
		_bag_title.text = "Bag (%d/%d, %.1f kg)" % [bag.size(), _items.BAG_SLOTS, _items.bag_weight()]
		_speed.text = "Walking speed: %d%%" % roundi(_items.speed_multiplier() * 100.0)
	else:
		_bag_title.text = "Bag: on the floor, out of reach (%d items)" % bag.size()
		_speed.text = "Walking speed: 100%"
