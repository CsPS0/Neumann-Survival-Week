extends Node
## Headless co-op server. Run it with:
##   godot --headless --path . res://scenes/dedicated_server.tscn -- --port 7777 --max-players 4 --public-host 203.0.113.5
## Every option is also read from NEUMANN_PORT, NEUMANN_MAX_PLAYERS and NEUMANN_PUBLIC_HOST (used by Docker).
## The server only relays players. The game itself runs on each player's device.


func _ready() -> void:
	var port := _option("port", "NEUMANN_PORT", NetSession.DEFAULT_PORT)
	var max_players := _option("max-players", "NEUMANN_MAX_PLAYERS", NetSession.MAX_CLIENTS)
	var public_host := _text_option("public-host", "NEUMANN_PUBLIC_HOST")
	if NetSession.host_session(port, max_players, true, public_host) != OK:
		printerr("Server failed to start: " + NetSession.last_error)
		get_tree().quit(1)
		return
	NetSession.player_joined.connect(func(id: int) -> void:
		print("Player %d joined. Players: %d" % [id, NetSession.player_count()]))
	NetSession.player_left.connect(func(id: int) -> void:
		print("Player %d left. Players: %d" % [id, NetSession.player_count()]))
	print("The Empty School dedicated server")
	print("Listening on UDP port %d for up to %d players." % [port, max_players])
	print("Address: " + NetSession.get_address())
	var code := NetSession.get_display_code()
	print("Room code: " + (code if code != "" else "not available for this host, use the address"))
	if public_host == "":
		print("This address is the local one. Pass --public-host with the address players use to reach this machine.")


func _text_option(name: String, env: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--" + name)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return OS.get_environment(env)


func _option(name: String, env: String, fallback: int) -> int:
	var text := _text_option(name, env)
	return int(text) if text.is_valid_int() else fallback
