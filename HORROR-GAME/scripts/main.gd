extends Node3D
## Builds the three-floor school from scripts/floor_data.gd (plan pixels -> metres), places the story
## objects, teachers and lights, bakes one navigation mesh, and runs the HUD, menu and game flow.

const DoorScript := preload("res://scripts/door.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")
const Textures := preload("res://scripts/textures.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const InteractableScript := preload("res://scripts/interactable.gd")
const TeacherScript := preload("res://scripts/teacher_npc.gd")
const CaretakerScript := preload("res://scripts/caretaker.gd")
const CsokiScript := preload("res://scripts/csoki.gd")
const QuestScript := preload("res://scripts/quest.gd")
const DayNightScript := preload("res://scripts/day_night.gd")
const MenuScript := preload("res://scripts/menu.gd")
const CampaignScript := preload("res://scripts/campaign.gd")
const CrowdScript := preload("res://scripts/crowd.gd")
const ScareScript := preload("res://scripts/scare_flash.gd")
const StaffManagerScript := preload("res://scripts/staff_manager.gd")
const EndingScreen := preload("res://scripts/ending_screen.gd")
const Lessons := preload("res://scripts/lessons.gd")
const Clues := preload("res://scripts/clues.gd")
const Rooms := preload("res://scripts/rooms.gd")
const FindsScript := preload("res://scripts/finds.gd")
const PortaScript := preload("res://scripts/porta.gd")
const PorterScript := preload("res://scripts/porter.gd")
const TasksScript := preload("res://scripts/tasks.gd")
const MechaScript := preload("res://scripts/mecha.gd")
const HauntingScript := preload("res://scripts/haunting.gd")
const DreamScript := preload("res://scripts/dream.gd")
const FurnitureScript := preload("res://scripts/furniture.gd")
const HidingSpotScript := preload("res://scripts/hiding_spot.gd")

const WS := FloorData.WORLD_SCALE   ## Shorthand: plan-tied metre values are multiplied by it, human-sized ones are not.
const FLOOR_HEIGHT := 4.0       ## Floor-to-floor distance.
const WALL_HEIGHT := 3.2
const WALL_THICKNESS := 0.25
const DOOR_WIDTH := 1.5
const DOOR_HEIGHT := 2.2
const STAIR_STEPS := 22
const FLOOR_NAMES := ["Ground floor", "1st floor", "2nd floor"]
const TEACHER_ORDER: Array = Lessons.SUSPECT_IDS   ## Accusation options, in button order.

## Stairwell footprints in metres (identical on every floor), plan sized times WORLD_SCALE. Each flight climbs towards +Z.
const STAIR_X := [[-8.8 * WS, -7.0 * WS], [7.0 * WS, 8.8 * WS]]
const STAIR_Z := [[-11.9 * WS, -4.4 * WS], [6.4 * WS, 13.9 * WS]]

const DOOR_SWING := {"N": -1.0, "S": 1.0, "W": 1.0, "E": -1.0}
const OUTWARD := {"N": Vector2(0, -1), "S": Vector2(0, 1), "W": Vector2(-1, 0), "E": Vector2(1, 0)}

## Open rooms that never hold the red room or a note: the fixed story rooms and the lesson rooms.
const RESERVED_ROOMS := ["5", "14", "24", "33", "229", "205", "GT8", "114", "23", "113", "28", "109", "121", "GT11-12", "GT2"]

const CLASS_OPEN_EARLY := 5.0   ## Game minutes before the bell that the teacher opens the classroom.

const AFTER_HOURS_ROOMS := [[2, "205"], [2, "GT8"], [1, "114"]]   ## One per day: locked until the last bell.
## Useful items on corner tables (same spot rule as the finds: `FindsScript.spot_position`), in open rooms only.
## 129 uses slot 2: its slot 1 holds the "Diary 2" find.
const ITEM_SPOTS := [
	{"id": "master_key", "kind": "key_card", "room": "GT10", "floor": 1, "slot": 2},
	{"id": "biscuit_gt3", "kind": "biscuit", "room": "GT3", "floor": 0, "slot": 1},
	{"id": "biscuit_45", "kind": "biscuit", "room": "45", "floor": 0, "slot": 1},
	{"id": "biscuit_wc", "kind": "biscuit", "room": "WC", "floor": 2, "slot": 0},
	{"id": "battery_35", "kind": "battery", "room": "35", "floor": 0, "slot": 1},
	{"id": "battery_129", "kind": "battery", "room": "129", "floor": 1, "slot": 2},
	{"id": "battery_gt5", "kind": "battery", "room": "GT5", "floor": 2, "slot": 1},
	{"id": "battery_gym", "kind": "battery", "room": "Tornaterem", "floor": 0, "slot": 1},
]
const ITEM_INFO := {   ## kind -> [inventory id, name, pickup message]
	"key_card": ["master_key", "Master key card", "A master key card. It should open one staff-only door."],
	"biscuit": ["biscuit", "Dog biscuit", "A dog biscuit. Csoki would follow you anywhere for this."],
	"battery": ["battery", "Battery", ""],
}

## id, name, floor, shirt colour, routine waypoints (plan pixels of that floor).
const TEACHERS := [
	["karpati", "Kárpáti Lajos", 1, Color(0.25, 0.3, 0.55), [Vector2(351, 250), Vector2(540, 289), Vector2(729, 250), Vector2(540, 655)]],
	["szentgyorgyi", "Dr. Szentgyörgyi Aranka", 1, Color(0.5, 0.25, 0.45), [Vector2(729, 250), Vector2(729, 500), Vector2(729, 780)]],
	["halmos", "Halmos Ervin", 0, Color(0.3, 0.45, 0.45), [Vector2(453, 420), Vector2(453, 575), Vector2(560, 580)]],
	["voros", "Vörös Ildikó", 0, Color(0.55, 0.25, 0.3), [Vector2(103, 300), Vector2(103, 146), Vector2(320, 146)]],
	["pasztor", "Pásztor Margit", 1, Color(0.25, 0.5, 0.35), [Vector2(729, 780), Vector2(540, 655), Vector2(351, 780)]],
	["onodi", "Ónodi Bence", 0, Color(0.4, 0.4, 0.2), [Vector2(200, 540), Vector2(330, 580), Vector2(103, 400)]],
	["fekete", "Fekete Zsombor", 2, Color(0.3, 0.3, 0.5), [Vector2(351, 250), Vector2(540, 289), Vector2(729, 250)]],
	["lazar", "Lázár Tivadar", 2, Color(0.2, 0.2, 0.22), [Vector2(351, 700), Vector2(351, 500), Vector2(540, 655)]],
]

@onready var player := $Player
@onready var entity := $HorrorEntity

var quest := QuestScript.new()
var daynight := DayNightScript.new()
var menu := MenuScript.new()
var campaign := CampaignScript.new()
var crowd := CrowdScript.new()
var scare := ScareScript.new()
var staff_manager := StaffManagerScript.new()
var finds := FindsScript.new()
var porta := PortaScript.new()
var tasks := TasksScript.new()
var dream := DreamScript.new()   ## Hunt days: the demon follows the player into a nap.
var haunting := HauntingScript.new()   ## Day 3: the demon starts pranking the player.
var mecha := MechaScript.new()   ## The daily neu_mecha chameleon and the phone feed.
var furniture := FurnitureScript.new()   ## Desks, PCs and WC fixtures; built before the navmesh bake.
var _table_spots: Array[Vector3] = []    ## Every `_table()` centre: furniture keeps clear of them.
var porter: Node        ## Mr. Bakó at the Porta desk (group "porta", never "teachers").
var ending_screen := EndingScreen.new()
var profile := preload("res://scripts/profile.gd").new()
var achievements := preload("res://scripts/achievements.gd").new()
var choice_ui := preload("res://scripts/choice_ui.gd").new()
var answer_sheet := preload("res://scripts/answer_sheet.gd").new()
var lesson_ui := preload("res://scripts/lesson_ui.gd").new()

var _menu_camera := Camera3D.new()
var _menu_tween: Tween
var _region := NavigationRegion3D.new()
var _wall_material := Textures.wall()
var _floor_material := Textures.floor_tiles()
var _ceiling_material := Textures.ceiling()
var _door_material := Textures.wood()
var _locked_material := Textures.wood(Color(1.7, 0.3, 0.3))
var _closed_material := Textures.wood(Color(0.45, 0.45, 0.5))   ## Demo-locked doors and barriers.
var _stair_material := Textures.concrete()
var _planter_material := _make_material(Color(0.12, 0.3, 0.2), 0.9)
var _metal_material := _make_material(Color(0.25, 0.27, 0.3), 0.5)
var _stone_material := _make_material(Color(0.4, 0.38, 0.36), 0.95)

var _hud_layer := CanvasLayer.new()
var _hud := Label.new()
var _stamina_bg := ColorRect.new()
var _stamina_bar: ColorRect
var _stamina_tween: Tween
var _prompt_label := Label.new()
var _message_label := Label.new()
var _flash := ColorRect.new()
var _code_panel := PanelContainer.new()
var _code_label := Label.new()
var _message_tween: Tween
var _flash_tween: Tween
var _hud_timer := 0.0

var _game_over := false
var _lesson_index := 0
var _code_open := false
var _code_buffer: Array[int] = []
var _battery := 1.0
var _floor_index := 0
var _accusing := false
var _fate_open := false   ## Set while the cure-or-destroy prompt is open.
var _deal_kind := ""    ## Set while the altar's pact prompt is open.
var _porta_kind := ""   ## Set while a Porta list (porter menu, key list, key board) is open.
var _porta_labels: Array = []
var _porter_line := -1
var _desk_position := Vector3.ZERO   ## Where the porter stands, behind the Porta desk.
var _wc_point := Vector3.ZERO        ## The porter's WC (second ground-floor WC).
var _front_door: Node   ## Its prompt follows the clock (go home vs run away).

var _red_room := [-1, -1]                 ## [floor, room index] of the locked room.
var _note_rooms: Array = []               ## Four [floor, room index].
var _note_pool: Array = []                ## Unused classrooms left over for the clues.
var _clue_rooms: Array = []               ## Classrooms picked for the open clues, shuffled once.
var _clue_spots: Array[Vector3] = []      ## Pickup positions on the clue tables, index = clue number.
var _find_spots := {}                     ## Find id -> pickup position on its table.
var _item_spots := {}                     ## ITEM_SPOTS id -> pickup position on its table.
var _form_spot := Vector3.ZERO            ## The signed form's table (day-1 sticker task).
var _form_room_label := ""
var _form_room_floor := -1
var _strange_object: Node3D                 ## Cracked object in Lab 14 (from day 2).
var _lab_fire: OmniLight3D                  ## Flickering glow in the wrecked lab on day 1 after the blast.
var _vial: Node3D                         ## Holy water: needs the hunt and the fuse.
var _room_doors := {}                     ## "floor:label" -> Door
var _room_panels := {}                    ## "floor:label" -> every panel Door of the room (a classroom can have two).
var _class_open := {}                     ## Classroom label -> its teacher has opened it for the lesson.
var _class_timer := 0.0
var csoki: Node         ## The caretaker's dog; lives in the ground-floor hall all week.
var _last_door: Node
var _patrol_markers: Array[Marker3D] = []
var _spawn_point := Vector3(-2.75 * WS, 0.1, 17.4 * WS)
var _nav_offset := 0.3
var _altar: StaticBody3D
var _fuse_box: Node3D
var _safe: Node3D
var _altar_meshes := {}
var _altar_candles: Array[OmniLight3D] = []

# Plan -> world conversion of the floor currently being built.
var _origin := Vector2.ZERO
var _scale := 1.0
var _y := 0.0
var _floor_i := 0
var _puppets := {}
const PlayerPuppetScene = preload("res://scenes/player_puppet.tscn")


func _ready() -> void:
	set_process(false)
	
	var bridge := preload("res://scripts/input_bridge.gd").new()
	bridge.name = "InputBridge"
	add_child(bridge)
	
	if XRManager.is_xr_active():
		var rig = preload("res://scenes/xr_player_rig.tscn").instantiate()
		player.add_child(rig)
		if player.has_node("Head/Camera3D/Torch"):
			player.get_node("Head/Camera3D/Torch").visible = false
		if player.has_node("Head/Camera3D/Phone"):
			player.get_node("Head/Camera3D/Phone").visible = false
	
	var platform_config := preload("res://scripts/platform_config.gd").new()
	platform_config.name = "PlatformConfig"
	add_child(platform_config)
	
	var touch_controls := preload("res://scenes/touch_controls.tscn").instantiate()
	add_child(touch_controls)
	
	add_child(profile)
	achievements.profile = profile
	add_child(achievements)
	profile.load_from_disk()   # Before the menu: Task 11 hands it to the menu before add_child(menu).
	add_child(quest)
	add_child(daynight)
	menu.profile = profile
	menu.on_settings_changed = _apply_settings
	add_child(menu)
	add_child(campaign)
	add_child(ending_screen)
	add_child(choice_ui)
	add_child(answer_sheet)
	lesson_ui.choice_ui = choice_ui
	lesson_ui.sheet = answer_sheet
	lesson_ui.typed = not XRManager.is_xr_active()
	add_child(lesson_ui)
	daynight.environment = $WorldEnvironment.environment
	quest.player = player
	quest.daynight = daynight
	quest.floor_names = FLOOR_NAMES
	quest.campaign = campaign
	quest.porta = porta
	campaign.daynight = daynight
	campaign.player = player
	campaign.quest = quest
	campaign.room_check = func(i: int) -> bool: return _player_in_room(Lessons.subject_at(campaign.day, i))
	crowd.player = player
	crowd.entity = entity
	crowd.campaign = campaign
	crowd.daynight = daynight
	add_child(crowd)
	scare.main = self
	add_child(scare)
	staff_manager.player = player
	staff_manager.campaign = campaign
	staff_manager.daynight = daynight
	add_child(staff_manager)
	finds.campaign = campaign
	add_child(finds)
	mecha.campaign = campaign
	mecha.main = self
	add_child(mecha)
	haunting.main = self
	add_child(haunting)
	dream.main = self
	add_child(dream)
	porta.campaign = campaign
	porta.player = player
	porta.room_closed = _is_room_closed
	add_child(porta)
	tasks.porta = porta
	tasks.finds = finds
	tasks.campaign = campaign
	add_child(tasks)
	for i in 4:
		quest.code.append(randi() % 10)

	add_child(_region)
	_choose_story_rooms()
	var stair_holes := _stair_rects()
	for i in FloorData.FLOORS.size():
		_build_floor(FloorData.FLOORS[i], i, stair_holes)
	_build_stairs()
	_setup_classrooms()
	_place_story_objects()
	_set_story_active(false)
	var tables: Array[Vector3] = _clue_spots.duplicate()
	tables.append_array(_find_spots.values())
	tables.append_array(_item_spots.values())
	tables.append(_form_spot)
	crowd.avoid = tables   # Seats stay off the clue, find and form tables.
	var stand_clear: Array[Vector3] = _clue_spots.duplicate()
	stand_clear.append(_form_spot)
	staff_manager.avoid = stand_clear   # The form table sits at its room's centre, where a teacher would stand.
	_build_front_door()
	add_child(furniture)
	var keep: Array[Vector3] = _table_spots.duplicate()
	keep.append_array([_fuse_box.position, _safe.position])
	furniture.build(_region, keep)
	crowd.seats = furniture.seats   # Students sit on the furniture's chairs.
	_bake_navigation()
	await get_tree().physics_frame  # The navigation map syncs on the first physics frame.
	await _calibrate_nav_height()
	_setup_patrol()
	_spawn_teachers()
	_spawn_csoki()
	_spawn_porter()
	_place_finds()
	_place_items()
	_place_form()
	_place_lockers()
	_build_hud()
	_connect_signals()
	_apply_settings()
	staff_manager.nav_offset = _nav_offset
	staff_manager.exit_point = _spawn_point
	set_process(true)

	# Day 1 begins at the title screen; the demon sleeps until nightfall, so the torch stays off until then.
	entity.sleep()
	_start_title_scene()
	player.set_flashlight(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Title screen: a slow dolly down the ground-floor corridor with the entity standing frozen at the far end.
## The entity stays asleep (processing disabled, so physics never moves it); only its visibility is switched on.
func _start_title_scene() -> void:
	_select_floor(0)
	var a := _to_world(330.0, 146.0)
	var b := _to_world(850.0, 146.0)
	add_child(_menu_camera)
	_menu_camera.position = Vector3(a.x, 1.6, a.y)
	_menu_camera.rotation.y = -PI * 0.5
	_menu_camera.make_current()
	_menu_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	_menu_tween.tween_property(_menu_camera, "position:x", b.x - 6.0, 30.0).from(a.x)
	entity.global_position = Vector3(b.x, 0.1, b.y)
	entity.rotation.y = PI * 0.5
	entity.visible = true


func _stop_title_scene() -> void:
	if not _menu_camera.is_inside_tree():
		return
	if _menu_tween:
		_menu_tween.kill()
	remove_child(_menu_camera)
	_menu_camera.queue_free()
	player.camera.make_current()
	entity.sleep()


func _process(delta: float) -> void:
	_hud_timer -= delta
	_class_timer -= delta
	if _class_timer <= 0.0:
		_class_timer = 0.5
		_update_classrooms()
	_front_door.prompt = "Go home (next day)" if campaign.day <= CampaignScript.LAST_SCHOOL_DAY 			and daynight.minutes >= CampaignScript.LAST_BELL else "Run away (ends the run)"
	var floor_now := clampi(roundi(player.global_position.y / FLOOR_HEIGHT), 0, FLOOR_NAMES.size() - 1)
	if floor_now != _floor_index or _hud_timer <= 0.0:
		_floor_index = floor_now
		_hud_timer = 0.5
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _code_open:
		_handle_code_input(event)
		return
	if _game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G and not menu.is_open():
		_open_accusation()
	elif event.is_action_pressed(&"ui_cancel") and not _game_over and not menu.is_open() and not choice_ui.visible \
			and not lesson_ui.visible:
		get_tree().paused = true
		_hud_layer.visible = false
		menu.show_pause()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _connect_signals() -> void:
	player.caught.connect(_on_player_caught)
	player.battery_changed.connect(_on_battery_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.exhausted_changed.connect(func(e: bool) -> void:
		if _stamina_bar:
			_stamina_bar.color = Color(0.9, 0.2, 0.2) if e else Color(0.7, 0.85, 1.0)
		if e and player.exhausted_count == 10:
			campaign.event.emit("out_of_breath", {}))
	entity.appeared.connect(func() -> void: scare.trigger())
	entity.spotted.connect(func() -> void:
		if campaign.lethal():
			scare.trigger())
	player.inspected.connect(_show_message)
	player.prompt_changed.connect(func(text: String) -> void: _prompt_label.text = text)
	player.item_added.connect(func(_id: String) -> void: _update_hud())
	player.inventory_changed.connect(_update_hud)
	player.phone_mode_changed.connect(func(_two: bool) -> void: _update_hud())
	daynight.dusk_started.connect(_on_dusk)
	daynight.night_fell.connect(_on_night)
	quest.changed.connect(_on_quest_changed)
	quest.code_requested.connect(_open_code_lock)
	quest.ritual_started.connect(_on_ritual_started)
	quest.ritual_interrupted.connect(_on_ritual_interrupted)
	quest.ritual_completed.connect(_on_ritual_completed)
	quest.choice_requested.connect(_on_choice_requested)
	campaign.day_started.connect(_on_day_started)
	campaign.ending.connect(_on_ending)
	campaign.event.connect(achievements.on_event)
	campaign.event.connect(func(name: String, _data: Dictionary) -> void:
		if name == "explosion":
			_on_explosion())
	achievements.unlocked.connect(func(id: String) -> void:
		_show_message("Achievement: %s" % achievements.LIST[id][0], 4.0))
	campaign.hunt_started.connect(_on_hunt_started)
	choice_ui.chosen.connect(_on_choice)
	campaign.lesson_started.connect(_on_lesson_started)
	campaign.lesson_missed.connect(func(i: int) -> void:
		_show_message("You missed %s." % Lessons.subject_at(campaign.day, i), 4.0))
	campaign.bell.connect(_on_bell)
	lesson_ui.finished.connect(_on_lesson_finished)
	menu.start_requested.connect(_start_game)
	menu.resume_requested.connect(_resume)
	menu.restart_requested.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	
	NetSession.player_joined.connect(_on_peer_connected)
	NetSession.player_left.connect(_on_peer_disconnected)
	if NetSession.is_multiplayer_active():
		for id in multiplayer.get_peers():
			_on_peer_connected(id)

func _on_peer_connected(id: int) -> void:
	var puppet = PlayerPuppetScene.instantiate()
	puppet.name = str(id)
	add_child(puppet)
	_puppets[id] = puppet
	puppet.sync_name.rpc(str(id))

func _on_peer_disconnected(id: int) -> void:
	if _puppets.has(id):
		var puppet = _puppets[id]
		puppet.queue_free()
		_puppets.erase(id)


# --- Game flow --------------------------------------------------------------

func _apply_settings() -> void:
	profile.apply(player, $WorldEnvironment.environment)


func _start_game() -> void:
	_stop_title_scene()
	menu.hide_all()
	_hud_layer.visible = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	campaign.start_day(1)


func _resume() -> void:
	menu.hide_all()
	_hud_layer.visible = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_dusk() -> void:
	_show_message("The sun is setting. The teachers are leaving...", 5.0)
	for teacher: Node in get_tree().get_nodes_in_group("teachers"):
		teacher.leave()


func _on_night() -> void:
	_show_message("Night has fallen. Something wakes up. Keep your light on and your feet quiet.", 6.0)
	for teacher: Node in get_tree().get_nodes_in_group("teachers"):
		teacher.queue_free()  # Anyone still inside is gone by nightfall.
	porta.doze()
	porter.return_to_desk()
	player.set_flashlight(true)
	if not campaign.lethal():
		return   # Days 1-3: the night belongs to the caretaker, not the entity.
	entity.wake(_far_patrol_point())


func _far_patrol_point() -> Vector3:
	var far: Array[Vector3] = []
	for marker in _patrol_markers:
		if marker.global_position.distance_to(player.global_position) > 25.0:
			far.append(marker.global_position)
	return far.pick_random() if not far.is_empty() else _patrol_markers.pick_random().global_position


func _on_player_caught() -> void:
	if _game_over or campaign.ending_id != 0:
		return
	quest.on_player_caught()
	if dream.active:
		entity.sleep()
		dream.caught()   # A dream never kills: you wake up late.
		return
	
	if NetSession.is_multiplayer_active():
		player.is_downed = true
		player.controls_enabled = false
		player.set_flashlight(false)
		NetSession.rpc("update_player_downed", true)
		NetSession.rpc("notify_downed", multiplayer.get_unique_id())
		_show_message("You are down! Wait for a revive.", 5.0)
		return
		
	if campaign.lethal():
		_flash.color.a = 0.85
		create_tween().tween_property(_flash, "color:a", 0.25, 1.5)
		campaign.player_killed()
	else:
		_blackout()


## Days 1-3: the entity cannot kill. The screen goes black and you wake in the entrance hall 20 minutes later.
func _blackout() -> void:
	entity.sleep()
	scare.overlay.color.a = 0.0
	scare.restore()
	if choice_ui.visible or lesson_ui.visible:
		return   # Mid-quiz the entity is asleep anyway; never yank the player out of it.
	campaign.record_blackout()
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = Color(0.0, 0.0, 0.0, 1.0)
	player.global_position = _spawn_point
	player.rotation.y = 0.0
	player.revive()
	player.set_flashlight(false)
	_show_message("You black out. You wake up in the entrance hall. 20 minutes are gone.", 5.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 2.0)
	_flash_tween.tween_callback(func() -> void: _flash.color = Color(0.7, 0.0, 0.0, 0.0))


## Day 1, after the third lesson: Lab 14 explodes and everyone is sent home. The lab door is blown open and burns until
## the next morning, so staying behind pays off with the lab's secrets, at the risk of the caretaker.
func _on_explosion() -> void:
	var boom := AudioStreamPlayer.new()
	boom.stream = SoundBank.explosion()
	boom.volume_db = 4.0
	boom.process_mode = Node.PROCESS_MODE_ALWAYS
	boom.finished.connect(boom.queue_free)
	add_child(boom)
	boom.play()
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = Color(1.0, 0.85, 0.6, 0.95)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 2.5)
	_flash_tween.tween_callback(func() -> void: _flash.color = Color(0.7, 0.0, 0.0, 0.0))
	var door: Node = _room_doors.get("0:14")
	if door:
		door.locked = false
		door.set_open(true)
	if _lab_fire == null:
		var centre := _room_centre(0, "14")
		_lab_fire = OmniLight3D.new()
		_lab_fire.light_color = Color(1.0, 0.45, 0.15)
		_lab_fire.omni_range = 9.0
		_lab_fire.position = centre + Vector3(0.0, 1.8, 0.0)
		add_child(_lab_fire)
		var flicker := create_tween().bind_node(_lab_fire).set_loops()
		flicker.tween_property(_lab_fire, "light_energy", 0.5, 0.17)
		flicker.tween_property(_lab_fire, "light_energy", 1.8, 0.23)
	_show_message("A deafening blast shakes the building. The alarm rings: everyone out, school is cancelled for today.", 7.0)
	get_tree().create_timer(7.5, false).timeout.connect(func() -> void:
		if campaign.day == CampaignScript.INCIDENT_DAY and campaign.ending_id == 0:
			_show_message("Go home through the front door, or stay and find out what happened in Lab 14. The caretaker is on patrol.", 8.0))


func _on_ending(id: int) -> void:
	_game_over = true
	_accusing = false
	_fate_open = false
	_porta_kind = ""
	scare.overlay.color.a = 0.0
	scare.restore()
	if _code_open:
		_close_code_lock()
	choice_ui.close()
	answer_sheet.close()
	entity.sleep()
	player.controls_enabled = false
	ending_screen.show_ending(id, campaign.stats())


func _on_day_started(day: int) -> void:
	player.global_position = _spawn_point
	player.rotation.y = 0.0
	player.revive()
	player.set_flashlight(day > CampaignScript.LAST_SCHOOL_DAY)
	if quest.ritual_active:
		quest.on_player_caught()   # A ritual unfinished at the rollover is over.
	entity.chase_speed = campaign.chase_speed()
	entity.sleep()
	for old in get_tree().get_nodes_in_group("caretaker"):
		old.queue_free()
	var card_was_valid: bool = porta.card_valid
	porta.on_day_started(day)
	_reset_classrooms()
	if day >= 2:
		if _lab_fire:
			_lab_fire.queue_free()
			_lab_fire = null
		var lab_door: Node = _room_doors.get("0:14")
		if lab_door and campaign.incident and day == 2:
			lab_door.set_open(false)
			_lock_lab_door(lab_door, true)   # Police tape: back to the porter's board key.
	_show_strange_object(day >= 2)
	if day >= 2 and not porta.card_valid:
		for form: Node in get_tree().get_nodes_in_group("form"):
			form.queue_free()
	porter.return_to_desk(true)   # Whatever happened yesterday, he starts the day at his desk.
	_spawn_teachers()   # Yesterday's teachers are gone or still walking out; start the day with fresh ones.
	staff_manager.sync_now()
	var day_text := "Day %d. %s%s" % [day, "Your student card expired at midnight. " if card_was_valid and not porta.card_valid else "",
			campaign.objective()]
	if day == 1:
		_show_message(TasksScript.OPENING, 7.0)
		get_tree().create_timer(7.0, false).timeout.connect(func() -> void:
			if campaign.day == 1 and _message_label.text == TasksScript.OPENING:   # Nothing else took the line meanwhile.
				_show_message(day_text, 7.0))
	else:
		_show_message(day_text, 7.0)
	if day <= CampaignScript.LAST_SCHOOL_DAY:
		_station_teachers(0)
	else:
		for room: Array in AFTER_HOURS_ROOMS:   # Hunt days have no last bell: no room stays staff-only.
			_set_after_hours_lock(room, false)
	_place_clues(day)
	mecha.on_day_started(day)
	if day == CampaignScript.LAST_SCHOOL_DAY + 1:
		_open_accusation()


## Story items only exist for the player once the culprit is named (day 4). The holy water also needs the fuse.
func _set_story_active(active: bool) -> void:
	for item: Node in get_tree().get_nodes_in_group("story"):
		_set_item_active(item, active and (item != _vial or quest.fuse_placed))


func _set_item_active(item: Node, active: bool) -> void:
	item.visible = active
	item.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	item.collision_layer = 16 if active else 0


func _open_accusation() -> void:
	if campaign.day <= CampaignScript.LAST_SCHOOL_DAY or campaign.hunt_active or _game_over \
			or choice_ui.visible or lesson_ui.visible or _deal_kind != "" or _porta_kind != "":
		return
	var options: Array = []
	for id: String in TEACHER_ORDER:
		options.append(Lessons.TEACHER_NAMES[id])
	options.append("Not yet. Check the clues first.")
	player.controls_enabled = false
	_accusing = true
	choice_ui.ask("Who is the entity?", "Name the teacher. A wrong guess ends the investigation.", options)


func _on_choice_requested(kind: String) -> void:
	if choice_ui.visible or lesson_ui.visible or _accusing or _game_over or _porta_kind != "" or _fate_open:
		return
	player.controls_enabled = false
	_deal_kind = kind
	var options: Array = ["Make a deal", "Not now"]
	if kind == "ritual_or_deal":
		options = ["Begin the ritual", "Make a deal", "Not now"]
	choice_ui.ask("The altar", "Something waits behind the candles. It offers you a deal.", options)


## choice_ui is shared with the lesson quiz: each user of it keeps its own state flag and ignores picks otherwise.
func _on_choice(index: int) -> void:
	if _porta_kind != "":
		_on_porta_choice(index)
		return
	if _fate_open:
		_fate_open = false
		choice_ui.close()
		player.controls_enabled = true
		campaign.ritual_completed(index == 1)   # Fires the ending, which locks the controls again.
		return
	if not _accusing:
		if _deal_kind == "":
			return
		var kind := _deal_kind
		_deal_kind = ""
		choice_ui.close()
		if _game_over:
			return
		player.controls_enabled = true
		var make_deal := (kind == "ritual_or_deal" and index == 1) or (kind == "deal" and index == 0)
		if make_deal:
			campaign.make_deal()   # Fires the ending, which locks the controls again.
		elif kind == "ritual_or_deal" and index == 0:
			quest.begin_ritual(player)
		return
	_accusing = false
	choice_ui.close()
	if _game_over:
		return
	player.controls_enabled = true
	if index >= TEACHER_ORDER.size():
		return
	if campaign.accuse(TEACHER_ORDER[index]):
		_show_message("You are right. Now end it: salt, holy water and the bell, at the altar.", 7.0)


## Porta lists share choice_ui like the quiz and the altar; `_porta_kind` marks which one is open.
func _open_porta(kind: String, title: String, body: String, options: Array) -> void:
	if choice_ui.visible or lesson_ui.visible or _accusing or _game_over or _deal_kind != "" or _porta_kind != "" \
			or _code_open or menu.is_open():
		return
	player.controls_enabled = false
	_porta_kind = kind
	choice_ui.ask(title, body, options)


func _open_porter_menu(_by: Node) -> void:
	if porta.asleep:
		_show_message("Mr. Bakó is asleep at his desk, snoring softly.")
		return
	_open_porta("porta_menu", "Porta", "Mr. Bakó looks up from his newspaper.",
			["Ask for a key", "Tell him there is a leak in the WC", "Chat", "Ask for the sticker", "Return the key", "Leave"])


func _open_key_board(_by: Node) -> void:
	_open_porta("porta_board", "Key board", "Rows of hooks. One of them is labelled 14.", _key_options())


func _key_options() -> Array:
	_porta_labels = porta.lendable_keys()
	_porta_labels.append(PortaScript.FORBIDDEN)
	var options := _porta_labels.map(func(l: String) -> String: return "Red room" if l == PortaScript.RED else l)
	options.append("Leave")   # Past the labels: picks nothing, so an accidental E on the board is harmless.
	return options


## The spec's catch rule: he sees the board if he is awake, within 6 m and nothing solid (wall, door) is in between.
func _porter_sees_player() -> bool:
	if porta.asleep:
		return false
	var from: Vector3 = porter.global_position + Vector3(0.0, 1.6, 0.0)
	var to: Vector3 = player.global_position + Vector3(0.0, 1.6, 0.0)
	if from.distance_to(to) > 6.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	var skip: Array[RID] = [porter.get_rid(), player.get_rid()]
	query.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_porta_choice(index: int) -> void:
	var kind := _porta_kind
	_porta_kind = ""
	choice_ui.close()
	if _game_over:
		return
	player.controls_enabled = true
	match kind:
		"porta_menu":
			match index:
				0:
					_open_porta("porta_keys", "Ask for a key", "Which room?", _key_options())
				1:
					_show_message("Mr. Bakó: " + porta.distract())
				2:
					_show_message("Mr. Bakó: " + _porter_chat())
				3:
					_show_message("Mr. Bakó: " + porta.ask_sticker())
				4:
					_show_message("Mr. Bakó: " + porta.return_key())
		"porta_keys":
			if index < _porta_labels.size():
				_show_message("Mr. Bakó: " + porta.ask_key(_porta_labels[index]))
		"porta_board":
			if index < _porta_labels.size():
				var msg := porta.try_steal(_porta_labels[index], _porter_sees_player())
				_show_message("Mr. Bakó: " + msg if msg.begins_with("Put that back") else msg)


func _porter_chat() -> String:
	if porta.is_board_locked():
		return "I'm not talking to you. Not today."
	var lines := [
		"Thirty years at this desk. Keys come back, people don't always.",
		"Sign the book, bring the key back, and we stay friends.",
		"The pipes in that WC have leaked since before you were born.",
	]
	_porter_line = (_porter_line + 1) % lines.size()
	return lines[_porter_line]


func _on_hunt_started() -> void:
	_set_story_active(true)
	for teacher: Node in get_tree().get_nodes_in_group("teachers"):
		if teacher.npc_id == campaign.culprit:
			teacher.queue_free()   # The teacher is gone; what remains is the demon.


func _set_after_hours_lock(room: Array, locked: bool) -> void:
	var door: Node = _room_doors.get("%d:%s" % [room[0], room[1]])
	if door:
		if locked:
			door.set_open(false)
		door.locked = locked
		door.key_id = "__after__"
		door.master_key_ok = locked   # The only door the master key card opens.
		door.locked_message = "Staff only until the last bell." if locked else ""


## Three clues per school day: a classroom, room 33 (ground floor, same table every day), and a room locked until the last bell.
## The tables already exist (built before the navmesh bake); this only spawns the pickups.
func _place_clues(day: int) -> void:
	for old in get_tree().get_nodes_in_group("clue"):
		old.queue_free()
	if day > CampaignScript.LAST_SCHOOL_DAY:
		return
	for type in 3:
		var k := (day - 1) * 3 + type
		var text := Clues.text(campaign.culprit, k)
		var clue := _item("note", "clue_%d" % k, "clue", _clue_spots[k], "Clue: " + text)
		clue.add_to_group("clue")
		clue.taken.connect(func(_id: String) -> void: campaign.add_clue(text))
	_set_after_hours_lock(AFTER_HOURS_ROOMS[day - 1], true)


## One table per clue spot (9), built before the navmesh bake so it is carved out. Spots are offset from the room
## centre where the centre is taken (the safe) or the door swings.
func _build_clue_tables() -> void:
	_clue_rooms = _note_pool.duplicate()
	_clue_rooms.shuffle()
	var on_table := func(spot: Vector3) -> Vector3: return spot + Vector3(0.0, _table(spot) - spot.y + 0.03, 0.0)
	var staff_spot: Vector3 = on_table.call(_room_centre(0, Rooms.STORY_ROOMS["staff_clue"]) + Vector3(0.7 * WS, 0.0, 0.0))   # Same spot every day: one table.
	for day in CampaignScript.LAST_SCHOOL_DAY:
		var room: Array = _clue_rooms[day]
		var after: Array = AFTER_HOURS_ROOMS[day]
		_clue_spots.append(on_table.call(_room_centre(room[0], "", room[1])))
		_clue_spots.append(staff_spot)
		_clue_spots.append(on_table.call(_room_centre(after[0], after[1]) + Vector3(-1.8 * WS, 0.0, 1.0 * WS)))


func _on_lesson_started(i: int) -> void:
	_porta_kind = ""   # The quiz takes over the shared choice list.
	_lesson_index = i
	var subject: String = Lessons.subject_at(campaign.day, i)
	daynight.running = false
	player.controls_enabled = false
	entity.sleep()   # Never let it catch the player mid-quiz.
	lesson_ui.run(subject, Lessons.TEACHER_NAMES[Lessons.teacher_of(subject, campaign.day)], campaign.day == CampaignScript.TEST_DAY)


func _on_lesson_finished(correct: int, total: int) -> void:
	campaign.finish_lesson(_lesson_index, correct, total)
	player.controls_enabled = true
	_show_message("Lesson over: %d/%d correct." % [correct, total], 4.0)


func _on_bell(kind: String, index: int) -> void:
	match kind:
		"lesson_end":
			_station_teachers(index + 1)
			_run_encounter(index)
			if index in [1, 3, 5] and porter.is_at_desk() and not porta.asleep:
				porta.send_away(60.0)   # Breaks 2, 4 and 6: a WC trip, the board is unguarded.
		"last_bell":
			for teacher: Node in get_tree().get_nodes_in_group("teachers"):
				teacher.leave()
			_set_after_hours_lock(AFTER_HOURS_ROOMS[campaign.day - 1], false)
			if not (campaign.incident and campaign.day == CampaignScript.INCIDENT_DAY):   # The blast has its own text.
				_show_message("Last bell. Go home through the front door, or stay and risk it.", 6.0)
		"caretaker":
			_spawn_caretaker()


## Classrooms are locked all day. Their teacher opens each one CLASS_OPEN_EARLY minutes before the lesson and locks it
## after, once the player is out of it (never locked in). A key opens one earlier; closing it with the key locks it.
func _setup_classrooms() -> void:
	for subject: String in Lessons.SUBJECTS:
		for door: Node in _room_panels.get("%d:%s" % [Lessons.floor_of(subject), Lessons.room_of(subject)], []):
			door.lock_key = PortaScript.key_item(Lessons.room_of(subject))
			door.key_id = door.lock_key
			door.locked = true


func _reset_classrooms() -> void:
	_class_open.clear()
	for subject: String in Lessons.SUBJECTS:
		var message := "Locked. Ask Mr. Bakó at the Porta for the key."
		if campaign.day <= CampaignScript.LAST_SCHOOL_DAY:
			message = "Locked. The teacher opens it at %s. Mr. Bakó at the Porta has a key." % CampaignScript.fmt(
					CampaignScript.lesson_start(Lessons.lesson_of(subject, campaign.day)) - CLASS_OPEN_EARLY)
		_set_classroom(subject, false, message)


func _update_classrooms() -> void:
	if campaign.day > CampaignScript.LAST_SCHOOL_DAY:
		return
	var m: float = daynight.minutes
	for subject: String in Lessons.SUBJECTS:
		var lesson := Lessons.lesson_of(subject, campaign.day)
		var want := m >= CampaignScript.lesson_start(lesson) - CLASS_OPEN_EARLY and m < CampaignScript.lesson_end(lesson)
		var room := Lessons.room_of(subject)
		var is_open: bool = _class_open.get(room, false)
		if want and not is_open:
			_class_open[room] = true
			_set_classroom(subject, true)
		elif not want and is_open and not _player_in_room(subject):
			_class_open[room] = false
			_set_classroom(subject, false)


func _set_classroom(subject: String, open: bool, message := "") -> void:
	for door: Node in _room_panels.get("%d:%s" % [Lessons.floor_of(subject), Lessons.room_of(subject)], []):
		if open:
			door.locked = false
			door.set_open(true)
		else:
			door.set_open(false)
			door.locked = true
			if message != "":
				door.locked_message = message


## Porta rule: the key only goes back once the room's door is closed (and, for a classroom, locked).
func _is_room_closed(label: String) -> bool:
	var wanted := quest.red_room_label if label == PortaScript.RED else label
	for key: String in _room_panels:
		if key.substr(key.find(":") + 1) != wanted:
			continue
		for door: Node in _room_panels[key]:
			if door.is_open or (door.lock_key != "" and not door.locked):
				return false
	return true


func _run_encounter(break_index: int) -> void:
	var kind := CampaignScript.encounter_for(campaign.day, break_index)
	if kind == "" or choice_ui.visible or lesson_ui.visible or _game_over:
		return
	var at := _marker_near(12.0, 26.0)
	if at == Vector3.INF:
		at = _marker_near(6.0, 40.0)
	if at == Vector3.INF:
		return
	entity.chase_speed = campaign.chase_speed()
	entity.encounter(kind == "chase", at, 6.0 if kind == "glimpse" else 22.0)


## A patrol marker on the player's floor, between `lo` and `hi` metres away.
func _marker_near(lo: float, hi: float) -> Vector3:
	var found: Array[Vector3] = []
	for marker in _patrol_markers:
		var distance := marker.global_position.distance_to(player.global_position)
		if absf(marker.global_position.y - player.global_position.y) < 2.0 and distance > lo and distance < hi:
			found.append(marker.global_position)
	return found.pick_random() if not found.is_empty() else Vector3.INF


## Teachers walk to the room of the lesson they teach next; the others return to their routine.
func _station_teachers(lesson: int) -> void:
	for teacher: Node in get_tree().get_nodes_in_group("teachers"):
		teacher.set_station(Vector3.INF)
		if lesson >= CampaignScript.LESSONS:
			continue
		var subject: String = Lessons.subject_at(campaign.day, lesson)
		if Lessons.teacher_of(subject, campaign.day) == teacher.npc_id:
			teacher.set_station(_room_centre(Lessons.floor_of(subject), Lessons.room_of(subject)))


func _on_ritual_started() -> void:
	entity.force_hunt = true
	entity.chase_speed = 4.6
	for candle in _altar_candles:
		candle.visible = true


func _on_ritual_interrupted() -> void:
	entity.force_hunt = false
	entity.chase_speed = 4.2
	for candle in _altar_candles:
		candle.visible = false


func _on_ritual_completed() -> void:
	entity.sleep()
	daynight.force_day()
	var chime := AudioStreamPlayer.new()
	chime.stream = SoundBank.chime()
	add_child(chime)
	chime.play()
	_fate_open = true
	player.controls_enabled = false
	choice_ui.ask("The host", "The demon is gone, but %s lies on the floor of the Aula, still breathing. Cure the teacher, or destroy the body so nothing can return?" % Lessons.TEACHER_NAMES[campaign.culprit],
			["Cure the teacher", "Destroy the host"])


func _on_quest_changed() -> void:
	for item: String in _altar_meshes:
		_altar_meshes[item].visible = quest.altar_items[item]
	if is_instance_valid(_vial):
		_set_item_active(_vial, campaign.hunt_active and quest.fuse_placed)
	_update_hud()


# --- Floors ----------------------------------------------------------------

func _to_world(px: float, py: float) -> Vector2:
	return (Vector2(px, py) - _origin) * _scale


func _select_floor(index: int) -> void:
	var data: Dictionary = FloorData.FLOORS[index]
	_origin = data["origin"]
	_scale = data["scale"]
	_y = index * FLOOR_HEIGHT
	_floor_i = index


func _build_floor(data: Dictionary, index: int, stair_holes: Array[Rect2]) -> void:
	_select_floor(index)
	var rect: Rect2 = data["rect"]
	var p0 := _to_world(rect.position.x, rect.position.y)
	var p1 := _to_world(rect.end.x, rect.end.y)
	var world_rect := Rect2(p0, p1 - p0)
	var no_holes: Array[Rect2] = []
	# Upper floors have the stairwell cut out of the slab; every floor but the top has a hole in its ceiling.
	_slab(world_rect, _y, 0.5, stair_holes if index > 0 else no_holes, _floor_material, true)
	_slab(world_rect, _y + WALL_HEIGHT + 0.3, 0.3,
			stair_holes if index < FloorData.FLOORS.size() - 1 else no_holes, _ceiling_material, false)

	var rooms: Array = data["rooms"]
	for r in rooms.size():
		_build_room(rooms[r], index == _red_room[0] and r == _red_room[1])
	for solid: Array in data["solids"]:
		var a := _to_world(solid[0], solid[1])
		var b := _to_world(solid[2], solid[3])
		var centre := (a + b) * 0.5
		_box(_region, Vector3(centre.x, _y + WALL_HEIGHT * 0.5, centre.y),
				Vector3(absf(b.x - a.x), WALL_HEIGHT, absf(b.y - a.y)), _planter_material, true)
	for wall: Array in data["end_walls"]:
		_wall(_to_world(wall[0], wall[1]), _to_world(wall[2], wall[3]))
	for lamp: Vector2 in data["lights"]:
		_add_lamp(_to_world(lamp.x, lamp.y))


func _build_room(room: Array, locked := false) -> void:
	var p0 := _to_world(room[1], room[2])
	var p1 := _to_world(room[3], room[4])
	var doors := {}  # side -> [position px or -1, has panel]
	for token: String in String(room[5]).split(" ", false):
		var side := token.substr(0, 1)
		var position_px := token.substr(1).to_float() if token.length() > 1 else -1.0
		doors[side.to_upper()] = [position_px, side == side.to_upper()]

	var edges := {
		"N": [p0, Vector2(p1.x, p0.y)],
		"S": [Vector2(p0.x, p1.y), p1],
		"W": [p0, Vector2(p0.x, p1.y)],
		"E": [Vector2(p1.x, p0.y), p1],
	}
	_last_door = null
	var closed := Rooms.type_of(room[0]) == "other"
	for side: String in edges:
		var a: Vector2 = edges[side][0]
		var b: Vector2 = edges[side][1]
		if not doors.has(side):
			_wall(a, b)
			continue
		var along_x := side == "N" or side == "S"
		var centre := (a + b) * 0.5
		var position_px: float = doors[side][0]
		if position_px >= 0.0:
			var world := _to_world(position_px, position_px)
			centre = Vector2(world.x, a.y) if along_x else Vector2(a.x, world.y)
		_wall_with_door(a, b, side, centre, String(room[0]), doors[side][1], locked, closed)
		if _last_door and not _room_doors.has("%d:%s" % [_floor_i, room[0]]):
			_room_doors["%d:%s" % [_floor_i, room[0]]] = _last_door


func _wall(a: Vector2, b: Vector2, y0 := 0.0, y1 := WALL_HEIGHT) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b) + WALL_THICKNESS
	var horizontal := absf(a.y - b.y) < 0.001
	var size := Vector3(length, y1 - y0, WALL_THICKNESS) if horizontal \
			else Vector3(WALL_THICKNESS, y1 - y0, length)
	_box(_region, Vector3(mid.x, _y + (y0 + y1) * 0.5, mid.y), size, _wall_material, true)


## `closed` (demo): the door is locked for good, or a doorless opening gets a solid DemoBarrier. Either way the
## opening is carved out of the navmesh, so no agent path leads into a closed room.
func _wall_with_door(a: Vector2, b: Vector2, side: String, centre: Vector2, label: String, with_panel: bool,
		locked := false, closed := false) -> void:
	var along_x := side == "N" or side == "S"
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var mid := centre.x if along_x else centre.y
	var d0 := mid - DOOR_WIDTH * 0.5
	var d1 := mid + DOOR_WIDTH * 0.5
	var fixed := a.y if along_x else a.x
	var point := func(v: float) -> Vector2: return Vector2(v, fixed) if along_x else Vector2(fixed, v)

	_wall(point.call(lo), point.call(d0))
	_wall(point.call(d1), point.call(hi))
	_wall(point.call(d0), point.call(d1), DOOR_HEIGHT, WALL_HEIGHT)  # Lintel.
	if closed:
		var gap: Vector2 = point.call(mid)
		var size := Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.1) if along_x else Vector3(0.1, DOOR_HEIGHT, DOOR_WIDTH)
		if with_panel:
			# Invisible, on layer 7 only: nothing collides with it or ray-casts it, but the navmesh bake carves it.
			var block := StaticBody3D.new()
			block.collision_layer = 64
			block.collision_mask = 0
			block.position = Vector3(gap.x, _y + DOOR_HEIGHT * 0.5, gap.y)
			var shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = size
			shape.shape = box_shape
			block.add_child(shape)
			_region.add_child(block)
		else:
			var barrier := _box(_region, Vector3(gap.x, _y + DOOR_HEIGHT * 0.5, gap.y), size, _closed_material, true,
					InteractableScript)
			barrier.name = "DemoBarrier"
			barrier.prompt = "Closed"
			barrier.handler = func(by: Node) -> void: by.inspected.emit(Rooms.DEMO_MESSAGE)
			barrier.add_to_group("demo_barrier")
	if not with_panel:
		return

	var hinge: Vector2 = point.call(d0 + WALL_THICKNESS * 0.5)
	var door := DoorScript.new()
	door.width = DOOR_WIDTH - WALL_THICKNESS
	door.height = DOOR_HEIGHT
	door.open_sign = DOOR_SWING[side]
	door.panel_material = _closed_material if closed else (_locked_material if locked else _door_material)
	door.locked = locked or closed
	if closed:
		door.key_id = "__demo__"
		door.locked_message = Rooms.DEMO_MESSAGE
	door.position = Vector3(hinge.x, _y, hinge.y)
	door.rotation.y = 0.0 if along_x else -PI * 0.5
	add_child(door)
	_last_door = door
	var panel_key := "%d:%s" % [_floor_i, label]
	if not _room_panels.has(panel_key):
		_room_panels[panel_key] = []
	_room_panels[panel_key].append(door)
	if locked and not closed:
		door.unlocked.connect(func() -> void:
			quest.red_room_opened = true
			quest.changed.emit())

	var outward: Vector2 = OUTWARD[side]
	var sign_pos: Vector2 = Vector2(point.call(mid)) + outward * (WALL_THICKNESS * 0.5 + 0.02)
	if label != "":
		var plaque := MeshInstance3D.new()
		var plaque_box := BoxMesh.new()
		plaque_box.size = Vector3(0.65, 0.24, 0.015)
		var plaque_mat := StandardMaterial3D.new()
		plaque_mat.albedo_color = Color(0.18, 0.16, 0.14)
		plaque_mat.metallic = 0.3
		plaque_mat.roughness = 0.6
		plaque.mesh = plaque_box
		plaque.material_override = plaque_mat
		plaque.position = Vector3(sign_pos.x, _y + 2.6, sign_pos.y)
		plaque.rotation.y = atan2(outward.x, outward.y)
		add_child(plaque)

		var sign_label := Label3D.new()
		sign_label.text = label
		sign_label.pixel_size = 0.0028
		sign_label.font_size = 64
		sign_label.outline_size = 4
		sign_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
		sign_label.modulate = Color(0.85, 0.85, 0.85) if closed else (Color(1.0, 0.95, 0.85) if not locked else Color(1.0, 0.4, 0.4))
		sign_label.position = Vector3(sign_pos.x, _y + 2.6, sign_pos.y) + Vector3(outward.x, 0.0, outward.y) * 0.012
		sign_label.rotation.y = atan2(outward.x, outward.y)
		add_child(sign_label)


