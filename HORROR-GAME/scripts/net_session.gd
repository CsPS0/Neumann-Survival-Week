extends Node
## Co-op session: Godot ENet on one UDP port. The host (a player or a headless dedicated server) listens, clients join
## by address. The room code is the host address and port packed into ten letters, see make_room_code.

signal session_started(is_host: bool)
signal session_ended
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal connection_succeeded
signal connection_failed
signal lan_room_found(code: String, address: String)

const DEFAULT_PORT = 7777
const DISCOVERY_PORT = 7778
const MAX_CLIENTS = 4
const CODE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

var server_is_dedicated := false
var last_error := ""
var lan_rooms := {}

var _peer: ENetMultiplayerPeer
var _udp_peer: PacketPeerUDP
var _listener: PacketPeerUDP
var _broadcasting := false
var _broadcast_timer := 0.0
var _room_code := ""
var _address := ""
var _is_host := false
var _connected := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func is_multiplayer_active() -> bool:
	return _peer != null

func is_host() -> bool:
	return _peer != null and _is_host

func is_connected_to_session() -> bool:
	return _peer != null and (_is_host or _connected)

## Players in the session, this one included. A dedicated server is not a player.
func player_count() -> int:
	if _peer == null:
		return 0
	if _is_host:
		return multiplayer.get_peers().size() + (0 if server_is_dedicated else 1)
	var others := multiplayer.get_peers().size()
	return others if server_is_dedicated else others + 1

## Peer ids of the other players, without a dedicated server.
func get_remote_players() -> Array[int]:
	var ids: Array[int] = []
	if _peer == null:
		return ids
	for id in multiplayer.get_peers():
		if id == 1 and server_is_dedicated:
			continue
		ids.append(id)
	return ids

func host_session(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS, dedicated := false,
		public_host := "") -> Error:
	leave_session()
	last_error = ""
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err != OK:
		last_error = "Could not open UDP port %d (error %d). Is another game already hosting?" % [port, err]
		printerr(last_error)
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	_is_host = true
	_connected = true
	server_is_dedicated = dedicated
	var host := public_host if public_host != "" else get_local_address()
	_address = "%s:%d" % [host, port]
	_room_code = make_room_code(host, port)
	_start_lan_broadcast()
	session_started.emit(true)
	return OK

## Joins by room code, "host", "host:port" or "ip:port". Returns OK when the connection attempt started.
func join_session(target: String, port: int = DEFAULT_PORT) -> Error:
	leave_session()
	last_error = ""
	var parsed := parse_address(target, port)
	if parsed.is_empty():
		last_error = "Enter a room code or an address like 192.168.1.20:7777."
		return ERR_INVALID_PARAMETER
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(parsed["host"], parsed["port"])
	if err != OK:
		last_error = "Could not start the connection (error %d)." % err
		printerr(last_error)
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	_is_host = false
	_connected = false
	_address = "%s:%d" % [parsed["host"], parsed["port"]]
	_room_code = make_room_code(parsed["host"], parsed["port"])
	session_started.emit(false)
	return OK

func leave_session() -> void:
	var was_active := _peer != null
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_peer = null
	_is_host = false
	_connected = false
	server_is_dedicated = false
	_room_code = ""
	_address = ""
	_stop_lan_broadcast()
	if was_active:
		session_ended.emit()

func get_room_code() -> String:
	return _room_code

## The room code as shown to players: XXXXX-XXXXX.
func get_display_code() -> String:
	return _room_code.substr(0, 5) + "-" + _room_code.substr(5) if _room_code.length() == 10 else _room_code

func get_address() -> String:
	return _address

## First private IPv4 address of this machine, else 127.0.0.1.
func get_local_address() -> String:
	var fallback := ""
	for a in IP.get_local_addresses():
		var parts := a.split(".")
		if parts.size() != 4 or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		var second := int(parts[1])
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and second >= 16 and second <= 31):
			return a
		if fallback == "":
			fallback = a
	return fallback if fallback != "" else "127.0.0.1"

## Packs an IPv4 address and a port into ten letters (A to Z, 2 to 7). Other hosts return an empty code.
static func make_room_code(host: String, port: int) -> String:
	var parts := host.split(".")
	if parts.size() != 4 or port < 1 or port > 65535:
		return ""
	var value := 0
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return ""
		value = (value << 8) | int(p)
	value = (value << 16) | port
	var code := ""
	for i in 10:
		code = CODE_ALPHABET[value & 31] + code
		value >>= 5
	return code

## Reverses make_room_code. Returns {"host", "port"} or an empty dictionary.
static func decode_room_code(text: String) -> Dictionary:
	var clean := text.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if clean.length() != 10:
		return {}
	var value := 0
	for c in clean:
		var idx := CODE_ALPHABET.find(c)
		if idx < 0:
			return {}
		value = (value << 5) | idx
	var port := value & 0xFFFF
	var ip := value >> 16
	if port == 0 or ip > 0xFFFFFFFF:
		return {}
	return {"host": "%d.%d.%d.%d" % [(ip >> 24) & 255, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255], "port": port}

## Accepts a room code, "host", "host:port" or "ip:port". Returns {"host", "port"} or an empty dictionary.
static func parse_address(text: String, default_port: int = DEFAULT_PORT) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {}
	var decoded := decode_room_code(t)
	if not decoded.is_empty() and not t.contains(".") and not t.contains(":"):
		return decoded
	var host := t
	var port := default_port
	if t.count(":") == 1:
		host = t.get_slice(":", 0)
		var port_text := t.get_slice(":", 1)
		if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
			return {}
		port = int(port_text)
	if host == "" or host.contains(" "):
		return {}
	return {"host": host, "port": port}

func _start_lan_broadcast() -> void:
	if _room_code == "":
		return
	_udp_peer = PacketPeerUDP.new()
	_udp_peer.set_broadcast_enabled(true)
	_udp_peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcasting = true
	_broadcast_timer = 0.0

func _stop_lan_broadcast() -> void:
	_broadcasting = false
	if _udp_peer:
		_udp_peer.close()
		_udp_peer = null

## Starts listening for rooms that hosts announce on the local network.
func start_lan_discovery() -> void:
	lan_rooms.clear()
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null

func stop_lan_discovery() -> void:
	if _listener:
		_listener.close()
		_listener = null

func _process(delta: float) -> void:
	if _broadcasting and _udp_peer:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = 1.0
			_udp_peer.put_packet(("NEUMANN_ROOM:%s:%s" % [_room_code, _address]).to_utf8_buffer())
	if _listener:
		while _listener.get_available_packet_count() > 0:
			var msg := _listener.get_packet().get_string_from_utf8()
			var fields := msg.split(":", true, 2)
			if fields.size() == 3 and fields[0] == "NEUMANN_ROOM" and not lan_rooms.has(fields[1]):
				lan_rooms[fields[1]] = fields[2]
				lan_room_found.emit(fields[1], fields[2])

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		server_hello.rpc_id(id, server_is_dedicated)
		player_joined.emit(id)
	elif id != 1:
		player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	player_left.emit(id)

func _on_server_disconnected() -> void:
	leave_session()

func _on_connected_to_server() -> void:
	_connected = true
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	last_error = "Could not reach %s. Check the code, the host and that UDP port is open." % _address
	leave_session()
	connection_failed.emit()

## Sent by the host to every new peer so a client knows whether peer 1 is a player or a dedicated server.
@rpc("authority", "reliable")
func server_hello(dedicated: bool) -> void:
	server_is_dedicated = dedicated
	if not dedicated:
		player_joined.emit(1)

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



