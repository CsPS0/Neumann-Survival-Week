extends Node
## Porta logic: key lending, stealing, the board lock, the student card. Pure state; main wires the NPC and the UI.

const Rooms := preload("res://scripts/rooms.gd")
const FloorData := preload("res://scripts/floor_data.gd")

signal key_given(label: String)
signal caught_stealing
signal sent_away(seconds: float)   ## main walks the porter to the WC and back.
signal key_returned(label: String)
signal changed

const CARD_DAY := 3               ## The new student card is handed out on this day and expires at its midnight.
const FORBIDDEN := "14"
const RED := "red"

var campaign: Node
var player: Node
var card_valid := true            ## False from day 4 on when the sticker was not stamped on day 3.
var has_form := false
var card_renewed := false
var board_locked_day := 0
var distracted_day := 0
var away := false
var asleep := false               ## Night: he dozes at the desk, the board is unguarded (no soft-lock on day 5).
var borrowed: Array[String] = []
var stolen_14 := false
var signed_out := {}              ## Label -> game minute it was signed for. At most one key is lent at a time.
var room_closed := Callable()     ## (label) -> bool, set by main: is that room's door closed (and locked)?


static func key_item(label: String) -> String:
	return "storage_key" if label == RED else "key_" + label


## Labels on the board that can be lent: every open normal/computer room, plus the red room's key.
func lendable_keys() -> Array:
	var labels: Array = []
	for f in FloorData.FLOORS.size():
		for room: Array in FloorData.FLOORS[f]["rooms"]:
			var label: String = room[0]
			var type := Rooms.type_of(label)
			if (type == "normal" or type == "computer") and label != FORBIDDEN and not labels.has(label):
				labels.append(label)
	labels.append(RED)
	return labels


func is_board_locked() -> bool:
	return board_locked_day == campaign.day


func ask_key(label: String) -> String:
	if asleep:
		return "Mr. Bakó is asleep at his desk."
	if away:
		return "Nobody is at the desk."
	if label == FORBIDDEN:
		return "Fourteen? There is no key for fourteen. There never was."
	if not card_valid:
		return "Your card has expired. No keys today."
	if is_board_locked():
		return "The board is locked for today."
	if not lendable_keys().has(label):
		return "I have no key for that one."
	if signed_out.has(label) or player.has_item(key_item(label)):
		return "You already have that one."
	if not signed_out.is_empty():
		return "You still have the key for %s signed out. One key at a time. Bring it back first." % _room_name(signed_out.keys()[0])
	_give(label)
	signed_out[label] = campaign.daynight.minutes
	if not borrowed.has(label):
		borrowed.append(label)
		if borrowed.size() == 5:
			campaign.event.emit("key_collector", {})
	var opening := "Here." if label != RED else "The storage room? Fine. Don't lose it."
	return "%s Signed at %s. Close the room before you bring the key back." % [opening, campaign.fmt(signed_out[label])]


## Hands the signed key back. The room has to be closed first.
func return_key() -> String:
	if asleep:
		return "Mr. Bakó is asleep at his desk."
	if away:
		return "Nobody is at the desk."
	if signed_out.is_empty():
		return "You have no key signed out."
	var label: String = signed_out.keys()[0]
	if not player.has_item(key_item(label)):
		return "You do not have the key on you. Pick up your bag first."
	if room_closed.is_valid() and not room_closed.call(label):
		return "%s is still open. Close and lock it first, then bring the key back." % _room_name(label)
	var since: float = signed_out[label]
	signed_out.erase(label)
	player.remove_item(key_item(label))
	key_returned.emit(label)
	changed.emit()
	return "Signed back in at %s. It was out since %s." % [campaign.fmt(campaign.daynight.minutes), campaign.fmt(since)]


## The phone's task line for the key the player still has to bring back (empty when none).
func key_line() -> String:
	if signed_out.is_empty():
		return ""
	var label: String = signed_out.keys()[0]
	return "[ ] Return the key for %s (signed at %s): close the room first" % [_room_name(label), campaign.fmt(signed_out[label])]


func _room_name(label: String) -> String:
	return "the storage room" if label == RED else "room " + label


## `seen`: main's check that the porter is within 6 m with a clear line of sight. Away alone is not enough.
func try_steal(label: String, seen := false) -> String:
	if is_board_locked():
		return "The board is locked for today."
	if not away or seen:
		board_locked_day = campaign.day
		caught_stealing.emit()
		changed.emit()
		return "Put that back! The board is locked for today."
	if label != FORBIDDEN and not lendable_keys().has(label):
		return "There is no such key."
	if player.has_item(key_item(label)):
		return "That hook is empty. You already have it."
	_give(label)
	if label == FORBIDDEN:
		stolen_14 = true
		campaign.event.emit("sticky_fingers", {})
	return "You pocket the key. Nobody saw."


## Once a day: "there is a leak in the WC". A second try the same day is not believed and locks the board.
func distract() -> String:
	if asleep:
		return "Mr. Bakó is asleep at his desk."
	if away:
		return "Nobody is at the desk."
	if distracted_day == campaign.day:
		board_locked_day = campaign.day
		changed.emit()
		return "A leak? I don't believe you. The board is locked for today."
	distracted_day = campaign.day
	send_away(40.0)
	return "A leak?! I'll go and look. Stay out of the board!"


## He leaves the desk for `seconds` (a break trip or a distraction); main moves the NPC.
func send_away(seconds: float) -> void:
	away = true
	sent_away.emit(seconds)
	changed.emit()


func return_now() -> void:
	if asleep:
		return
	away = false
	changed.emit()


## Nightfall: he nods off at the desk. The board stays unguarded until morning, also on a day it was locked.
func doze() -> void:
	asleep = true
	away = true
	board_locked_day = 0
	changed.emit()


func on_day_started(day: int) -> void:
	asleep = false
	away = false
	if day > CARD_DAY and not card_renewed:
		card_valid = false
	changed.emit()


func ask_sticker() -> String:
	if campaign.day < CARD_DAY:
		return "New cards are handed out on day %d. Come back then." % CARD_DAY
	if card_renewed:
		return "You already have it. Don't push your luck."
	if not card_valid:
		return "Your card has expired. No stickers, no keys. Rules."
	if not has_form:
		return "I need the signed form first. Try a classroom on the 1st floor, somebody always leaves them lying around."
	has_form = false
	card_renewed = true
	player.remove_item("form")
	campaign.event.emit("card_renewed", {})
	changed.emit()
	return "Stamped. Your card is valid again."


func on_form_taken() -> void:
	has_form = true
	changed.emit()


func _give(label: String) -> void:
	var id := key_item(label)
	player.give_item(id, "Key " + label if label != RED else "Storage key")
	key_given.emit(label)
	changed.emit()