## Slab or ceiling covering `rect` (world XZ) minus the `holes`, split into boxes.
func _slab(rect: Rect2, y_top: float, thickness: float, holes: Array[Rect2], material: Material, collide: bool) -> void:
	var xs := [rect.position.x, rect.end.x]
	var zs := [rect.position.y, rect.end.y]
	for hole in holes:
		xs.append_array([hole.position.x, hole.end.x])
		zs.append_array([hole.position.y, hole.end.y])
	xs.sort()
	zs.sort()
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var cell := Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			if cell.size.x < 0.01 or cell.size.y < 0.01:
				continue
			var centre := cell.get_center()
			if holes.any(func(hole: Rect2) -> bool: return hole.has_point(centre)):
				continue
			var parent: Node3D = _region if collide else self
			_box(parent, Vector3(centre.x, y_top - thickness * 0.5, centre.y),
					Vector3(cell.size.x, thickness, cell.size.y), material, collide)


## Box with mesh (+ collision when `collide`). `script` swaps in a custom StaticBody3D script.
func _box(parent: Node3D, centre: Vector3, size: Vector3, material: Material, collide: bool,
		script: Script = null) -> Node3D:
	var holder: Node3D
	if script:
		holder = script.new()
	else:
		holder = StaticBody3D.new() if collide else Node3D.new()
	holder.position = centre
	parent.add_child(holder)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	holder.add_child(mesh)

	if collide:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		holder.add_child(shape)
	return holder


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


