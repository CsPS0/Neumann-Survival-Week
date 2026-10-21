extends RefCounted
## Picks the named-student roster: the real one (scripts/student_faces_local.gd, gitignored, real names and photo paths in
## assets/faces_local/) when it exists, else the committed scripts/student_faces_placeholder.gd with invented names and
## generated faces, so a fresh clone still opens and runs.

## Off: the build has no named students at all, with or without the local files. The crowd fills their seats and
## walking slots. Turn it on to bring back the two photo students (or the invented placeholder pair).
const NAMED_STUDENTS := false
const NONE := "res://scripts/student_faces_none.gd"
const REAL := "res://scripts/student_faces_local.gd"
const PLACEHOLDER := "res://scripts/student_faces_placeholder.gd"

static var _roster: GDScript


static func roster() -> GDScript:
	if _roster == null:
		if not NAMED_STUDENTS:
			_roster = load(NONE)
		else:
			_roster = load(REAL if ResourceLoader.exists(REAL) else PLACEHOLDER)
	return _roster
