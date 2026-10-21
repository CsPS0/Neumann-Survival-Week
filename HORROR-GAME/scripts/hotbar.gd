extends HBoxContainer
## Bottom-centre hotbar: the active hand, both pockets and the bag, with the hand highlighted. The full list is in the
## inventory grid (Tab). The name of the item in the hand shows above the bar for a moment when it changes.

const ItemSlot := preload("res://scripts/item_slot.gd")
const SLOT := 60.0

var _items: RefCounted
var _hand: PanelContainer
var _pockets: Array[PanelContainer] = []
var _bag: PanelContainer
var _name_label := Label.new()
var _name_tween: Tween
var _last_hand := ""


func setup(items: RefCounted, name_label_parent: Node) -> void:
	_items = items
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand = _slot("")
	_pockets = [_slot("L"), _slot("R")]
	_bag = _slot("BAG")
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name_label.modulate.a = 0.0
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label_parent.add_child(_name_label)
	_name_label.custom_minimum_size = Vector2(400.0, 0.0)
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(SLOT) + 40)
	refresh()


func _slot(tag: String) -> PanelContainer:
	var slot: PanelContainer = ItemSlot.new()
	slot.setup(SLOT, tag, false)
	add_child(slot)
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
	var carried: int = _items.slots[_items.Place.BAG].size()
	_bag.set_text("%d/%d" % [carried, _items.BAG_SLOTS], not _items.bag_worn)
	_bag.tag.text = "BAG" if _items.bag_worn else "DROPPED"
	if hand_id != _last_hand:
		_last_hand = hand_id
		if hand_id != "":
			_flash_name(_items.label_of(hand_id))


func _flash_name(text: String) -> void:
	_name_label.text = text
	if _name_tween:
		_name_tween.kill()
	_name_label.modulate.a = 1.0
	_name_tween = create_tween()
	_name_tween.tween_interval(1.8)
	_name_tween.tween_property(_name_label, "modulate:a", 0.0, 0.6)
