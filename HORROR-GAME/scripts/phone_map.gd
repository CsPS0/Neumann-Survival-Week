extends Control
## Contents of the phone screen. Page 0: whole-floor plan (arrows switch floor; the player marker only with the easy map).
## Page 1: timetable plus the day tasks (school days) or the story task list. Page 2: collected clues. Page 3: finds. Page 4: neu_mecha. Finds everything it needs through groups ("player", "entity", "quest", ...).

const FloorData := preload("res://scripts/floor_data.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Finds := preload("res://scripts/finds.gd")
const TYPE_FILL := {
	"normal": Color(0.1, 0.16, 0.32), "computer": Color(0.08, 0.24, 0.26), "wc": Color(0.16, 0.19, 0.25),
	"gym": Color(0.36, 0.2, 0.08), "entrance": Color(0.34, 0.3, 0.08), "other": Color(0.09, 0.09, 0.1),
}

const FLOOR_HEIGHT := 4.0
const HEADER := 46.0
const LOGICAL_WIDTH := 300.0     ## Pages 1+ are laid out for 300x560 and scaled to the real viewport.

var page := 0
var floor_view := 0
var easy := false
var _time := 0.0


func _ready() -> void:
	clip_contents = true
	refresh_settings()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Scale and offset that put the whole plan rectangle (plan pixels) centred inside `area` (screen pixels).
static func fit(plan_rect: Rect2, area: Rect2) -> Dictionary:
	var s := minf(area.size.x / plan_rect.size.x, area.size.y / plan_rect.size.y)
	return {"scale": s, "offset": area.get_center() - plan_rect.get_center() * s}


func refresh_settings() -> void:
	var profile := get_tree().get_first_node_in_group("profile")
	easy = profile != null and bool(profile.get_setting("easy_map"))


func shows_marker() -> bool:
	return easy


func _draw() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var font := ThemeDB.fallback_font
	var ui := size.x / LOGICAL_WIDTH
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.09))
	if page == 0:
		_draw_full_map(player, font, ui)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui)
		match page:
			1: _draw_tasks(font)
			2: _draw_clues(font)
			3: _draw_finds(font)
			4: _draw_mecha(font)

	# Header (laid out in logical units on every page).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui)
	draw_rect(Rect2(0.0, 0.0, LOGICAL_WIDTH, HEADER), Color(0.02, 0.03, 0.06))
	var clock := get_tree().get_first_node_in_group("daynight")
	draw_string(font, Vector2(14.0, 20.0), clock.time_text() if clock else "--:--",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
	var campaign := get_tree().get_first_node_in_group("campaign")
	var title: String = ["FLOOR %d" % floor_view, "TIMETABLE" if campaign and campaign.day <= 3 else "TASKS", "CLUES",
			"FINDS", "NEU_MECHA"][page]
	draw_string(font, Vector2(14.0, 40.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.9, 1.0))
	draw_string(font, Vector2(LOGICAL_WIDTH - 100.0, 20.0), "TAB: next",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_interference(player)


## Page 0: the whole floor `floor_view`, fitted to the screen. The player marker, key/altar markers and the
## red-room pulse only show with the easy map.
func _draw_full_map(player: Node3D, font: Font, ui: float) -> void:
	var data: Dictionary = FloorData.FLOORS[floor_view]
	var view := fit(data["rect"], Rect2(8.0, HEADER * ui + 8.0, size.x - 16.0, size.y - HEADER * ui - 48.0))
	var s: float = view["scale"]
	var off: Vector2 = view["offset"]
	var quest := get_tree().get_first_node_in_group("quest")
	var show_red: bool = (
		easy
		and quest != null
		and player.has_item("storage_key")
		and not quest.red_room_opened
		and quest.red_room_floor == floor_view
	)

	for room: Array in data["rooms"]:
		var rect := Rect2(Vector2(room[1], room[2]) * s + off, Vector2(room[3] - room[1], room[4] - room[2]) * s)
		var label := String(room[0])
		var closed := not Rooms.is_open(label)
		var fill: Color = TYPE_FILL[Rooms.type_of(label)]
		if show_red and label == quest.red_room_label:
			fill = Color(0.6, 0.1, 0.1).lerp(Color(0.2, 0.1, 0.2), 0.5 + 0.5 * sin(_time * 5.0))
		draw_rect(rect, fill)
		draw_rect(rect, Color(0.25, 0.27, 0.32) if closed else Color(0.3, 0.45, 0.8), false, 1.0)
		if label != "" and rect.size.x >= 22.0:
			var font_size := clampi(roundi(rect.size.x * 0.28), 8, 16)
			draw_string(font, rect.get_center() + Vector2(-rect.size.x * 0.5, font_size * 0.35), label,
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color(0.45, 0.47, 0.52) if closed else Color(0.8, 0.9, 1.0))
		if closed and rect.size.x >= 40.0 and rect.size.y >= 30.0:
			draw_string(font, rect.get_center() + Vector2(-rect.size.x * 0.5, 15.0), "demo",
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color(0.4, 0.42, 0.46))
	for solid: Array in data["solids"]:
		draw_rect(Rect2(Vector2(solid[0], solid[1]) * s + off, Vector2(solid[2] - solid[0], solid[3] - solid[1]) * s), Color(0.1, 0.3, 0.2))
	draw_string(font, Vector2(8.0, size.y - 14.0), "< > floor", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.65, 0.75))
	if not easy:
		return

	var to_screen := func(world: Vector3) -> Vector2:
		return (Vector2(world.x, world.z) / float(data["scale"]) + (data["origin"] as Vector2)) * s + off
	for pickup: Node3D in get_tree().get_nodes_in_group("pickup"):
		if pickup.get("kind") == "key" and roundi(pickup.global_position.y / FLOOR_HEIGHT) == floor_view:
			var key_pos: Vector2 = to_screen.call(pickup.global_position)
			draw_circle(key_pos, 6.0, Color(1.0, 0.8, 0.2))
			draw_string(font, key_pos + Vector2(8.0, 4.0), "KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3))
	var altar := get_tree().get_first_node_in_group("altar") as Node3D
	if altar and floor_view == 0:
		var altar_pos: Vector2 = to_screen.call(altar.global_position)
		draw_circle(altar_pos, 6.0, Color(0.8, 0.3, 1.0))
		draw_string(font, altar_pos + Vector2(8.0, 4.0), "ALTAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.5, 1.0))

	# Player: dot + heading wedge, only on the floor the player stands on.
	if clampi(roundi(player.global_position.y / FLOOR_HEIGHT), 0, FloorData.FLOORS.size() - 1) != floor_view:
		return
	var centre: Vector2 = to_screen.call(player.global_position)
	var forward := -player.global_basis.z
	var heading := Vector2(forward.x, forward.z).normalized()
	var side := Vector2(-heading.y, heading.x)
	draw_colored_polygon(PackedVector2Array([
		centre + heading * 13.0, centre - heading * 7.0 + side * 8.0, centre - heading * 7.0 - side * 8.0,
	]), Color(0.2, 1.0, 0.5))
	draw_arc(centre, 17.0 + 3.0 * sin(_time * 3.0), 0.0, TAU, 24, Color(0.2, 1.0, 0.5, 0.5), 1.5)


func _draw_tasks(font: Font) -> void:
	var campaign := get_tree().get_first_node_in_group("campaign")
	if campaign and campaign.day <= 3:
		var y0 := HEADER + 28.0
		for line: String in campaign.phone_lines():
			draw_string(font, Vector2(14.0, y0), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 13, Color(0.85, 0.9, 1.0))
			y0 += 20.0
		var tasks := get_tree().get_first_node_in_group("tasks")
		if tasks == null:
			return
		y0 += 8.0
		for line: String in tasks.lines(campaign.day):
			var colour := (
				Color(0.45, 0.9, 0.55) if line.begins_with("[x]")
				else (Color(1.0, 0.5, 0.4) if line.begins_with("[!]")
				else (Color(0.6, 0.65, 0.75) if line.begins_with(" ") else Color(0.85, 0.9, 1.0)))
			)
			var width := LOGICAL_WIDTH - 24.0
			draw_multiline_string(font, Vector2(14.0, y0), line, HORIZONTAL_ALIGNMENT_LEFT, width, 11, -1, colour)
			y0 += font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, width, 11).y + 3.0
		return
	var quest := get_tree().get_first_node_in_group("quest")
	if quest == null:
		return
	var y := HEADER + 28.0
	for line: String in quest.task_lines():
		var done := line.begins_with("[x]")
		var colour := Color(0.45, 0.9, 0.55) if done else (Color(0.85, 0.9, 1.0) if not line.begins_with(" ") else Color(0.6, 0.65, 0.75))
		draw_string(font, Vector2(14.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 13, colour)
		y += 24.0
	y += 14.0
	draw_string(font, Vector2(14.0, y), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.9, 1.0))
	draw_multiline_string(font, Vector2(14.0, y + 18.0), quest.hint(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 13,
			-1, Color(0.9, 0.9, 0.95))


func _draw_clues(font: Font) -> void:
	var campaign := get_tree().get_first_node_in_group("campaign")
	var y := HEADER + 28.0
	if campaign == null or campaign.clues.is_empty():
		draw_string(font, Vector2(14.0, y), "No clues yet. Search the rooms during breaks.",
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 13, Color(0.6, 0.65, 0.75))
		return
	for text: String in campaign.clues:
		draw_multiline_string(font, Vector2(14.0, y), "- " + text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 12,
				-1, Color(0.85, 0.9, 1.0))
		y += 40.0


func items_text() -> String:
	var finds := get_tree().get_first_node_in_group("finds")
	if finds == null:
		return ""
	if finds.items_total > 0:
		return "Items  %d/%d" % [finds.items_found, finds.items_total]
	return "Items  %d" % finds.items_found


## Page 3: per category a count, then the found titles in the order found and "???" for the rest, in two columns.
func _draw_finds(font: Font) -> void:
	var finds := get_tree().get_first_node_in_group("finds")
	if finds == null:
		return
	var y := HEADER + 26.0
	for cat: Array in [["page", "Pages", Finds.PAGES.size()], ["secret", "Secrets", Finds.SECRETS.size()],
			["card", "Cards", Finds.CARDS.size()]]:
		var names: Array[String] = []
		for id: String in finds.found:
			if Finds.kind_of(id) == cat[0]:
				names.append(Finds.entry(id)["title"])
		draw_string(font, Vector2(14.0, y), "%s  %d/%d" % [cat[1], names.size(), cat[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.4, 0.9, 1.0))
		y += 18.0
		for i in mini(cat[2], 12):
			var known := i < names.size()
			draw_string(font, Vector2(14.0 + (i % 2) * 140.0, y + floorf(i / 2.0) * 15.0), names[i] if known else "???",
					HORIZONTAL_ALIGNMENT_LEFT, 134.0, 11, Color(0.85, 0.9, 1.0) if known else Color(0.45, 0.5, 0.6))
		y += ceili(mini(cat[2], 12) / 2.0) * 15.0 + 12.0
	draw_string(font, Vector2(14.0, y), items_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.9, 1.0))
	var feed := get_tree().get_first_node_in_group("neu_mecha")
	if feed:
		draw_string(font, Vector2(14.0, y + 20.0), "Chameleons  %d/%d" % [feed.found_count(), Finds.MECHA.size()],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.9, 1.0))


## Page 4: the neu_mecha feed, newest post first, at most three. The newest card shows the photo at card width,
## the two older ones a thumbnail (three full photos do not fit the screen).
func _draw_mecha(font: Font) -> void:
	var feed := get_tree().get_first_node_in_group("neu_mecha")
	if feed == null:
		return
	var posts: Array = feed.posts()
	posts.reverse()
	if posts.is_empty():
		draw_string(font, Vector2(14.0, HEADER + 28.0), "No post yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.65, 0.75))
	var y := HEADER + 8.0
	for i in mini(posts.size(), 3):
		var post: Dictionary = posts[i]
		var big := i == 0
		var photo := Rect2(16.0, y + 8.0, 268.0, 201.0) if big else Rect2(16.0, y + 8.0, 64.0, 48.0)
		var text_x := 16.0 if big else 88.0
		var text_y := photo.end.y + 16.0 if big else y + 20.0
		var text_w := LOGICAL_WIDTH - 8.0 - text_x
		var caption: String = post["caption"]
		var caption_h := font.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, text_w, 11).y
		var h := maxf(photo.end.y + 8.0, text_y + caption_h + 6.0) - y
		draw_rect(Rect2(8.0, y, LOGICAL_WIDTH - 16.0, h), Color(0.07, 0.09, 0.14))
		if post["photo"] != null:
			draw_texture_rect(post["photo"], photo, false)
		else:
			draw_rect(photo, Color(0.02, 0.02, 0.03))
			draw_string(font, Vector2(photo.position.x, photo.get_center().y + 4.0), "photo unavailable",
					HORIZONTAL_ALIGNMENT_CENTER, photo.size.x, 11 if big else 8, Color(0.45, 0.5, 0.6))
		draw_string(font, Vector2(text_x, text_y), "neu_mecha  day %d" % post["day"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.4, 0.9, 1.0))
		if post["found"]:
			draw_string(font, Vector2(text_x, text_y), "found", HORIZONTAL_ALIGNMENT_RIGHT, text_w - 8.0, 12,
					Color(0.45, 0.9, 0.55))
		draw_multiline_string(font, Vector2(text_x, text_y + 15.0), caption, HORIZONTAL_ALIGNMENT_LEFT, text_w - 8.0, 11, -1,
				Color(0.85, 0.9, 1.0))
		y += h + 8.0
	draw_string(font, Vector2(14.0, size.y * LOGICAL_WIDTH / size.x - 14.0),
			"Chameleons  %d/%d" % [feed.found_count(), Finds.MECHA.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.9, 1.0))


## The closer the entity (when awake), the more the screen breaks up.
func _draw_interference(player: Node3D) -> void:
	var entity := get_tree().get_first_node_in_group("entity") as Node3D
	if entity == null or not entity.visible:
		return
	var distance := player.global_position.distance_to(entity.global_position)
	var strength := clampf(1.0 - distance / 22.0, 0.0, 1.0)
	if strength <= 0.0:
		return
	for i in int(strength * 40.0):
		var y := randf() * size.y
		draw_rect(Rect2(0.0, y, size.x, randf_range(1.0, 4.0)), Color(0.8, 0.9, 1.0, randf() * strength * 0.5))
	if randf() < strength * 0.15:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.7))
