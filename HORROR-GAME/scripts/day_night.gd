extends Node
## Game clock and lighting. Day: bright lamps and ambient light, teachers about, demon asleep.
## Dusk: lamps flicker. Night: nearly pitch dark - the flashlight is the only reliable light.

signal dusk_started
signal night_fell
signal day_returned

const DAY_START := 6.0 * 60.0
const DUSK := 17.0 * 60.0 + 30.0
const NIGHT := 18.0 * 60.0
const LAMP_ENERGY := 1.4

@export var minutes_per_second := 2.0   ## 600 game minutes of daylight last 5 real minutes.

var minutes := DAY_START
var running := false
var is_night := false
var environment: Environment
var sun: DirectionalLight3D     ## The sun: moves east to west between 06:00 and 18:00, shadows come from the walls.
var quality := 2                ## 0 low (mobile, Quest), 1 medium, 2 high. See set_quality().

var _lamps: Array[SpotLight3D] = []
var _darkness := 0.0           ## 0 = day, 1 = night.
var _dusk_announced := false
var _flicker_left := 0.0
var _sky: Sky
var _sky_material: ProceduralSkyMaterial


func _ready() -> void:
	add_to_group("daynight")
	_build_outdoors()


func register_lamp(lamp: SpotLight3D) -> void:
	_lamps.append(lamp)


## Sun, sky and the ground outside the windows.
func _build_outdoors() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.6
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(600.0, 600.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.17, 0.26, 0.13)
	ground_material.roughness = 1.0
	plane.material = ground_material
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.52, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_curve = 0.15
	_sky_material.ground_curve = 0.05
	_sky = Sky.new()
	_sky.sky_material = _sky_material
	set_quality(quality)


## Shadow range, shadow atlas size and the effects that cost the most. Mobile and Quest builds start on 0.
func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	if sun:
		match quality:
			0:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun.directional_shadow_max_distance = 30.0
			1:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				sun.directional_shadow_max_distance = 45.0
			_:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				sun.directional_shadow_max_distance = 70.0
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][quality], true)
	if environment:
		environment.ssao_enabled = quality >= 2 and not _is_mobile()
	_apply_sky()


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios")


func time_text() -> String:
	var total := int(minutes) % (24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]


## Every lamp stutters for `seconds` (a haunting prank).
func flicker(seconds: float) -> void:
	_flicker_left = seconds


func skip_to_dusk() -> void:
	minutes = maxf(minutes, DUSK)


func force_day() -> void:
	is_night = false
	minutes = DAY_START
	_dusk_announced = false
	day_returned.emit()


## A new school day: 06:00, daylight, clock running.
func start_day() -> void:
	force_day()
	running = true


func _process(delta: float) -> void:
	if running:
		minutes += minutes_per_second * delta
		if not _dusk_announced and not is_night and minutes >= DUSK:
			_dusk_announced = true
			dusk_started.emit()
		if not is_night and minutes >= NIGHT:
			is_night = true
			night_fell.emit()
	var target := 1.0 if (is_night or minutes >= NIGHT) else clampf(inverse_lerp(DUSK, NIGHT, minutes), 0.0, 1.0)
	if not is_night and minutes < DUSK:
		target = 0.0
	_darkness = move_toward(_darkness, target, delta * 0.5)
	_flicker_left = maxf(_flicker_left - delta, 0.0)
	_apply_lighting(delta)


func _apply_lighting(delta: float) -> void:
	_apply_sun()
	if environment:
		environment.ambient_light_energy = lerpf(0.3, 0.015, _darkness)
		environment.ambient_light_color = Color(0.85, 0.88, 0.9).lerp(Color(0.35, 0.4, 0.6), _darkness)
		environment.fog_density = lerpf(0.004, 0.045, _darkness)
		environment.fog_light_color = Color(0.55, 0.62, 0.7).lerp(Color(0.015, 0.02, 0.03), _darkness)
		environment.fog_sky_affect = 0.0
		if quality >= 1 and not _is_mobile():
			# Thin by day, so the sun shows as beams through the windows. Thick at night.
			environment.volumetric_fog_enabled = true
			environment.volumetric_fog_density = lerpf(0.03, 0.032, _darkness)
			environment.volumetric_fog_albedo = Color(0.9, 0.92, 0.95).lerp(Color(0.04, 0.04, 0.07), _darkness)
			environment.volumetric_fog_emission = Color(0.01, 0.01, 0.02)
		else:
			environment.volumetric_fog_enabled = false
	var flicker := _darkness > 0.05 and _darkness < 0.98
	var night_flicker := _darkness >= 0.98
	for lamp in _lamps:
		var energy := LAMP_ENERGY * (1.0 - _darkness) * lerpf(0.75, 1.0, _darkness)   # Daylight does part of the work.
		if flicker and randf() < 0.2:
			energy *= randf_range(0.0, 0.8)
		elif night_flicker and randf() < 0.01:
			energy = randf_range(0.12, 0.45)
		if _flicker_left > 0.0 and randf() < 0.6:
			energy = 0.0
		lamp.light_energy = energy
		lamp.visible = energy > 0.01


## Sun position from the clock: rises in the east at 06:00, is highest at noon, sets in the west at 18:00.
func _apply_sun() -> void:
	if sun == null:
		return
	var t := clampf((minutes - DAY_START) / (NIGHT - DAY_START), 0.0, 1.0)
	var elevation := deg_to_rad(lerpf(7.0, 62.0, sin(t * PI)))
	var azimuth := t * PI
	var to_sun := Vector3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	var warmth := clampf(1.0 - (rad_to_deg(elevation) - 7.0) / 28.0, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.58, 0.3), warmth)
	var energy := lerpf(2.2, 3.4, sin(elevation)) * (1.0 - _darkness)
	sun.light_energy = energy
	sun.visible = energy > 0.01
	sun.light_volumetric_fog_energy = 1.0
	_apply_sky(warmth)


func _apply_sky(warmth := 0.0) -> void:
	if environment == null or _sky == null:
		return
	if environment.sky != _sky:
		environment.background_mode = Environment.BG_SKY
		environment.sky = _sky
	var day_top := Color(0.3, 0.5, 0.88)
	var day_horizon := Color(0.72, 0.82, 0.92).lerp(Color(1.0, 0.7, 0.45), warmth * 0.8)
	var night := Color(0.008, 0.01, 0.025)
	_sky_material.sky_top_color = day_top.lerp(night, _darkness)
	_sky_material.sky_horizon_color = day_horizon.lerp(Color(0.02, 0.025, 0.045), _darkness)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	_sky_material.ground_bottom_color = Color(0.1, 0.14, 0.09).lerp(night, _darkness)
	_sky_material.sky_energy_multiplier = lerpf(1.0, 0.6, _darkness)
