extends Node
## Applies the match (match.gd) to the school: who stands where, who is the entity, what the others see, and the
## match HUD. It does nothing until a round begins, so the solo campaign and plain co-op never touch it.
## The entity is one HorrorEntity node on every device. The driver (the seeker's own device, or the device that runs
## the computer-controlled entity) moves it and sends its position about 20 times a second. On the other devices the
## node is `remote_driven` and only follows that stream, so flashes, footsteps and the heartbeat work as in the campaign.

const BodyMarker := preload("res://scripts/body_marker.gd")
const FloorData := preload("res://scripts/floor_data.gd")
const SYNC_INTERVAL := 0.05
const PUPPET_LAYER := 17
const SPREAD := 1.1   ## Metres between survivors at the start.

var main: Node
var player: Node
var entity: Node
var active := false

var _layer := CanvasLayer.new()
var _status := Label.new()
var _banner := Label.new()
var _curtain := ColorRect.new()
var _banner_left := 0.0
var _sync_timer := 0.0
var _puppet_timer := 0.0
var _stun_left := 0.0
var _far_point := Vector3.ZERO
var _bodies: Array[Node] = []
var _room_timer := 0.0
var _last_room := ""
var _takedown_ready_at := 0.0   ## Seconds on the engine clock when the entity may take someone down again.
var _vote_peers: Array[int] = []
var _meeting_open := false
var _previous_phase := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.layer = 30
	add_child(_layer)
	_curtain.color = Color(0, 0, 0, 1)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.visible = false
	_layer.add_child(_curtain)
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position.y = 12.0
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_status)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size = Vector2(760, 0)
	_banner.position = Vector2(-380, -60)
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_color", Color(0.95, 0.2, 0.15))
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 8)
	_layer.add_child(_banner)
	Match.round_begun.connect(_on_round_begun)
	Match.phase_changed.connect(_on_phase_changed)
	Match.player_state_changed.connect(_on_player_state_changed)
	Match.round_ended.connect(_on_round_ended)
	Match.hiding_changed.connect(_on_hiding_changed)
	Match.entity_synced.connect(_on_entity_synced)
	Match.stun_received.connect(_on_stun)
	Match.driver_changed.connect(_apply_driver)
	Match.start_rejected.connect(func(reason: String) -> void: _say(reason, 5.0))
	Match.body_dropped.connect(_on_body_dropped)
	Match.meeting_started.connect(_on_meeting_started)
	Match.meeting_result.connect(_on_meeting_result)
	Match.takedown_acked.connect(func(cooldown: float) -> void:
		_takedown_ready_at = Time.get_ticks_msec() / 1000.0 + cooldown)
	main.choice_ui.chosen.connect(_on_vote_choice)


# --- Round events -----------------------------------------------------------

func _on_round_begun(info: Dictionary) -> void:
	if not active:
		active = true
		main.enter_match_mode()
	_far_point = _far_from_spawn()
	_reset_entity()
	_clear_bodies()
	_meeting_open = false
	_last_room = ""
	_takedown_ready_at = Time.get_ticks_msec() / 1000.0 + Match.FIRST_TAKEDOWN_DELAY + Match.BRIEF_TIME
	player.seeker_mode = false
	player.is_downed = false
	_stun_left = 0.0
	_curtain.visible = false
	for puppet in main._puppets.values():
		puppet.set_downed(false)
	_refresh_puppets()
	var survivors: Array = info["survivors"]
	survivors.sort()
	if info["mode"] == Match.Mode.DEDUCTION:
		_label_puppets()
	if info["spectator"]:
		_place(main._spawn_point)
		player.controls_enabled = false
		player.set_flashlight(false)
		_say("A round is running. You join the next one.", 6.0)
		return
	if Match.is_seeker_me() and info["mode"] == Match.Mode.HIDE_SEEK:
		player.seeker_mode = true
		player.set_flashlight(false)
		_place(_far_point)
		player.controls_enabled = false
		return
	var index := survivors.find(Match.my_id())
	_place(main._spawn_point + Vector3((index % 3 - 1) * SPREAD, 0.0, -(index / 3) * SPREAD))
	player.battery = player.battery_max
	player.battery_changed.emit(1.0)
	player.revive()
	player.set_flashlight(true)
	player.controls_enabled = false   # Frozen until the phase message arrives, a frame later.


