extends Node3D
## Procedural furniture, built once by main.gd before the navmesh bake: rows of desks and chairs with a teacher's desk,
## board, cabinet, radiator and bin in the classrooms; the same rows with PCs in the GT rooms; stalls with toilets,
## sinks, a mirror and a bin in every WC. Low-poly primitives merged into one mesh per kind and drawn as one MultiMesh
## per kind and floor; one StaticBody3D (layer 1, under the navigation region) holds a box per piece, so the bake
## carves it out. Classrooms face along their longer axis with a centre aisle (teacher stations stand at the room
## centre); GT rooms may line their PCs along the side walls instead. Any desk near a door swing, a table, a station or
## on a lane from a door or table to the aisle is left out. WCs keep a clear strip from the door to the far wall.
## `seats` is where the crowd sits. Lab 14, the Porta and the demo-closed rooms get nothing.

const FloorData := preload("res://scripts/floor_data.gd")
const Rooms := preload("res://scripts/rooms.gd")
const FindsScript := preload("res://scripts/finds.gd")

const FLOOR_HEIGHT := 4.0
const WALL := 0.125           ## Half the wall thickness: room rects run along the wall centre lines.
const SKIP := ["14"]          ## Lab 14 keeps its own fittings (table, cabinet, pages).
const DOOR_CLEAR := 1.4       ## Nothing within this of a door hinge (the panel is 1.25 m).
const DOOR_APPROACH := 1.2    ## Desks keep this far from a door opening.
const TABLE_CLEAR := 1.3      ## Desks keep this far from a table centre.
## A table in the centre aisle: no desk inside this square around it, or (PCs along the walls) inside a band this wide
## either side of it, wall to wall. The aisle widens into a clean box around the table; round clearances leave
## diagonal pinches that the navmesh bake closes off.
const AISLE_TABLE_CLEAR := 1.9
const WALL_TABLE_BAND := 1.4
const PROP_CLEAR := 1.0       ## Teacher desk, cabinet, bin, radiator: from a table centre.
const WC_TABLE_CLEAR := 0.6   ## WC fixtures: from a table centre (outside the 0.9 m table, the find stays reachable).
const CENTRE_CLEAR := 0.8     ## Room centre: teacher stations and the story tables placed there.
const LANE := 0.75            ## Half-width of the lanes from doors and tables to the centre aisle.
const STRIP := 0.7            ## WC: half-width of the clear strip from the door to the far wall.
## Per room kind: seat width, desk depth, row pitch, front zone (board, teacher's desk), back zone, centre aisle.
## GT rooms also try PCs along both side walls (`walls`) and keep whichever layout seats more.
const LAYOUT := {
	"normal": {"seat": 0.6, "desk": 0.5, "pitch": 1.1, "front": 1.5, "back": 1.1, "aisle": 1.8, "modes": ["rows"]},
	"computer": {"seat": 0.65, "desk": 0.65, "pitch": 1.3, "front": 1.5, "back": 1.1, "aisle": 1.8, "modes": ["rows", "walls"]},
}

var seats := {}    ## "floor:label" -> Array of {pos: Vector3 (chair, floor level), yaw: float (facing the board)}
var pieces := {}   ## "floor:room index" -> Array of [kind, Rect2 footprint]

var _xforms := {}  ## mesh kind -> Array (one per floor) of Array[Transform3D]
var _body := StaticBody3D.new()
var _shapes := {}
var _floor := 0
var _key := ""