# --- Stairs ----------------------------------------------------------------

func _stair_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for x: Array in STAIR_X:
		for z: Array in STAIR_Z:
			rects.append(Rect2(x[0], z[0], x[1] - x[0], z[1] - z[0]))
	return rects


## Two stacked flights per stairwell (ground->1st, 1st->2nd). Visual steps are mesh-only;
## walking happens on an invisible ramp, so the character controller never has to climb risers.
func _build_stairs() -> void:
	for rect in _stair_rects():
		for flight in 2:
			_build_flight(rect, flight * FLOOR_HEIGHT, flight == 1)


func _build_flight(rect: Rect2, y0: float, top_flight: bool) -> void:
	var width := rect.size.x
	var length := rect.size.y
	var xc := rect.get_center().x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var rise := FLOOR_HEIGHT / STAIR_STEPS
	var depth := length / STAIR_STEPS

	for k in STAIR_STEPS:
		# The lower flight is a solid wedge; the upper one is a thin sawtooth so it leaves headroom below.
		var top := (k + 1) * rise
		var height := minf(top, 0.5) if top_flight else top
		_box(self, Vector3(xc, y0 + top - height * 0.5, z0 + (k + 0.5) * depth),
				Vector3(width, height, depth), _stair_material, false)

	var ramp := StaticBody3D.new()
	var angle := atan2(FLOOR_HEIGHT, length)
	ramp.position = Vector3(xc, y0 + FLOOR_HEIGHT * 0.5 - 0.15, rect.get_center().y)
	ramp.rotation.x = -angle
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(width, 0.3, sqrt(length * length + FLOOR_HEIGHT * FLOOR_HEIGHT))
	ramp_shape.shape = ramp_box
	ramp.add_child(ramp_shape)
	_region.add_child(ramp)

	# Side walls double as railings one metre above the next floor.
	var wall_height := FLOOR_HEIGHT + 1.0
	for x in [rect.position.x - 0.05, rect.end.x + 0.05]:
		_box(_region, Vector3(x, y0 + wall_height * 0.5, rect.get_center().y),
				Vector3(0.1, wall_height, length), _wall_material, true)
	if top_flight:
		# Nothing boards here on the top floor, so rail off the open end of the hole.
		_box(_region, Vector3(xc, y0 + FLOOR_HEIGHT + 0.5, z0 + 0.05),
				Vector3(width, 1.0, 0.1), _wall_material, true)
	else:
		# Close the space under the flight; stops short of the floor so the player can step off the ramp's end.
		_box(_region, Vector3(xc, y0 + (FLOOR_HEIGHT - 0.4) * 0.5, z1 - 0.05),
				Vector3(width, FLOOR_HEIGHT - 0.4, 0.1), _wall_material, true)


