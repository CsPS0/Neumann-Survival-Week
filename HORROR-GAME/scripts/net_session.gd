extends Node

signal session_started(is_host: bool)
signal session_ended
signal player_joined(peer_id: int)
signal player_left(peer_id: int)

const DEFAULT_PORT = 7777
const MAX_CLIENTS = 4

var _peer: ENetMultiplayerPeer
var _udp_peer: PacketPeerUDP
var _broadcasting := false
var _room_code := ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
func is_multiplayer_active() -> bool:
	return _peer != null

func host_session() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err = _peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if err != OK:
		printerr("Failed to host session")
		return
	multiplayer.multiplayer_peer = _peer
	_generate_room_code()
	_start_lan_broadcast()
	session_started.emit(true)

func join_session(ip: String, port: int = DEFAULT_PORT) -> void:
	_peer = ENetMultiplayerPeer.new()
	var err = _peer.create_client(ip, port)
	if err != OK:
		printerr("Failed to join session")
		return
	multiplayer.multiplayer_peer = _peer
	session_started.emit(false)

func leave_session() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_stop_lan_broadcast()
	session_ended.emit()

func _generate_room_code() -> void:
	const CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	_room_code = ""
	for i in 6:
		_room_code += CHARS[randi() % CHARS.length()]

func get_room_code() -> String:
	return _room_code

func _start_lan_broadcast() -> void:
	_udp_peer = PacketPeerUDP.new()
	_udp_peer.set_broadcast_enabled(true)
	_udp_peer.set_dest_address("255.255.255.255", DEFAULT_PORT + 1)
	_broadcasting = true

func _stop_lan_broadcast() -> void:
	_broadcasting = false
	if _udp_peer:
		_udp_peer.close()
		_udp_peer = null

func _process(_delta: float) -> void:
	if _broadcasting and _udp_peer:
		var msg = "NEUMANN_ROOM:" + _room_code
		_udp_peer.put_packet(msg.to_utf8_buffer())

func _on_peer_connected(id: int) -> void:
	player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	player_left.emit(id)

func _on_server_disconnected() -> void:
	leave_session()

@rpc("any_peer", "unreliable")
func update_player_transform(pos: Vector3, yaw: float, sprint: bool) -> void:
	var sender = multiplayer.get_remote_sender_id()
	var main = get_tree().current_scene
	if main and main.name == "Main":
		if main._puppets.has(sender):
			main._puppets[sender].target_position = pos
			main._puppets[sender].target_rotation = yaw
			main._puppets[sender].is_sprinting = sprint

@rpc("any_peer", "reliable")
func update_player_flashlight(on: bool) -> void:
	var sender = multiplayer.get_remote_sender_id()
	var main = get_tree().current_scene
	if main and main.name == "Main":
		if main._puppets.has(sender):
			main._puppets[sender].target_flashlight = on
			main._puppets[sender].flashlight.visible = on

@rpc("any_peer", "reliable")
func update_player_downed(downed: bool) -> void:
	var sender = multiplayer.get_remote_sender_id()
	var main = get_tree().current_scene
	if main and main.name == "Main":
		if main._puppets.has(sender):
			if downed:
				main._puppets[sender].rotation.x = PI / 2.0
				main._puppets[sender].position.y = 0.2
			else:
				main._puppets[sender].rotation.x = 0.0
				main._puppets[sender].position.y = 0.0

@rpc("any_peer", "reliable")
func notify_downed(player_id: int) -> void:
	var main = get_tree().current_scene
	if not main or main.name != "Main": return
	
	# Check if all players are downed
	var all_downed = true
	if not main.player.is_downed:
		all_downed = false
	for peer in multiplayer.get_peers():
		if main._puppets.has(peer) and main._puppets[peer].rotation.x == 0.0:
			all_downed = false
			
	if all_downed:
		rpc("team_wiped")

@rpc("any_peer", "call_local")
func team_wiped() -> void:
	var main = get_tree().current_scene
	if not main or main.name != "Main": return
	if main.campaign.lethal():
		main.campaign.player_killed()
	else:
		main._blackout()

@rpc("any_peer", "call_local")
func revive_player(target_id: int) -> void:
	if multiplayer.get_unique_id() == target_id:
		var main = get_tree().current_scene
		if main and main.name == "Main" and main.player:
			main.player.is_downed = false
			main.player.revive()
			rpc("update_player_downed", false)

@rpc("any_peer", "call_remote")
func sync_pickup_taken(item_id: String, kind: String) -> void:
	var main = get_tree().current_scene
	if not main or main.name != "Main": return
	
	# If the item gives global progress or team inventory, give it to local player too
	# Here we just remove the physical node so others can't grab it
	for node in get_tree().get_nodes_in_group("pickup"):
		if node.item_id == item_id:
			node.queue_free()

@rpc("any_peer", "call_remote")
func sync_ritual_placement(item_kind: String) -> void:
	var main = get_tree().current_scene
	if not main or main.name != "Main": return
	# Find quest and invoke placement
	if main.quest:
		main.quest.place_ritual_item(item_kind, true) # Requires modify in quest.gd



