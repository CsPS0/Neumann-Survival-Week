extends RefCounted
## What the player carries. One active hand (left or right), two pockets and a bag on the back.
## The bag holds the most but is heavy: it slows the player down. A dropped bag keeps its items, but nothing in it
## can be reached until the player wears it again. Keys, finds and the story items all go through add / has / remove.

signal changed

enum Place { HAND, POCKET_LEFT, POCKET_RIGHT, BAG }

const BAG_SLOTS := 8
const POCKET_SLOTS := 1
const HAND_SLOTS := 1
const BAG_EMPTY_WEIGHT := 3.0            ## kg of the empty bag.
const ITEM_WEIGHT := 0.5                 ## kg of a normal item in the bag.
const KEY_WEIGHT := 0.1                  ## kg of a key or key card.
const HEAVY_WEIGHTS := {"salt": 1.2, "vial": 1.0, "bell": 1.5, "fuse": 0.8}
const SPEED_PENALTY_PER_KG := 0.03       ## Share of the speed lost per kg in the bag. An empty bag costs 9%.
const MAX_SPEED_PENALTY := 0.3           ## Never slower than 70% of normal speed.

var bag_worn := true
var left_handed := true                  ## True when the active hand is the left one.
var slots := {Place.HAND: [], Place.POCKET_LEFT: [], Place.POCKET_RIGHT: [], Place.BAG: []}
var names := {}                          ## Item id -> display name.


static func capacity(place: int) -> int:
	match place:
		Place.HAND: return HAND_SLOTS
		Place.BAG: return BAG_SLOTS
		_: return POCKET_SLOTS


static func is_key(id: String) -> bool:
	return id.begins_with("key_") or id == "storage_key" or id == "master_key"


static func item_weight(id: String) -> float:
	if is_key(id):
		return KEY_WEIGHT
	return HEAVY_WEIGHTS.get(id, ITEM_WEIGHT)


func is_reachable(place: int) -> bool:
	return place != Place.BAG or bag_worn


## Stores an item in the first place with room: the hand, the pockets, then the bag (only while it is worn).
## Keys are small and go the other way round: a pocket first, then the bag, the hand last.
## `force` keeps the item even when everything is full (story items must never be lost): it goes into the hand.
## Returns the place used, or -1 when there was no room.
func add(id: String, display_name: String, force := false) -> int:
	var order: Array = [Place.POCKET_LEFT, Place.POCKET_RIGHT, Place.BAG, Place.HAND] if is_key(id) \
			else [Place.HAND, Place.POCKET_LEFT, Place.POCKET_RIGHT, Place.BAG]
	for place: int in order:
		if is_reachable(place) and slots[place].size() < capacity(place):
			return _put(place, id, display_name)
	if force:
		return _put(Place.HAND, id, display_name)
	return -1


func can_add() -> bool:
	for place: int in slots:
		if is_reachable(place) and slots[place].size() < capacity(place):
			return true
	return false


## Only items the player can reach count: a dropped bag hides its contents.
func has(id: String) -> bool:
	return locate(id) != -1


func locate(id: String) -> int:
	for place: int in slots:
		if is_reachable(place) and slots[place].has(id):
			return place
	return -1


func remove(id: String) -> void:
	var place := locate(id)
	if place == -1:
		return
	slots[place].erase(id)
	changed.emit()


func hand_item() -> String:
	return slots[Place.HAND][0] if not slots[Place.HAND].is_empty() else ""


## Moves the item in the hand to a pocket or the bag. False when there is no room.
func stow_hand() -> bool:
	var id := hand_item()
	if id == "":
		return true
	for place: int in [Place.POCKET_LEFT, Place.POCKET_RIGHT, Place.BAG]:
		if is_reachable(place) and slots[place].size() < capacity(place):
			slots[Place.HAND].pop_front()
			slots[place].append(id)
			changed.emit()
			return true
	return false


## Takes the first item from a pocket (then the bag) into the empty hand. Returns its id, or "" when none.
func take_to_hand() -> String:
	if hand_item() != "":
		return ""
	for place: int in [Place.POCKET_LEFT, Place.POCKET_RIGHT, Place.BAG]:
		if is_reachable(place) and not slots[place].is_empty():
			var id: String = slots[place].pop_front()
			slots[Place.HAND].append(id)
			changed.emit()
			return id
	return ""


func swap_hand() -> void:
	left_handed = not left_handed
	changed.emit()


func set_bag_worn(worn: bool) -> void:
	bag_worn = worn
	changed.emit()


## Weight carried in the bag (empty bag included). Zero while the bag is on the floor.
func bag_weight() -> float:
	if not bag_worn:
		return 0.0
	var total := BAG_EMPTY_WEIGHT
	for id: String in slots[Place.BAG]:
		total += item_weight(id)
	return total


## Factor for the walk and sprint speed: 1.0 without the bag, lower the heavier it is.
func speed_multiplier() -> float:
	return 1.0 - minf(bag_weight() * SPEED_PENALTY_PER_KG, MAX_SPEED_PENALTY)


static func place_name(place: int) -> String:
	match place:
		Place.POCKET_LEFT: return "left pocket"
		Place.POCKET_RIGHT: return "right pocket"
		Place.BAG: return "bag"
		_: return "hand"


func label_of(id: String) -> String:
	return names.get(id, id)


## One short line for the HUD.
func summary() -> String:
	var hand := hand_item()
	var parts: Array[String] = ["%s hand: %s" % ["Left" if left_handed else "Right", label_of(hand) if hand != "" else "empty"]]
	var pockets: Array[String] = []
	for place: int in [Place.POCKET_LEFT, Place.POCKET_RIGHT]:
		pockets.append(label_of(slots[place][0]) if not slots[place].is_empty() else "-")
	parts.append("Pockets: %s, %s" % [pockets[0], pockets[1]])
	if bag_worn:
		var bag_names: Array[String] = []
		for id: String in slots[Place.BAG]:
			bag_names.append(label_of(id))
		parts.append("Bag %d/%d (%.1f kg): %s" % [bag_names.size(), BAG_SLOTS, bag_weight(),
				", ".join(bag_names) if not bag_names.is_empty() else "empty"])
	else:
		parts.append("Bag: on the floor (%d items out of reach)" % slots[Place.BAG].size())
	return "   |   ".join(parts)


func _put(place: int, id: String, display_name: String) -> int:
	slots[place].append(id)
	names[id] = display_name
	changed.emit()
	return place