# --- Story objects ----------------------------------------------------------

## Picks the red locked room and the four rooms that hold code notes.
func _choose_story_rooms() -> void:
	var pool := []
	for i in FloorData.FLOORS.size():
		var rooms: Array = FloorData.FLOORS[i]["rooms"]
		for r in rooms.size():
			var label: String = rooms[r][0]
			var doors: String = rooms[r][5]
			var type := Rooms.type_of(label)
			if (type != "normal" and type != "computer") or RESERVED_ROOMS.has(label) or doors.contains(" ") \
					or doors != doors.to_upper():
				continue
			pool.append([i, r])
	pool.shuffle()
	var find_rooms := {}
	for f: Dictionary in FindsScript.all() + ITEM_SPOTS + FindsScript.MECHA:
		find_rooms["%d:%s" % [f["floor"], f["room"]]] = true
	# The signed form's room first (an open classroom without a find, upstairs if possible), so nothing else takes it.
	var form_ok := func(r: Array) -> bool:
		var label: String = FloorData.FLOORS[r[0]]["rooms"][r[1]][0]
		return Rooms.type_of(label) == "normal" and not find_rooms.has("%d:%s" % [r[0], label])
	var form_rooms := pool.filter(func(r: Array) -> bool: return r[0] == 1 and form_ok.call(r))
	if form_rooms.is_empty():
		form_rooms = pool.filter(form_ok)
	var form_room: Array = form_rooms[0]
	pool.erase(form_room)
	_form_room_floor = form_room[0]
	_form_room_label = FloorData.FLOORS[form_room[0]]["rooms"][form_room[1]][0]
	for k in pool.size():   # The red room is key-locked: never one that holds a find.
		if not find_rooms.has("%d:%s" % [pool[k][0], FloorData.FLOORS[pool[k][0]]["rooms"][pool[k][1]][0]]):
			var first: Array = pool[0]
			pool[0] = pool[k]
			pool[k] = first
			break
	_red_room = pool[0]
	_note_rooms = pool.slice(1, 5)
	_note_pool = pool.slice(5)
	quest.red_room_floor = _red_room[0]
	quest.red_room_label = FloorData.FLOORS[_red_room[0]]["rooms"][_red_room[1]][0]