func build(region: Node3D, keep: Array[Vector3]) -> void:
	_body.name = "Furniture"
	region.add_child(_body)
	for f in FloorData.FLOORS.size():
		_floor = f
		var data: Dictionary = FloorData.FLOORS[f]
		var origin: Vector2 = data["origin"]
		var scale: float = data["scale"]
		var rooms: Array = data["rooms"]
		for r in rooms.size():
			var room: Array = rooms[r]
			var type := Rooms.type_of(room[0])
			if SKIP.has(room[0]) or not type in ["normal", "computer", "wc"]:
				continue
			var a := (Vector2(room[1], room[2]) - origin) * scale
			var b := (Vector2(room[3], room[4]) - origin) * scale
			var rect := Rect2(a, b - a).abs()
			var tables: Array[Vector2] = []
			for k: Vector3 in keep:
				if absf(k.y - f * FLOOR_HEIGHT) < 1.0 and rect.grow(0.2).has_point(Vector2(k.x, k.z)):
					tables.append(Vector2(k.x, k.z))
			var doors: Array = FindsScript._door_points(room, origin, scale)
			var hinges: Array[Vector2] = []
			for p: Vector2 in doors:
				var along_x := absf(p.y - rect.position.y) < 0.05 or absf(p.y - rect.end.y) < 0.05
				hinges.append(p - (Vector2(0.625, 0.0) if along_x else Vector2(0.0, 0.625)))
			_key = "%d:%d" % [f, r]
			pieces[_key] = []
			if type == "wc":
				_wc(rect, doors, hinges, tables)
			else:
				_classroom(room[0], type, rect, doors, hinges, tables)
	_draw()


# --- Classrooms and GT rooms -----------------------------------------------------

func _classroom(label: String, type: String, rect: Rect2, doors: Array, hinges: Array[Vector2], tables: Array[Vector2]) -> void:
	var best: Dictionary = {}
	var inner := rect.grow(-WALL)
	# The centre aisle runs along the longer axis (either one in a square room).
	var axes := [true, false] if absf(inner.size.x - inner.size.y) < 0.5 else [inner.size.y > inner.size.x]
	for mode: String in LAYOUT[type]["modes"]:
		for along_z: bool in axes:
			for front: float in [1.0, -1.0]:   # the board at either end
				var plan := _plan(type, mode, inner, along_z, front, doors, hinges, tables)
				if best.is_empty() or plan["score"] > best["score"]:
					best = plan
	var list: Array = []
	for item: Array in best["items"]:
		_add(item[0], item[1], item[2], item[3], item[4], item[6] if item.size() > 6 else Vector3.ONE)
		if item[0] == "desk" or item[0] == "pc_desk":
			var chair: Vector2 = item[5]
			list.append({"pos": Vector3(chair.x, _floor * FLOOR_HEIGHT, chair.y), "yaw": item[2]})
	seats["%d:%s" % [_floor, label]] = list


