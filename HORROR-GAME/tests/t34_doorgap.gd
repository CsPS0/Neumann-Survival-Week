extends SceneTree
## Door gap: no NPC may park in a doorway (opening +-0.9 m) and the player's capsule must fit through every open
## door while NPCs stand at their stations in lessons, breaks, before school and after hours.
var fails := 0
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

const CampaignScript := preload("res://scripts/campaign.gd")
const Lessons := preload("res://scripts/lessons.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const TeacherScript := preload("res://scripts/teacher_npc.gd")

var main: Node
var doors: Array = []   ## [door, opening centre, along, normal, half width]
var parked_total := 0
var blocked_total := 0
var parked_names := {}

func _fresh() -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	m.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	m._start_game()
	await create_timer(0.3).timeout
	return m

func _npcs() -> Array:
	var out: Array = []
	for g in ["teachers", "ambient_staff", "porta", "caretaker"]:
		for n in get_nodes_in_group(g):
			if is_instance_valid(n) and not n.is_queued_for_deletion() and n is CharacterBody3D:
				out.append(n)
	return out

## Local (along, normal) offset of `p` from door `d`'s opening centre, or null when on another floor.
func _local(d: Array, p: Vector3) -> Variant:
	var c: Vector3 = d[1]
	if absf(p.y - c.y) > 1.5:
		return null
	var off := p - c
	return Vector2(off.dot(d[2]), off.dot(d[3]))

func _in_zone(d: Array, p: Vector3, r: float) -> bool:
	var l: Variant = _local(d, p)
	return l != null and absf(l.x) < float(d[4]) + r and absf(l.y) < 0.9 + r

## Player capsule (r 0.4) swept through the opening along the normal; any of three lateral lanes clear = passable.
func _passable(d: Array, mask: int) -> bool:
	var space: PhysicsDirectSpaceState3D = main.player.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = mask
	var skip: Array[RID] = [main.player.get_rid()]
	if not d[0].is_open:
		skip.append(d[0].get_rid())   # a closed door is opened by the player; only people count
	q.exclude = skip
	for lane in [-0.15, 0.0, 0.15]:
		var start: Vector3 = d[1] + d[2] * lane - d[3] * 0.7 + Vector3(0.0, 1.0, 0.0)
		q.transform = Transform3D(Basis(), start)
		q.motion = d[3] * 1.4
		var res := space.cast_motion(q)
		if res[0] >= 1.0:
			return true
	return false

func _collect_doors() -> void:
	doors.clear()
	# Classrooms are locked all day now. The doorway geometry is the same, so locked doors count too: a closed door is
	# not an obstacle in _passable and only NPCs standing in the opening do. Doors of the closed demo rooms never open
	# for anybody, so nobody walks through them and they are skipped.
	for door in get_nodes_in_group("doors"):
		if door.key_id == "__demo__":
			continue
		var along: Vector3 = Basis(Vector3.UP, door._closed_yaw) * Vector3.RIGHT
		var centre: Vector3 = door.global_position + along * (door.width * 0.5)
		doors.append([door, centre, along, along.cross(Vector3.UP).normalized(), door.width * 0.5])

## Let the NPCs settle for `settle` s, then sample for `window` s.
func _scenario(label: String, minutes: float, at: Vector3, settle := 8.0, window := 6.0) -> void:
	main.daynight.minutes = minutes
	main.player.global_position = at + Vector3(0.0, 0.1, 0.0)
	main.player.velocity = Vector3.ZERO
	main.staff_manager.sync_now()
	await create_timer(settle).timeout
	main.daynight.minutes = minutes   # hold the phase
	var samples := 0
	var in_zone := {}     # npc -> count
	var first_pos := {}
	var blocked := {}     # door index -> count
	var t := 0.0
	while t < window:
		samples += 1
		for n in _npcs():
			if not first_pos.has(n):
				first_pos[n] = n.global_position
			for i in doors.size():
				if _in_zone(doors[i], n.global_position, 0.3):
					in_zone[n] = int(in_zone.get(n, 0)) + 1
					break
		for i in doors.size():
			var d: Array = doors[i]
			var near := false
			for n in _npcs():
				if _in_zone(d, n.global_position, 0.3):
					near = true
			if near and _passable(d, 1 | 8) and not _passable(d, 41):
				blocked[i] = int(blocked.get(i, 0)) + 1
		main.player.global_position = at + Vector3(0.0, 0.1, 0.0)
		await create_timer(0.5).timeout
		t += 0.5
	var parked := 0
	for n in in_zone:
		if not is_instance_valid(n):
			continue
		var moved: float = n.global_position.distance_to(first_pos[n])
		if in_zone[n] >= samples * 0.8 and moved < 0.5:
			parked += 1
			parked_names["%s @ %s" % [n.npc_name, label]] = true
			print("  PARKED %s (%s) at %s" % [n.npc_name, label, str(n.global_position)])
	var stuck_doors := 0
	for i in blocked:
		if blocked[i] >= samples * 0.8:
			stuck_doors += 1
			print("  BLOCKED door %s at %s (%s)" % [doors[i][0].name, str(doors[i][1]), label])
	parked_total += parked
	blocked_total += stuck_doors
	print("SCEN %-26s npcs=%d parked=%d blocked_doors=%d" % [label, _npcs().size(), parked, stuck_doors])

func _run() -> void:
	main = await _fresh()
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	_collect_doors()
	print("doors: %d" % doors.size())
	check(doors.size() > 30, "doors found")

	# Static rule first: no station or route stop of any NPC kind lies in a doorway.
	var bad_stops := 0
	for n in _npcs() + get_nodes_in_group("csoki"):
		for p: Vector3 in n.route:
			for d in doors:
				if _in_zone(d, p, 0.3):
					bad_stops += 1
					print("  ROUTE STOP in doorway: %s %s" % [n.npc_name, str(p)])
	check(bad_stops == 0, "route stops in doorways: %d" % bad_stops)

	var spots: Array = [["hall", main._room_centre(0, "Bejárat")]]
	for f in FloorData.FLOORS.size():
		for poly: Array in FloorData.FLOORS[f]["corridors"]:
			var data: Dictionary = FloorData.FLOORS[f]
			var w: Vector2 = ((poly[poly.size() / 2] as Vector2) - (data["origin"] as Vector2)) * float(data["scale"])
			spots.append(["corr%d" % f, Vector3(w.x, f * 4.0, w.y)])
	var day: int = main.campaign.day
	for i in CampaignScript.LESSONS:
		var subject: String = Lessons.subject_at(day, i)
		var room: Vector3 = main._room_centre(Lessons.floor_of(subject), Lessons.room_of(subject))
		await _scenario("lesson%d %s" % [i, Lessons.room_of(subject)], CampaignScript.lesson_start(i) + 5.0, room)
		var s: Array = spots[i % spots.size()]
		await _scenario("lesson%d %s" % [i, s[0]], CampaignScript.lesson_start(i) + 20.0, s[1])
		await _scenario("break%d %s" % [i, s[0]], CampaignScript.lesson_end(i) + 2.0, s[1])
	await _scenario("pre hall", CampaignScript.FIRST_BELL - 20.0, spots[0][1])
	await _scenario("after hall", CampaignScript.LAST_BELL + 3.0, spots[0][1])

	# Door race: a door closed on an NPC standing in its swing must not hold the NPC.
	var swing_doors: Array = doors.filter(func(x: Array) -> bool: return not x[0].locked)
	var d: Array = swing_doors[0]
	var probe := TeacherScript.new()
	probe.ambient = true
	probe.npc_name = "Probe"
	probe.path_offset = main._nav_offset
	var target: Vector3 = d[1] + d[3] * 3.0
	var route: Array[Vector3] = [target]
	probe.route = route
	probe.position = d[1] - d[3] * 0.6 + Vector3(0, 0.1, 0)
	main.add_child(probe)
	await create_timer(0.3).timeout
	probe.set_station(target)
	d[0].set_open(false)
	await create_timer(6.0).timeout
	check(Vector2(probe.global_position.x - target.x, probe.global_position.z - target.z).length() < 1.5,
			"NPC behind a closing door still walks through (at %s)" % str(probe.global_position))
	probe.queue_free()

	print("TOTAL parked=%d blocked=%d" % [parked_total, blocked_total])
	check(parked_total == 0, "NPCs parked in doorways: %d %s" % [parked_total, str(parked_names.keys())])
	check(blocked_total == 0, "doors blocked to the player: %d" % blocked_total)
	var path: String = main.profile.path
	main.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
