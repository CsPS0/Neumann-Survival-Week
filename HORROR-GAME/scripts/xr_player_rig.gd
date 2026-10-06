extends Node3D

@onready var origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var flashlight: SpotLight3D = $XROrigin3D/RightHand/Flashlight
@onready var interact_ray: RayCast3D = $XROrigin3D/RightHand/InteractRay
@onready var vignette: MeshInstance3D = $XROrigin3D/XRCamera3D/Vignette

var input_bridge: Node
var snap_turn_threshold := 0.5
var has_snap_turned := false
var player: CharacterBody3D

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	input_bridge = get_tree().get_first_node_in_group("input_bridge") as Node
	if input_bridge:
		input_bridge.current_mode = 2 # Mode.XR
	
	left_hand.button_pressed.connect(_on_left_button)
	right_hand.button_pressed.connect(_on_right_button)
	
	# Height calibration helper: center the player XROrigin
	if XRServer.primary_interface:
		# Let XR system settle, then center
		get_tree().create_timer(0.5).timeout.connect(func(): XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true))
		
	# Setup vignette material
	var vig_mat = ShaderMaterial.new()
	vig_mat.shader = Shader.new()
	vig_mat.shader.code = """
	shader_type spatial;
	render_mode unshaded, depth_test_disabled;
	uniform float intensity : hint_range(0.0, 1.0) = 0.0;
	void fragment() {
		vec2 uv = SCREEN_UV - vec2(0.5);
		float dist = length(uv) * 2.0;
		float alpha = smoothstep(0.5, 1.5, dist) * intensity;
		ALBEDO = vec3(0.0);
		ALPHA = alpha;
	}
	"""
	vignette.material_override = vig_mat

func _physics_process(_delta: float) -> void:
	if not player: return
	
	if input_bridge:
		var move_vec := left_hand.get_vector2("primary")
		# Adjust move_vec so that pressing 'up' moves in the camera's forward direction
		# To do this without changing player.gd, we find the yaw difference between camera and player.
		var cam_yaw = camera.global_rotation.y
		var player_yaw = player.global_rotation.y
		var yaw_diff = cam_yaw - player_yaw
		
		var input_dir = Vector2(move_vec.x, -move_vec.y)
		var rotated_dir = input_dir.rotated(-yaw_diff)
		
		input_bridge.feed_move_vector(rotated_dir)
		input_bridge.is_sprinting = left_hand.is_button_pressed("primary_click") or left_hand.get_float("grip") > 0.5
	
	var turn_vec := right_hand.get_vector2("primary")
	if abs(turn_vec.x) > snap_turn_threshold:
		if not has_snap_turned:
			var turn_angle = -sign(turn_vec.x) * deg_to_rad(45.0)
			player.rotate_y(turn_angle)
			has_snap_turned = true
	else:
		has_snap_turned = false
		
	# Synchronize player global position with XR tracking (roomscale walking)
	var cam_pos = camera.global_position
	var p_pos = player.global_position
	var pos_diff = Vector3(cam_pos.x - p_pos.x, 0, cam_pos.z - p_pos.z)
	if pos_diff.length() > 0.001:
		player.global_position += pos_diff
		origin.global_position -= pos_diff
			
	if vignette and vignette.material_override:
		var speed = Vector3(player.velocity.x, 0, player.velocity.z).length()
		var target_intensity = clamp(speed / 4.0, 0.0, 0.8)
		var current = vignette.material_override.get_shader_parameter("intensity")
		vignette.material_override.set_shader_parameter("intensity", lerp(current, target_intensity, 0.1))
		vignette.visible = (target_intensity > 0.01 or current > 0.01)
		
	# Synchronize interact_ray target with Godot's original player raycast
	var head_cam = player.get_node_or_null("Head/Camera3D")
	if head_cam:
		if head_cam.has_node("InteractRay"):
			var orig_ray = head_cam.get_node("InteractRay") as RayCast3D
			orig_ray.global_transform = interact_ray.global_transform
		
		# Sync flashlight with player's flashlight
		if head_cam.has_node("Flashlight"):
			var orig_flash = head_cam.get_node("Flashlight") as SpotLight3D
			flashlight.visible = orig_flash.visible
			flashlight.light_energy = orig_flash.light_energy
			# Prevent original from lighting up the scene
			orig_flash.light_energy = 0.0

func _on_left_button(action: String) -> void:
	if action == "grip_click" or action == "by_button":
		if input_bridge:
			input_bridge.trigger_phone()
	elif action == "ax_button":
		if input_bridge:
			input_bridge.trigger_phone_tab()

func _on_right_button(action: String) -> void:
	if action == "trigger_click":
		if input_bridge:
			input_bridge.trigger_interact()
	elif action == "grip_click" or action == "by_button":
		if input_bridge:
			input_bridge.trigger_flashlight()
