extends CanvasLayer
## Title screen, pause menu and their sub-pages. Runs while the tree is paused. The 3D school behind the title is
## the live world: main.gd runs a slow camera dolly and shows the entity at the end of the corridor.

signal start_requested
signal resume_requested
signal restart_requested

const Endings := preload("res://scripts/endings.gd")
const Achievements := preload("res://scripts/achievements.gd")
const SettingsUI := preload("res://scripts/settings_ui.gd")

const LORE := "Five days at the Neumann school. Something in the building is not what it seems.\n\n" \
		+ "Attend your lessons, watch the teachers, and find out who it is before it finds you."
const CONTROLS := "WASD  move        Shift  sprint        Mouse  look\n" \
		+ "F  flashlight        Q  phone (Tab: apps)        E  interact\n" \
		+ "G  name the entity (day 4)        Esc  pause"

var profile: Node
var on_settings_changed := Callable()

var _pages := {}
var _list_label := Label.new()
var _ach_label := Label.new()
var _title_label := Label.new()
var _flicker := 0.0
var _from_title := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build_title()
	_build_pause()
	_build_settings_page()
	_build_page("achievements", "ACHIEVEMENTS", _ach_label)
	_build_page("endings", "ENDINGS", _list_label)
	var how := Label.new()
	how.text = CONTROLS
	_build_page("how", "HOW TO PLAY", how)
	_build_lobby_page()
	show_title()


func _process(delta: float) -> void:
	_flicker -= delta
	if _pages["title"].visible and _flicker <= 0.0:
		_flicker = randf_range(0.05, 0.6)
		_title_label.modulate.a = 1.0 if randf() > 0.15 else randf_range(0.3, 0.8)
	if _pages.has("lobby") and _pages["lobby"].visible:
		_refresh_lobby()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or not is_open():
		return
	if _pages["pause"].visible:
		resume_requested.emit()
	elif not _pages["title"].visible:
		_open("title" if _from_title else "pause")   # Sub-page: back to where it came from.
	get_viewport().set_input_as_handled()


func show_title() -> void:
	_from_title = true
	_open("title")


func show_pause() -> void:
	_from_title = false
	_open("pause")


func hide_all() -> void:
	for page: Control in _pages.values():
		page.visible = false


func is_open() -> bool:
	for page: Control in _pages.values():
		if page.visible:
			return true
	return false


func _open(page_name: String) -> void:
	_refresh_lists()
	for key: String in _pages:
		_pages[key].visible = key == page_name


func _refresh_lists() -> void:
	_list_label.text = _endings_text()
	_ach_label.text = _achievements_text()
	if _pages.has("lobby") and _pages["lobby"].visible:
		_refresh_lobby()


func _endings_text() -> String:
	var lines: Array[String] = []
	for id in range(1, Endings.COUNT + 1):
		var seen: bool = profile != null and profile.endings_seen.has(id)
		lines.append("%d. %s" % [id, Endings.LIST[id]["title"] if seen else "???"])
	return "\n".join(lines)


func _achievements_text() -> String:
	var lines: Array[String] = []
	for id: String in Achievements.LIST:
		var got: bool = profile != null and profile.has(id)
		lines.append("%s %s - %s" % ["[x]" if got else "[ ]", Achievements.LIST[id][0],
				Achievements.LIST[id][1] if got else "???"])
	return "\n".join(lines)


## A full-screen page: a left-hand shade panel with a VBox on top. Returns the VBox.
func _new_page(key: String, shade_alpha: float) -> VBoxContainer:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_pages[key] = page
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760.0
	shade.color = Color(0.0, 0.0, 0.0, shade_alpha)
	page.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	box.offset_left = 70.0
	box.offset_right = 700.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)
	return box


func _build_title() -> void:
	var box := _new_page("title", 0.55)
	_title_label.text = "THE EMPTY SCHOOL"
	_title_label.add_theme_font_size_override("font_size", 60)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.12, 0.1))
	box.add_child(_title_label)
	var lore := Label.new()
	lore.text = LORE
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.add_theme_font_size_override("font_size", 18)
	lore.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	box.add_child(lore)
	box.add_child(_button("New game", func() -> void: start_requested.emit()))
	box.add_child(_button("Host Co-op", func() -> void:
		NetSession.host_session()
		_open("lobby")
	))
	box.add_child(_button("Join Co-op", func() -> void:
		NetSession.join_session("127.0.0.1")
		_open("lobby")
	))
	box.add_child(_button("Achievements", func() -> void: _open("achievements")))
	box.add_child(_button("Endings", func() -> void: _open("endings")))
	box.add_child(_button("Settings", func() -> void: _open("settings")))
	box.add_child(_button("How to play", func() -> void: _open("how")))
	box.add_child(_button("Quit", func() -> void: get_tree().quit()))


func _build_settings_page() -> void:
	var box := _new_page("settings", 0.85)
	box.add_child(_heading("SETTINGS"))
	var ui := SettingsUI.new()
	ui.setup(profile, func() -> void:
		if on_settings_changed.is_valid():
			on_settings_changed.call())
	box.add_child(ui)
	box.add_child(_button("Back", _back))

var _lobby_code_label := Label.new()
var _lobby_players_label := Label.new()

func _build_lobby_page() -> void:
	var box := _new_page("lobby", 0.85)
	box.add_child(_heading("CO-OP LOBBY"))
	
	_lobby_code_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_lobby_code_label)
	
	_lobby_players_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_lobby_players_label)
	
	box.add_child(_button("Start Co-op", func() -> void: start_requested.emit()))
	box.add_child(_button("Back", func() -> void:
		NetSession.leave_session()
		_back()
	))

func _refresh_lobby() -> void:
	if NetSession.is_multiplayer_active():
		_lobby_code_label.text = "Room Code: " + NetSession.get_room_code() if multiplayer.is_server() else "Connected to server"
		_lobby_players_label.text = "Connected Players: " + str(multiplayer.get_peers().size() + 1)
	else:
		_lobby_code_label.text = "Disconnected"
		_lobby_players_label.text = ""


func _build_pause() -> void:
	var box := _new_page("pause", 0.7)
	box.add_child(_heading("PAUSED"))
	box.add_child(_button("Resume", func() -> void: resume_requested.emit()))
	box.add_child(_button("Settings", func() -> void: _open("settings")))
	box.add_child(_button("Restart", func() -> void: restart_requested.emit()))
	box.add_child(_button("Quit", func() -> void: get_tree().quit()))


func _build_page(key: String, title: String, content: Control) -> void:
	var box := _new_page(key, 0.85)
	box.add_child(_heading(title))
	content.add_theme_font_size_override("font_size", 16 if key == "achievements" else 20)
	if key == "achievements":   # More rows than fit at 720p: scroll.
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0.0, 480.0)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(content)
		box.add_child(scroll)
	else:
		box.add_child(content)
	box.add_child(_button("Back", _back))


func _back() -> void:
	_open("title" if _from_title else "pause")


func _heading(text: String) -> Label:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 36)
	return heading


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(action)
	return button
