extends Node
## Find registry and state. Data (PAGES, SECRETS, CARDS) plus which ones the player has found. Spot geometry: the four
## inner corners of a room (inset 0.9 m), ordered from the farthest from the room's doors to the nearest, so slot 0 is
## the most hidden corner. A label used twice on a floor (WC) means the first one.

const FloorData := preload("res://scripts/floor_data.gd")

signal found_item(kind: String, id: String)

const INSET := 0.9
const FLOOR_HEIGHT := 4.0   ## Same as main.gd (main cannot be preloaded here: it preloads this file).

const PAGES := [
	{"id": "lab1", "room": "14", "floor": 0, "slot": 1, "title": "Experiment log 1",
		"text": "Day 1. The club sealed a glass ampoule marked S-14 in the fume cupboard: sodium, sulphur and a salt I cannot name. The meter reads wrong in a way I have never seen."},
	{"id": "lab2", "room": "14", "floor": 0, "slot": 2, "title": "Experiment log 2",
		"text": "Day 9. The lights flicker whenever the ampoule is moved. Two students felt cold. The caretaker says the lab door stood open at night, but I locked it myself."},
	{"id": "lab3", "room": "14", "floor": 0, "slot": 3, "title": "Experiment log 3",
		"text": "Last entry. It is no longer in the ampoule. It is in the school. Salt, holy water and a bell: the old caretaker's rhyme. I do not understand it. Keep this room locked."},
	{"id": "gym1", "room": "27", "floor": 0, "slot": 0, "title": "Coach's log 1",
		"text": "3 a.m. alarm again. Wet footprints from the lab corridor to the Tornaterem and none back. Nobody on the camera."},
	{"id": "gym2", "room": "Tornaterem", "floor": 0, "slot": 0, "title": "Coach's log 2",
		"text": "A girl fainted on the last lap. She said someone in a teacher's lanyard stood in the stands. The stands were empty."},
	{"id": "com1", "room": "GT11-12", "floor": 0, "slot": 1, "title": "server.log 1",
		"text": "02:11 power surge on circuit 14. 02:11 door sensor 14 opened by: (no card). 02:12 camera 7 offline."},
	{"id": "com2", "room": "GT2", "floor": 0, "slot": 1, "title": "server.log 2",
		"text": "03:00 the badge reader logs a teacher's card in the lab corridor. That teacher is on leave. The card is in a locked drawer."},
	{"id": "com3", "room": "GT8", "floor": 2, "slot": 1, "title": "server.log 3",
		"text": "Backup restored. File sample_s14.txt reappears every night at 02:11 with one new line: 'You looked.'"},
	{"id": "wc1", "room": "WC", "floor": 0, "slot": 0, "title": "Graffiti",
		"text": "Do not go to the lab after dark. It knows your name. - 11.c"},
	{"id": "wc2", "room": "WC", "floor": 1, "slot": 0, "title": "Torn note",
		"text": "I took a key from the Porta once. He pretends there is no 14 on the board. Why does he hide it?"},
	{"id": "cls1", "room": "33", "floor": 0, "slot": 2, "title": "Diary 1",
		"text": "The teachers are strange since the club. One of them stopped sleeping. I counted: the corridor lights go out in the order he walks."},
	{"id": "cls2", "room": "129", "floor": 1, "slot": 1, "title": "Diary 2",
		"text": "I think the thing learned to look like one of them. That is why nobody can find it. Watch who is never tired."},
]

const SECRETS := [
	{"id": "toy", "room": "5", "floor": 0, "slot": 2, "title": "Rubber bone",
		"text": "A chewed red rubber bone. Csoki would love this."},
	{"id": "tape", "room": "27", "floor": 0, "slot": 2, "title": "Cassette",
		"text": "A cassette in a gym locker. Side A: the school song. Side B: breathing."},
	{"id": "drawing", "room": "45", "floor": 0, "slot": 3, "title": "Tiny drawing",
		"text": "Under the board eraser: a tiny chameleon with gears. 'neu_mecha was here.'"},
	{"id": "mirror", "room": "WC", "floor": 1, "slot": 3, "title": "Mirror message",
		"text": "In the steam on the mirror: WE SEE YOU, 11.A."},
	{"id": "photo", "room": "14", "floor": 0, "slot": 0, "title": "Club photo",
		"text": "A faded photo of the chemistry club: ten students and a teacher whose face is scratched out."},
]

const CARDS := [
	{"id": "card_karpati", "room": "35", "floor": 0, "slot": 0, "title": "Kárpáti Lajos",
		"text": "Kárpáti Lajos. Favourite formula: F = ma. Hobby: collecting broken calculators."},
	{"id": "card_szentgyorgyi", "room": "42", "floor": 0, "slot": 0, "title": "Dr. Szentgyörgyi Aranka",
		"text": "Dr. Szentgyörgyi Aranka. Never marks in green. Said to bake the best pogácsa in school."},
	{"id": "card_halmos", "room": "43", "floor": 0, "slot": 0, "title": "Halmos Ervin",
		"text": "Halmos Ervin. Was seen hugging a transformer. Says it hums back."},
	{"id": "card_voros", "room": "114", "floor": 1, "slot": 0, "title": "Vörös Ildikó",
		"text": "Vörös Ildikó. Carries a pocket poem for every kind of weather."},
	{"id": "card_pasztor", "room": "120", "floor": 1, "slot": 0, "title": "Pásztor Margit",
		"text": "Pásztor Margit. Corrects the grammar on the vending machine."},
	{"id": "card_onodi", "room": "205", "floor": 2, "slot": 0, "title": "Ónodi Bence",
		"text": "Ónodi Bence. His password is a secret. His hoodie is not."},
	{"id": "card_fekete", "room": "225", "floor": 2, "slot": 0, "title": "Fekete Zsombor",
		"text": "Fekete Zsombor. Calls the school wifi his pet."},
	{"id": "card_lazar", "room": "233", "floor": 2, "slot": 0, "title": "Lázár Tivadar",
		"text": "Lázár Tivadar. Knows the date of every battle and none of his own birthday."},
]

