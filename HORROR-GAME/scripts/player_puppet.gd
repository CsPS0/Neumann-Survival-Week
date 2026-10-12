class_name PlayerPuppet extends StaticBody3D

@onready var body = $Body
@onready var head = $Head
@onready var flashlight = $Head/Flashlight
@onready var nametag = $Nametag

var target_position := Vector3.ZERO
var target_rotation := 0.0
var target_flashlight := false
var is_sprinting := false
var is_hiding := false          ## Match mode: set from the hiding report; the entity reads it like the player's.
var walk_speed := 3.0           ## Same fields the entity reads on the real player.
var velocity := Vector3.ZERO
var _last_position := Vector3.ZERO
var _catch_cooldown := 0.0

func _ready() -> void:
	target_position = global_position
	target_rotation = rotation.y
	flashlight.visible = target_flashlight

var prompt = "Revive"
var _revive_timer = 0.0

func _process(delta: float) -> void:
	_last_position = global_position
	global_position = global_position.lerp(target_position, 15.0 * delta)
	velocity = (global_position - _last_position) / maxf(delta, 0.001)
	_catch_cooldown = maxf(_catch_cooldown - delta, 0.0)
	rotation.y = lerp_angle(rotation.y, target_rotation, 15.0 * delta)
	flashlight.visible = target_flashlight
	
	if is_sprinting:
		# Simple run animation
		var t = Time.get_ticks_msec() / 1000.0
		body.position.y = 0.75 + sin(t * 15.0) * 0.05
	else:
		var t = Time.get_ticks_msec() / 1000.0
		body.position.y = 0.75 + sin(t * 5.0) * 0.02
		
	# Re-orient nametag manually if billboard isn't enough, but billboard=1 handles it in scene
	
	if Match.is_active():
		_update_match_prompt()
		return
	var main = get_tree().current_scene
	if rotation.x != 0 and main and main.name == "Main" and main.player:
		var ray = main.player.interact_ray
		if ray.is_colliding() and ray.get_collider() == self:
			if Input.is_action_pressed("interact") and not main.player.is_downed:
				_revive_timer += delta
				prompt = "Reviving... " + str(int((_revive_timer / 3.0) * 100)) + "%"
				if _revive_timer >= 3.0:
					NetSession.rpc("revive_player", name.to_int())
					_revive_timer = 0.0
			else:
				_revive_timer = 0.0
				prompt = "Revive"
		else:
			_revive_timer = 0.0
			prompt = "Revive"

func interact(by: Node) -> void:
	# Revive is handled in _process. In a match the entity's player catches with E.
	if Match.is_active() and Match.is_seeker_me() and Match.phase == Match.Phase.HUNT and _catch_cooldown <= 0.0 \
			and Match.state_of(name.to_int()) == Match.PState.ALIVE and by.get("seeker_mode"):
		_catch_cooldown = 1.0
		Match.report_catch(name.to_int())


## Called by the computer-controlled entity when it reaches this survivor.
func on_caught(_source: Node3D = null) -> void:
	if Match.is_bot_host_me():
		Match.report_catch(name.to_int())


func set_downed(downed: bool) -> void:
	rotation.x = PI / 2.0 if downed else 0.0
	position.y = 0.2 if downed else 0.0


func _update_match_prompt() -> void:
	var main = get_tree().current_scene
	if main == null or main.name != "Main" or main.player == null:
		return
	var state := Match.state_of(name.to_int())
	var ray = main.player.interact_ray
	var aimed: bool = ray.is_colliding() and ray.get_collider() == self
	if Match.is_seeker_me():
		prompt = "Catch"
		return
	if state != Match.PState.DOWNED or Match.phase != Match.Phase.HUNT or main.player.is_downed:
		_revive_timer = 0.0
		prompt = ""
		return
	if aimed and Input.is_action_pressed("interact"):
		_revive_timer += get_process_delta_time()
		prompt = "Reviving... " + str(int((_revive_timer / 3.0) * 100)) + "%"
		if _revive_timer >= 3.0:
			Match.report_revive(name.to_int())
			_revive_timer = 0.0
	else:
		_revive_timer = 0.0
		prompt = "Revive"


@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector3, yaw: float, sprint: bool) -> void:
	target_position = pos
	target_rotation = yaw
	is_sprinting = sprint

@rpc("any_peer", "reliable")
func sync_flashlight(on: bool) -> void:
	target_flashlight = on

@rpc("any_peer", "reliable")
func sync_name(player_name: String) -> void:
	if nametag:
		nametag.text = player_name
