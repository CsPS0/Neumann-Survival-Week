extends Node
## Maps campaign events to achievements and persists them through Profile.

signal unlocked(id: String)

const LIST := {
	"first_day": ["First Day", "Finish day 1 and go home."],
	"model_student": ["Model Student", "Attend all 7 lessons in one day."],
	"straight_a": ["Straight A", "Answer every question right on a day with all 7 lessons attended."],
	"early_bird": ["Early Bird", "Be in the first lesson's room before 07:00."],
	"night_owl": ["Night Owl", "Stay after dark and still make it home."],
	"detective": ["Detective", "Find all 9 clues."],
	"right_suspect": ["Right Suspect", "Name the entity correctly."],
	"close_call": ["Close Call", "Black out, then make it to the next lesson."],
	"ending_1": ["Caught", "Reach ending 1."],
	"ending_2": ["Exorcist", "Reach ending 2."],
	"ending_3": ["Expelled", "Reach ending 3."],
	"ending_4": ["Valedictorian", "Reach ending 4."],
	"ending_5": ["Runaway", "Reach ending 5."],
	"ending_6": ["Dealmaker", "Reach ending 6."],
	"ending_7": ["Overtime", "Reach ending 7."],
	"ending_8": ["Wrong Call", "Reach ending 8."],
	"completionist": ["Completionist", "See all 8 endings."],
	"out_of_breath": ["Out of Breath", "Run out of stamina 10 times."],
	"good_boy": ["Good Boy", "Pet Csoki."],
	"archivist": ["Archivist", "Read all 12 story pages."],
	"everything_found": ["Everything Found", "Find all 5 hidden secrets."],
	"full_deck": ["Full Deck", "Collect all 8 teacher cards."],
	"key_collector": ["Key Collector", "Borrow 5 different keys."],
	"sticky_fingers": ["Sticky Fingers", "Steal the key to Lab 14."],
	"mecha_master": ["Mecha Master", "Find all 5 neu_mecha chameleons."],
}

var profile: Node


func on_event(event_name: String, data: Dictionary) -> void:
	match event_name:
		"day_started":
			if data.get("day", 0) == 2:
				_unlock("first_day")
		"ending":
			var id := int(data.get("id", 0))
			if not LIST.has("ending_%d" % id):
				return
			profile.mark_ending(id)
			_unlock("ending_%d" % id)
			if profile.endings_seen.size() >= 8:
				_unlock("completionist")
		_:
			# Only ids that are not triggered by the cases above; ending_* and completionist are not events.
			if LIST.has(event_name) and not event_name.begins_with("ending_") and event_name != "completionist" \
					and event_name != "first_day":
				_unlock(event_name)


func _unlock(id: String) -> void:
	if profile.unlock(id):
		unlocked.emit(id)