func _room_centre(floor_index: int, label: String, room_index := -1) -> Vector3:
	var data: Dictionary = FloorData.FLOORS[floor_index]
	var rooms: Array = data["rooms"]
	for r in rooms.size():
		if (room_index >= 0 and r == room_index) or (room_index < 0 and rooms[r][0] == label):
			var origin: Vector2 = data["origin"]
			var scale: float = data["scale"]
			var a := (Vector2(rooms[r][1], rooms[r][2]) - origin) * scale
			var b := (Vector2(rooms[r][3], rooms[r][4]) - origin) * scale
			var centre := (a + b) * 0.5
			return Vector3(centre.x, floor_index * FLOOR_HEIGHT, centre.y)
	return Vector3.ZERO


func _table(centre: Vector3) -> float:
	_table_spots.append(centre)
	_box(_region, centre + Vector3(0.0, 0.375, 0.0), Vector3(0.9, 0.75, 0.9), _door_material, true)
	return centre.y + 0.75


## `story`: hidden until day 4 (group "story"). Batteries, clues and finds pass false or are excluded here.
func _item(kind: String, id: String, display_name: String, pos: Vector3, message := "", story := true) -> Node3D:
	var item := PickupScript.new()
	item.kind = kind
	item.item_id = id
	item.display_name = display_name
	item.message = message
	item.position = pos
	add_child(item)
	if story and kind != "battery" and not id.begins_with("clue_"):
		item.add_to_group("story")
	return item


