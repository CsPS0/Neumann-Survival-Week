extends Node
## Story state: four chained tasks that end in an exorcism of the demon at the Aula altar.
##   1. Storage key (borrowed or stolen at the Porta) -> red locked room -> salt + fuse
##   2. Fuse -> fuse box (room 24) powers the Lab 14 cabinet; Lab 14 key (stolen from the Porta board) -> holy water
##   3. Four hidden notes -> safe code -> old safe (room 229, 2nd floor) -> bell
##   4. Place salt, water and bell on the altar, then survive the ritual at night.

signal changed
signal code_requested
signal ritual_started
signal ritual_completed
signal ritual_interrupted
signal choice_requested(kind: String)   ## Day 5 altar: "deal" or "ritual_or_deal".

const KEY_ID := "storage_key"
const RITUAL_ITEMS := {"salt": "Salt", "vial": "Holy water", "bell": "Silver bell"}
const RITUAL_SECONDS := 40.0

var player: Node
var daynight: Node
var campaign: Node
var porta: Node   ## Read for the expired-card hint.
var floor_names: Array = []

var red_room_label := ""
var red_room_floor := 0
var red_room_opened := false
var fuse_placed := false
var lab_door: Node
var code: Array[int] = []
var notes_found: Array[bool] = [false, false, false, false]
var safe_open := false
var altar_items := {"salt": false, "vial": false, "bell": false}
var ritual_active := false
var ritual_left := 0.0
var ritual_done := false


func _ready() -> void:
	add_to_group("quest")


func _process(delta: float) -> void:
	if not ritual_active:
		return
	ritual_left -= delta
	if ritual_left <= 0.0:
		ritual_active = false
		ritual_done = true
		ritual_completed.emit()
		changed.emit()


# --- Interactions ------------------------------------------------------------

func fuse_box_interact(by: Node) -> void:
	if fuse_placed:
		by.inspected.emit("The fuse box hums. The lab is powered.")
	elif by.has_item("fuse"):
		by.remove_item("fuse")
		fuse_placed = true
		by.inspected.emit("You push in the fuse. A cabinet in the lab hums to life.")
		changed.emit()
	else:
		by.inspected.emit("The fuse box is missing its main fuse.")


func safe_interact(by: Node) -> void:
	if safe_open:
		by.inspected.emit("The safe is empty.")
	else:
		code_requested.emit()


func try_code(attempt: Array[int]) -> bool:
	if attempt == code:
		safe_open = true
		player.give_item("bell", RITUAL_ITEMS["bell"])
		changed.emit()
		return true
	return false


func altar_interact(by: Node) -> void:
	if ritual_active or ritual_done:
		return
	var placed := []
	for item: String in RITUAL_ITEMS:
		if by.has_item(item) and not altar_items[item]:
			by.remove_item(item)
			altar_items[item] = true
			placed.append(RITUAL_ITEMS[item])
	if not placed.is_empty():
		changed.emit()
		by.inspected.emit("You place the %s on the altar." % ", ".join(placed))
		return
	var missing := []
	for item: String in RITUAL_ITEMS:
		if not altar_items[item]:
			missing.append(RITUAL_ITEMS[item])
	var all_placed := missing.is_empty()
	if campaign and campaign.hunt_active and campaign.day == campaign.FINAL_DAY:
		choice_requested.emit("ritual_or_deal" if all_placed and daynight.is_night else "deal")
		if not all_placed:
			by.inspected.emit("The altar waits for: %s." % ", ".join(missing))
		elif not daynight.is_night:
			by.inspected.emit("The ritual needs darkness.")
		return
	if not all_placed:
		by.inspected.emit("The altar waits for: %s." % ", ".join(missing))
	elif daynight.is_night:
		begin_ritual(by)
	else:
		daynight.skip_to_dusk()
		by.inspected.emit("The ritual needs darkness. You wait for the sun to set...")


func begin_ritual(by: Node) -> void:
	ritual_active = true
	ritual_left = RITUAL_SECONDS
	ritual_started.emit()
	by.inspected.emit("The candles ignite. THE DEMON KNOWS WHERE YOU ARE. Survive %d seconds!" % int(RITUAL_SECONDS))
	changed.emit()


func on_player_caught() -> void:
	if ritual_active:
		ritual_active = false
		ritual_interrupted.emit()
		changed.emit()


# --- Status text -------------------------------------------------------------

