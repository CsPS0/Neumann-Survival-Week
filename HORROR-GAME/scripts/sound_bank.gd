extends RefCounted
## Procedurally synthesised sound effects (no audio files needed). Streams are cached per name.

const RATE := 22050

static var _cache := {}


## Soft thud with filtered noise. `heavy` = the entity's slower, lower step.
static func footstep(variant: int, heavy := false) -> AudioStreamWAV:
	return _cached("step_%d_%s" % [variant, heavy], func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + variant
		var length := int(RATE * (0.34 if heavy else 0.2))
		var out := PackedFloat32Array()
		out.resize(length)
		var smooth := 0.0
		var alpha := (0.05 if heavy else 0.12) + variant * 0.015
		var thud_hz := (48.0 if heavy else 70.0) + variant * 4.0
		for i in length:
			var t := float(i) / RATE
			smooth += (rng.randf_range(-1.0, 1.0) - smooth) * alpha
			var attack := 1.0 - exp(-t * 900.0)
			var body := smooth * exp(-t * (14.0 if heavy else 26.0)) * 2.2
			var thud := sin(TAU * thud_hz * t) * exp(-t * (18.0 if heavy else 34.0))
			out[i] = (body + thud) * attack * 0.9
		return _make(out))


## Loud distorted shriek used when the entity catches the player.
static func jumpscare() -> AudioStreamWAV:
	return _cached("jumpscare", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var duration := 1.7
		var length := int(RATE * duration)
		var out := PackedFloat32Array()
		out.resize(length)
		var phase := 0.0
		var phase_b := 0.0
		for i in length:
			var t := float(i) / RATE
			var hz := 520.0 + 1100.0 * (t / duration) + 140.0 * sin(TAU * 17.0 * t)
			phase += TAU * hz / RATE
			phase_b += TAU * hz * 1.51 / RATE
			var tone := sin(phase) + 0.6 * sin(phase_b) + 0.35 * sin(phase * 3.7)
			var raw := tanh(tone * 3.0) * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
			var envelope := minf(t / 0.004, 1.0) * (1.0 if t < 0.9 else exp(-(t - 0.9) * 4.0))
			out[i] = raw * envelope
		return _make(out))


## Low rumble with a dissonant swell, played when the entity starts hunting.
static func sting() -> AudioStreamWAV:
	return _cached("sting", func() -> AudioStreamWAV:
		var length := int(RATE * 1.6)
		var out := PackedFloat32Array()
		out.resize(length)
		for i in length:
			var t := float(i) / RATE
			var swell := sin(PI * minf(t / 1.6, 1.0))
			var rumble := sin(TAU * 52.0 * t) * 0.6 * exp(-t * 1.2)
			var dissonance := (sin(TAU * 466.0 * t) + sin(TAU * 494.0 * t)) * 0.18 * swell
			out[i] = rumble + dissonance
		return _make(out))


static func door_creak() -> AudioStreamWAV:
	return _cached("creak", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var length := int(RATE * 0.7)
		var out := PackedFloat32Array()
		out.resize(length)
		var phase := 0.0
		var wobble := 0.0
		for i in length:
			var t := float(i) / RATE
			wobble += (rng.randf_range(-1.0, 1.0) - wobble) * 0.002
			phase += TAU * (150.0 + 90.0 * (t / 0.7) + wobble * 400.0) / RATE
			var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
			out[i] = saw * 0.35 * sin(PI * t / 0.7) * (0.6 + 0.4 * sin(TAU * 23.0 * t))
		return _make(out))


static func knock() -> AudioStreamWAV:
	return _cached("knock", func() -> AudioStreamWAV:
		var length := int(RATE * 0.3)
		var out := PackedFloat32Array()
		out.resize(length)
		for i in length:
			var t := float(i) / RATE
			out[i] = sin(TAU * 110.0 * t) * exp(-t * 30.0) * 0.9
		return _make(out))


static func chime() -> AudioStreamWAV:
	return _cached("chime", func() -> AudioStreamWAV:
		var length := int(RATE * 0.9)
		var out := PackedFloat32Array()
		out.resize(length)
		for i in length:
			var t := float(i) / RATE
			out[i] = (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1320.0 * t)) * 0.3 * exp(-t * 4.5)
		return _make(out))


static func click() -> AudioStreamWAV:
	return _cached("click", func() -> AudioStreamWAV:
		var length := int(RATE * 0.05)
		var out := PackedFloat32Array()
		out.resize(length)
		for i in length:
			var t := float(i) / RATE
			out[i] = sin(TAU * 1800.0 * t) * exp(-t * 120.0) * 0.5
		return _make(out))


## Short shrill scream of a frightened student (used when the entity shows up near the crowd).
static func scream() -> AudioStreamWAV:
	return _cached("scream", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var duration := 0.7
		var length := int(RATE * duration)
		var out := PackedFloat32Array()
		out.resize(length)
		var phase := 0.0
		for i in length:
			var t := float(i) / RATE
			var hz := 900.0 + 700.0 * sin(PI * t / duration) + 60.0 * sin(TAU * 23.0 * t)
			phase += TAU * hz / RATE
			var tone := sin(phase) + 0.4 * sin(phase * 2.01)
			var envelope := minf(t / 0.01, 1.0) * exp(-t * 2.2)
			out[i] = (tanh(tone * 1.6) * 0.7 + rng.randf_range(-1.0, 1.0) * 0.12) * envelope * 0.6
		return _make(out))