func _place_story_objects() -> void:
	# The red room's key (storage_key) is borrowed or stolen at the Porta.
	_build_porta()

	# Red room: salt and fuse on a table.
	var red := _room_centre(_red_room[0], "", _red_room[1])
	var top := _table(red)
	_item("salt", "salt", "Salt", red + Vector3(-0.2, top - red.y + 0.12, 0.0))
	_item("fuse", "fuse", "Fuse", red + Vector3(0.2, top - red.y + 0.08, 0.0))

	# Chemistry lab: its door takes key 14 (only ever stolen from the Porta board). The holy water sits on a cabinet
	# by the back (west) wall, powered by the fuse box in room 24.
	var lab := _room_centre(0, "14")
	_table(lab)
	var cabinet := Vector3(FloorData.room_rect(0, "14").position.x + WALL_THICKNESS * 0.5 + 0.3, 0.0, lab.z)
	_box(_region, cabinet + Vector3(0.0, 0.5, 0.0), Vector3(0.5, 1.0, 1.2), _metal_material, true)
	_vial = _item("vial", "vial", "Holy water", cabinet + Vector3(0.0, 1.1, 0.0))
	var lab_door: Node = _room_doors.get("0:14")
	if lab_door:
		_lock_lab_door(lab_door)
		quest.lab_door = lab_door
	_build_strange_object(lab)
	var fuse_room := _room_centre(0, Rooms.STORY_ROOMS["fuse"])
	_fuse_box = _box(_region, fuse_room + Vector3(0.0, 0.75, 0.0), Vector3(0.9, 1.5, 0.35), _metal_material, true, InteractableScript)
	_fuse_box.prompt = "Check fuse box"
	_fuse_box.handler = quest.fuse_box_interact

	# The old safe in room 229 (2nd floor).
	var office := _room_centre(2, Rooms.STORY_ROOMS["safe"])
	_safe = _box(_region, office + Vector3(0.0, 0.5, 0.0), Vector3(0.8, 1.0, 0.7), _metal_material, true, InteractableScript)
	_safe.prompt = "Open safe"
	_safe.handler = quest.safe_interact

	# Four code notes on tables in random classrooms.
	for i in 4:
		var room_pos := _room_centre(_note_rooms[i][0], "", _note_rooms[i][1])
		top = _table(room_pos)
		var note := _item("note", "note_%d" % i, "note", room_pos + Vector3(0.0, top - room_pos.y + 0.03, 0.0),
				"Torn note: digit %d of the safe code is %d." % [i + 1, quest.code[i]])
		note.taken.connect(func(_id: String) -> void:
			quest.notes_found[i] = true
			quest.changed.emit())

	_build_clue_tables()
	_build_find_tables()
	_build_form_table()
	_build_altar()
	_place_batteries()


