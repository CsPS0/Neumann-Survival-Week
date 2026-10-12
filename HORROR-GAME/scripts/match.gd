extends Node
## Round logic for the multiplayer modes, an autoload that exists on every peer. Peer 1 is the authority: the hosting
## player, or the dedicated server, which runs this script without a world. It owns the roles, the phase, the timers and
## the win check. Other peers send reports (a catch, a revive) and mirror what the authority broadcasts.
## Nothing here touches the school: match_world.gd listens to the signals and moves the world.

signal round_begun(info: Dictionary)
signal phase_changed(phase: int, seconds: float)
signal player_state_changed(peer: int, state: int)
signal round_ended(result: Dictionary)
signal hiding_changed(peer: int, on: bool)
signal entity_synced(pos: Vector3, yaw: float, aggressive: bool)
signal stun_received(seconds: float)
signal start_rejected(reason: String)
signal driver_changed   ## The device that runs the computer-controlled entity changed.
signal body_dropped(victim: int, pos: Vector3)
signal meeting_started(info: Dictionary)
signal vote_progress(count: int, total: int)
signal meeting_result(ejected: int, was_entity: bool, tally: Dictionary)
signal takedown_acked(cooldown: float)

enum Mode { NONE, HIDE_SEEK, DEDUCTION }
enum Phase { LOBBY, HIDING, HUNT, RESULT, PLAY, MEETING }
enum PState { ALIVE, DOWNED, OUT }

const BOT := 0              ## Seeker id of the computer-controlled entity.
const SEEK_RANDOM := -1     ## Start option: a random player is the entity.
const HIDE_TIME := 25.0     ## Survivors scatter while the entity waits.
const HUNT_TIME := 240.0    ## Survivors win when this runs out with someone still up.
const DOWNED_TIME := 25.0   ## A downed survivor is out after this unless a teammate revives them.
const RESULT_TIME := 12.0   ## Then the next round starts by itself, with the same options.
const BRIEF_TIME := 8.0         ## Social Deduction: roles are shown, nobody acts yet.
const PLAY_TIME := 360.0        ## Social Deduction: the crew wins when this runs out with the entity not ejected.
const MEETING_TIME := 45.0
const MEETING_RESULT_TIME := 6.0
const TAKEDOWN_COOLDOWN := 30.0
const FIRST_TAKEDOWN_DELAY := 20.0
const MEETING_LOCKOUT := 15.0   ## No meeting can be called in the first seconds of play.
const MIN_DEDUCTION_PLAYERS := 3
const LOG_AGE := 60.0           ## The room log shows the last minute.

var mode := Mode.NONE
var phase := Phase.LOBBY
var seeker := BOT
var bot_host := 1
var states := {}            ## Survivor peer id -> PState.
var time_left := 0.0
var round_number := 0
var last_result := {}
var my_role := ""           ## Social Deduction: "entity" or "crew". Only this device (and the authority) knows it.
var labels := {}            ## Peer id -> "Student 1", "Teacher 2", ...
var meeting := {}

var _downed_left := {}      ## Authority only: peer id -> seconds until the survivor is out.
var _last_mode := Mode.NONE
var _last_choice := BOT
var _spectator := false
var _entity_id := 0         ## Authority only. Clients learn it when the round is over.
var _cooldown_end := 0.0
var _play_left := 0.0
var _clock := 0.0
var _bodies := {}           ## Authority only: victim peer id -> true while its body lies there.
var _votes := {}
var _vote_closed := false
var _meeting_calls := {}
var _room_log: Array = []   ## Authority only: {t, peer, room}.


func _ready() -> void:
	NetSession.player_joined.connect(_on_player_joined)
	NetSession.player_left.connect(_on_player_left)
	NetSession.session_ended.connect(reset)


func my_id() -> int:
	return multiplayer.get_unique_id() if NetSession.is_multiplayer_active() else 0


func is_authority() -> bool:
	return NetSession.is_multiplayer_active() and multiplayer.is_server()


## True from the start of a round until the next lobby.
func is_active() -> bool:
	return mode != Mode.NONE and phase != Phase.LOBBY


func is_seeker_me() -> bool:
	return seeker != BOT and seeker == my_id()


## True on the one device that runs the computer-controlled entity.
func is_bot_host_me() -> bool:
	return seeker == BOT and bot_host == my_id()


## True on the device that moves the entity and sends its position to the others.
func is_driver() -> bool:
	return is_seeker_me() or is_bot_host_me()


func is_entity_me() -> bool:
	return my_role == "entity"


func is_spectator() -> bool:
	return _spectator


