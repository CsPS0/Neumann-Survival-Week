extends RefCounted
## The 21 classes (grades 9-13 with four classes each, plus the language-prep class 9.ny), their sizes and which
## classroom each one is in during a lesson. Deterministic per day and lesson. Data and pure functions only.

const FloorData := preload("res://scripts/floor_data.gd")
const Rooms := preload("res://scripts/rooms.gd")

const CLASSES := [
	"9.a", "9.b", "9.c", "9.d", "9.ny", "10.a", "10.b", "10.c", "10.d", "11.a", "11.b", "11.c", "11.d",
	"12.a", "12.b", "12.c", "12.d", "13.a", "13.b", "13.c", "13.d",
]
const PLAYER_CLASS := "11.a"
## Open rooms that hold the story (key crate, lab, fuse box, staff clue, safe, after-hours clue rooms): no class sits there.
const STORY := ["5", "14", "24", "33", "229", "205", "GT8", "114"]
const MIN_AREA := 30.0   ## m2: smaller rooms cannot seat a class.


static func size_of(id: String) -> int:
	if id == PLAYER_CLASS:
		return 25   # 24 classmates and the player
	if id == "9.ny":
		return 15 + absi(hash(id)) % 4
	return 25 + absi(hash(id)) % 6


## Every ordinary classroom: [floor, label], in a stable order.
static func classrooms() -> Array:
	var rooms: Array = []
	for f in FloorData.FLOORS.size():
		var seen := {}
		for room: Array in FloorData.FLOORS[f]["rooms"]:
			var label: String = room[0]
			var type := Rooms.type_of(label)
			if (type != "normal" and type != "computer") or STORY.has(label) or seen.has(label):
				continue
			seen[label] = true
			var rect := FloorData.room_rect(f, label)
			if rect.size.x * rect.size.y >= MIN_AREA:
				rooms.append([f, label])
	return rooms


## class id -> [floor, label]. The player's class sits in `player_room`; every other class gets its own room.
static func assign(day: int, lesson: int, player_room: Array) -> Dictionary:
	var pool: Array = []
	for room: Array in classrooms():
		if room != player_room:
			pool.append(room)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, lesson])
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Array = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var result := {}
	var next := 0
	for id: String in CLASSES:
		if id == PLAYER_CLASS:
			result[id] = player_room
		else:
			result[id] = pool[next]
			next += 1
	return result
