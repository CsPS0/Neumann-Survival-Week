extends Node3D
## Student crowd: ONE MultiMeshInstance3D pair (bodies and heads), no per-student node, no navigation.
## The named students of scripts/student_faces_source.gd (two, with a photo face) are the exception: each takes one seat
## of the player's class in lessons and one walking slot in breaks, and is drawn by its own photo_student.gd node.
## Collision: a small pool of capsule bodies follows the students closest to the player, so nobody can be walked through.
## In a lesson the classes near the player sit in their classrooms; in a break they walk the corridors (corridor flow, culling and panic).
## Polls the campaign clock twice a second. Hunt days, after hours and the far side of the school show nobody.

const Classes := preload("res://scripts/classes.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const Lessons := preload("res://scripts/lessons.gd")
const CampaignScript := preload("res://scripts/campaign.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")
const Outbreak := preload("res://scripts/outbreak.gd")
const StudentModel := preload("res://scripts/student_model.gd")
const PhotoStudentScript := preload("res://scripts/photo_student.gd")
static var Faces: GDScript = preload("res://scripts/student_faces_source.gd").roster()

const MAX_CROWD := 150
const NEAR := 35.0           ## Only classrooms and corridors within this many metres (and one floor) are drawn.
const FLOOR_HEIGHT := 4.0
const PLAYER_CLEAR := 1.0    ## Nobody is seated within this radius of the player.
const TABLE_CLEAR := 0.9     ## ... or of a clue table.
const FLOW_SPEED := Vector2(1.1, 1.8)
const PANIC_RADIUS := 25.0
const FLOW_CLEAR := 0.5      ## A walker closer than this to the camera is not drawn (the collision keeps students further out).
const COLLIDE_LAYER := 128   ## Layer 8: only the player's mask contains it, so rays, the entity and the navmesh ignore it.
const COLLIDE_POOL := 8      ## Capsule bodies shared by all students; the closest ones to the player get one.
const COLLIDE_RANGE := 2.5   ## Metres: only students this close (horizontally) need a body.
const COLLIDE_RADIUS := 0.28
const COLLIDE_HEIGHT := 1.5
const PARKED := Vector3(0.0, -1000.0, 0.0)
const NAMED_CHAIRS := [6, 13]   ## Chair indices (front rows first) of the player's class that the named students take.
const NAMED_WALKERS := [3, 9]   ## Walking slot indices that the named students take in a break.

var player: Node3D
var entity: Node3D
var campaign: Node
var daynight: Node
var hidden := false:   ## True: draw nobody (scare flash).
	set(value):
		hidden = value
		_last_key = ""
		_dirty = true
var avoid: Array[Vector3] = []   ## Table positions to keep seats away from (main's clue and find tables).
var seats := {}   ## "floor:label" -> chairs of that classroom ({pos, yaw}), from main's furniture.

var _body_mm := MultiMesh.new()   ## Body, clothes, head and hair in one mesh, animated by the shader.
var _slots: Array[Dictionary] = []   ## {kind: "seat"|"flow", pos: Vector3, yaw: float, colour: Color, ...}
var _drawn: Array[Dictionary] = []   ## The subset actually drawn this frame (counts read this).
var _shown := 0
var _timer := 0.0
var _last_key := ""
var _visible: Array[Dictionary] = []   ## Reused every frame.
var _dirty := false
var _moving := false
var _panicked := 0
var _screamed := false
var _scream := AudioStreamPlayer3D.new()
var _bodies: Array[StaticBody3D] = []
var _named: Array[PhotoStudentScript] = []   ## One photo_student.gd node per roster entry.
var _last_awake := false


func _ready() -> void:
	_body_mm.transform_format = MultiMesh.TRANSFORM_3D
	_body_mm.use_colors = true
	_body_mm.use_custom_data = true
	_body_mm.mesh = StudentModel.mesh()
	_body_mm.instance_count = MAX_CROWD
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _body_mm
	instance.material_override = StudentModel.material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-200.0, -20.0, -200.0), Vector3(400.0, 60.0, 400.0))
	add_child(instance)
	_body_mm.visible_instance_count = 0
	_scream.max_distance = 40.0
	add_child(_scream)
	for entry: Dictionary in Faces.STUDENTS:
		var named := PhotoStudentScript.new()
		named.setup(entry)
		add_child(named)
		_named.append(named)
	var capsule := CapsuleShape3D.new()
	capsule.radius = COLLIDE_RADIUS
	capsule.height = COLLIDE_HEIGHT
	for i in COLLIDE_POOL:
		var body := StaticBody3D.new()
		body.collision_layer = COLLIDE_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		body.add_child(shape)
		add_child(body)
		body.global_position = PARKED
		_bodies.append(body)


