extends RefCounted
## Picks the staff roster script: the real one (scripts/staff.gd, gitignored, 79 real names) when it exists, else the
## committed scripts/staff_placeholder.gd with invented names, so a fresh clone still opens and runs.

const REAL := "res://scripts/staff.gd"
const PLACEHOLDER := "res://scripts/staff_placeholder.gd"

static var _roster: GDScript


static func roster() -> GDScript:
	if _roster == null:
		_roster = load(REAL if ResourceLoader.exists(REAL) else PLACEHOLDER)
	return _roster
