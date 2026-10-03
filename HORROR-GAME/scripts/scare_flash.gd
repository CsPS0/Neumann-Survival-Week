extends CanvasLayer
## Split-second blackout with a harsh sting when the entity shows up, plus "everyone else vanishes" until it is gone.
## The caretaker is never hidden (he is his own threat). Cooldown 20 s; blocked behind overlays, endings and menus.

const SoundBank := preload("res://scripts/sound_bank.gd")

const COOLDOWN := 20.0
const RETURN_DELAY := 1.0
const MAX_HIDDEN := 25.0

var overlay := ColorRect.new()
var cooldown_left := 0.0
var npcs_hidden := false
var main: Node                    ## Provides the NPC groups, entity, crowd, Csoki, overlays and the profile.

var _sound := AudioStreamPlayer.new()
var _tween: Tween
var _gone_for := 0.0
var _hidden_for := 0.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_sound.volume_db = 2.0
	add_child(_sound)


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if not npcs_hidden:
		return
	_hidden_for += delta
	_apply_hidden(true)   # Re-hide anything that spawned meanwhile.
	var entity: Node3D = main.entity
	if entity != null and is_instance_valid(entity) and entity.visible:
		_gone_for = 0.0
	else:
		_gone_for += delta
	if _gone_for >= RETURN_DELAY or _hidden_for >= MAX_HIDDEN:
		_set_hidden(false)


## Returns false when blocked. With the setting off the NPCs still vanish but there is no black frame or sound.
func trigger() -> bool:
	if cooldown_left > 0.0 or _blocked():
		return false
	cooldown_left = COOLDOWN
	_set_hidden(true)
	_gone_for = 0.0
	_hidden_for = 0.0
	if main.profile.get_setting("scare_flash"):
		var hold := randf_range(0.10, 0.30)
		overlay.color.a = 1.0
		_sound.stream = SoundBank.flash_sting(randf_range(0.1, 0.5))
		_sound.play()
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_interval(hold)
		_tween.tween_property(overlay, "color:a", 0.0, 0.10)
	return true


func _blocked() -> bool:
	return main == null or main._game_over or main.choice_ui.visible or main.lesson_ui.visible or main.menu.is_open() \
			or main.campaign.ending_id != 0


func _set_hidden(on: bool) -> void:
	npcs_hidden = on
	_apply_hidden(on)
	main.crowd.hidden = on


func _apply_hidden(on: bool) -> void:
	for group in ["teachers", "ambient_staff", "csoki", "porta"]:
		for node in main.get_tree().get_nodes_in_group(group):
			if node is Node3D:
				node.visible = not on
			if node is CollisionObject3D:   # A hidden NPC must not be an invisible wall; restore its own layer after.
				if on and not node.has_meta(&"flash_layer"):
					node.set_meta(&"flash_layer", node.collision_layer)
					node.collision_layer = 0
				elif not on and node.has_meta(&"flash_layer"):
					node.collision_layer = node.get_meta(&"flash_layer")
					node.remove_meta(&"flash_layer")