## The daily neu_mecha chameleon (mecha.gd): one spot per day, not a find (own counter, own phone page).
## WC (floor 1) and Tornaterem use slots 1 and 3: their slots 3 and 1 hold the mirror secret and a battery.
const MECHA := [
	{"id": "mecha_1", "day": 1, "room": "GT11-12", "floor": 0, "slot": 3, "reward": "battery",
		"caption": "Many screens, no windows. The keyboards are asleep. Look low, by the wall."},
	{"id": "mecha_2", "day": 2, "room": "33", "floor": 0, "slot": 0, "reward": "biscuit",
		"caption": "Number 33 loves to be early. Look where the chalk gets tired."},
	{"id": "mecha_3", "day": 3, "room": "27", "floor": 0, "slot": 3, "reward": "page",
		"caption": "Where the whistle lives. Check behind the line you may not cross."},
	{"id": "mecha_4", "day": 4, "room": "WC", "floor": 1, "slot": 1, "reward": "battery",
		"caption": "Tiles, taps and echoes. Somebody's reflection winked back."},
	{"id": "mecha_5", "day": 5, "room": "Tornaterem", "floor": 0, "slot": 3, "reward": "biscuit",
		"caption": "The biggest room, two lessons at once. The chameleon blends with the wall bars."},
]

var campaign: Node
var found: Dictionary = {}   ## id -> true, in the order found.
var items_found := 0         ## Useful items taken (main's ITEM_SPOTS); not finds, only the page's "Items" line.
var items_total := 0


func _ready() -> void:
	add_to_group("finds")


func mark(id: String) -> bool:
	if found.has(id):
		return false
	found[id] = true
	var kind := kind_of(id)
	found_item.emit(kind, id)
	if campaign:
		match kind:
			"page":
				if count("page") == PAGES.size():
					campaign.event.emit("archivist", {})
			"secret":
				if count("secret") == SECRETS.size():
					campaign.event.emit("everything_found", {})
			"card":
				if count("card") == CARDS.size():
					campaign.event.emit("full_deck", {})
	return true


static func kind_of(id: String) -> String:
	for p: Dictionary in PAGES:
		if p["id"] == id:
			return "page"
	for s: Dictionary in SECRETS:
		if s["id"] == id:
			return "secret"
	for c: Dictionary in CARDS:
		if c["id"] == id:
			return "card"
	return ""


static func entry(id: String) -> Dictionary:
	for f: Dictionary in all():
		if f["id"] == id:
			return f
	return {}


func count(kind: String) -> int:
	var n := 0
	for id: String in found:
		if kind_of(id) == kind:
			n += 1
	return n


static func all() -> Array:
	return PAGES + SECRETS + CARDS


## World position (floor level) of corner `slot` of the room `label` on `floor_index`.
static func spot_position(floor_index: int, label: String, slot: int) -> Vector3:
	var data: Dictionary = FloorData.FLOORS[floor_index]
	var origin: Vector2 = data["origin"]
	var scale: float = data["scale"]
	for room: Array in data["rooms"]:
		if room[0] != label:
			continue
		var a := (Vector2(room[1], room[2]) - origin) * scale
		var b := (Vector2(room[3], room[4]) - origin) * scale
		var rect := Rect2(a, b - a).abs().grow(-INSET)
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]
		var doors := _door_points(room, origin, scale)
		corners.sort_custom(func(p: Vector2, q: Vector2) -> bool:
			return _nearest(p, doors) > _nearest(q, doors))
		var c: Vector2 = corners[clampi(slot, 0, 3)]
		return Vector3(c.x, floor_index * FLOOR_HEIGHT, c.y)
	return Vector3.ZERO


static func _door_points(room: Array, origin: Vector2, scale: float) -> Array:
	var points: Array = []
	var a := (Vector2(room[1], room[2]) - origin) * scale
	var b := (Vector2(room[3], room[4]) - origin) * scale
	var mid := (a + b) * 0.5
	for token: String in String(room[5]).split(" ", false):
		var side := token.substr(0, 1).to_upper()
		var pos_px := token.substr(1).to_float() if token.length() > 1 else -1.0
		var at := (Vector2(pos_px, pos_px) - origin) * scale
		match side:
			"N": points.append(Vector2(mid.x if pos_px < 0 else at.x, a.y))
			"S": points.append(Vector2(mid.x if pos_px < 0 else at.x, b.y))
			"W": points.append(Vector2(a.x, mid.y if pos_px < 0 else at.y))
			"E": points.append(Vector2(b.x, mid.y if pos_px < 0 else at.y))
	return points


static func _nearest(p: Vector2, points: Array) -> float:
	var best := INF
	for q: Vector2 in points:
		best = minf(best, p.distance_to(q))
	return best