## Gives the students nearest to the player a capsule body, parks the rest. Only the drawn students count.
func _physics_process(_delta: float) -> void:
	var here := player.global_position if player != null else PARKED
	var near: Array[Dictionary] = []
	if player != null and not hidden:
		for slot: Dictionary in _drawn:
			var pos: Vector3 = slot["pos"]
			var flat := Vector2(pos.x - here.x, pos.z - here.z).length()
			if flat <= COLLIDE_RANGE and absf(pos.y - here.y) < FLOOR_HEIGHT * 0.5:
				near.append({"pos": pos, "flat": flat})
		if near.size() > COLLIDE_POOL:
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["flat"] < b["flat"])
	for i in COLLIDE_POOL:
		if i < near.size():
			var pos: Vector3 = near[i]["pos"]
			var floor_y := roundf(pos.y / FLOOR_HEIGHT) * FLOOR_HEIGHT   # Seat positions are chair height; the body stands on the floor.
			_bodies[i].global_position = Vector3(pos.x, floor_y + COLLIDE_HEIGHT * 0.5, pos.z)
		else:
			_bodies[i].global_position = PARKED


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		sync_now()
	_advance(delta)


func shown_count() -> int:
	return _shown


func seated_count() -> int:
	return _count_kind("seat")


func flow_count() -> int:
	return _count_kind("flow")


func panicked_count() -> int:
	return _panicked


func _count_kind(kind: String) -> int:
	var n := 0
	for slot: Dictionary in _drawn:
		if slot["kind"] == kind:
			n += 1
	return n


## Recompute what is drawn from the clock and the player's position (only when something relevant changed).
## Seats depend on where the player stands (nobody sits on them); corridor walkers only on the floor, so they keep walking.
func sync_now() -> void:
	if hidden:
		_apply([])
		return
	if campaign == null or daynight == null or player == null:
		return
	var phase := CampaignScript.phase_at(daynight.minutes, campaign.day)
	var lesson := CampaignScript.lesson_at(daynight.minutes)
	var here := player.global_position
	var band := int((daynight.minutes - CampaignScript.lesson_start(0)) / 55.0) if daynight.minutes >= CampaignScript.lesson_start(0) else -1
	var key := "%s|%d|%d|%d|%d" % [phase, lesson, campaign.day, band, roundi(here.y / FLOOR_HEIGHT)]
	if phase == "lesson":
		key += "|%d|%d" % [roundi(here.x), roundi(here.z)]
	if key == _last_key:
		return
	_last_key = key
	_slots.clear()
	_moving = false
	if campaign.day <= CampaignScript.LAST_SCHOOL_DAY:
		if phase == "lesson" and lesson >= 0:
			_build_seats(lesson)
		elif phase == "break":
			_build_flow(1.0 - 0.6 * Outbreak.student_rate(campaign.day), hash([campaign.day, band]))   # The ill stay home.
		elif phase == "pre":
			_build_flow(0.25, hash([campaign.day, -1]))
	_dirty = true
	_advance(0.0)


func _build_seats(lesson: int) -> void:
	var subject: String = Lessons.subject_at(campaign.day, lesson)
	var player_room := [Lessons.floor_of(subject), Lessons.room_of(subject)]
	var assignment := Classes.assign(campaign.day, lesson, player_room)
	var order: Array = []
	for id: String in assignment:
		var room: Array = assignment[id]
		var rect := FloorData.room_rect(room[0], room[1])
		var centre := Vector3(rect.get_center().x, room[0] * FLOOR_HEIGHT, rect.get_center().y)
		var distance := player.global_position.distance_to(centre)
		if absf(player.global_position.y - centre.y) <= FLOOR_HEIGHT + 1.0 and distance <= NEAR:
			order.append([id == Classes.PLAYER_CLASS, distance, id, room])
	order.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0]
		return a[1] < b[1])
	for entry: Array in order:
		_seat_class(entry[2], entry[3])


