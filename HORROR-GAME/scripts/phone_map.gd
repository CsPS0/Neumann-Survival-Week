extends Control
## Contents of the phone screen. Page 0: whole-floor plan (arrows switch floor; the player marker only with the easy map).
## Page 1: the tasks (what to do now, the day tasks or the story task list). Page 2: collected clues. Page 3: finds. Page 4: neu_mecha.
## Page 5: e-Kréten (timetable, grades, absences, messages). Page 6: Neumann Diákhirdetmények (lost items and news).
## Finds everything it needs through groups ("player", "entity", "quest", ...).

const FloorData := preload("res://scripts/floor_data.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Finds := preload("res://scripts/finds.gd")
const Ekreta := preload("res://scripts/ekreta.gd")
const Bulletin := preload("res://scripts/bulletin.gd")
const TYPE_FILL := {
	"normal": Color(0.1, 0.16, 0.32), "computer": Color(0.08, 0.24, 0.26), "wc": Color(0.16, 0.19, 0.25),
	"gym": Color(0.36, 0.2, 0.08), "entrance": Color(0.34, 0.3, 0.08), "other": Color(0.09, 0.09, 0.1),
}

const FLOOR_HEIGHT := 4.0
const HEADER := 46.0
const LOGICAL_WIDTH := 300.0     ## Pages 1+ are laid out for 300x560 and scaled to the real viewport.
const BAR := 24.0                ## Height of the app bar at the bottom (logical units).
const PAGE_COUNT := 7
const APP_NAMES := ["MAP", "TASKS", "CLUES", "FINDS", "MECHA", "e-KRÉTEN", "NOTICES"]
const ONE_HAND_APPS := 2         ## One hand opens the first two apps: map and tasks.
const MAX_ZOOM := 6.0
const ZOOM_STEP := 1.5

const EK_BLUE := Color(0.0, 0.5, 0.72)
const EK_TEXT := Color(0.13, 0.16, 0.2)
const EK_GREY := Color(0.42, 0.46, 0.52)
const EK_CARD := Color(1.0, 1.0, 1.0)
const GRADE_COLOURS := [Color(0.85, 0.2, 0.2), Color(0.9, 0.5, 0.15), Color(0.9, 0.75, 0.1), Color(0.5, 0.75, 0.25), Color(0.15, 0.65, 0.35)]
const TAG_COLOURS := {"LOST": Color(0.95, 0.7, 0.2), "FOUND": Color(0.45, 0.9, 0.55), "NEWS": Color(0.4, 0.75, 1.0)}

var page := 0
var floor_view := 0
var zoom := 1.0                  ## Map zoom, 1 = whole floor.
var pan := Vector2.ZERO          ## Map pan in plan pixels, added to the focus (the plan centre, or the player when zoomed with the easy map).
var section := 0                 ## Section of the open app (e-Kréten tab).
var scroll := 0                  ## First visible row of a list page.
var easy := false
var two_hands := false           ## Two hands: all apps. One hand: map and tasks only.
var _time := 0.0
var _bulletin_key := ""
var _bulletin_posts: Array = []


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


## Map: zoom by `factor`. Back at 1x the pan resets.
func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 1.0, MAX_ZOOM)
	if zoom <= 1.0:
		pan = Vector2.ZERO
	else:
		_clamp_pan()


## Map: pan by `dir` (x right, y down) in a fixed share of the visible part. Does nothing at 1x.
func pan_by(dir: Vector2) -> void:
	if zoom <= 1.0:
		return
	var rect: Rect2 = FloorData.FLOORS[floor_view]["rect"]
	pan += dir * rect.size * 0.18 / zoom
	_clamp_pan()


## List pages: move the first visible row by `delta`.
func scroll_by(delta: int) -> void:
	scroll = maxi(scroll + delta, 0)


func set_page(value: int) -> void:
	page = value
	scroll = 0


func set_section(value: int) -> void:
	section = posmod(value, Ekreta.SECTIONS.size())
	scroll = 0