## One candidate layout: [kind, centre, yaw, footprint, height, chair position] items and a score (seats, +50 for a
## teacher's desk). Depth `v` runs from the board wall into the room, `u` across it from the centre line.
func _plan(type: String, mode: String, inner: Rect2, along_z: bool, front: float, doors: Array, hinges: Array[Vector2], tables: Array[Vector2]) -> Dictionary:
	var p: Dictionary = LAYOUT[type]
	var c := inner.get_center()
	var d := Vector2(0.0, front) if along_z else Vector2(front, 0.0)
	var a := Vector2(1.0, 0.0) if along_z else Vector2(0.0, 1.0)
	var depth := inner.size.y if along_z else inner.size.x
	var half := (inner.size.x if along_z else inner.size.y) * 0.5
	var o := c - d * depth * 0.5
	var at := func(u: float, v: float) -> Vector2: return o + d * v + a * u
	var box := func(u: float, v: float, hu: float, hv: float) -> Rect2:
		var p0: Vector2 = at.call(u - hu, v - hv)
		var p1: Vector2 = at.call(u + hu, v + hv)
		return Rect2(p0, p1 - p0).abs()
	var facing := atan2(d.x, d.y)        # the board faces the class
	var teacher := atan2(-d.x, -d.y)     # the teacher looks at the class
	# Lanes from every door and table to the nearest point of the centre line.
	var lanes: Array = []
	for q: Vector2 in doors + tables:
		lanes.append([q, c + d * (q - c).dot(d)])
	var desk: float = p["desk"]
	var chair_off := desk * 0.5 + 0.3
	# Half-width of the free middle: the centre aisle, or up to the chairs of the PCs along the walls.
	var aisle_half: float = float(p["aisle"]) * 0.5 if mode == "rows" else half - 0.03 - desk * 0.5 - chair_off - 0.22
	var aisle_boxes: Array[Rect2] = []
	for t: Vector2 in tables:
		var tu := (t - c).dot(a)
		if absf(tu) < aisle_half:
			var tv := (t - o).dot(d)
			aisle_boxes.append(box.call(tu, tv, AISLE_TABLE_CLEAR, AISLE_TABLE_CLEAR) if mode == "rows" else box.call(0.0, tv, half, WALL_TABLE_BAND))
	# Teacher stations: the centre, and 1.5 m along the longer axis when a table takes the centre (staff_manager.gd).
	var stations: Array[Vector2] = [c]
	if tables.any(func(t: Vector2) -> bool: return t.distance_to(c) < 1.2):
		stations.append(c + (Vector2.RIGHT if inner.size.x >= inner.size.y else Vector2.DOWN) * 1.5)
		lanes.append([stations[1], c])
	var items: Array = []
	var seat_count := 0
	var pc := type == "computer"
	var seat: float = p["seat"]
	var spots: Array = []   # [u, v, facing in (u, v)] per desk
	if mode == "rows":
		var n := int((half - 0.05 - float(p["aisle"]) * 0.5) / seat)
		var v := float(p["front"]) + desk * 0.5
		while v + chair_off + 0.22 <= depth - float(p["back"]):
			for side: float in [-1.0, 1.0]:
				for k in n:
					spots.append([side * (half - 0.05 - seat * (k + 0.5)), v, Vector2(0.0, -1.0)])
			v += float(p["pitch"])
	else:   # facing the side walls, the full length of the room (the teacher's desk stays in the middle)
		var v := 0.3 + seat * 0.5
		while v + seat * 0.5 <= depth - 0.3:
			for side: float in [-1.0, 1.0]:
				spots.append([side * (half - 0.03 - desk * 0.5), v, Vector2(side, 0.0)])
			v += seat
	for spot: Array in spots:
		var here := Vector2(spot[0], spot[1])
		var f: Vector2 = spot[2]
		var across := Vector2(f.y, -f.x) * seat * 0.5
		var p0: Vector2 = at.call(here.x + f.x * desk * 0.5 + across.x, here.y + f.y * desk * 0.5 + across.y)
		var p1: Vector2 = at.call(here.x - f.x * (chair_off + 0.22) - across.x, here.y - f.y * (chair_off + 0.22) - across.y)
		var foot := Rect2(p0, p1 - p0).abs()
		if not _free(foot, stations, hinges, tables, TABLE_CLEAR, lanes, aisle_boxes) or doors.any(func(q: Vector2) -> bool: return _gap(foot, q) < DOOR_APPROACH):
			continue
		var fw := a * f.x + d * f.y
		var yaw := atan2(-fw.x, -fw.y)
		var chair: Vector2 = at.call(here.x - f.x * chair_off, here.y - f.y * chair_off)
		items.append(["pc_desk" if pc else "desk", at.call(here.x, here.y), yaw, foot, 0.78, chair])
		items.append(["chair", chair, yaw, Rect2(), 0.0])
		if pc:
			items.append(["pc", at.call(here.x, here.y), yaw, Rect2(), 0.0])
		seat_count += 1
	var score := seat_count
	# Teacher's desk (chair between it and the board), centred or to one side.
	for u: float in [0.0, 1.7, -1.7]:
		var foot: Rect2 = box.call(u, 0.665, 0.7, 0.585)
		if _free(foot, stations, hinges, tables, PROP_CLEAR, lanes):
			items.append(["teacher_desk", at.call(u, 0.9), teacher, box.call(u, 0.9, 0.7, 0.35), 0.78])
			items.append(["chair", at.call(u, 0.3), teacher, box.call(u, 0.3, 0.22, 0.22), 0.9])
			if pc:
				items.append(["pc", at.call(u, 0.9), teacher, Rect2(), 0.0])
			var bin_u := u + (0.95 if u >= 0.0 else -0.95)
			var bin: Rect2 = box.call(bin_u, 0.4, 0.15, 0.15)
			if _free(bin, stations, hinges, tables, PROP_CLEAR, lanes):
				items.append(["bin", at.call(bin_u, 0.4), facing, bin, 0.35])
			score += 50
			break
	# Board on the front wall, clear of the door openings.
	for spot: Vector2 in [Vector2(0.0, 1.0), Vector2(half * 0.45, 1.0), Vector2(-half * 0.45, 1.0),
			Vector2(half - 1.0, 0.67), Vector2(1.0 - half, 0.67)]:   # [u, width scale]
		var foot: Rect2 = box.call(spot.x, 0.03, 1.2 * spot.y, 0.03)
		if not doors.any(func(q: Vector2) -> bool: return _gap(foot, q) < 0.9):
			items.append(["whiteboard" if pc else "board", at.call(spot.x, 0.03), facing, foot, 0.0, Vector2.ZERO, Vector3(spot.y, 1.0, 1.0)])
			score += 10
			break
	# Cabinet and radiator on the back wall, only where free.
	for u: float in [half - 0.6, -(half - 0.6)]:
		var foot: Rect2 = box.call(u, depth - 0.25, 0.5, 0.23)
		if _free(foot, stations, hinges, tables, PROP_CLEAR, lanes):
			items.append(["cabinet", at.call(u, depth - 0.25), facing, foot, 1.9])
			break
	var radiator: Rect2 = box.call(0.0, depth - 0.07, 0.6, 0.06)
	if _free(radiator, stations, hinges, tables, PROP_CLEAR, lanes):
		items.append(["radiator", at.call(0.0, depth - 0.07), facing, radiator, 0.75])
	return {"items": items, "score": score}