func state_of(peer: int) -> int:
	return states.get(peer, PState.OUT)


func alive_count() -> int:
	var n := 0
	for peer: int in states:
		if states[peer] == PState.ALIVE:
			n += 1
	return n


func reset() -> void:
	mode = Mode.NONE
	phase = Phase.LOBBY
	states.clear()
	_downed_left.clear()
	time_left = 0.0
	_spectator = false
	my_role = ""
	labels.clear()


# --- Starting a round -------------------------------------------------------

## Any player can ask. `seeker_choice` is BOT or SEEK_RANDOM.
func request_start(mode_id: int, seeker_choice: int) -> void:
	if NetSession.is_multiplayer_active():
		_request_start.rpc_id(1, mode_id, seeker_choice)


@rpc("any_peer", "call_local", "reliable")
func _request_start(mode_id: int, seeker_choice: int) -> void:
	if not is_authority():
		return
	if phase != Phase.LOBBY and phase != Phase.RESULT:
		return
	var err := _begin(mode_id, seeker_choice)
	if err != "":
		var sender := multiplayer.get_remote_sender_id()
		_reject.rpc_id(sender if sender != 0 else 1, err)


@rpc("authority", "call_local", "reliable")
func _reject(reason: String) -> void:
	start_rejected.emit(reason)


## Authority: picks the roles and starts the hiding phase. Returns an error text, or "" on success.
func _begin(mode_id: int, seeker_choice: int) -> String:
	if mode_id == Mode.DEDUCTION:
		return _begin_deduction()
	if mode_id != Mode.HIDE_SEEK:
		return "Unknown mode."
	var players := _player_ids()
	if players.is_empty():
		return "No players."
	var chosen := BOT
	if seeker_choice != BOT:
		if players.size() < 2:
			return "A player as the entity needs at least 2 players. Pick the computer."
		chosen = players.pick_random()
	var survivors := players.duplicate()
	survivors.erase(chosen)
	var host := 1
	if NetSession.server_is_dedicated:
		host = players.min()
	_last_mode = mode_id as Mode
	_last_choice = seeker_choice
	_round_begin.rpc(mode_id, chosen, host, survivors, round_number + 1)
	_set_phase(Phase.HIDING, HIDE_TIME)
	return ""


## Social Deduction: one random player is the entity. Each player is told only their own role, so the id of the
## entity stays on the authority until the round is over.
func _begin_deduction() -> String:
	var players := _player_ids()
	if players.size() < MIN_DEDUCTION_PLAYERS:
		return "Social Deduction needs at least %d players." % MIN_DEDUCTION_PLAYERS
	players.sort()
	var names := {}
	for i in players.size():
		names[players[i]] = "%s %d" % ["Student" if i % 2 == 0 else "Teacher", i + 1]
	_entity_id = players.pick_random()
	_last_mode = Mode.DEDUCTION
	_last_choice = BOT
	_clock = 0.0
	_bodies.clear()
	_meeting_calls.clear()
	_room_log.clear()
	_cooldown_end = FIRST_TAKEDOWN_DELAY + BRIEF_TIME
	_labels_sync.rpc(names)
	for peer: int in players:
		_role_private.rpc_id(peer, "entity" if peer == _entity_id else "crew")
	_round_begin.rpc(Mode.DEDUCTION, -1, 1, players, round_number + 1)
	_set_phase(Phase.HIDING, BRIEF_TIME)
	return ""


@rpc("authority", "call_local", "reliable")
func _labels_sync(names: Dictionary) -> void:
	labels = names


@rpc("authority", "call_local", "reliable")
func _role_private(role: String) -> void:
	my_role = role


@rpc("authority", "call_local", "reliable")
func _round_begin(mode_id: int, chosen: int, host: int, survivors: Array, number: int) -> void:
	mode = mode_id as Mode
	seeker = chosen
	bot_host = host
	round_number = number
	states.clear()
	_downed_left.clear()
	for peer: int in survivors:
		states[peer] = PState.ALIVE
		_downed_left[peer] = 0.0
	_spectator = my_id() != seeker and not states.has(my_id())
	if mode_id == Mode.HIDE_SEEK:
		my_role = ""
		labels = {}
	last_result = {}
	round_begun.emit({"mode": mode, "seeker": seeker, "bot_host": bot_host, "survivors": survivors,
			"round": number, "spectator": _spectator})


func _set_phase(new_phase: Phase, seconds: float) -> void:
	_phase_sync.rpc(new_phase, seconds)