func _on_phase_changed(phase: int, _seconds: float) -> void:
	if Match.mode == Match.Mode.DEDUCTION:
		_deduction_phase(phase)
		_previous_phase = phase
		return
	match phase:
		Match.Phase.HIDING:
			if Match.is_seeker_me():
				_curtain.visible = true
				_say("You are the entity.\nWait while they hide. Then hunt them down.", 3600.0)
			elif Match.is_spectator():
				pass
			else:
				player.controls_enabled = true
				var who := "the computer" if Match.seeker == Match.BOT else "player %d" % Match.seeker
				_say("Hide! The entity (%s) wakes in %d seconds.\nLockers hide you. A torch flash stuns it." \
						% [who, int(Match.HIDE_TIME)], 6.0)
		Match.Phase.HUNT:
			_curtain.visible = false
			_start_hunt()
		Match.Phase.RESULT:
			_stop_hunt()
		Match.Phase.LOBBY:
			_stop_hunt()
			_say("Waiting for players. Open the pause menu to leave.", 3600.0)


func _start_hunt() -> void:
	_apply_driver()
	if Match.is_seeker_me():
		player.controls_enabled = true
		_say("Hunt them down. Look at a survivor and press E to catch.", 6.0)
	elif not Match.is_spectator():
		_say("The entity is coming.", 3.0)


## The device that drives the entity runs it; every other device follows the stream.
func _apply_driver() -> void:
	if Match.phase != Match.Phase.HUNT:
		return
	entity.remote_driven = false
	entity.target_provider = Callable()
	if Match.is_seeker_me():
		entity.sleep()
	elif Match.is_bot_host_me():
		entity.target_provider = _targets
		entity.chase_speed = 4.2
		entity.patrol_speed = 2.4
		entity.hunt_hint_interval = 15.0
		entity.wake(_far_point)
	else:
		entity.remote_driven = true
		entity.wake(_far_point)


func _stop_hunt() -> void:
	_reset_entity()
	if not Match.is_seeker_me():
		return
	player.controls_enabled = false


func _reset_entity() -> void:
	entity.remote_driven = false
	entity.target_provider = Callable()
	entity.hunt_hint_interval = 0.0
	entity.sleep()


func _on_round_ended(result: Dictionary) -> void:
	_meeting_open = false
	main.choice_ui.close()
	_clear_bodies()
	var text: String = result["reason"]
	var mine := _side_wins(result["winner"])
	_say("%s\n%s" % ["You win." if mine else "You lose.", text], float(Match.RESULT_TIME))
	if not Match.is_seeker_me():
		player.controls_enabled = false


func _side_wins(winner: String) -> bool:
	if Match.is_spectator():
		return false
	if Match.mode == Match.Mode.DEDUCTION:
		return (winner == "entity") == Match.is_entity_me()
	return (winner == "seeker") == Match.is_seeker_me()


func _on_player_state_changed(peer: int, state: int) -> void:
	if peer != Match.my_id():
		var puppet = main._puppets.get(peer)
		if puppet:
			if Match.mode == Match.Mode.DEDUCTION:
				_apply_puppet(peer, puppet)   # The body replaces the puppet.
			else:
				puppet.set_downed(state != Match.PState.ALIVE)
		return
	if Match.mode == Match.Mode.DEDUCTION:
		if state == Match.PState.OUT:
			player.is_downed = true
			player.controls_enabled = false
			player.set_flashlight(false)
			if player.is_hiding:
				player.exit_hiding()
			_say("You are out. Watch the others.", 5.0)
		return
	match state:
		Match.PState.DOWNED:
			if player.is_hiding:
				player.exit_hiding()
			player.is_downed = true
			player.controls_enabled = false
			player.set_flashlight(false)
			_say("You are down. A teammate has %d seconds to revive you." % int(Match.DOWNED_TIME), 5.0)
		Match.PState.ALIVE:
			player.is_downed = false
			player.revive()
			_say("You are back up. Run.", 3.0)
		Match.PState.OUT:
			player.is_downed = true
			player.controls_enabled = false
			_say("You are out. Watch the others.", 5.0)