## A class sits on its room's chairs (front rows first), one student per chair; students next to the player or a table
## are only dropped, never re-packed, so nobody shifts when the player walks about. A class that does not fit in the
## budget is skipped whole.
func _seat_class(id: String, room: Array) -> void:
	var wanted := Classes.size_of(id) - 1 if id == Classes.PLAYER_CLASS else Classes.size_of(id)   # the player is one of them
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var list: Array[Dictionary] = []
	var look := RandomNumberGenerator.new()   # Own generator: the look never shifts the colours and sick rolls above.
	look.seed = hash([id, "look"])
	var chairs: Array = seats.get("%d:%s" % [room[0], room[1]], [])
	var chair_index := -1
	for chair: Dictionary in chairs.slice(0, wanted):
		chair_index += 1
		var colour := _shirt(rng)
		var ill: bool = campaign.day >= Outbreak.FIRST_DAY and rng.randf() < Outbreak.student_rate(campaign.day)
		if ill:
			colour = colour.lerp(Color(0.6, 0.75, 0.55), 0.6)
		if _blocked(chair["pos"]):
			continue
		var slot := {"kind": "seat", "pos": chair["pos"], "yaw": chair["yaw"], "colour": colour, "sick": ill, "look": look.randf()}
		var who: int = NAMED_CHAIRS.find(chair_index) if id == Classes.PLAYER_CLASS else -1
		if who >= 0 and who < _named.size():
			slot["who"] = who   # Never ill: the named students stay in class.
			slot["sick"] = false
		list.append(slot)
	if _slots.size() + list.size() <= MAX_CROWD:
		_slots.append_array(list)


func _blocked(pos: Vector3) -> bool:
	var here := player.global_position
	if absf(here.y - pos.y) < FLOOR_HEIGHT * 0.5 and Vector2(here.x - pos.x, here.z - pos.z).length() < PLAYER_CLEAR:
		return true
	for table: Vector3 in avoid:
		if absf(table.y - pos.y) < FLOOR_HEIGHT * 0.5 and Vector2(table.x - pos.x, table.z - pos.z).length() < TABLE_CLEAR:
			return true
	return false


func _shirt(rng: RandomNumberGenerator) -> Color:
	return [Color(0.25, 0.3, 0.55), Color(0.55, 0.25, 0.3), Color(0.3, 0.45, 0.35), Color(0.4, 0.4, 0.45)][rng.randi() % 4]


## Walkers on the corridor polylines of the floors near the player: `density` scales how many (0..1).
## Corridors are separate polylines (not one connected network), so each student walks its own line back to front.
func _build_flow(density: float, seed_value: int) -> void:
	var budget := int(MAX_CROWD * density)
	var lines: Array[Dictionary] = []
	var total := 0.0
	for f in FloorData.FLOORS.size():
		if absf(f * FLOOR_HEIGHT - player.global_position.y) > FLOOR_HEIGHT + 1.0:
			continue
		var data: Dictionary = FloorData.FLOORS[f]
		var origin: Vector2 = data["origin"]
		var scale: float = data["scale"]
		for poly: Array in data["corridors"]:
			var points: Array[Vector3] = []
			for p: Vector2 in poly:
				var w := (p - origin) * scale
				points.append(Vector3(w.x, f * FLOOR_HEIGHT, w.y))
			var length := 0.0
			for i in points.size() - 1:
				length += points[i].distance_to(points[i + 1])
			lines.append({"points": points, "length": length})
			total += length
	if total <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for line: Dictionary in lines:
		var n := int(budget * float(line["length"]) / total)
		for i in n:
			if _slots.size() >= MAX_CROWD:
				return
			var dir := 1.0 if rng.randf() < 0.5 else -1.0
			var slot := {"kind": "flow", "line": line, "s": rng.randf() * float(line["length"]),
					"dir": dir, "speed": rng.randf_range(FLOW_SPEED.x, FLOW_SPEED.y),
					"lane": dir * rng.randf_range(0.2, 0.6), "colour": _shirt(rng), "pos": Vector3.ZERO, "yaw": 0.0,
					"look": fposmod(float(hash([seed_value, _slots.size()])), 997.0) / 997.0}
			var who: int = NAMED_WALKERS.find(_slots.size())
			if who >= 0 and who < _named.size():
				slot["who"] = who
			_slots.append(slot)
			_moving = true