@rpc("authority", "call_local", "reliable")
func _phase_sync(new_phase: int, seconds: float) -> void:
	phase = new_phase as Phase
	time_left = seconds
	phase_changed.emit(phase, seconds)


## Peer ids of everyone who plays: the clients, and the host when it is not a dedicated server.
func _player_ids() -> Array:
	var ids: Array = []
	if not NetSession.server_is_dedicated:
		ids.append(1)
	for id in NetSession.get_remote_players():
		ids.append(id)
	return ids


# --- Reports from players ---------------------------------------------------

## The entity (a player, or the device running the computer) reached a survivor.
func report_catch(target: int) -> void:
	if NetSession.is_multiplayer_active():
		_report_catch.rpc_id(1, target)


@rpc("any_peer", "call_local", "reliable")
func _report_catch(target: int) -> void:
	if not is_authority() or phase != Phase.HUNT or state_of(target) != PState.ALIVE:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var allowed := (seeker == sender) if seeker != BOT else (bot_host == sender)
	if not allowed:
		return
	_downed_left[target] = DOWNED_TIME
	_state_sync.rpc(target, PState.DOWNED)
	_check_end()


## A free survivor helped a downed one up.
func report_revive(target: int) -> void:
	if NetSession.is_multiplayer_active():
		_report_revive.rpc_id(1, target)


@rpc("any_peer", "call_local", "reliable")
func _report_revive(target: int) -> void:
	if not is_authority() or phase != Phase.HUNT or state_of(target) != PState.DOWNED:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if sender == target or state_of(sender) != PState.ALIVE:
		return
	_state_sync.rpc(target, PState.ALIVE)


@rpc("authority", "call_local", "reliable")
func _state_sync(peer: int, state: int) -> void:
	states[peer] = state
	player_state_changed.emit(peer, state)


## A survivor entered or left a hiding spot. Everyone hides or shows that survivor's puppet.
func send_hiding(on: bool) -> void:
	if NetSession.is_multiplayer_active():
		_hiding_sync.rpc(on)