func _on_hiding_changed(peer: int, on: bool) -> void:
	var puppet = main._puppets.get(peer)
	if puppet == null:
		return
	puppet.is_hiding = on
	_apply_puppet(peer, puppet)


func _on_entity_synced(pos: Vector3, yaw: float, aggressive: bool) -> void:
	if not Match.is_driver() and entity.remote_driven:
		entity.set_remote_state(pos, yaw, aggressive)


func _on_stun(seconds: float) -> void:
	if Match.phase != Match.Phase.HUNT:
		return
	if Match.is_seeker_me():
		_stun_left = seconds
		player.controls_enabled = false
		_say("Blinded by the torch.", seconds)
	else:
		entity.stun(seconds)


# --- Per frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_banner_left -= delta
	if _banner_left <= 0.0 and _banner.text != "":
		_banner.text = ""
	_update_status()
	if _stun_left > 0.0:
		_stun_left -= delta
		if _stun_left <= 0.0 and Match.phase == Match.Phase.HUNT and Match.is_seeker_me():
			player.controls_enabled = true
	if Match.mode == Match.Mode.DEDUCTION:
		_track_room(delta)
	_puppet_timer -= delta
	if _puppet_timer <= 0.0:
		_puppet_timer = 0.5
		_refresh_puppets()
	if Match.phase == Match.Phase.HUNT and Match.is_driver():
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = SYNC_INTERVAL
			_send_entity()


func _send_entity() -> void:
	if Match.is_seeker_me():
		Match.send_entity_state(player.global_position, player.rotation.y, true)
	elif entity.visible:
		var aggressive: bool = entity.state == HorrorEntity.State.CHASE or entity.state == HorrorEntity.State.ATTACK
		Match.send_entity_state(entity.global_position, entity.rotation.y, aggressive)


## Top line: the clock, the role and who is still up.
func _update_status() -> void:
	if Match.mode == Match.Mode.DEDUCTION:
		_update_deduction_status()
		return
	var role := "Spectator"
	if Match.is_seeker_me():
		role = "Entity"
	elif not Match.is_spectator():
		role = "Survivor"
	var phase_text := ""
	match Match.phase:
		Match.Phase.HIDING:
			phase_text = "Hide  %d s" % ceili(Match.time_left)
		Match.Phase.HUNT:
			phase_text = "Hunt  %d:%02d" % [int(Match.time_left) / 60, int(Match.time_left) % 60]
		Match.Phase.RESULT:
			phase_text = "Round over"
		_:
			phase_text = "Waiting"
	_status.text = "%s  |  %s  |  Survivors up: %d of %d" % [role, phase_text, _up_count(), Match.states.size()]


func _up_count() -> int:
	var n := 0
	for peer: int in Match.states:
		if Match.states[peer] != Match.PState.OUT:
			n += 1
	return n


func hud_text() -> String:
	if Match.mode == Match.Mode.DEDUCTION:
		return "Battery %d%%\n[F] light   [E] interact, hide, report a body   [G] call a meeting (once)   [Shift] sprint   [Esc] pause" \
				% roundi(player.battery / player.battery_max * 100.0)
	var held := "flashlight" if player.flashlight.visible else "empty hands"
	return "Battery %d%%  |  In hand: %s\n[F] light   [T] flash the entity   [E] interact, hide, revive   [Shift] sprint   [Esc] pause" \
			% [roundi(player.battery / player.battery_max * 100.0), held]


## The computer-controlled entity: the local player and the puppets of survivors who are up.
func _targets() -> Array:
	var list: Array = []
	if Match.state_of(Match.my_id()) == Match.PState.ALIVE:
		list.append(player)
	for peer: int in main._puppets:
		if Match.state_of(peer) == Match.PState.ALIVE and is_instance_valid(main._puppets[peer]):
			list.append(main._puppets[peer])
	return list


