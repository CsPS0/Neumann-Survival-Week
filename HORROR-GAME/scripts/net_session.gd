extends Node
## Co-op session: Godot ENet on one UDP port. The host (a player or a headless dedicated server) listens, clients join
## by address. The room code is four digits. The host announces code and address by UDP broadcast on the local network
## and a joining player looks the code up there. Off the local network, players join by address.

signal session_started(is_host: bool)
signal session_ended
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal connection_succeeded
signal connection_failed
signal lan_room_found(code: String, address: String)
signal room_code_changed(code: String)

const DEFAULT_PORT = 7777
const DISCOVERY_PORT = 7778
const MAX_CLIENTS = 4
const CODE_LENGTH = 4
const ROOM_TIMEOUT = 4.0

var server_is_dedicated := false
var last_error := ""
## Rooms seen on the network: code -> {"address", "seen"} where seen is a time in seconds.
var lan_rooms := {}

var _peer: ENetMultiplayerPeer
var _udp_peer: PacketPeerUDP
var _listener: PacketPeerUDP
var _broadcasting := false
var _broadcast_timer := 0.0
var _room_code := ""
var _forced_code := ""
var _address := ""
var _is_host := false
var _connected := false

func _ready() -> void:
	# The menus pause the tree. Discovery and the session must keep running there.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		public_host := "", room_code := "") -> Error:
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
	_forced_code = room_code if is_valid_code(room_code) else ""
	start_lan_discovery()
	_room_code = _forced_code if _forced_code != "" else _pick_free_code()
	_start_lan_broadcast()
	session_started.emit(true)
	return OK

## Joins by "host", "host:port" or "ip:port". A room code needs resolve_room first. Returns OK when the connection
## attempt started.
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
	_forced_code = ""
	_address = ""
	_stop_lan_broadcast()
	stop_lan_discovery()
	if was_active:
		session_ended.emit()

func get_room_code() -> String:
	return _room_code

func get_display_code() -> String:
	return _room_code

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

static func is_valid_code(text: String) -> bool:
	if text.length() != CODE_LENGTH:
		return false
	for c in text:
		if c < "0" or c > "9":
			return false
	return true

## A random four digit code that no room on the network announces right now.
func _pick_free_code() -> String:
	_prune_rooms()
	for i in 200:
		var code := "%04d" % (randi() % 10000)
		if not lan_rooms.has(code):
			return code
	return "%04d" % (randi() % 10000)

## Looks a room code up on the local network. A query goes out by broadcast, and by loopback for a host on this
## computer, and the host that holds the code answers with its address. Returns "" after the timeout.
func resolve_room(code: String, timeout := 3.0) -> String:
	var clean := code.strip_edges()
	if not is_valid_code(clean):
		return ""
	var query := PacketPeerUDP.new()
	query.set_broadcast_enabled(true)
	var waited := 0.0
	var next_send := 0.0
	var address := ""
	while waited <= timeout and address == "":
		if waited >= next_send:
			next_send = waited + 0.5
			for target in ["255.255.255.255", "127.0.0.1"]:
				query.set_dest_address(target, DISCOVERY_PORT)
				query.put_packet(("NEUMANN_FIND:%s" % clean).to_utf8_buffer())
		while query.get_available_packet_count() > 0:
			var fields := query.get_packet().get_string_from_utf8().split(":", true, 2)
			if fields.size() == 3 and fields[0] == "NEUMANN_ROOM" and fields[1] == clean:
				address = fields[2]
		if address == "":
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
	query.close()
	return address

## Accepts "host", "host:port" or "ip:port". Returns {"host", "port"} or an empty dictionary.
static func parse_address(text: String, default_port: int = DEFAULT_PORT) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {}
	if is_valid_code(t):
		return {}
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
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null

func stop_lan_discovery() -> void:
	if _listener:
		_listener.close()
		_listener = null
	lan_rooms.clear()

func _prune_rooms() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for code in lan_rooms.keys():
		if now - float(lan_rooms[code]["seen"]) > ROOM_TIMEOUT:
			lan_rooms.erase(code)

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
			if fields.size() == 3 and fields[0] == "NEUMANN_ROOM" and is_valid_code(fields[1]):
				_on_room_announced(fields[1], fields[2])
			elif fields.size() == 2 and fields[0] == "NEUMANN_FIND" and _is_host and fields[1] == _room_code:
				_listener.set_dest_address(_listener.get_packet_ip(), _listener.get_packet_port())
				_listener.put_packet(("NEUMANN_ROOM:%s:%s" % [_room_code, _address]).to_utf8_buffer())

func _on_room_announced(code: String, address: String) -> void:
	if address == _address and _is_host:
		return
	var is_new: bool = not lan_rooms.has(code) or lan_rooms[code]["address"] != address
	lan_rooms[code] = {"address": address, "seen": Time.get_ticks_msec() / 1000.0}
	if is_new:
		lan_room_found.emit(code, address)
	# Two hosts picked the same code. The host with the larger address picks a new one.
	if _is_host and code == _room_code and _forced_code == "" and address < _address:
		_room_code = _pick_free_code()
		room_code_changed.emit(_room_code)

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