## One short dog bark (Csoki).
static func bark() -> AudioStreamWAV:
	return _cached("bark", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		var length := int(RATE * 0.28)
		var out := PackedFloat32Array()
		out.resize(length)
		var phase := 0.0
		for i in length:
			var t := float(i) / RATE
			var hz := 420.0 - 230.0 * (t / 0.28)
			phase += TAU * hz / RATE
			var tone := sin(phase) + 0.5 * sin(phase * 2.0) + 0.25 * sin(phase * 3.0)
			var envelope := minf(t / 0.01, 1.0) * exp(-t * 11.0)
			out[i] = (tanh(tone * 1.4) * 0.65 + rng.randf_range(-1.0, 1.0) * 0.3 * exp(-t * 30.0)) * envelope
		return _make(out))


## A short ragged exhale (the player ran out of breath).
static func breath() -> AudioStreamWAV:
	return _cached("breath", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 55
		var length := int(RATE * 0.7)
		var out := PackedFloat32Array()
		out.resize(length)
		var smooth := 0.0
		for i in length:
			var t := float(i) / RATE
			smooth += (rng.randf_range(-1.0, 1.0) - smooth) * 0.18
			var envelope := sin(PI * minf(t / 0.7, 1.0))
			out[i] = smooth * envelope * 0.9
		return _make(out))


## Harsh descending stinger, `seconds` long (0.1 - 0.5). Cached per tenth of a second.
static func flash_sting(seconds: float) -> AudioStreamWAV:
	var tenths := clampi(roundi(seconds * 10.0), 1, 5)
	return _cached("flash_%d" % tenths, func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 91 + tenths
		var duration := tenths / 10.0
		var length := int(RATE * duration)
		var out := PackedFloat32Array()
		out.resize(length)
		var phase := 0.0
		for i in length:
			var t := float(i) / RATE
			var hz := 1500.0 - 1100.0 * (t / duration)
			phase += TAU * hz / RATE
			var tone := signf(sin(phase)) * 0.5 + sin(phase * 1.5) * 0.4
			var raw := tone * 0.7 + rng.randf_range(-1.0, 1.0) * 0.5
			var envelope := minf(t / 0.003, 1.0) * exp(-t * (2.5 / duration))
			out[i] = clampf(raw * envelope, -1.0, 1.0)
		return _make(out))


## Low double-thud heartbeat pulse when terrified or hiding.
static func heartbeat() -> AudioStreamWAV:
	return _cached("heartbeat", func() -> AudioStreamWAV:
		var duration := 0.7
		var length := int(RATE * duration)
		var out := PackedFloat32Array()
		out.resize(length)
		for i in length:
			var t := float(i) / RATE
			var lub := sin(TAU * 52.0 * t) * exp(-t * 22.0) if t < 0.25 else 0.0
			var t2 := t - 0.24
			var dub := sin(TAU * 44.0 * t2) * exp(-t2 * 24.0) * 0.85 if t2 >= 0.0 and t2 < 0.28 else 0.0
			out[i] = clampf((lub + dub) * 0.95, -1.0, 1.0)
		return _make(out))


## Metallic locker door opening or closing.
static func locker_door() -> AudioStreamWAV:
	return _cached("locker_door", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 44
		var duration := 0.4
		var length := int(RATE * duration)
		var out := PackedFloat32Array()
		out.resize(length)
		var smooth := 0.0
		for i in length:
			var t := float(i) / RATE
			smooth += (rng.randf_range(-1.0, 1.0) - smooth) * 0.15
			var metal := (sin(TAU * 380.0 * t) + 0.5 * sin(TAU * 720.0 * t) + 0.3 * sin(TAU * 1150.0 * t)) * exp(-t * 12.0)
			var scrape := smooth * exp(-t * 18.0) * 0.6
			out[i] = clampf((metal * 0.6 + scrape * 0.4) * 0.8, -1.0, 1.0)
		return _make(out))


## Two short chesty coughs.
static func cough() -> AudioStreamWAV:
	return _cached("cough", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var length := int(RATE * 0.7)
		var out := PackedFloat32Array()
		out.resize(length)
		var smooth := 0.0
		for i in length:
			var t := float(i) / RATE
			smooth += (rng.randf_range(-1.0, 1.0) - smooth) * 0.3
			var burst := exp(-pow((t - 0.08) * 22.0, 2.0)) + 0.8 * exp(-pow((t - 0.4) * 18.0, 2.0))
			out[i] = (smooth * 0.8 + sin(TAU * 140.0 * t) * 0.3) * burst * 0.8
		return _make(out))


## A deep blast with falling rumble, played when Lab 14 explodes.
static func explosion() -> AudioStreamWAV:
	return _cached("explosion", func() -> AudioStreamWAV:
		var rng := RandomNumberGenerator.new()
		rng.seed = 14
		var length := int(RATE * 3.0)
		var out := PackedFloat32Array()
		out.resize(length)
		var smooth := 0.0
		for i in length:
			var t := float(i) / RATE
			smooth += (rng.randf_range(-1.0, 1.0) - smooth) * 0.08
			var boom := sin(TAU * (70.0 - 30.0 * minf(t, 1.0)) * t) * exp(-t * 2.2)
			var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 14.0)
			var rumble := smooth * exp(-t * 1.4)
			out[i] = clampf((boom * 0.9 + crack * 0.7 + rumble * 1.4) * minf(t / 0.003, 1.0), -1.0, 1.0)
		return _make(out))


static func _cached(key: String, builder: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