## No door swing, table, teacher station or lane under the footprint.
func _free(foot: Rect2, stations: Array[Vector2], hinges: Array[Vector2], tables: Array[Vector2], table_clear: float, lanes: Array,
		aisle_boxes: Array[Rect2] = []) -> bool:
	for station: Vector2 in stations:
		if _gap(foot, station) < CENTRE_CLEAR:
			return false
	for h: Vector2 in hinges:
		if _gap(foot, h) < DOOR_CLEAR:
			return false
	for t: Vector2 in tables:
		if _gap(foot, t) < table_clear:
			return false
	for clear: Rect2 in aisle_boxes:
		if clear.intersects(foot):
			return false
	for lane: Array in lanes:
		var from: Vector2 = lane[0]
		var to: Vector2 = lane[1]
		var steps := maxi(ceili(from.distance_to(to) / 0.2), 1)
		for i in steps + 1:
			if _gap(foot, from.lerp(to, float(i) / steps)) < LANE:
				return false
	return true


## Distance from a point to a rectangle (0 inside).
static func _gap(r: Rect2, q: Vector2) -> float:
	return Vector2(maxf(maxf(r.position.x - q.x, q.x - r.end.x), 0.0), maxf(maxf(r.position.y - q.y, q.y - r.end.y), 0.0)).length()


# --- WCs --------------------------------------------------------------------------