func reset_map(floor_index := 0) -> void:
	floor_view = floor_index
	pan = Vector2.ZERO


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
	var light := page == 5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.95, 0.97) if light else Color(0.03, 0.05, 0.09))
	if page == 0:
		_draw_full_map(player, font, ui)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui)
		match page:
			1: _draw_tasks(font)
			2: _draw_clues(font)
			3: _draw_finds(font)
			4: _draw_mecha(font)
			5: _draw_ekreta(font)
			6: _draw_bulletin(font)

	# Header and app bar (laid out in logical units on every page).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui)
	var header_colour := EK_BLUE if page == 5 else (Color(0.4, 0.22, 0.04) if page == 6 else Color(0.02, 0.03, 0.06))
	draw_rect(Rect2(0.0, 0.0, LOGICAL_WIDTH, HEADER), header_colour)
	var clock := get_tree().get_first_node_in_group("daynight")
	draw_string(font, Vector2(14.0, 20.0), clock.time_text() if clock else "--:--",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
	var titles := ["FLOOR %d" % floor_view, "TASKS", "CLUES", "FINDS", "NEU_MECHA", "e-Kréten", "Diákhirdetmények"]
	draw_string(font, Vector2(14.0, 40.0), titles[page], HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color.WHITE if page >= 5 else Color(0.4, 0.9, 1.0))
	draw_string(font, Vector2(LOGICAL_WIDTH - 130.0, 20.0), "TAB: next  H: %s" % ("1 hand" if two_hands else "2 hands"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.75))
	_draw_app_bar(font)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_interference(player)


## The row of app names at the bottom, the open one highlighted.
func _draw_app_bar(font: Font) -> void:
	var top := size.y / (size.x / LOGICAL_WIDTH) - BAR
	draw_rect(Rect2(0.0, top, LOGICAL_WIDTH, BAR), Color(0.02, 0.03, 0.06))
	var cell := LOGICAL_WIDTH / PAGE_COUNT
	for i in PAGE_COUNT:
		var active := i == page
		var open := two_hands or i < ONE_HAND_APPS
		if active:
			draw_rect(Rect2(i * cell + 2.0, top + 2.0, cell - 4.0, BAR - 4.0), Color(0.12, 0.2, 0.34))
		draw_string(font, Vector2(i * cell, top + 15.0), APP_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, cell, 8,
				Color(0.9, 0.95, 1.0) if active else (Color(0.5, 0.55, 0.65) if open else Color(0.28, 0.3, 0.36)))


## Page 0: the whole floor `floor_view`, fitted to the screen. The player marker, key/altar markers and the
## red-room pulse only show with the easy map.
func _draw_full_map(player: Node3D, font: Font, ui: float) -> void:
	var data: Dictionary = FloorData.FLOORS[floor_view]
	var area := Rect2(8.0, HEADER * ui + 8.0, size.x - 16.0, size.y - HEADER * ui - BAR * ui - 40.0)
	var plan: Rect2 = data["rect"]
	var base := fit(plan, area)
	var s: float = base["scale"] * zoom
	var focus := _focus_plan(player) + pan
	var off: Vector2 = area.get_center() - focus * s
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
			var font_size := clampi(roundi(rect.size.x * 0.28), 8, 24)
			draw_string(font, rect.get_center() + Vector2(-rect.size.x * 0.5, font_size * 0.35), label,
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color(0.45, 0.47, 0.52) if closed else Color(0.8, 0.9, 1.0))
		if closed and rect.size.x >= 40.0 and rect.size.y >= 30.0:
			draw_string(font, rect.get_center() + Vector2(-rect.size.x * 0.5, 15.0), "demo",
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color(0.4, 0.42, 0.46))
	for solid: Array in data["solids"]:
		draw_rect(Rect2(Vector2(solid[0], solid[1]) * s + off, Vector2(solid[2] - solid[0], solid[3] - solid[1]) * s), Color(0.1, 0.3, 0.2))
	var hint_y := size.y - BAR * ui - 10.0
	draw_rect(Rect2(0.0, hint_y - 16.0, size.x, 24.0), Color(0.03, 0.05, 0.09, 0.85))
	draw_string(font, Vector2(8.0, hint_y), "< > floor   +/- or wheel zoom   IJKL pan", HORIZONTAL_ALIGNMENT_LEFT, size.x - 70.0, 11,
			Color(0.6, 0.65, 0.75))
	draw_string(font, Vector2(size.x - 62.0, hint_y), "x%.1f" % zoom, HORIZONTAL_ALIGNMENT_RIGHT, 54.0, 13, Color(0.4, 0.9, 1.0))
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


## Plan pixel the map is centred on: the player when zoomed in with the easy map (on the player's own floor), else the plan centre.
func _focus_plan(player: Node3D) -> Vector2:
	var data: Dictionary = FloorData.FLOORS[floor_view]
	var rect: Rect2 = data["rect"]
	if zoom > 1.0 and easy and clampi(roundi(player.global_position.y / FLOOR_HEIGHT), 0, FloorData.FLOORS.size() - 1) == floor_view:
		var at := Vector2(player.global_position.x, player.global_position.z) / float(data["scale"]) + (data["origin"] as Vector2)
		return at.clamp(rect.position, rect.end)
	return rect.get_center()


## Keeps the panned focus inside the plan rectangle.
func _clamp_pan() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var rect: Rect2 = FloorData.FLOORS[floor_view]["rect"]
	var base := _focus_plan(player) if player != null else rect.get_center()
	pan = (base + pan).clamp(rect.position, rect.end) - base


## Page 1: what to do now, then the day tasks (school days) or the story task list (hunt days). The timetable lives in e-Kréten.
func _draw_tasks(font: Font) -> void:
	var campaign := get_tree().get_first_node_in_group("campaign")
	if campaign == null:
		return
	var y := HEADER + 24.0
	draw_string(font, Vector2(14.0, y), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.9, 1.0))
	var width := LOGICAL_WIDTH - 28.0
	var objective: String = campaign.objective()
	draw_multiline_string(font, Vector2(14.0, y + 17.0), objective, HORIZONTAL_ALIGNMENT_LEFT, width, 12, -1, Color(0.9, 0.9, 0.95))
	y += 17.0 + font.get_multiline_string_size(objective, HORIZONTAL_ALIGNMENT_LEFT, width, 12).y + 16.0
	draw_string(font, Vector2(14.0, y), "TASKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.9, 1.0))
	y += 18.0
	var lines: Array[String] = []
	if campaign.day <= campaign.LAST_SCHOOL_DAY:
		var tasks := get_tree().get_first_node_in_group("tasks")
		if tasks != null:
			lines = tasks.lines(campaign.day)
		lines.append("Skipped lessons: %d/%d (see e-Kréten)" % [campaign.skipped, campaign.SKIP_LIMIT])
	else:
		var quest := get_tree().get_first_node_in_group("quest")
		if quest != null:
			lines = quest.task_lines()
	for line: String in lines:
		var colour := (
			Color(0.45, 0.9, 0.55) if line.begins_with("[x]")
			else (Color(1.0, 0.5, 0.4) if line.begins_with("[!]")
			else (Color(0.6, 0.65, 0.75) if line.begins_with(" ") else Color(0.85, 0.9, 1.0)))
		)
		draw_multiline_string(font, Vector2(14.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, width, 11, -1, colour)
		y += font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, width, 11).y + 4.0


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
	draw_string(font, Vector2(14.0, size.y * LOGICAL_WIDTH / size.x - BAR - 8.0),
			"Chameleons  %d/%d" % [feed.found_count(), Finds.MECHA.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.9, 1.0))


## Page 5: e-Kréten. Light screen, blue header, four sections (Left / Right) and lists that scroll (I / K).
func _draw_ekreta(font: Font) -> void:
	var campaign := get_tree().get_first_node_in_group("campaign")
	if campaign == null:
		return
	var cell := LOGICAL_WIDTH / Ekreta.SECTIONS.size()
	for i in Ekreta.SECTIONS.size():
		var active := i == section
		draw_rect(Rect2(i * cell, HEADER, cell, 24.0), EK_CARD)
		draw_string(font, Vector2(i * cell, HEADER + 16.0), Ekreta.SECTIONS[i], HORIZONTAL_ALIGNMENT_CENTER, cell, 11,
				EK_BLUE if active else EK_GREY)
		if active:
			draw_rect(Rect2(i * cell + 6.0, HEADER + 21.0, cell - 12.0, 3.0), EK_BLUE)
	var y := HEADER + 40.0
	draw_string(font, Vector2(14.0, y), "%s  |  %s  |  day %d" % [Ekreta.STUDENT, Ekreta.SCHOOL, campaign.day],
			HORIZONTAL_ALIGNMENT_LEFT, LOGICAL_WIDTH - 28.0, 10, EK_GREY)
	y += 10.0
	var bottom := size.y * LOGICAL_WIDTH / size.x - BAR - 6.0
	match section:
		0: _ek_timetable(font, campaign, y, bottom)
		1: _ek_grades(font, campaign, y, bottom)
		2: _ek_absences(font, campaign, y, bottom)
		3: _ek_messages(font, campaign, y, bottom)


func _ek_empty(font: Font, y: float, text: String) -> void:
	draw_multiline_string(font, Vector2(14.0, y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, LOGICAL_WIDTH - 28.0, 12, -1, EK_GREY)


func _ek_timetable(font: Font, campaign: Node, y: float, bottom: float) -> void:
	var rows := Ekreta.timetable(campaign)
	if rows.is_empty():
		_ek_empty(font, y, "No lessons today. The extraordinary break lasts until further notice.")
		return
	var clock := get_tree().get_first_node_in_group("daynight")
	var now: int = campaign.lesson_at(clock.minutes) if clock else -1
	for i in rows.size():
		var row: Dictionary = rows[i]
		var card := Rect2(8.0, y, LOGICAL_WIDTH - 16.0, 48.0)
		draw_rect(card, EK_CARD)
		draw_rect(Rect2(card.position, Vector2(3.0, card.size.y)), EK_BLUE if i == now else Color(0.8, 0.84, 0.88))
		draw_string(font, card.position + Vector2(12.0, 19.0), row["time"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, EK_TEXT)
		draw_string(font, card.position + Vector2(56.0, 19.0), row["subject"], HORIZONTAL_ALIGNMENT_LEFT, 120.0, 13, EK_TEXT)
		draw_string(font, card.position + Vector2(56.0, 36.0), "room %s  |  %s" % [row["room"], row["teacher"]],
				HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 64.0, 9, EK_GREY)
		var chip := ""
		var colour := EK_GREY
		if row["status"] == "done":
			chip = "Held"
			colour = Color(0.15, 0.6, 0.3)
		elif row["status"] == "missed":
			chip = "Absent"
			colour = Color(0.8, 0.2, 0.2)
		elif row["status"] == "cancelled":
			chip = "Cancelled"
		elif row["sick"]:
			chip = "Substitute"
			colour = Color(0.85, 0.5, 0.1)
		elif i == now:
			chip = "Now"
			colour = EK_BLUE
		draw_string(font, card.position + Vector2(card.size.x - 86.0, 19.0), chip, HORIZONTAL_ALIGNMENT_RIGHT, 78.0, 10, colour)
		y += 52.0


func _ek_grades(font: Font, campaign: Node, y: float, bottom: float) -> void:
	var grades: Array = campaign.grades.duplicate()
	if grades.is_empty():
		_ek_empty(font, y, "No grades yet. Grades appear here after your lessons.")
		return
	draw_string(font, Vector2(14.0, y + 14.0), "Average  %.2f" % Ekreta.average(grades, campaign.TEST_DAY),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, EK_TEXT)
	y += 26.0
	grades.reverse()
	scroll = mini(scroll, maxi(grades.size() - 1, 0))
	for i in range(scroll, grades.size()):
		if y + 38.0 > bottom:
			break
		var entry: Dictionary = grades[i]
		var grade := Ekreta.grade_for(int(entry["correct"]), int(entry["total"]))
		draw_rect(Rect2(8.0, y, LOGICAL_WIDTH - 16.0, 36.0), EK_CARD)
		draw_circle(Vector2(30.0, y + 18.0), 13.0, GRADE_COLOURS[grade - 1])
		draw_string(font, Vector2(24.0, y + 24.0), str(grade), HORIZONTAL_ALIGNMENT_CENTER, 12.0, 16, Color.WHITE)
		draw_string(font, Vector2(52.0, y + 15.0), entry["subject"], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 12, EK_TEXT)
		var weight := "  |  200%" if int(entry["day"]) == campaign.TEST_DAY else ""
		draw_string(font, Vector2(52.0, y + 29.0), "%s  |  day %d  |  %d/%d%s" % [Ekreta.kind_of(entry, campaign.TEST_DAY),
				entry["day"], entry["correct"], entry["total"], weight], HORIZONTAL_ALIGNMENT_LEFT, 230.0, 9, EK_GREY)
		y += 40.0


func _ek_absences(font: Font, campaign: Node, y: float, bottom: float) -> void:
	draw_string(font, Vector2(14.0, y + 14.0), "Unexcused  %d / %d" % [campaign.skipped, campaign.SKIP_LIMIT],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.2, 0.2) if campaign.skipped > 0 else EK_TEXT)
	y += 26.0
	if campaign.absences.is_empty():
		_ek_empty(font, y, "No absences. At %d unexcused absences you are expelled." % campaign.SKIP_LIMIT)
		return
	var list: Array = campaign.absences.duplicate()
	list.reverse()
	scroll = mini(scroll, maxi(list.size() - 1, 0))
	for i in range(scroll, list.size()):
		if y + 38.0 > bottom:
			break
		var entry: Dictionary = list[i]
		draw_rect(Rect2(8.0, y, LOGICAL_WIDTH - 16.0, 36.0), EK_CARD)
		draw_rect(Rect2(8.0, y, 3.0, 36.0), Color(0.8, 0.2, 0.2))
		draw_string(font, Vector2(20.0, y + 15.0), entry["subject"], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 12, EK_TEXT)
		draw_string(font, Vector2(20.0, y + 29.0), "day %d, %s" % [entry["day"], campaign.fmt(campaign.lesson_start(int(entry["lesson"])))],
				HORIZONTAL_ALIGNMENT_LEFT, 150.0, 9, EK_GREY)
		draw_string(font, Vector2(170.0, y + 22.0), "Unexcused", HORIZONTAL_ALIGNMENT_RIGHT, 114.0, 10, Color(0.8, 0.2, 0.2))
		y += 40.0


func _ek_messages(font: Font, campaign: Node, y: float, bottom: float) -> void:
	var list := Ekreta.messages(campaign.day)
	scroll = mini(scroll, maxi(list.size() - 1, 0))
	var width := LOGICAL_WIDTH - 40.0
	for i in range(scroll, list.size()):
		var m: Array = list[i]
		var body_h := font.get_multiline_string_size(m[3], HORIZONTAL_ALIGNMENT_LEFT, width, 10).y
		var h := 36.0 + body_h
		if y + h > bottom and i > scroll:
			break
		draw_rect(Rect2(8.0, y, LOGICAL_WIDTH - 16.0, h), EK_CARD)
		draw_string(font, Vector2(18.0, y + 14.0), m[2], HORIZONTAL_ALIGNMENT_LEFT, 190.0, 12, EK_TEXT)
		draw_string(font, Vector2(18.0, y + 27.0), "%s  |  day %d" % [m[1], m[0]], HORIZONTAL_ALIGNMENT_LEFT, width, 9, EK_BLUE)
		draw_multiline_string(font, Vector2(18.0, y + 41.0), m[3], HORIZONTAL_ALIGNMENT_LEFT, width, 10, -1, EK_GREY)
		y += h + 6.0


## Page 6: Neumann Diákhirdetmények. Posts of the days so far, newest day first, scrolled with I / K.
func _draw_bulletin(font: Font) -> void:
	var campaign := get_tree().get_first_node_in_group("campaign")
	var finds := get_tree().get_first_node_in_group("finds")
	if campaign == null:
		return
	var found: Dictionary = finds.found if finds != null else {}
	var key := "%d:%d" % [campaign.day, found.size()]
	if key != _bulletin_key:
		_bulletin_key = key
		_bulletin_posts = Bulletin.posts(campaign.day, found)
	var lost := 0
	var back := 0
	for post: Dictionary in _bulletin_posts:
		if post["find"] != "":
			lost += 1
			back += 1 if post["found"] else 0
	var y := HEADER + 20.0
	draw_string(font, Vector2(14.0, y), "Lost items: %d of %d posted are back" % [back, lost], HORIZONTAL_ALIGNMENT_LEFT,
			LOGICAL_WIDTH - 28.0, 11, Color(0.95, 0.8, 0.5))
	y += 10.0
	var bottom := size.y * LOGICAL_WIDTH / size.x - BAR - 6.0
	var width := LOGICAL_WIDTH - 36.0
	scroll = mini(scroll, maxi(_bulletin_posts.size() - 1, 0))
	for i in range(scroll, _bulletin_posts.size()):
		var post: Dictionary = _bulletin_posts[i]
		var body_h := font.get_multiline_string_size(post["text"], HORIZONTAL_ALIGNMENT_LEFT, width, 10).y
		var h := 36.0 + body_h
		if y + h > bottom and i > scroll:
			break
		draw_rect(Rect2(8.0, y, LOGICAL_WIDTH - 16.0, h), Color(0.08, 0.1, 0.15))
		var colour: Color = TAG_COLOURS[post["tag"]]
		draw_rect(Rect2(8.0, y, 3.0, h), colour)
		draw_string(font, Vector2(18.0, y + 14.0), post["tag"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, colour)
		draw_string(font, Vector2(LOGICAL_WIDTH - 90.0, y + 14.0), "day %d" % post["day"], HORIZONTAL_ALIGNMENT_RIGHT, 74.0, 9,
				Color(0.5, 0.55, 0.65))
		draw_string(font, Vector2(18.0, y + 28.0), post["title"], HORIZONTAL_ALIGNMENT_LEFT, width, 12,
				Color(0.5, 0.55, 0.65) if post["found"] else Color(0.9, 0.93, 1.0))
		draw_multiline_string(font, Vector2(18.0, y + 42.0), post["text"], HORIZONTAL_ALIGNMENT_LEFT, width, 10, -1,
				Color(0.65, 0.7, 0.8))
		y += h + 6.0


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
