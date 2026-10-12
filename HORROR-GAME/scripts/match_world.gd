extends Node
## Applies the match (match.gd) to the school: who stands where, who is the entity, what the others see, and the
## match HUD. It does nothing until a round begins, so the solo campaign and plain co-op never touch it.
## The entity is one HorrorEntity node on every device. The driver (the seeker's own device, or the device that runs
## the computer-controlled entity) moves it and sends its position about 20 times a second. On the other devices the
## node is `remote_driven` and only follows that stream, so flashes, footsteps and the heartbeat work as in the campaign.

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


# --- Round events -----------------------------------------------------------

func _on_round_begun(info: Dictionary) -> void:
	if not active:
		active = true
		main.enter_match_mode()
	_far_point = _far_from_spawn()
	_reset_entity()
	player.seeker_mode = false
	player.is_downed = false
	_stun_left = 0.0
	_curtain.visible = false
	for puppet in main._puppets.values():
		puppet.set_downed(false)
	_refresh_puppets()
	var survivors: Array = info["survivors"]
	survivors.sort()
	if info["spectator"]:
		_place(main._spawn_point)
		player.controls_enabled = false
		player.set_flashlight(false)
		_say("A round is running. You join the next one.", 6.0)
		return
	if Match.is_seeker_me():
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
	var text: String = result["reason"]
	var mine := _side_wins(result["winner"])
	_say("%s\n%s" % ["You win." if mine else "You lose.", text], float(Match.RESULT_TIME))
	if not Match.is_seeker_me():
		player.controls_enabled = false


func _side_wins(winner: String) -> bool:
	if Match.is_spectator():
		return false
	return (winner == "seeker") == Match.is_seeker_me()


func _on_player_state_changed(peer: int, state: int) -> void:
	if peer != Match.my_id():
		var puppet = main._puppets.get(peer)
		if puppet:
			puppet.set_downed(state != Match.PState.ALIVE)
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
	puppet.visible = shown
	puppet.collision_layer = PUPPET_LAYER if shown else 0


func _say(text: String, seconds: float) -> void:
	_banner.text = text
	_banner_left = seconds
