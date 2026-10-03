extends RefCounted
## The eight endings: title, colour and closing text.

const COUNT := 8
const LIST := {
	1: {"title": "Caught", "colour": Color(0.9, 0.2, 0.2),
		"text": "It was never a ghost. It was someone who knew your name.\nThe school keeps one more student."},
	2: {"title": "Banished", "colour": Color(0.5, 1.0, 0.6),
		"text": "The bell rings once and the whispers stop.\nThe school is free. Nobody asks what happened to the teacher."},
	3: {"title": "Expelled", "colour": Color(1.0, 0.75, 0.3),
		"text": "Your parents are called. The investigation ends at the front gate.\nSomething in the building is relieved."},
	4: {"title": "Top student", "colour": Color(0.4, 0.8, 1.0),
		"text": "Perfect marks, a banished demon and a school that finally sleeps.\nThe principal calls it a record year."},
	5: {"title": "Ran away", "colour": Color(0.8, 0.8, 0.85),
		"text": "You walk out and keep walking. You will never know who it was.\nThe school stays open."},
	6: {"title": "Pact", "colour": Color(0.75, 0.3, 0.9),
		"text": "The deal is simple: it leaves you alone, you leave it the school.\nYou graduate on time."},
	7: {"title": "Overtime", "colour": Color(0.6, 0.6, 0.5),
		"text": "The week ends without an answer. Monday comes.\nThe corridors are still listening."},
	8: {"title": "Wrong person", "colour": Color(1.0, 0.4, 0.5),
		"text": "You point at the wrong teacher and the whole school sees it.\nThe real one smiles from the back of the room."},
}
