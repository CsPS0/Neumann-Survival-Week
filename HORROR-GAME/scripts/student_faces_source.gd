extends RefCounted
## Picks the named-student roster: the real one (scripts/student_faces_local.gd, gitignored, real names and photo paths in
## assets/faces_local/) when it exists, else the committed scripts/student_faces_placeholder.gd with invented names and
## generated faces, so a fresh clone still opens and runs.

const REAL := "res://scripts/student_faces_local.gd"
const PLACEHOLDER := "res://scripts/student_faces_placeholder.gd"

static var _roster: GDScript


static func roster() -> GDScript:
	if _roster == null:
		_roster = load(REAL if ResourceLoader.exists(REAL) else PLACEHOLDER)
	return _roster