## Stalls along one side wall, sinks with a mirror along the other, a bin where free. `u` runs along the door wall
## from the door, `v` from the door wall to the far wall; |u| < STRIP stays clear all the way.
func _wc(rect: Rect2, doors: Array, hinges: Array[Vector2], tables: Array[Vector2]) -> void:
	var inner := rect.grow(-WALL)
	var door: Vector2 = doors[0]
	var d := Vector2.DOWN if absf(door.y - rect.position.y) < 0.05 else (Vector2.UP if absf(door.y - rect.end.y) < 0.05 \
			else (Vector2.RIGHT if absf(door.x - rect.position.x) < 0.05 else Vector2.LEFT))
	var a := Vector2(-d.y, d.x)
	var o := door + d * WALL
	var corners := [inner.position, inner.end, Vector2(inner.position.x, inner.end.y), Vector2(inner.end.x, inner.position.y)]
	var us: Array = corners.map(func(q: Vector2) -> float: return (q - o).dot(a))
	var vs: Array = corners.map(func(q: Vector2) -> float: return (q - o).dot(d))
	var depth: float = vs.max()
	var walls := [us.min(), us.max()]   # u of the two side walls
	var at := func(u: float, v: float) -> Vector2: return o + d * v + a * u
	var box := func(u0: float, u1: float, v0: float, v1: float) -> Rect2:
		var p0: Vector2 = at.call(u0, v0)
		var p1: Vector2 = at.call(u1, v1)
		return Rect2(p0, p1 - p0).abs()
	var ok := func(foot: Rect2) -> bool:
		return hinges.all(func(h: Vector2) -> bool: return _gap(foot, h) >= DOOR_CLEAR) \
				and tables.all(func(t: Vector2) -> bool: return _gap(foot, t) >= WC_TABLE_CLEAR)
	# Greedy run of up to `count` fixtures of `width` (along v) and `reach` (from the wall) on side `s`.
	var run := func(s: int, width: float, reach: float, count: int) -> Array:
		var wall: float = walls[s]
		var sign := -1.0 if s == 0 else 1.0
		var out: Array = []
		var v := 0.05
		while v + width <= depth - 0.05 and out.size() < count:
			if ok.call(box.call(wall, wall - sign * reach, v, v + width)):
				out.append(v)
				v += width
			else:
				v += 0.05
		return out
	var best: Array = []
	for stall_side: int in [0, 1]:
		var lane: float = absf(float(walls[stall_side])) - STRIP
		var reach := minf(1.3, lane - 0.05)
		var stalls: Array = run.call(stall_side, 0.75, reach, 5) if reach >= 0.95 else []
		var sinks: Array = run.call(1 - stall_side, 0.6, 0.45, 3)
		var score := stalls.size() + sinks.size() + (100 if stalls.size() >= 3 and sinks.size() >= 2 else 0)
		if best.is_empty() or score > best[0]:
			best = [score, stall_side, stalls, sinks, reach]
	var stall_side: int = best[1]
	var reach: float = best[4]
	for s: int in [stall_side, 1 - stall_side]:
		var wall: float = walls[s]
		var sign := -1.0 if s == 0 else 1.0
		var lane_yaw := atan2(sign * a.x, sign * a.y)   # local +Z towards the side wall
		if s == stall_side:
			var edges := {}
			for v: float in best[2]:
				_add("toilet", at.call(wall - sign * 0.45, v + 0.375), lane_yaw, box.call(wall, wall - sign * 0.7, v + 0.15, v + 0.6), 0.8)
				for e: float in [v, v + 0.75]:
					if not edges.has(snappedf(e, 0.01)):
						edges[snappedf(e, 0.01)] = true
						_add("partition", at.call(wall - sign * reach * 0.5, e), lane_yaw,
								box.call(wall, wall - sign * reach, e - 0.02, e + 0.02), 1.95, Vector3(1.0, 1.0, reach))
		else:
			var sinks: Array = best[3]
			for v: float in sinks:
				_add("sink", at.call(wall - sign * 0.25, v + 0.3), lane_yaw, box.call(wall, wall - sign * 0.45, v + 0.05, v + 0.55), 0.9)
			if not sinks.is_empty():
				var v0: float = sinks.min()
				var v1: float = float(sinks.max()) + 0.6
				_add("mirror", at.call(wall - sign * 0.01, (v0 + v1) * 0.5), lane_yaw, box.call(wall, wall - sign * 0.02, v0, v1),
						0.0, Vector3(v1 - v0, 1.0, 1.0))
	# Bin against a side wall, clear of everything placed.
	for s: int in [1 - stall_side, stall_side]:
		var wall: float = walls[s]
		var sign := -1.0 if s == 0 else 1.0
		var v := 0.3
		while v < depth - 0.3:
			var foot: Rect2 = box.call(wall, wall - sign * 0.3, v - 0.15, v + 0.15)
			if ok.call(foot) and not pieces[_key].any(func(item: Array) -> bool: return (item[1] as Rect2).grow(0.05).intersects(foot)):
				_add("bin", foot.get_center(), 0.0, foot, 0.35)
				return
			v += 0.1


