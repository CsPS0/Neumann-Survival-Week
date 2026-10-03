extends "res://scripts/teacher_npc.gd"
## Mr. Bakó, the porter (invented). Stands behind the Porta desk, walks to a WC and back on `go_away`, and is never
## sent home or freed: group "porta" only, never "teachers". `interact` is handled by main's menu.

signal returned   ## Back at the desk after a trip.

var desk_position := Vector3.ZERO
var interact_handler: Callable
var return_limit := 30.0           ## Seconds walking back before he is put at the desk (never stuck away).

var _token := 0
var _returning := false
var _return_time := 0.0


func _ready() -> void:
	npc_name = "Mr. Bakó"
	shirt_colour = Color(0.08, 0.12, 0.3)   # Dark blue vest.
	super._ready()
	remove_from_group("teachers")
	add_to_group("porta")
	prompt = "Talk to Mr. Bakó"


func interact(by: Node = null) -> void:
	if by != null and interact_handler.is_valid():
		interact_handler.call(by)


func leave() -> void:
	pass   # He stays at the Porta day and night.


func is_at_desk() -> bool:
	return not _returning and _station == desk_position \
			and Vector2(global_position.x - desk_position.x, global_position.z - desk_position.z).length() < 1.5


## Walk to `wc_point`, wait there until `seconds` after the call, then walk back; `returned` fires at the desk.
func go_away(seconds: float, wc_point: Vector3) -> void:
	_token += 1
	var token := _token
	_returning = false
	set_station(wc_point)
	await get_tree().create_timer(seconds).timeout
	if token == _token and is_inside_tree():
		_come_back()


## Cancels a trip. `teleport` (new day) puts him straight behind the desk.
func return_to_desk(teleport := false) -> void:
	_token += 1
	if teleport:
		global_position = desk_position + Vector3(0.0, 0.1, 0.0)
		velocity = Vector3.ZERO
	_come_back()


func _come_back() -> void:
	set_station(desk_position)
	_returning = true
	_return_time = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _returning:
		_return_time += delta
		var flat := Vector2(global_position.x - desk_position.x, global_position.z - desk_position.z).length()
		if flat >= 1.5 and _return_time > return_limit:
			global_position = desk_position + Vector3(0.0, 0.1, 0.0)
			flat = 0.0
		if flat < 1.5:
			_returning = false
			returned.emit()
	elif _station == desk_position and Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		rotation.y = lerp_angle(rotation.y, 0.0, 4.0 * delta)   # Face the door (north).
