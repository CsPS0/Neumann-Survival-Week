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

var _lamps: Array[SpotLight3D] = []
var _darkness := 0.0           ## 0 = day, 1 = night.
var _dusk_announced := false
var _flicker_left := 0.0


func _ready() -> void:
	add_to_group("daynight")


func register_lamp(lamp: SpotLight3D) -> void:
	_lamps.append(lamp)


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
	if environment:
		environment.ambient_light_energy = lerpf(0.55, 0.015, _darkness)
		environment.ambient_light_color = Color(0.85, 0.88, 0.9).lerp(Color(0.35, 0.4, 0.6), _darkness)
		environment.fog_density = lerpf(0.004, 0.045, _darkness)
		environment.fog_light_color = Color(0.45, 0.5, 0.55).lerp(Color(0.015, 0.02, 0.03), _darkness)
		
		var is_mobile := OS.has_feature("mobile") or OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios")
		if not is_mobile:
			if _darkness > 0.15:
				environment.volumetric_fog_enabled = true
				environment.volumetric_fog_density = lerpf(0.0, 0.032, _darkness)
				environment.volumetric_fog_albedo = Color(0.22, 0.25, 0.32).lerp(Color(0.04, 0.04, 0.07), _darkness)
				environment.volumetric_fog_emission = Color(0.01, 0.01, 0.02)
			else:
				environment.volumetric_fog_enabled = false
	var flicker := _darkness > 0.05 and _darkness < 0.98
	var night_flicker := _darkness >= 0.98
	for lamp in _lamps:
		var energy := LAMP_ENERGY * (1.0 - _darkness)
		if flicker and randf() < 0.2:
			energy *= randf_range(0.0, 0.8)
		elif night_flicker and randf() < 0.01:
			energy = randf_range(0.12, 0.45)
		if _flicker_left > 0.0 and randf() < 0.6:
			energy = 0.0
		lamp.light_energy = energy
		lamp.visible = energy > 0.01
