extends RefCounted
## What every room on the plans is used for. Data only. In the demo only `other` rooms are closed.

const DEMO_MESSAGE := "Not available in the demo."

const NORMAL := ["5", "14", "23", "24", "28", "33", "35", "42", "43", "44", "45", "46", "109", "113", "114", "120", "121",
		"125", "129", "133", "205", "225", "229", "233"]
const GYM := ["27", "Tornaterem"]
const ENTRANCE := ["Bejárat", "Porta"]
## Fixed story rooms (all normal rooms, none of them a lesson room).
const STORY_ROOMS := {"fuse": "24", "safe": "229", "staff_clue": "33", "lab": "14"}


static func type_of(label: String) -> String:
	if NORMAL.has(label):
		return "normal"
	if label.begins_with("GT"):
		return "computer"
	if label == "WC":
		return "wc"
	if GYM.has(label):
		return "gym"
	if ENTRANCE.has(label):
		return "entrance"
	return "other"


static func is_open(label: String) -> bool:
	return type_of(label) != "other"