func _lock_lab_door(door: Node, sealed := false) -> void:
	door.locked = true
	door.key_id = "key_14"
	door.locked_message = "Sealed with tape after the blast. The key for 14 is not on the board." if sealed \
			else "Locked. The key for 14 is not on the board."


## The strange object the chemistry club experimented on: a cracked black egg on the lab table. Only exists from day 2.
func _build_strange_object(lab: Vector3) -> void:
	var glow := _make_material(Color(0.05, 0.03, 0.08), 0.2)
	glow.emission_enabled = true
	glow.emission = Color(0.6, 0.1, 0.9)
	glow.emission_energy_multiplier = 1.5
	_strange_object = _box(_region, lab + Vector3(0.0, 0.75 + 0.14, 0.0), Vector3(0.22, 0.28, 0.22), glow, true, InteractableScript)
	var egg := SphereMesh.new()
	egg.radius = 0.11
	egg.height = 0.28
	egg.material = glow
	(_strange_object.get_child(0) as MeshInstance3D).mesh = egg
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.2, 1.0)
	light.omni_range = 4.0
	light.light_energy = 1.2
	_strange_object.add_child(light)
	_strange_object.prompt = "Examine the object"
	_strange_object.handler = func(by: Node) -> void:
		by.inspected.emit("A black egg, cracked open. It is warm now, and it pulses like a slow heartbeat. Something left it.")
	_strange_object.visible = false
	_strange_object.process_mode = Node.PROCESS_MODE_DISABLED
	_strange_object.collision_layer = 0


func _show_strange_object(on: bool) -> void:
	_strange_object.visible = on
	_strange_object.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_strange_object.collision_layer = 16 if on else 0


## Porta (ground floor, 3.8 m square, door in the north wall): the desk in the south-east, the porter behind it, the
## key board on the west wall. The west half stays free (2 m between board and desk) from the door to the desk.
func _build_porta() -> void:
	var c := _room_centre(0, "Porta")
	_box(_region, c + Vector3(1.0, 0.45, -0.05), Vector3(1.4, 0.9, 0.7), _door_material, true)
	_desk_position = c + Vector3(1.0, 0.0, 1.05)
	_select_floor(0)
	var west := _to_world(454.0, 0.0).x + WALL_THICKNESS * 0.5 + 0.05
	var board := _box(self, Vector3(west, 1.5, c.z + 0.3), Vector3(0.08, 0.9, 1.3), _door_material, true, InteractableScript)
	board.name = "KeyBoard"
	board.prompt = "Look at the key board"
	board.handler = _open_key_board
	var brass := _make_material(Color(0.8, 0.65, 0.25), 0.35)
	for i in 12:
		var key := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.02, 0.09, 0.03)
		mesh.material = brass
		key.mesh = mesh
		key.position = Vector3(0.06, 0.25 - floori(i / 4.0) * 0.25, -0.45 + (i % 4) * 0.3)
		board.add_child(key)
	var wc := _to_world(582.0, 622.0)
	_wc_point = Vector3(wc.x, 0.0, wc.y)


## One table per find (pages, secrets, cards), per neu_mecha spot and per useful item in a corner of its room, built
## before the navmesh bake like the clue tables.
func _build_find_tables() -> void:
	for f: Dictionary in FindsScript.all() + FindsScript.MECHA:
		var spot := FindsScript.spot_position(f["floor"], f["room"], f["slot"])
		_find_spots[f["id"]] = spot + Vector3(0.0, _table(spot) - spot.y + 0.03, 0.0)
	for f: Dictionary in ITEM_SPOTS:
		var spot := FindsScript.spot_position(f["floor"], f["room"], f["slot"])
		_item_spots[f["id"]] = spot + Vector3(0.0, _table(spot) - spot.y + 0.03, 0.0)


func find_spot(id: String) -> Vector3:
	return _find_spots[id]


## A pickup on a find table that is neither a story item nor a counted find (the neu_mecha chameleon).
func spawn_find(kind: String, id: String, display_name: String, pos: Vector3, message: String) -> Node3D:
	return _item(kind, id, display_name, pos, message, false)


## The find pickups: there from day 1 (not story items), each counted once by `finds`.
func _place_finds() -> void:
	for f: Dictionary in FindsScript.all():
		var id: String = f["id"]
		var kind := FindsScript.kind_of(id)
		var text: String = "%s\n%s" % [f["title"], f["text"]] if kind == "page" else f["text"]
		var item := _item(kind, id, f["title"], _find_spots[id], text, false)
		item.add_to_group("find")
		item.taken.connect(func(_id: String) -> void: finds.mark(id))


## The useful items (group "item", not finds): counted only as the Finds page's "Items" line.
func _place_items() -> void:
	for f: Dictionary in ITEM_SPOTS:
		var info: Array = ITEM_INFO[f["kind"]]
		var item := _item(f["kind"], info[0], info[1], _item_spots[f["id"]], info[2], false)
		item.add_to_group("item")
	var item_nodes := get_tree().get_nodes_in_group("item")
	finds.items_total = item_nodes.size()
	for item: Node in item_nodes:
		item.taken.connect(func(_id: String) -> void: finds.items_found += 1)


## The signed form's table at the centre of its room (picked in `_choose_story_rooms`). Built before the navmesh bake.
func _build_form_table() -> void:
	var centre := _room_centre(_form_room_floor, _form_room_label)
	_form_spot = centre + Vector3(0.0, _table(centre) - centre.y + 0.03, 0.0)


func _place_form() -> void:
	var form := _item("form", "form", "signed form", _form_spot,
			"A blank student form. It needs a signature, but the porter just wants the paper.", false)
	form.add_to_group("form")
	form.taken.connect(func(_id: String) -> void: porta.on_form_taken())


func _place_lockers() -> void:
	var spots := [
		[0, 107.0, 280.0, PI * 0.5],
		[0, 735.0, 300.0, -PI * 0.5],
		[0, 260.0, 150.0, 0.0],
		[1, 107.0, 320.0, PI * 0.5],
		[1, 735.0, 350.0, -PI * 0.5],
		[2, 107.0, 300.0, PI * 0.5],
		[2, 735.0, 280.0, -PI * 0.5],
	]
	for sp in spots:
		_select_floor(sp[0])
		var w := _to_world(sp[1], sp[2])
		var locker := HidingSpotScript.new()
		locker.position = Vector3(w.x, _y, w.y)
		locker.rotation.y = sp[3]
		add_child(locker)


## Stone altar in the Aula with proxies for the three ritual items and candles lit during the ritual.
func _build_altar() -> void:
	_select_floor(0)
	var pos2 := _to_world(453.0, 440.0)
	var base := Vector3(pos2.x, 0.0, pos2.y)
	_altar = _box(_region, base + Vector3(0.0, 0.45, 0.0), Vector3(1.6, 0.9, 0.8), _stone_material, true, InteractableScript) as StaticBody3D
	_altar.prompt = "Altar"
	_altar.handler = quest.altar_interact
	_altar.add_to_group("altar")

	var colours := {"salt": Color(0.95, 0.95, 1.0), "vial": Color(0.3, 0.6, 1.0), "bell": Color(1.0, 0.8, 0.25)}
	var slot := -0.45
	for item: String in colours:
		var mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.07
		cylinder.bottom_radius = 0.09
		cylinder.height = 0.2
		cylinder.material = _make_material(colours[item], 0.4)
		mesh.mesh = cylinder
		mesh.position = Vector3(slot, 0.55, 0.0)
		mesh.visible = false
		_altar.add_child(mesh)
		_altar_meshes[item] = mesh
		slot += 0.45
	for x in [-0.7, 0.7]:
		var candle := OmniLight3D.new()
		candle.light_color = Color(1.0, 0.6, 0.25)
		candle.light_energy = 1.2
		candle.omni_range = 6.0
		candle.position = Vector3(x, 1.1, 0.0)
		candle.visible = false
		_altar.add_child(candle)
		_altar_candles.append(candle)


## Front door in the entrance hall: interact to go home (after the last bell on days 1-3) or leave for good.
func _build_front_door() -> void:
	var hall := _room_centre(0, "Bejárat")
	var door := _box(self, hall + Vector3(0.0, 1.1, 1.3 * WS), Vector3(1.4, 2.2, 0.2), _door_material, true, InteractableScript)
	door.name = "FrontDoor"
	_front_door = door
	door.handler = func(_by: Node) -> void: campaign.use_front_door()
	# Garden door on the entrance hall's east wall (x = 454 px), beside the front door. Closed in the demo.
	_select_floor(0)
	var east := _to_world(454.0, 0.0).x - WALL_THICKNESS * 0.5 - 0.1
	var garden := _box(self, Vector3(east, 1.1, hall.z), Vector3(0.2, 2.2, 1.4), _closed_material, true, InteractableScript)
	garden.name = "GardenDoor"
	garden.prompt = "Garden"
	garden.handler = func(by: Node) -> void: by.inspected.emit("Garden: not available in the demo.")


func _player_in_room(subject: String) -> bool:
	var floor_index: int = Lessons.floor_of(subject)
	if roundi(player.global_position.y / FLOOR_HEIGHT) != floor_index:
		return false
	var data: Dictionary = FloorData.FLOORS[floor_index]
	for room: Array in data["rooms"]:
		if room[0] == Lessons.room_of(subject):
			var a: Vector2 = (Vector2(room[1], room[2]) - data["origin"]) * data["scale"]
			var b: Vector2 = (Vector2(room[3], room[4]) - data["origin"]) * data["scale"]
			return Rect2(a, b - a).abs().has_point(Vector2(player.global_position.x, player.global_position.z))
	return false


## Spare batteries lying in the corridors.
func _place_batteries() -> void:
	for i in 7:
		var floor_index := randi() % FloorData.FLOORS.size()
		_select_floor(floor_index)
		var lamps: Array = FloorData.FLOORS[floor_index]["lights"]
		var lamp: Vector2 = lamps.pick_random()
		var pos := _to_world(lamp.x + randf_range(-20.0, 20.0), lamp.y + randf_range(-20.0, 20.0))
		_item("battery", "battery", "Battery", Vector3(pos.x, _y + 0.2, pos.y))


