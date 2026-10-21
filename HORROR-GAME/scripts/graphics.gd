extends RefCounted
## Graphics quality: the presets, the single settings and the code that applies them to the engine.
## Low-end PCs: "dynamic_lighting" off replaces every lamp with ambient light (see day_night.gd), which is the biggest saving.

const KEYS: Array[String] = ["render_scale", "dynamic_lighting", "shadows", "view_distance", "effects", "aa", "vsync", "fps_cap"]
const PRESET_NAMES: Array[String] = ["Low", "Medium", "High"]
const ALL_LAYERS := 0xFFFFF

## Whether lights outside the school lamps (candles, fires, the phone flash) are on. Read when they are created.
static var dynamic_lighting := true


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("web") or OS.has_feature("ios")


static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Preset used on first start: weak graphics chips (integrated, software) start on Low, discrete cards on High.
static func detect_quality() -> int:
	if is_mobile():
		return 0
	if DisplayServer.get_name() == "headless":
		return 2
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
			return 2
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, RenderingDevice.DEVICE_TYPE_CPU:
			return 0
		_:
			return 1


## Values of preset 0 (Low), 1 (Medium) or 2 (High). Phones and headsets keep their lamps: the mobile renderer handles them.
static func preset_values(level: int) -> Dictionary:
	var mobile := is_mobile()
	match clampi(level, 0, 2):
		0:
			return {"render_scale": 0.75 if mobile else 0.6, "dynamic_lighting": mobile, "shadows": 1 if mobile else 0,
					"view_distance": 70.0, "effects": false, "aa": 0, "vsync": true, "fps_cap": 0}
		1:
			return {"render_scale": 0.85, "dynamic_lighting": true, "shadows": 1, "view_distance": 120.0,
					"effects": false, "aa": 1, "vsync": true, "fps_cap": 0}
		_:
			return {"render_scale": 1.0, "dynamic_lighting": true, "shadows": 2, "view_distance": 250.0,
					"effects": true, "aa": 0 if mobile else 2, "vsync": true, "fps_cap": 0}


## The preset whose values equal the current settings, or PRESET_NAMES.size() when they match none (custom).
static func matching_preset(profile: Node) -> int:
	for level in PRESET_NAMES.size():
		var values := preset_values(level)
		var same := true
		for key: String in KEYS:
			var want: Variant = values[key]
			var have: Variant = profile.get_setting(key)
			if want is bool:
				same = same and have == want
			else:
				same = same and is_equal_approx(float(have), float(want))
		if same:
			return level
	return PRESET_NAMES.size()


## Tags a light that is not a school lamp. It is switched off with the other dynamic lights.
static func tag_extra(light: Light3D) -> void:
	light.add_to_group("extra_light")
	if not dynamic_lighting:
		light.light_cull_mask = 0


static func apply(profile: Node, viewport: Viewport, player: Node, daynight: Node) -> void:
	var dynamic: bool = profile.get_setting("dynamic_lighting")
	var shadows := int(profile.get_setting("shadows"))
	dynamic_lighting = dynamic
	if daynight:
		daynight.set_graphics(dynamic, shadows, profile.get_setting("effects"))
	for light: Light3D in viewport.get_tree().get_nodes_in_group("extra_light"):
		light.light_cull_mask = ALL_LAYERS if dynamic else 0
	if not viewport.use_xr:   # Headsets size the render target themselves.
		var scale := float(profile.get_setting("render_scale"))
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if scale >= 0.999 or is_compatibility() \
				else Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = scale
		var aa := int(profile.get_setting("aa"))
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.msaa_3d = Viewport.MSAA_2X if aa == 2 else Viewport.MSAA_DISABLED
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if profile.get_setting("vsync")
				else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(profile.get_setting("fps_cap"))
	if player:
		var camera: Camera3D = player.get("camera")
		if camera:
			camera.far = float(profile.get_setting("view_distance"))
		var torch: SpotLight3D = player.get("flashlight")
		if torch:
			torch.shadow_enabled = dynamic and shadows >= 1
