extends Node
## The phone's day tasks. Pure state derived from porta and finds; text only.

const OPENING := "Monday at the Neumann school. A normal morning, a normal timetable. Go to your lessons and enjoy the calm."

var porta: Node
var finds: Node
var campaign: Node


func _ready() -> void:
	add_to_group("tasks")


func is_done(id: String) -> bool:
	match id:
		"card":
			return porta != null and porta.card_renewed
		"lab":
			return finds != null and finds.found.has("lab1") and finds.found.has("lab2") and finds.found.has("lab3")
	return false


## Day 1 starts with the opening text (the phone draws it wrapped).
func lines(day: int) -> Array[String]:
	var out: Array[String] = []
	if day == 1:
		out.append(OPENING)
		out.append("%s Get the sticker for your student card (it expires tonight)" % _mark("card"))
		out.append("    ask Mr. Bakó at the Porta; he wants a signed form from a classroom on the 1st floor")
		if campaign != null and campaign.incident:
			out.append("[!] An explosion shook Lab 14 and the school is closed")
			out.append("%s Find out what happened in Lab 14" % _mark("lab"))
			out.append("    go home through the front door, or stay and risk the caretaker")
	else:
		if porta != null and not porta.card_valid:
			out.append("[!] Card expired: the porter lends nothing")
		out.append("%s Find out what happened in Lab 14" % _mark("lab"))
	return out


func _mark(id: String) -> String:
	return "[x]" if is_done(id) else "[ ]"