# --- Meshes and drawing -------------------------------------------------------------

## Records one piece: a MultiMesh instance, a collision box when `height` > 0, and its footprint for the tests.
func _add(kind: String, at: Vector2, yaw: float, foot: Rect2, height: float, scale := Vector3.ONE) -> void:
	if not _xforms.has(kind):
		_xforms[kind] = [[], [], []]
	_xforms[kind][_floor].append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale), Vector3(at.x, _floor * FLOOR_HEIGHT, at.y)))
	if foot.has_area():
		pieces[_key].append([kind, foot])
	if height > 0.0 and foot.has_area():
		var size := Vector3(foot.size.x, height, foot.size.y)
		var shape := CollisionShape3D.new()
		if not _shapes.has(size):
			var box_shape := BoxShape3D.new()
			box_shape.size = size
			_shapes[size] = box_shape
		shape.shape = _shapes[size]
		shape.position = Vector3(foot.get_center().x, _floor * FLOOR_HEIGHT + height * 0.5, foot.get_center().y)
		_body.add_child(shape)


func _draw() -> void:
	var meshes := _meshes()
	for kind: String in _xforms:
		for f in FloorData.FLOORS.size():
			var list: Array = _xforms[kind][f]
			if list.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[kind]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = "%s_%d" % [kind, f]
			instance.multimesh = mm
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)