func hint() -> String:
	if not player.has_item(KEY_ID) and not red_room_opened:
		if porta != null and not porta.card_valid:
			return "Your card expired, so the porter lends nothing. Take the red room's key from the Porta board while he is away."
		return "Ask the porter (Porta, by the entrance) for the red room's key."
	if not red_room_opened:
		return "The key fits the red door on the %s." % floor_names[red_room_floor]
	if not fuse_placed and not player.has_item("fuse"):
		return "Take the fuse and the salt from the table in the red room."
	if not fuse_placed:
		return "Put the fuse in the fuse box in room 24 (ground floor). It powers the cabinet in Lab 14."
	if not _has_or_placed("vial") and lab_door != null and lab_door.locked and not player.has_item("key_14"):
		return "Lab 14 is locked and the porter never lends its key. Take it from the Porta board while he is away."
	if not _has_or_placed("vial"):
		return "Take the holy water from the humming cabinet in Lab 14 (ground floor)."
	if not safe_open and not _has_or_placed("bell"):
		return "The old safe in room 229 (2nd floor) needs a 4-digit code from four hidden notes."
	if not (altar_items["salt"] and altar_items["vial"] and altar_items["bell"]):
		return "Bring salt, holy water and the bell to the altar in the Aula (ground floor)."
	if not ritual_done:
		return "Start the ritual at the altar once night has fallen. Then survive."
	return "The demon is banished."


func objective() -> String:
	return hint()


func task_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s Salt  - red door, %s" % [_mark(_has_or_placed("salt")), floor_names[red_room_floor]])
	lines.append("    key: Porta %s" % _mark(red_room_opened))
	lines.append("%s Holy water - Lab 14 cabinet" % _mark(_has_or_placed("vial")))
	lines.append("    fuse -> fuse box, room 24 %s" % _mark(fuse_placed))
	lines.append("%s Silver bell - old safe, room 229" % _mark(_has_or_placed("bell")))
	lines.append("    code: %s" % code_progress())
	lines.append("%s Ritual at the Aula altar (night)" % _mark(ritual_done))
	return lines


func code_progress() -> String:
	var parts: Array[String] = []
	for i in 4:
		parts.append(str(code[i]) if notes_found[i] else "_")
	return " ".join(parts)


func dialogue(id: String) -> Array[String]:
	var lines: Array[String] = []
	match id:
		"karpati":
			lines.append("Kárpáti Lajos: Three years ago the chemistry club opened something in Lab 14. Something old.")
			lines.append("Kárpáti Lajos: Since then nobody enrolls. Parents say the school is haunted. They are right.")
			lines.append("Kárpáti Lajos: By day it sleeps. At night it walks these halls. Light is your only friend.")
			lines.append("Kárpáti Lajos: To free the school: salt, holy water and the silver bell, placed on the altar in the Aula.")
			lines.append("Kárpáti Lajos: And the ritual only works at night. Be careful, it listens for running feet.")
		"voros":
			lines.append("Vörös Ildikó: I locked Lab 14 after the accident. The porter keeps its key and lends it to nobody.")
			lines.append("Vörös Ildikó: The holy water, I mean the blessed vial, still sits on the shelf in there.")
			lines.append("Vörös Ildikó: The fuse box is in room 24, on the ground floor. The main fuse went missing years ago.")
		"onodi":
			lines.append("Ónodi Bence: The storage key hangs on the porter's board. Ask Mr. Bakó nicely.")
			lines.append("Ónodi Bence: It opens one locked room. I forget which, the lock was painted red after the incident.")
			lines.append("Ónodi Bence: Batteries? I leave spares lying around the corridors. You will want them at night.")
		"lazar":
			lines.append("Lázár Tivadar: I put the school bell in the old safe in room 229, upstairs. The code is a four-digit number.")
			lines.append("Lázár Tivadar: I tore it into four notes and hid them in classrooms. Foolish, I know.")
			lines.append("Lázár Tivadar: When the sun sets, leave. I always do. The staff cannot help you after dark.")
		"szentgyorgyi", "halmos", "pasztor", "fekete":
			lines.append("I know nothing about the ritual. Ask the others, and do not stay after dark.")
	if not lines.is_empty():
		lines.append("Hint: " + hint())
	return lines


func _mark(done: bool) -> String:
	return "[x]" if done else "[ ]"


func _has_or_placed(item: String) -> bool:
	return altar_items[item] or player.has_item(item)

