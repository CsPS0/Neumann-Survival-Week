extends Node
## Ambient background teachers: at most MAX_AMBIENT real-name teachers exist at once, only near the player and only on
## school days (before school, in lessons, in breaks). Lessons: the teacher of each nearby class stands in that class's
## room (the class's homeroom teacher where it has one). Breaks: each walks one corridor polyline. They never talk.

static var Staff: GDScript = preload("res://scripts/staff_source.gd").roster()
const Classes := preload("res://scripts/classes.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const Lessons := preload("res://scripts/lessons.gd")
const CampaignScript := preload("res://scripts/campaign.gd")
const TeacherScript := preload("res://scripts/teacher_npc.gd")

const MAX_AMBIENT := 8
const NEAR := 30.0
const FLOOR_HEIGHT := 4.0

var player: Node3D
var campaign: Node
var daynight: Node
var nav_offset := 0.3
var exit_point := Vector3.ZERO
var avoid: Array[Vector3] = []   ## Spots an ambient teacher must not stand on (main's clue spots and the form table).

var _timer := 0.0
var _last_key := ""


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		sync_now()


func ambient_count() -> int:
	var n := 0
	for t in get_tree().get_nodes_in_group("ambient_staff"):
		if not t.is_queued_for_deletion():
			n += 1
	return n


func sync_now() -> void:
	if campaign == null or daynight == null or player == null:
		return
	var phase := CampaignScript.phase_at(daynight.minutes, campaign.day)
	var school: bool = campaign.day <= CampaignScript.LAST_SCHOOL_DAY and (phase == "pre" or phase == "lesson" or phase == "break")
	var lesson := CampaignScript.lesson_at(daynight.minutes)
	var key := "%s|%d|%d|%d" % [phase, lesson, campaign.day, roundi(player.global_position.y / FLOOR_HEIGHT)]
	var rebuild := key != _last_key
	_last_key = key
	if rebuild:
		_clear()
	if not school:
		return
	if not rebuild:
		# Position only: drop the far ones, keep the rest walking, top up the missing.
		for t in get_tree().get_nodes_in_group("ambient_staff"):
			if t.global_position.distance_to(player.global_position) > NEAR + 10.0:
				t.remove_from_group("ambient_staff")
				t.queue_free()
	var used := {}
	var live := {}
	for t in get_tree().get_nodes_in_group("ambient_staff"):
		used[t.npc_name] = true
		live[t.get_meta("slot")] = true
	var wanted: Array[Dictionary] = _wanted(phase, lesson, used, live)
	for spec in wanted:
		if ambient_count() >= MAX_AMBIENT:
			break
		_spawn(spec)


func _clear() -> void:
	for t in get_tree().get_nodes_in_group("ambient_staff"):
		t.remove_from_group("ambient_staff")   # queue_free alone keeps it listed until the frame ends.
		t.queue_free()


## Up to MAX_AMBIENT placements near the player: {name, role, floor, station (Vector3 or INF), route}.
func _wanted(phase: String, lesson: int, used: Dictionary, live: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([campaign.day, lesson, phase])
	var here := player.global_position
	if phase == "lesson" and lesson >= 0:
		var subject: String = Lessons.subject_at(campaign.day, lesson)
		var assignment := Classes.assign(campaign.day, lesson, [Lessons.floor_of(subject), Lessons.room_of(subject)])
		var near: Array = []
		for id: String in assignment:
			if id == Classes.PLAYER_CLASS:
				continue   # a suspect teaches the player's class
			var room: Array = assignment[id]
			var rect := FloorData.room_rect(room[0], room[1])
			var centre := Vector3(rect.get_center().x, room[0] * FLOOR_HEIGHT, rect.get_center().y)
			for spot: Vector3 in avoid:
				if Vector2(spot.x - centre.x, spot.z - centre.z).length() < 1.2 and absf(spot.y - centre.y) < FLOOR_HEIGHT * 0.5:
					centre += (Vector3.RIGHT if rect.size.x >= rect.size.y else Vector3.BACK) * 1.5   # along the longer axis, still inside the room
					break
			if absf(here.y - centre.y) <= FLOOR_HEIGHT + 1.0 and here.distance_to(centre) <= NEAR:
				near.append([here.distance_to(centre), id, centre])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for entry: Array in near:
			if live.has(entry[1]):
				continue
			var person := _person_for(entry[1], used, rng)
			if person.is_empty():
				continue
			out.append({"name": person[0], "role": person[1], "floor": roundi((entry[2] as Vector3).y / FLOOR_HEIGHT),
					"station": (entry[2] as Vector3) + Vector3(0.0, 0.1, 0.0), "route": [], "slot": entry[1]})
	else:
		var lines: Array = []
		for f in FloorData.FLOORS.size():
			if absf(f * FLOOR_HEIGHT - here.y) > FLOOR_HEIGHT + 1.0:
				continue
			var data: Dictionary = FloorData.FLOORS[f]
			for poly: Array in data["corridors"]:
				if poly.size() < 2:
					continue
				var gap := INF
				for v: Vector2 in poly:
					var w := _world(f, v)
					gap = minf(gap, Vector2(here.x - w.x, here.z - w.z).length())
				lines.append([gap, f, poly, "%d:%s" % [f, str(poly[0])]])
		lines.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for line: Array in lines:
			if live.has(line[3]) or (line[0] as float) > NEAR + 10.0:
				continue
			var person := _person_for("", used, rng)
			if person.is_empty():
				continue
			out.append({"name": person[0], "role": person[1], "floor": line[1], "station": Vector3.INF, "route": line[2], "slot": line[3]})
	return out


func _world(f: int, p: Vector2) -> Vector3:
	var data: Dictionary = FloorData.FLOORS[f]
	var w: Vector2 = (p - (data["origin"] as Vector2)) * float(data["scale"])
	return Vector3(w.x, f * FLOOR_HEIGHT, w.y)


## E-prompt label of a roster role: "teacher" for the subject teachers, else director / deputy / support.
static func label_of(role: String) -> String:
	return "teacher" if role in ["specialist", "teacher"] else role


## The homeroom teacher of the class (or a random roster person) not used yet: [name, role label].
func _person_for(class_id: String, used: Dictionary, rng: RandomNumberGenerator) -> Array:
	var who: String = Staff.homeroom_teacher(class_id)
	if who == "" or used.has(who):
		var pool: Array = []
		for p: Array in Staff.ROSTER:
			if p[1] != "support" and not used.has(p[0]) and p[3] == "":
				pool.append(p)
		if pool.is_empty():
			return []
		var pick: Array = pool[rng.randi() % pool.size()]
		who = pick[0]
	used[who] = true
	for p: Array in Staff.ROSTER:
		if p[0] == who:
			var role: String = p[1]
			return [who, label_of(role)]
	return []


func _spawn(spec: Dictionary) -> void:
	var f: int = spec["floor"]
	var station: Vector3 = spec["station"]
	var teacher := TeacherScript.new()
	teacher.ambient = true
	teacher.set_meta("slot", spec["slot"])
	teacher.npc_id = "ambient_%s" % spec["name"]
	teacher.npc_name = spec["name"]
	teacher.role_label = spec["role"]
	teacher.shirt_colour = Color.from_hsv(float(absi(hash(spec["name"])) % 100) / 100.0, 0.35, 0.5)
	teacher.path_offset = nav_offset
	teacher.exit_point = exit_point
	var route: Array[Vector3] = []
	if station.is_finite():
		route.append(station)
		teacher.position = station
	else:
		for p: Vector2 in spec["route"]:
			route.append(_world(f, p))
		var start := route[0]   # the vertex nearest the player: never spawned beyond the keep distance
		for v: Vector3 in route:
			if Vector2(v.x - player.global_position.x, v.z - player.global_position.z).length() < Vector2(start.x - player.global_position.x, start.z - player.global_position.z).length():
				start = v
		teacher.position = start + Vector3(0.0, 0.1, 0.0)
	teacher.route = route
	get_parent().add_child(teacher)
	if station.is_finite():
		teacher.set_station(station)