## Called by main when the entity caught the local player. Only the device running the computer entity can get here.
func on_local_caught() -> void:
	if Match.is_bot_host_me():
		Match.report_catch(Match.my_id())


# --- Helpers ----------------------------------------------------------------

func _place(at: Vector3) -> void:
	player.global_position = at + Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	if player.is_hiding:
		player.exit_hiding()


func _far_from_spawn() -> Vector3:
	var best: Vector3 = main._spawn_point
	var best_distance := -1.0
	for marker: Marker3D in main._patrol_markers:
		var distance := marker.global_position.distance_to(main._spawn_point)
		if distance > best_distance:
			best_distance = distance
			best = marker.global_position
	return best


func _refresh_puppets() -> void:
	for peer: int in main._puppets:
		_apply_puppet(peer, main._puppets[peer])


## The entity's own player has no puppet on screen (the entity node shows it), and a hidden survivor is in a locker.
func _apply_puppet(peer: int, puppet: Node) -> void:
	var shown: bool = peer != Match.seeker and not puppet.is_hiding
	if Match.mode == Match.Mode.DEDUCTION:
		shown = shown and Match.state_of(peer) == Match.PState.ALIVE
	puppet.visible = shown
	puppet.collision_layer = PUPPET_LAYER if shown else 0


func _say(text: String, seconds: float) -> void:
	_banner.text = text
	_banner_left = seconds


# --- Social Deduction -------------------------------------------------------

func _label_puppets() -> void:
	for peer: int in main._puppets:
		main._puppets[peer].nametag.text = Match.labels.get(peer, "")


func _deduction_phase(phase: int) -> void:
	match phase:
		Match.Phase.HIDING:
			_label_puppets()
			player.controls_enabled = not Match.is_spectator()
			if Match.is_entity_me():
				_say("You are the ENTITY.\nBlend in. Take crew down with E when nobody sees. Do not get voted out.", 8.0)
			elif not Match.is_spectator():
				_say("You are CREW (%s).\nOne of you is the entity. Find the body, read the room log, vote it out." \
						% Match.labels.get(Match.my_id(), ""), 8.0)
		Match.Phase.PLAY:
			if _previous_phase == Match.Phase.MEETING:
				_back_to_start()
			if Match.state_of(Match.my_id()) == Match.PState.ALIVE and not Match.is_spectator():
				player.controls_enabled = true
				main.player.set_flashlight(true)
		Match.Phase.MEETING:
			player.controls_enabled = false
		Match.Phase.RESULT:
			_meeting_open = false
			main.choice_ui.close()
			player.controls_enabled = false


## After a meeting everybody starts again at the entrance.
func _back_to_start() -> void:
	var peers: Array = Match.states.keys()
	peers.sort()
	var index := maxi(peers.find(Match.my_id()), 0)
	_place(main._spawn_point + Vector3((index % 3 - 1) * SPREAD, 0.0, -(index / 3) * SPREAD))


func _update_deduction_status() -> void:
	var role := "Spectator"
	if Match.is_entity_me():
		role = "Entity"
	elif Match.my_role == "crew":
		role = "Crew"
	var phase_text := "Waiting"
	match Match.phase:
		Match.Phase.HIDING:
			phase_text = "Get ready  %d s" % ceili(Match.time_left)
		Match.Phase.PLAY:
			phase_text = "Night  %d:%02d" % [int(Match.time_left) / 60, int(Match.time_left) % 60]
		Match.Phase.MEETING:
			phase_text = "Meeting  %d s" % ceili(Match.time_left)
		Match.Phase.RESULT:
			phase_text = "Round over"
	var extra := ""
	if Match.is_entity_me() and Match.phase == Match.Phase.PLAY:
		var wait := _takedown_ready_at - Time.get_ticks_msec() / 1000.0
		extra = "  |  Take down: " + ("ready" if wait <= 0.0 else "%d s" % ceili(wait))
	_status.text = "%s  |  %s  |  Alive: %d%s" % [role, phase_text, Match.alive_count(), extra]


