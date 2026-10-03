extends Node3D
## Student crowd: ONE MultiMeshInstance3D pair (bodies and heads), no per-student node, no collision, no navigation.
## In a lesson the classes near the player sit in their classrooms; in a break they walk the corridors (corridor flow, culling and panic).
## Polls the campaign clock twice a second. Hunt days, after hours and the far side of the school show nobody.

const Classes := preload("res://scripts/classes.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const Lessons := preload("res://scripts/lessons.gd")
const CampaignScript := preload("res://scripts/campaign.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")

const MAX_CROWD := 150
const NEAR := 35.0           ## Only classrooms and corridors within this many metres (and one floor) are drawn.
const FLOOR_HEIGHT := 4.0
const PLAYER_CLEAR := 1.0    ## Nobody is seated within this radius of the player.
const TABLE_CLEAR := 0.9     ## ... or of a clue table.
const FLOW_SPEED := Vector2(1.1, 1.8)
const PANIC_RADIUS := 25.0

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

var _body_mm := MultiMesh.new()
var _head_mm := MultiMesh.new()
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


func _ready() -> void:
	_body_mm.transform_format = MultiMesh.TRANSFORM_3D
	_body_mm.use_colors = true
	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 1.5
	_body_mm.mesh = body
	_body_mm.instance_count = MAX_CROWD
	_head_mm.transform_format = MultiMesh.TRANSFORM_3D
	var head := SphereMesh.new()
	head.radius = 0.12
	head.height = 0.24
	_head_mm.mesh = head
	_head_mm.instance_count = MAX_CROWD
	var body_material := StandardMaterial3D.new()
	body_material.vertex_color_use_as_albedo = true
	body_material.roughness = 0.9
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(0.8, 0.62, 0.52)
	head_material.roughness = 0.9
	for pair: Array in [[_body_mm, body_material], [_head_mm, head_material]]:
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = pair[0]
		instance.material_override = pair[1]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_body_mm.visible_instance_count = 0
	_head_mm.visible_instance_count = 0
	_scream.max_distance = 40.0
	add_child(_scream)




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
			_build_flow(1.0, hash([campaign.day, band]))
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
	var chairs: Array = seats.get("%d:%s" % [room[0], room[1]], [])
	for chair: Dictionary in chairs.slice(0, wanted):
		var colour := _shirt(rng)
		if not _blocked(chair["pos"]):
			list.append({"kind": "seat", "pos": chair["pos"], "yaw": chair["yaw"], "colour": colour})
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
			_slots.append({"kind": "flow", "line": line, "s": rng.randf() * float(line["length"]),
					"dir": dir, "speed": rng.randf_range(FLOW_SPEED.x, FLOW_SPEED.y),
					"lane": dir * rng.randf_range(0.2, 0.6), "colour": _shirt(rng), "pos": Vector3.ZERO, "yaw": 0.0})
			_moving = true


## Move the walkers, hide those too far from the player or near an awake entity, then redraw.
func _advance(delta: float) -> void:
	if hidden:
		_apply([])
		return
	var panic := _entity_awake()
	if not (_dirty or _moving or panic or _panicked > 0):
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
			if gap > NEAR * 1.3 or gap < PLAYER_CLEAR:   # too far, or about to walk through the camera
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
	for i in _shown:
		var slot: Dictionary = list[i]
		var pos: Vector3 = slot["pos"]
		var facing := Basis(Vector3.UP, slot["yaw"])
		if slot["kind"] == "seat":
			# On the chair seat (0.45 m): the shortened body from the seat up, the head above it.
			_body_mm.set_instance_transform(i, Transform3D(facing.scaled(Vector3(1.0, 0.55, 1.0)), pos + Vector3(0.0, 0.86, 0.0)))
			_head_mm.set_instance_transform(i, Transform3D(facing, pos + Vector3(0.0, 1.38, 0.0)))
		else:
			_body_mm.set_instance_transform(i, Transform3D(facing, pos + Vector3(0.0, 0.75, 0.0)))
			_head_mm.set_instance_transform(i, Transform3D(facing, pos + Vector3(0.0, 1.62, 0.0)))
		_body_mm.set_instance_color(i, slot["colour"])
	_body_mm.visible_instance_count = _shown
	_head_mm.visible_instance_count = _shown