# --- Lights, navigation, teachers, patrol ------------------------------------

func _add_lamp(pos: Vector2) -> void:
	var light := SpotLight3D.new()
	light.position = Vector3(pos.x, _y + WALL_HEIGHT - 0.2, pos.y)
	light.rotation.x = -PI * 0.5
	light.spot_angle = 70.0
	light.spot_range = 6.5 * WS   # Lamps sit at plan positions, so they are WS times further apart.
	light.light_energy = 1.4
	light.light_color = Color(0.9, 0.95, 0.8)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 16.0
	light.distance_fade_shadow = 10.0
	light.distance_fade_length = 4.0
	add_child(light)
	daynight.register_lamp(light)


func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Radius, height and climb are multiples of the cell size; 0.4 m lets agents squeeze past the 1.2 m gap beside the stairs.
	nav_mesh.cell_size = 0.2
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.4
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.2)
	NavigationServer3D.map_set_cell_height(map, 0.2)
	_region.navigation_mesh = nav_mesh
	_region.bake_navigation_mesh(false)  # Synchronous: agents start after a physics frame.


## Baked paths float a little above the floor (depends on cell/agent size). Measure it on the real map so
## agents judge "reached the waypoint" against the floor instead of the raised path.
func _calibrate_nav_height() -> void:
	var map := get_world_3d().navigation_map
	var waited := 0
	while NavigationServer3D.map_get_iteration_id(map) == 0 and waited < 20:
		await get_tree().physics_frame
		waited += 1
	var probe := NavigationServer3D.map_get_closest_point(map, _spawn_point)
	_nav_offset = probe.y - _spawn_point.y + 0.1 if probe.y > 0.0 else 0.3
	entity.nav.path_height_offset = _nav_offset


## Waypoints for the demon: a loop through the ground floor, then 1st, then 2nd.
func _setup_patrol() -> void:
	var holder := Node3D.new()
	holder.name = "PatrolPoints"
	add_child(holder)
	var paths: Array[NodePath] = []
	for i in FloorData.FLOORS.size():
		_select_floor(i)
		for waypoint: Vector2 in FloorData.FLOORS[i]["patrol"]:
			var world := _to_world(waypoint.x, waypoint.y)
			var marker := Marker3D.new()
			marker.position = Vector3(world.x, _y, world.y)
			holder.add_child(marker)
			_patrol_markers.append(marker)
			paths.append(entity.get_path_to(marker))
	entity.patrol_points = paths


func _spawn_teachers() -> void:
	for old in get_tree().get_nodes_in_group("teachers"):
		old.remove_from_group("teachers")   # queue_free alone would keep it listed until the frame ends.
		old.queue_free()
	for entry: Array in TEACHERS:
		if campaign.hunt_active and entry[0] == campaign.culprit:
			continue   # Exposed: it only exists as the demon now.
		_select_floor(entry[2])
		var route: Array[Vector3] = []
		for waypoint: Vector2 in entry[4]:
			var world := _to_world(waypoint.x, waypoint.y)
			route.append(Vector3(world.x, _y, world.y))
		var teacher := TeacherScript.new()
		teacher.npc_id = entry[0]
		teacher.npc_name = entry[1]
		teacher.shirt_colour = entry[3]
		teacher.route = route
		teacher.exit_point = _spawn_point
		teacher.dialogue_provider = Callable(campaign, "dialogue")
		teacher.sick = campaign.sick.has(entry[0])
		teacher.path_offset = _nav_offset
		teacher.position = route[0] + Vector3(0.0, 0.1, 0.0)
		add_child(teacher)


## Csoki lives in the ground-floor hall all week; it is not in group "teachers", so nothing frees or sends it home.
func _spawn_csoki() -> void:
	_select_floor(0)
	var route: Array[Vector3] = []
	for p: Vector2 in FloorData.FLOORS[0]["csoki"]:
		var w := _to_world(p.x, p.y)
		route.append(Vector3(w.x, _y, w.y))
	csoki = CsokiScript.new()
	csoki.npc_id = "csoki"
	csoki.route = route
	csoki.exit_point = route[0]
	csoki.path_offset = _nav_offset
	csoki.entity = entity
	csoki.campaign = campaign
	csoki.daynight = daynight
	csoki.player = player
	csoki.position = route[0] + Vector3(0.0, 0.1, 0.0)
	add_child(csoki)


func _spawn_porter() -> void:
	porter = PorterScript.new()
	porter.npc_id = "porter"
	var route: Array[Vector3] = [_desk_position]
	porter.route = route
	porter.exit_point = _desk_position
	porter.desk_position = _desk_position
	porter.path_offset = _nav_offset
	porter.interact_handler = _open_porter_menu
	porter.position = _desk_position + Vector3(0.0, 0.1, 0.0)
	add_child(porter)
	porter.set_station(_desk_position)
	porta.sent_away.connect(func(seconds: float) -> void: porter.go_away(seconds, _wc_point))
	porter.returned.connect(porta.return_now)


func _spawn_caretaker() -> void:
	for old in get_tree().get_nodes_in_group("caretaker"):
		old.queue_free()
	var route: Array[Vector3] = []
	for marker in _patrol_markers:
		route.append(marker.global_position)
	route.shuffle()
	var care := CaretakerScript.new()
	care.npc_id = "caretaker"
	care.npc_name = "Caretaker"
	care.shirt_colour = Color(0.18, 0.2, 0.18)
	care.route = route
	care.exit_point = _spawn_point
	care.path_offset = _nav_offset
	care.player = player
	care.position = _far_patrol_point() + Vector3(0.0, 0.1, 0.0)
	_show_message("You hear keys jingling. The caretaker is making his rounds.", 5.0)
	care.caught_player.connect(func() -> void:
		_flash.color.a = 0.85
		campaign.expel())
	add_child(care)


# --- HUD ----------------------------------------------------------------------

func _build_hud() -> void:
	var layer := _hud_layer
	add_child(layer)
	layer.visible = false  # Shown once the game starts.

	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.7, 0.0, 0.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

	var crosshair := ColorRect.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.size = Vector2(4.0, 4.0)
	crosshair.position = Vector2(-2.0, -2.0)
	crosshair.color = Color(1.0, 1.0, 1.0, 0.5)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair)

	_hud.position = Vector2(16.0, 12.0)
	_hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_hud)

	_stamina_bg.position = Vector2(16.0, 112.0)
	_stamina_bg.size = Vector2(160.0, 6.0)
	_stamina_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.visible = false
	layer.add_child(_stamina_bg)
	_stamina_bar = ColorRect.new()
	_stamina_bar.size = Vector2(160.0, 6.0)
	_stamina_bar.color = Color(0.7, 0.85, 1.0)
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.add_child(_stamina_bar)

	_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.position.y += 28.0
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_prompt_label)

	_message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message_label.custom_minimum_size = Vector2(760.0, 0.0)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.position.y -= 70.0
	_message_label.add_theme_font_size_override("font_size", 22)
	_message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_message_label.modulate.a = 0.0
	layer.add_child(_message_label)

	_code_panel.set_anchors_preset(Control.PRESET_CENTER)
	_code_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_code_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", 34)
	_code_panel.add_child(_code_label)
	_code_panel.visible = false
	layer.add_child(_code_panel)
	_update_hud()


func _update_hud() -> void:
	var held := "empty hands"
	if player.phone.raised:
		held = "phone (two hands)" if player.phone_two_hands else "phone (one hand)"
	elif player.flashlight.visible:
		held = "flashlight"
	# Tasks, the timetable and the objective live on the phone (Q, Tab): the HUD keeps what is needed to survive.
	_hud.text = "Day %d  |  %s  |  %s  |  Battery %d%%  |  In hand: %s\n[F] light   [Q] phone (H: one or two hands)   [E] interact   [Shift] sprint%s   [Esc] pause\n%s\n[B] drop or pick up the bag   [X] switch hand   [V] stow or take out" % [
		campaign.day, FLOOR_NAMES[_floor_index], daynight.time_text(), roundi(_battery * 100.0), held,
		"   [G] name the entity" if campaign.day > campaign.LAST_SCHOOL_DAY else "", player.items.summary()]


func _show_message(text: String, seconds := -1.0) -> void:
	_message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds if seconds > 0.0 else 2.5 + text.length() * 0.045)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.8)


func _on_stamina_changed(fraction: float) -> void:
	_stamina_bar.size.x = 160.0 * fraction
	_stamina_bg.visible = true
	if _stamina_tween:
		_stamina_tween.kill()
	if fraction >= 1.0:  # Hide after 2 s at full.
		_stamina_tween = create_tween()
		_stamina_tween.tween_interval(2.0)
		_stamina_tween.tween_callback(func() -> void: _stamina_bg.visible = false)


func _on_battery_changed(fraction: float) -> void:
	_battery = fraction


# --- Safe keypad ----------------------------------------------------------------

func _open_code_lock() -> void:
	_code_open = true
	_code_buffer.clear()
	player.controls_enabled = false
	_code_panel.visible = true
	_refresh_code_label()


func _close_code_lock() -> void:
	_code_open = false
	_code_panel.visible = false
	player.controls_enabled = true


func _refresh_code_label() -> void:
	var digits: Array[String] = []
	for i in 4:
		digits.append(str(_code_buffer[i]) if i < _code_buffer.size() else "_")
	_code_label.text = "SAFE\n%s\n\nnotes found: %s\nEnter: confirm   Esc: cancel" % [" ".join(digits), quest.code_progress()]


func _handle_code_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	get_viewport().set_input_as_handled()
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		_close_code_lock()
	elif key == KEY_BACKSPACE and not _code_buffer.is_empty():
		_code_buffer.pop_back()
	elif key >= KEY_0 and key <= KEY_9 and _code_buffer.size() < 4:
		_code_buffer.append(key - KEY_0)
	elif key >= KEY_KP_0 and key <= KEY_KP_9 and _code_buffer.size() < 4:
		_code_buffer.append(key - KEY_KP_0)
	elif (key == KEY_ENTER or key == KEY_KP_ENTER) and _code_buffer.size() == 4:
		if quest.try_code(_code_buffer):
			_close_code_lock()
			_show_message("Click. The safe swings open. You take the silver bell.")
			return
		_code_buffer.clear()
		_show_message("Wrong code.", 1.5)
	_refresh_code_label()
