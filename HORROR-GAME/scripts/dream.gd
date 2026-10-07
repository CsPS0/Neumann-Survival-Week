extends Node
## Hunt days: once a day the player falls asleep at a desk and the demon follows into the dream. Run to the front
## door to wake up. Being caught or running out of time also wakes the player, but late. Nothing in a dream kills.

const Clues := preload("res://scripts/clues.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")

const DREAM_AT := {4: 780.0, 5: 690.0}   ## Clock minutes (13:00 and 11:30).
const LIMIT := 60.0                      ## Seconds to reach the door.
const EXIT_RADIUS := 3.0
const MIN_START_DISTANCE := 15.0         ## The dream waits until the player is this far from the door.
const PENALTY := 40.0                    ## Game minutes lost when the dream is lost.
const TINT := Color(0.55, 0.0, 0.1, 0.22)

signal started
signal woke(escaped: bool)

var main: Node          ## Provides the player, the entity, the clock, the campaign and the message line.
var active := false
var escaped_count := 0
var failed_count := 0

var _left := 0.0
var _done_day := 0
var _layer := CanvasLayer.new()
var _tint := ColorRect.new()


func _ready() -> void:
	_layer.layer = 60
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(TINT, 0.0)
	_layer.add_child(_tint)
	add_child(_layer)


func _process(delta: float) -> void:
	if main == null:
		return
	if active:
		_left -= delta
		if _near_exit():
			wake(true)
		elif _left <= 0.0:
			wake(false)
		return
	var campaign: Node = main.campaign
	if not campaign.hunt_active or campaign.ending_id != 0 or main._game_over or _done_day == campaign.day:
		return
	if main.daynight.minutes < float(DREAM_AT.get(campaign.day, INF)) or main.daynight.is_night:
		return
	if main.choice_ui.visible or main.lesson_ui.visible or main.menu.is_open() or main.quest.ritual_active \
			or not main.daynight.running or _exit_distance() < MIN_START_DISTANCE:
		return
	start()


func start() -> void:
	var campaign: Node = main.campaign
	active = true
	_done_day = campaign.day
	_left = LIMIT
	_tint.color = TINT
	var beat := AudioStreamPlayer.new()
	beat.stream = SoundBank.heartbeat()
	beat.finished.connect(beat.queue_free)
	main.add_child(beat)
	beat.play()
	main.daynight.flicker(1.5)
	main._show_message("You fall asleep at your desk. The classroom is wrong. Run to the front door to wake up!", 7.0)
	var at: Vector3 = main._marker_near(12.0, 26.0)
	if at == Vector3.INF:
		at = main._marker_near(6.0, 40.0)
	if at != Vector3.INF:
		main.entity.chase_speed = campaign.chase_speed()
		main.entity.encounter(true, at, LIMIT)
	started.emit()


## The demon caught the player in the dream.
func caught() -> void:
	if active:
		wake(false)


func wake(escaped: bool) -> void:
	if not active:
		return
	active = false
	_tint.color = Color(TINT, 0.0)
	main.entity.sleep()
	if escaped:
		escaped_count += 1
		var clue: String = "Dream: " + Clues.text(main.campaign.culprit, 9)
		main.campaign.add_clue(clue)
		main._show_message("You wake up. The dream left a clue: " + clue, 6.0)
	else:
		failed_count += 1
		main.daynight.minutes += PENALTY
		main._show_message("You wake up late and shaken. %d minutes are gone." % int(PENALTY), 5.0)
	woke.emit(escaped)


func _near_exit() -> bool:
	var player: Node3D = main.player
	return absf(player.global_position.y - main._spawn_point.y) < 2.0 and _exit_distance() < EXIT_RADIUS


## Distance on the floor plane to the front door, 1000 m when on another floor.
func _exit_distance() -> float:
	var player: Node3D = main.player
	var exit: Vector3 = main._spawn_point
	if absf(player.global_position.y - exit.y) >= 2.0:
		return 1000.0
	return Vector2(player.global_position.x - exit.x, player.global_position.z - exit.z).length()