static func _mat(colour: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _bx(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


static func _cyl(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	return m


## One ArrayMesh from [material, [[primitive, offset], ...]] parts: one surface per material.
static func _merge(parts: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for part: Array in parts:
		var st := SurfaceTool.new()
		for piece: Array in part[1]:
			st.append_from(piece[0], 0, Transform3D(Basis(), piece[1]))
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, part[0])
	return out


## Every mesh in its local frame: the user faces -Z (pupil, teacher, toilet user); wall fixtures have the wall at +Z.
static func _meshes() -> Dictionary:
	var wood := _mat(Color(0.55, 0.4, 0.26), 0.7)
	var dark_wood := _mat(Color(0.35, 0.24, 0.15), 0.75)
	var metal := _mat(Color(0.28, 0.3, 0.33), 0.45, 0.6)
	var plastic := _mat(Color(0.22, 0.32, 0.5), 0.8)
	var black := _mat(Color(0.06, 0.06, 0.07), 0.5)
	var ceramic := _mat(Color(0.92, 0.92, 0.9), 0.25)
	var laminate := _mat(Color(0.55, 0.6, 0.62), 0.6)
	var screen := _mat(Color(0.02, 0.05, 0.06), 0.3)
	screen.emission_enabled = true
	screen.emission = Color(0.1, 0.4, 0.5)
	screen.emission_energy_multiplier = 0.3
	var mirror := _mat(Color(0.62, 0.7, 0.76), 0.1, 0.3)
	var legs := func(w: float, dz: float, h: float) -> Array:
		var out: Array = []
		for x in [-w, w]:
			for z in [-dz, dz]:
				out.append([_bx(0.035, h, 0.035), Vector3(x, h * 0.5, z)])
		return out
	return {
		"desk": _merge([[wood, [[_bx(0.56, 0.035, 0.5), Vector3(0.0, 0.74, 0.0)]]],
				[metal, legs.call(0.25, 0.21, 0.72) + [[_bx(0.5, 0.03, 0.03), Vector3(0.0, 0.2, -0.21)]]]]),
		"pc_desk": _merge([[wood, [[_bx(0.62, 0.035, 0.65), Vector3(0.0, 0.74, 0.0)]]],
				[metal, legs.call(0.28, 0.28, 0.72) + [[_bx(0.56, 0.03, 0.03), Vector3(0.0, 0.2, -0.28)]]]]),
		"chair": _merge([[plastic, [[_bx(0.4, 0.03, 0.4), Vector3(0.0, 0.45, 0.0)], [_bx(0.4, 0.32, 0.03), Vector3(0.0, 0.72, 0.2)]]],
				[metal, legs.call(0.17, 0.17, 0.44)]]),
		"teacher_desk": _merge([[dark_wood, [[_bx(1.4, 0.04, 0.7), Vector3(0.0, 0.76, 0.0)], [_bx(0.04, 0.74, 0.66), Vector3(-0.68, 0.37, 0.0)],
				[_bx(0.04, 0.74, 0.66), Vector3(0.68, 0.37, 0.0)], [_bx(1.32, 0.5, 0.03), Vector3(0.0, 0.49, -0.32)]]]]),
		"pc": _merge([[black, [[_bx(0.2, 0.02, 0.15), Vector3(0.0, 0.77, -0.15)], [_bx(0.04, 0.16, 0.04), Vector3(0.0, 0.86, -0.17)],
				[_bx(0.52, 0.32, 0.04), Vector3(0.0, 1.09, -0.17)], [_bx(0.42, 0.02, 0.14), Vector3(0.0, 0.77, 0.1)],
				[_bx(0.06, 0.025, 0.1), Vector3(0.3, 0.77, 0.1)]]],
				[screen, [[_bx(0.48, 0.28, 0.005), Vector3(0.0, 1.09, -0.148)]]]]),
		"board": _merge([[_mat(Color(0.08, 0.2, 0.14), 0.9), [[_bx(2.4, 1.1, 0.04), Vector3(0.0, 1.5, 0.0)]]],
				[dark_wood, [[_bx(2.4, 0.04, 0.08), Vector3(0.0, 0.93, 0.02)]]]]),
		"whiteboard": _merge([[_mat(Color(0.88, 0.9, 0.9), 0.2), [[_bx(2.4, 1.1, 0.04), Vector3(0.0, 1.5, 0.0)]]],
				[metal, [[_bx(2.4, 0.04, 0.08), Vector3(0.0, 0.93, 0.02)]]]]),
		"cabinet": _merge([[dark_wood, [[_bx(1.0, 1.9, 0.45), Vector3(0.0, 0.95, 0.0)]]],
				[metal, [[_bx(0.02, 0.2, 0.02), Vector3(-0.05, 1.0, -0.235)], [_bx(0.02, 0.2, 0.02), Vector3(0.05, 1.0, -0.235)]]]]),
		"radiator": _merge([[_mat(Color(0.85, 0.85, 0.82), 0.5), [[_bx(1.2, 0.6, 0.1), Vector3(0.0, 0.45, 0.0)]]]]),
		"bin": _merge([[_mat(Color(0.15, 0.17, 0.16), 0.8), [[_cyl(0.15, 0.35), Vector3(0.0, 0.175, 0.0)]]]]),
		"toilet": _merge([[ceramic, [[_bx(0.42, 0.38, 0.17), Vector3(0.0, 0.75, 0.27)], [_cyl(0.17, 0.4), Vector3(0.0, 0.2, 0.0)],
				[_cyl(0.19, 0.03), Vector3(0.0, 0.415, -0.02)]]]]),
		"partition": _merge([[laminate, [[_bx(0.04, 1.85, 1.0), Vector3(0.0, 1.0, 0.0)]]]]),
		"sink": _merge([[ceramic, [[_bx(0.5, 0.15, 0.4), Vector3(0.0, 0.8, 0.0)], [_bx(0.15, 0.72, 0.15), Vector3(0.0, 0.36, 0.08)]]],
				[metal, [[_cyl(0.015, 0.15), Vector3(0.0, 0.95, 0.15)], [_bx(0.03, 0.03, 0.12), Vector3(0.0, 1.02, 0.1)]]]]),
		"mirror": _merge([[mirror, [[_bx(1.0, 0.6, 0.02), Vector3(0.0, 1.5, 0.0)]]]]),
	}
