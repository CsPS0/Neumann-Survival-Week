extends RefCounted
## Roster helpers for the tests. They work with both the real scripts/staff.gd and the committed placeholder,
## so the tests pass on a fresh clone as well as on the owner's PC.

const REAL := "res://scripts/staff.gd"


static func has_real_file() -> bool:
	return ResourceLoader.exists(REAL)


static func roster() -> GDScript:
	return preload("res://scripts/staff_source.gd").roster()


static func roster_names() -> Array:
	var out: Array = []
	for p: Array in roster().ROSTER:
		out.append(p[0])
	return out


static func is_real_name(person: String) -> bool:
	return roster_names().has(person)


## Family name: names are written surname first, a leading "Dr" or "Dr." is dropped.
static func surname(person: String) -> String:
	var parts := person.split(" ", false)
	if parts.size() > 0 and parts[0].trim_suffix(".") == "Dr":
		parts.remove_at(0)
	return parts[0] if parts.size() > 0 else ""
