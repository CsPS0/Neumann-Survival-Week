extends RefCounted
## Data behind the phone app Neumann Diákhirdetmények, the student notice board. One post list that grows by day:
## "LOST" posts hint at where a collectible lies (the room is read from finds.gd, so the hint can never drift from the
## game) and turn into "FOUND" once the player has it, "NEWS" posts add lore. Invented text only: no real person is named.

const Finds := preload("res://scripts/finds.gd")

const FLOOR_NAMES := ["ground floor", "1st floor", "2nd floor"]

## [day, tag, title, text, find id]. `text` may hold one %s for the place. Find id "" for news posts.
const POSTS := [
	[1, "NEWS", "Welcome to the new week",
		"The notice board is back on the phone. Post lost items, found items and questions here. No selling, no gossip about teachers.", ""],
	[1, "LOST", "Red rubber bone",
		"Csoki's bone is gone again. Last seen around: %s. Reward: his gratitude.", "toy"],
	[1, "LOST", "Old cassette",
		"A cassette from the school radio days. Someone left it in a locker. Place: %s. Do not play side B.", "tape"],
	[1, "LOST", "Collector card of a teacher",
		"The class swapped these cards for a month, one is still missing. Place: %s.", "card_karpati"],
	[1, "LOST", "Collector card of a teacher",
		"Dropped on the way to the canteen, I think. Place: %s.", "card_szentgyorgyi"],
	[1, "LOST", "Coach's notebook page",
		"A page of the coach's log fell out of the folder. Place: %s. Please hand it in.", "gym1"],
	[1, "LOST", "Printout from the server room",
		"A strip of log paper, nobody knows whose. Place: %s.", "com1"],
	[1, "NEWS", "Csoki is looking for a new hiding spot",
		"The school dog was seen sleeping in a different room every day. Please do not lock him in.", ""],

	[2, "NEWS", "Lab 14 is sealed",
		"After yesterday's bang the lab door was fixed by someone nobody saw. The chemistry club members are unreachable.", ""],
	[2, "NEWS", "Many people are ill",
		"Cold hands, long sleep, bad dreams. The nurse says it is not the flu. The nurse looks tired too.", ""],
	[2, "LOST", "Tiny drawing",
		"I found a tiny drawing of a robot chameleon. Is it yours? Place: %s.", "drawing"],
	[2, "LOST", "Collector card of a teacher",
		"The one who hugs the transformer. Place: %s.", "card_halmos"],
	[2, "LOST", "Graffiti worth reading",
		"Somebody wrote a warning on the wall. Place: %s. I did not write it.", "wc1"],
	[2, "LOST", "Torn diary page",
		"A diary page, written in a hurry, no name on it. Place: %s.", "cls1"],
	[2, "LOST", "Server printout",
		"Another strip of log paper. The badge reader logs a card that should be locked up. Place: %s.", "com2"],

	[3, "NEWS", "Test day",
		"Every lesson is a test. Do not leave the room during the test. People who walked the corridor alone heard footsteps behind them.", ""],
	[3, "NEWS", "New student cards",
		"The Porta hands out new cards today. The old ones expire at midnight. The porter wants a form signed in a classroom on the 1st floor.", ""],
	[3, "LOST", "Message on the mirror",
		"The steam wrote it, not me. Place: %s.", "mirror"],
	[3, "LOST", "Collector card of a teacher",
		"The one with a poem for every weather. Place: %s.", "card_voros"],
	[3, "LOST", "Collector card of a teacher",
		"She corrects the vending machine's grammar. Place: %s.", "card_pasztor"],
	[3, "LOST", "Torn note",
		"A torn note about the Porta and a key. Place: %s.", "wc2"],
	[3, "LOST", "Second diary page",
		"This one says the thing learned to look like a teacher. Place: %s.", "cls2"],
	[3, "LOST", "Coach's second page",
		"A girl fainted on the last lap and told the coach something. Page lost. Place: %s.", "gym2"],

	[4, "NEWS", "The school is closed",
		"Nobody answers the phone at the office. The doors are open, the lights are not. Whoever stays, stays together.", ""],
	[4, "LOST", "Club photo",
		"A photo of the chemistry club, someone scratched out a face. Place: %s.", "photo"],
	[4, "LOST", "Collector card of a teacher",
		"His hoodie is on the card too. Place: %s.", "card_onodi"],
	[4, "LOST", "Collector card of a teacher",
		"The school wifi is his pet. Place: %s.", "card_fekete"],
	[4, "LOST", "Server printout",
		"The backup restored a file that reappears every night. Place: %s.", "com3"],

	[5, "NEWS", "Last notice",
		"The board has no moderator anymore. Final tip: salt, holy water and a bell. Everything else is in your clues.", ""],
	[5, "LOST", "Collector card of a teacher",
		"He knows every battle and none of his birthdays. Place: %s.", "card_lazar"],
]


## "room 33, ground floor", "the Tornaterem, ground floor", "the toilets, 1st floor".
static func place(find_id: String) -> String:
	var data := Finds.entry(find_id)
	var room: String = data["room"]
	var where := "the toilets" if room == "WC" else ("the " + room if room == "Tornaterem" else "room " + room)
	return "%s, %s" % [where, FLOOR_NAMES[int(data["floor"])]]


## Posts visible on `day`, newest day first (list order inside a day). Each: {day, tag, title, text, find, found}.
## `found` is a Dictionary id -> true (finds.found). A LOST post whose item has been picked up reads FOUND.
static func posts(day: int, found: Dictionary) -> Array:
	var out: Array = []
	for p: Array in POSTS:
		if int(p[0]) > day:
			continue
		var id: String = p[4]
		var is_found := id != "" and found.has(id)
		var text: String = p[3] % place(id) if id != "" else p[3]
		out.append({"day": p[0], "tag": "FOUND" if is_found else p[1], "title": p[2], "text": text, "find": id,
				"found": is_found, "index": out.size()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["day"]) > int(b["day"]) or (a["day"] == b["day"] and int(a["index"]) < int(b["index"])))
	return out