## Move the walkers, hide those too far from the player or near an awake entity, then redraw.
func _advance(delta: float) -> void:
	if hidden:
		_apply([])
		return
	var panic := _entity_awake()
	var awake_changed := panic != _last_awake   # The named students change expression with it.
	_last_awake = panic
	if not (_dirty or _moving or panic or _panicked > 0 or awake_changed):
		return
	_dirty = false
	_visible.clear()
	_panicked = 0
	var here := player.global_position
	for slot: Dictionary in _slots:
		if slot["kind"] == "flow":
			var line: Dictionary = slot["line"]
			var length: float = line["length"]
			var dir: float = slot["dir"]
			var s := fposmod(float(slot["s"]) + dir * float(slot["speed"]) * delta, length)
			slot["s"] = s
			var at := _point_on(line["points"], s)
			var heading: Vector3 = at[1]
			slot["pos"] = (at[0] as Vector3) + heading.cross(Vector3.UP) * float(slot["lane"])
			slot["yaw"] = atan2(-heading.x * dir, -heading.z * dir)
		var pos: Vector3 = slot["pos"]
		if slot["kind"] == "flow":
			var gap := pos.distance_to(here)
			if gap > NEAR * 1.3 or gap < FLOW_CLEAR:   # too far, or inside the camera
				continue
		if panic and pos.distance_to(entity.global_position) < PANIC_RADIUS:
			_panicked += 1
			continue
		_visible.append(slot)
	if _panicked > 0 and not _screamed:
		_screamed = true
		_scream.stream = SoundBank.scream()
		_scream.global_position = entity.global_position
		_scream.play()
	elif _panicked == 0:
		_screamed = false
	_apply(_visible)


func _entity_awake() -> bool:
	return entity != null and is_instance_valid(entity) and entity.visible   # asleep = hidden; a frozen glimpse is visible


## [position, unit direction] at distance `s` along a polyline of Vector3 points.
func _point_on(points: Array, s: float) -> Array:
	var left := s
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg := a.distance_to(b)
		if left <= seg or i == points.size() - 2:
			return [a.lerp(b, clampf(left / maxf(seg, 0.001), 0.0, 1.0)), (b - a).normalized()]
		left -= seg
	return [points[0], Vector3.FORWARD]


func _apply(list: Array[Dictionary]) -> void:
	_drawn = list
	_shown = mini(list.size(), MAX_CROWD)
	for named in _named:
		named.hide_student()
	var index := 0
	for i in _shown:
		var slot: Dictionary = list[i]
		var pos: Vector3 = slot["pos"]
		var look: float = slot["look"]
		if slot.has("who"):
			_place_named(slot)
			continue
		var sick: bool = slot.get("sick", false)
		var height := lerpf(0.92, 1.05, fposmod(look * 11.0, 1.0))
		var basis := Basis(Vector3.UP, slot["yaw"]).scaled(Vector3(1.0, height, 1.0))
		if slot["kind"] == "seat":
			# Hips on the chair seat (0.45 m): the model is 0.42 m lower and the shader folds the legs.
			_body_mm.set_instance_transform(index, Transform3D(basis, pos + Vector3(0.0, -0.42 * height, 0.0)))
			_body_mm.set_instance_custom_data(index, Color(look + (2.0 if sick else 0.0), 1.0, 0.0, 0.0))
		else:
			_body_mm.set_instance_transform(index, Transform3D(basis, pos))
			_body_mm.set_instance_custom_data(index, Color(look, 0.0, look * TAU, slot["speed"]))
		_body_mm.set_instance_color(index, slot["colour"])
		index += 1
	_body_mm.visible_instance_count = index


## A named student: the same height spread as the crowd, calm in a lesson, friendly in a break, sad once the entity is awake.
func _place_named(slot: Dictionary) -> void:
	var named := _named[slot["who"]]
	var look: float = named.look
	var height := lerpf(0.92, 1.05, fposmod(look * 11.0, 1.0))
	var expression := "sad" if _entity_awake() else ("smile" if slot["kind"] == "flow" else "neutral")
	named.show_at(slot["pos"], slot["yaw"], height, slot["kind"] == "seat", slot.get("speed", 0.0), expression)