func can_takedown() -> bool:
	return Match.is_entity_me() and Match.phase == Match.Phase.PLAY \
			and Time.get_ticks_msec() / 1000.0 >= _takedown_ready_at and player.controls_enabled


## The entity pressed E on a crew puppet.
func try_takedown(peer: int, pos: Vector3) -> void:
	if can_takedown() and Match.state_of(peer) == Match.PState.ALIVE:
		_takedown_ready_at = Time.get_ticks_msec() / 1000.0 + 2.0   # The authority answers with the real cooldown.
		Match.report_takedown(peer, pos)


func call_meeting() -> void:
	if Match.mode == Match.Mode.DEDUCTION and Match.phase == Match.Phase.PLAY \
			and Match.state_of(Match.my_id()) == Match.PState.ALIVE:
		Match.call_meeting()


func _on_body_dropped(victim: int, pos: Vector3) -> void:
	var body := BodyMarker.new()
	body.victim = victim
	main.add_child(body)
	body.global_position = Vector3(pos.x, pos.y, pos.z)
	_bodies.append(body)
	if player.global_position.distance_to(pos) < 20.0:
		main.daynight.flicker(1.6)   # The lights near a takedown stutter. This is a tell, not a proof.
	if victim == Match.my_id():
		_say("The entity got you.", 4.0)


func _clear_bodies() -> void:
	for body in _bodies:
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()


func _on_meeting_started(info: Dictionary) -> void:
	_clear_bodies()
	_meeting_open = false
	var caller: String = Match.labels.get(info["caller"], "Someone")
	var title := "%s found %s" % [caller, Match.labels.get(info["victim"], "")] if info["victim"] != 0 \
			else "%s called a meeting" % caller
	if Match.state_of(Match.my_id()) != Match.PState.ALIVE:
		_say("%s.\nYou are out. Watch the vote.\n\n%s" % [title, info["log"]], float(Match.MEETING_TIME))
		return
	_vote_peers.clear()
	var options: Array = []
	var peers: Array = Match.states.keys()
	peers.sort()
	for peer: int in peers:
		if Match.state_of(peer) == Match.PState.ALIVE:
			_vote_peers.append(peer)
			options.append("Vote: %s%s" % [Match.labels.get(peer, "?"), " (you)" if peer == Match.my_id() else ""])
	_vote_peers.append(0)
	options.append("Skip")
	_meeting_open = true
	main.choice_ui.ask(title, "Room log, last minute:\n%s\n\nMore than half of the living players must agree." % info["log"], options)


func _on_vote_choice(index: int) -> void:
	if not _meeting_open or index >= _vote_peers.size():
		return
	_meeting_open = false
	main.choice_ui.close()
	Match.cast_vote(_vote_peers[index])
	_say("Vote cast. Waiting for the others.", 10.0)


func _on_meeting_result(ejected: int, was_entity: bool, _tally: Dictionary) -> void:
	_meeting_open = false
	main.choice_ui.close()
	if ejected == 0:
		_say("No one was ejected.", float(Match.MEETING_RESULT_TIME))
	else:
		_say("%s was ejected.\n%s" % [Match.labels.get(ejected, "?"),
				"They were the entity." if was_entity else "They were crew."], float(Match.MEETING_RESULT_TIME))


## Reports the room when it changes. The log is the crew's evidence.
func _track_room(delta: float) -> void:
	_room_timer -= delta
	if _room_timer > 0.0 or Match.phase != Match.Phase.PLAY or Match.state_of(Match.my_id()) != Match.PState.ALIVE:
		return
	_room_timer = 0.5
	var floor_index := clampi(roundi(player.global_position.y / main.FLOOR_HEIGHT), 0, FloorData.FLOORS.size() - 1)
	var room := FloorData.room_label_at(floor_index, player.global_position.x, player.global_position.z)
	if room != _last_room:
		_last_room = room
		Match.report_room(room if room == "Corridor" else "Room " + room)