@rpc("any_peer", "call_local", "reliable")
func _hiding_sync(on: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	hiding_changed.emit(sender if sender != 0 else my_id(), on)


## Called about 20 times a second by the driver of the entity.
func send_entity_state(pos: Vector3, yaw: float, aggressive: bool) -> void:
	if NetSession.is_multiplayer_active():
		_entity_sync.rpc(pos, yaw, aggressive)


@rpc("any_peer", "call_remote", "unreliable")
func _entity_sync(pos: Vector3, yaw: float, aggressive: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_active() and (sender == seeker or (seeker == BOT and sender == bot_host)):
		entity_synced.emit(pos, yaw, aggressive)


## A survivor's torch flash hit the entity. The driver freezes it.
func send_stun(seconds: float) -> void:
	if NetSession.is_multiplayer_active():
		_stun_sync.rpc(seconds)


@rpc("any_peer", "call_local", "reliable")
func _stun_sync(seconds: float) -> void:
	if is_active() and is_driver():
		stun_received.emit(clampf(seconds, 0.0, 5.0))


# --- Authority: timers, win check, players leaving --------------------------

func _process(delta: float) -> void:
	if phase == Phase.LOBBY or mode == Mode.NONE:
		return
	time_left = maxf(time_left - delta, 0.0)
	if not is_authority():
		return
	_clock += delta
	if phase == Phase.HUNT:
		for peer: int in _downed_left.keys():
			if states.get(peer) == PState.DOWNED:
				_downed_left[peer] -= delta
				if _downed_left[peer] <= 0.0:
					_state_sync.rpc(peer, PState.OUT)
					_check_end()
					if phase != Phase.HUNT:
						return
	if time_left > 0.0:
		return
	match phase:
		Phase.HIDING:
			if mode == Mode.DEDUCTION:
				_set_phase(Phase.PLAY, PLAY_TIME)
			else:
				_set_phase(Phase.HUNT, HUNT_TIME)
		Phase.PLAY:
			_end_round("crew", "Dawn comes and the entity was not found out. The crew survives the night.")
		Phase.MEETING:
			if not _vote_closed:
				_tally()
			elif phase == Phase.MEETING:
				_set_phase(Phase.PLAY, _play_left)
		Phase.HUNT:
			_end_round("survivors", "Time is up. The survivors lasted the whole night.")
		Phase.RESULT:
			if _begin(_last_mode, _last_choice) != "":
				_set_phase(Phase.LOBBY, 0.0)


func _check_end() -> void:
	if phase != Phase.HUNT:
		return
	if alive_count() == 0:
		_end_round("seeker", "Nobody is left standing. The entity wins.")


func _end_round(winner: String, reason: String) -> void:
	var entity_peer := seeker if mode == Mode.HIDE_SEEK else _entity_id
	if mode == Mode.DEDUCTION:
		reason += " The entity was %s." % labels.get(_entity_id, "unknown")
	_round_over.rpc(winner, reason, entity_peer)
	_set_phase(Phase.RESULT, RESULT_TIME)


@rpc("authority", "call_local", "reliable")
func _round_over(winner: String, reason: String, entity_peer: int) -> void:
	var up := 0
	for peer: int in states:
		if states[peer] != PState.OUT:
			up += 1
	last_result = {"winner": winner, "reason": reason, "survivors_up": up, "seeker": seeker, "entity": entity_peer}
	round_ended.emit(last_result)


func _on_player_joined(id: int) -> void:
	if not is_authority() or mode == Mode.NONE or phase == Phase.LOBBY:
		return
	_labels_sync.rpc_id(id, labels)
	_snapshot.rpc_id(id, mode, seeker, bot_host, states, phase, time_left)


## A player who joins during a round sees the current round and waits for the next one.
@rpc("authority", "call_remote", "reliable")
func _snapshot(mode_id: int, chosen: int, host: int, current: Dictionary, current_phase: int, seconds: float) -> void:
	mode = mode_id as Mode
	seeker = chosen
	bot_host = host
	states = current.duplicate()
	_spectator = true
	round_begun.emit({"mode": mode, "seeker": seeker, "bot_host": bot_host, "survivors": states.keys(),
			"round": round_number, "spectator": true})
	phase = current_phase as Phase
	time_left = seconds
	phase_changed.emit(phase, seconds)


func _on_player_left(id: int) -> void:
	if not is_authority() or mode == Mode.NONE or phase == Phase.LOBBY:
		return
	_downed_left.erase(id)
	if states.has(id) and states[id] != PState.OUT:
		_state_sync.rpc(id, PState.OUT)
	if phase == Phase.RESULT:
		return
	if mode == Mode.DEDUCTION:
		if id == _entity_id:
			_end_round("crew", "The entity left the game.")
		else:
			_votes.erase(id)
			_check_deduction_end()
			if phase == Phase.MEETING and not _vote_closed and _votes.size() >= alive_count():
				_tally()
		return
	if id == seeker:
		_end_round("survivors", "The entity left the game.")
		return
	if seeker == BOT and id == bot_host:
		var others := _player_ids()
		others.erase(id)
		if others.is_empty():
			_end_round("survivors", "Nobody is left to run the entity.")
			return
		_bot_host_sync.rpc(others.min())
	_check_end()


@rpc("authority", "call_local", "reliable")
func _bot_host_sync(host: int) -> void:
	bot_host = host
	driver_changed.emit()


# --- Social Deduction -------------------------------------------------------

## The entity took a crew member down. `pos` is where the body lies (the entity device reads the puppet).
func report_takedown(target: int, pos: Vector3) -> void:
	if NetSession.is_multiplayer_active():
		_report_takedown.rpc_id(1, target, pos)


@rpc("any_peer", "call_local", "reliable")
func _report_takedown(target: int, pos: Vector3) -> void:
	if not is_authority() or mode != Mode.DEDUCTION or phase != Phase.PLAY:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if sender != _entity_id or target == _entity_id or state_of(target) != PState.ALIVE or _clock < _cooldown_end:
		return
	_cooldown_end = _clock + TAKEDOWN_COOLDOWN
	_bodies[target] = true
	_state_sync.rpc(target, PState.OUT)
	_body_sync.rpc(target, pos)
	_takedown_ack.rpc_id(sender, TAKEDOWN_COOLDOWN)
	_check_deduction_end()


@rpc("authority", "call_local", "reliable")
func _body_sync(victim: int, pos: Vector3) -> void:
	body_dropped.emit(victim, pos)


@rpc("authority", "call_local", "reliable")
func _takedown_ack(cooldown: float) -> void:
	takedown_acked.emit(cooldown)


## A living player found a body.
func report_body(victim: int) -> void:
	if NetSession.is_multiplayer_active():
		_report_body.rpc_id(1, victim)


@rpc("any_peer", "call_local", "reliable")
func _report_body(victim: int) -> void:
	if not is_authority() or mode != Mode.DEDUCTION or phase != Phase.PLAY or not _bodies.has(victim):
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if state_of(sender) == PState.ALIVE:
		_start_meeting(sender, victim)


## Every living player can call one meeting per round, not in the first seconds.
func call_meeting() -> void:
	if NetSession.is_multiplayer_active():
		_call_meeting.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _call_meeting() -> void:
	if not is_authority() or mode != Mode.DEDUCTION or phase != Phase.PLAY:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if state_of(sender) != PState.ALIVE or _meeting_calls.has(sender) or PLAY_TIME - time_left < MEETING_LOCKOUT:
		return
	_meeting_calls[sender] = true
	_start_meeting(sender, 0)


func _start_meeting(caller: int, victim: int) -> void:
	_play_left = time_left
	_votes.clear()
	_vote_closed = false
	_bodies.clear()
	_meeting_sync.rpc(caller, victim, _room_log_text(victim))
	_set_phase(Phase.MEETING, MEETING_TIME)


@rpc("authority", "call_local", "reliable")
func _meeting_sync(caller: int, victim: int, log_text: String) -> void:
	meeting = {"caller": caller, "victim": victim, "log": log_text}
	meeting_started.emit(meeting)


## The room log: where each player was in the last minute, newest first. It is true for the entity too, which is what
## makes it evidence.
func _room_log_text(victim: int) -> String:
	var lines: Array[String] = []
	var peers: Array = states.keys()
	peers.sort()
	for peer: int in peers:
		if peer == victim or states[peer] == PState.ALIVE:
			var seen: Array[String] = []
			for i in range(_room_log.size() - 1, -1, -1):
				var entry: Dictionary = _room_log[i]
				if entry["peer"] == peer and _clock - entry["t"] <= LOG_AGE:
					seen.append("%s (%d s ago)" % [entry["room"], int(_clock - entry["t"])])
					if seen.size() >= 3:
						break
			lines.append("%s%s: %s" % [labels.get(peer, "?"), " (the body)" if peer == victim else "", ", ".join(seen) if not seen.is_empty() else "no record"])
	return "\n".join(lines)


## Each device reports the room its player is in when it changes.
func report_room(room: String) -> void:
	if NetSession.is_multiplayer_active():
		_report_room.rpc_id(1, room)


@rpc("any_peer", "call_local", "reliable")
func _report_room(room: String) -> void:
	if not is_authority() or mode != Mode.DEDUCTION or phase != Phase.PLAY:
		return
	var sender := multiplayer.get_remote_sender_id()
	_room_log.append({"t": _clock, "peer": sender if sender != 0 else 1, "room": room})
	while _room_log.size() > 600:
		_room_log.pop_front()


## Vote for a living player, or 0 to skip.
func cast_vote(target: int) -> void:
	if NetSession.is_multiplayer_active():
		_cast_vote.rpc_id(1, target)


@rpc("any_peer", "call_local", "reliable")
func _cast_vote(target: int) -> void:
	if not is_authority() or phase != Phase.MEETING or _vote_closed:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if state_of(sender) != PState.ALIVE or _votes.has(sender) or (target != 0 and state_of(target) != PState.ALIVE):
		return
	_votes[sender] = target
	_vote_progress.rpc(_votes.size(), alive_count())
	if _votes.size() >= alive_count():
		_tally()


@rpc("authority", "call_local", "reliable")
func _vote_progress(count: int, total: int) -> void:
	vote_progress.emit(count, total)


## The player with more than half of the living players' votes is ejected.
func _tally() -> void:
	_vote_closed = true
	var counts := {}
	for voter: int in _votes:
		var target: int = _votes[voter]
		counts[target] = counts.get(target, 0) + 1
	var ejected := 0
	for target: int in counts:
		if target != 0 and counts[target] * 2 > alive_count():
			ejected = target
	var was_entity := ejected != 0 and ejected == _entity_id
	if ejected != 0:
		_state_sync.rpc(ejected, PState.OUT)
	_meeting_result.rpc(ejected, was_entity, counts)
	_set_phase(Phase.MEETING, MEETING_RESULT_TIME)
	_check_deduction_end()


@rpc("authority", "call_local", "reliable")
func _meeting_result(ejected: int, was_entity: bool, tally: Dictionary) -> void:
	meeting_result.emit(ejected, was_entity, tally)


## Crew wins when the entity is out. The entity wins when the living crew is no larger than it.
func _check_deduction_end() -> void:
	if mode != Mode.DEDUCTION or phase == Phase.RESULT or phase == Phase.LOBBY:
		return
	if state_of(_entity_id) != PState.ALIVE:
		_end_round("crew", "The entity is out.")
		return
	if alive_count() - 1 <= 1:
		_end_round("entity", "Only one crew member is left standing.")
