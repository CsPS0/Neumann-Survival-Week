extends Node
## Day 3: the demon starts to prank the player. Lame on purpose: flickering lights, a knock, a slammed door, a whisper
## and a short blackout flash. Nothing here can hurt the player. Quiet during quizzes, menus and endings.

const SoundBank := preload("res://scripts/sound_bank.gd")

const HAUNT_DAY := 3
const FIRST_DELAY := 20.0
const MIN_GAP := 35.0
const MAX_GAP := 70.0
const PRANKS := ["lights", "knock", "door", "whisper", "flash"]
const WHISPERS := ["...behind you.", "...you looked in the lab.", "...we see you, student.", "...it is cold in here.",
		"...do not sit near the window."]

signal prank(kind: String)

var main: Node        ## Provides the player, the campaign, the clock, the scare flash and the overlays.
var count := 0

var _left := FIRST_DELAY
var _day := 0


func _process(delta: float) -> void:
	if main == null or main.campaign.day != HAUNT_DAY or main.campaign.ending_id != 0 or main._game_over:
		return
	if _day != HAUNT_DAY:
		_day = HAUNT_DAY
		_left = FIRST_DELAY
	if main.choice_ui.visible or main.lesson_ui.visible or main.menu.is_open() or not main.daynight.running:
		return
	_left -= delta
	if _left <= 0.0:
		_left = randf_range(MIN_GAP, MAX_GAP)
		do_prank(PRANKS.pick_random())


func do_prank(kind: String) -> void:
	var player: Node3D = main.player
	count += 1
	match kind:
		"lights":
			main.daynight.flicker(2.5)
		"knock":
			var at := AudioStreamPlayer3D.new()
			at.stream = SoundBank.knock()
			at.volume_db = 6.0
			at.finished.connect(at.queue_free)
			main.add_child(at)
			at.global_position = player.global_position + player.global_transform.basis.z * 4.0 + Vector3.UP
			at.play()
		"door":
			var nearest: Node = null
			var best := 144.0
			for door: Node3D in main.get_tree().get_nodes_in_group(&"doors"):
				var d := door.global_position.distance_squared_to(player.global_position)
				if door.is_open and d < best:
					best = d
					nearest = door
			if nearest == null:
				kind = "whisper"
				_whisper()
			else:
				nearest.set_open(false)
		"whisper":
			_whisper()
		"flash":
			main.scare.trigger()
	prank.emit(kind)


func _whisper() -> void:
	var voice := AudioStreamPlayer.new()
	voice.stream = SoundBank.breath()
	voice.volume_db = -4.0
	voice.finished.connect(voice.queue_free)
	main.add_child(voice)
	voice.play()
	main.player.inspected.emit(WHISPERS.pick_random())
