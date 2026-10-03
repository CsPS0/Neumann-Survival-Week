extends RefCounted
## Procedurally generated, tileable PBR-ish materials (no image files needed). All use world-space
## triplanar mapping, so boxes of any size get correctly scaled textures. Swap any of these for
## real CC0 textures by returning a material with your own albedo/normal textures.

const SIZE := 256

static var _cache := {}


## Cream plaster above a teal painted dado. Tile = 4 m, so the dado lines up on every floor.
static func wall() -> StandardMaterial3D:
	return _cached("wall", func() -> StandardMaterial3D:
		var noise := _noise(0.03, 11).get_seamless_image(SIZE, SIZE)
		var fine := _noise(0.25, 12).get_seamless_image(SIZE, SIZE)
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var bump := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
		for y in SIZE:
			var height_m := (1.0 - float(y) / SIZE) * 4.0
			for x in SIZE:
				var base := Color(0.8, 0.76, 0.64)
				if height_m < 1.15:
					base = Color(0.2, 0.34, 0.3)
				elif height_m < 1.25:
					base = Color(0.1, 0.1, 0.1)
				var grime := noise.get_pixel(x, y).r
				var speck := fine.get_pixel(x, y).r
				var shade := 0.88 + grime * 0.16 + (speck - 0.5) * 0.08
				shade *= 0.8 + 0.2 * smoothstep(0.0, 1.5, height_m)  # Dirtier near the floor.
				img.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade))
				bump.set_pixel(x, y, Color(speck, speck, speck))
		return _material(img, bump, 0.25, 0.6, 0.9))


## Square tiles with grout and per-tile variation. Tile = 2 m (4x4 tiles of 0.5 m).
static func floor_tiles() -> StandardMaterial3D:
	return _cached("floor", func() -> StandardMaterial3D:
		var noise := _noise(0.08, 21).get_seamless_image(SIZE, SIZE)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var tone := []
		for i in 16:
			tone.append(rng.randf_range(0.85, 1.15))
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var bump := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
		for y in SIZE:
			for x in SIZE:
				var tile_x := x / 64
				var tile_y := y / 64
				var grout := (x % 64) < 2 or (y % 64) < 2
				var base := Color(0.5, 0.52, 0.5) if (tile_x + tile_y) % 2 == 0 else Color(0.36, 0.4, 0.38)
				var shade: float = tone[tile_y * 4 + tile_x] * (0.8 + noise.get_pixel(x, y).r * 0.35)
				var colour := Color(0.12, 0.12, 0.11) if grout else Color(base.r * shade, base.g * shade, base.b * shade)
				img.set_pixel(x, y, colour)
				var h := 0.1 if grout else 0.7 + noise.get_pixel(x, y).r * 0.2
				bump.set_pixel(x, y, Color(h, h, h))
		return _material(img, bump, 0.5, 0.35, 1.0))


## Acoustic ceiling tiles, 0.6 m grid. Tile = 2.4 m.
static func ceiling() -> StandardMaterial3D:
	return _cached("ceiling", func() -> StandardMaterial3D:
		var noise := _noise(0.4, 31).get_seamless_image(SIZE, SIZE)
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for y in SIZE:
			for x in SIZE:
				var line := (x % 64) < 2 or (y % 64) < 2
				var v := 0.28 + noise.get_pixel(x, y).r * 0.12
				var colour := Color(0.1, 0.1, 0.1) if line else Color(v, v, v * 0.97)
				img.set_pixel(x, y, colour)
		return _material(img, null, 1.0 / 2.4, 0.0, 1.0))


## Door wood with vertical grain. Tile = 1 m.
static func wood(tint := Color.WHITE) -> StandardMaterial3D:
	return _cached("wood_%s" % tint.to_html(), func() -> StandardMaterial3D:
		var grain := _noise(0.02, 41)
		grain.fractal_octaves = 3
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var seamless := grain.get_seamless_image(SIZE, SIZE)
		for y in SIZE:
			for x in SIZE:
				var stripe := seamless.get_pixel((x * 6) % SIZE, y / 4).r
				var v := 0.55 + stripe * 0.6
				img.set_pixel(x, y, Color(0.34 * v, 0.2 * v, 0.1 * v) * tint)
		var mat := _material(img, null, 1.0, 0.0, 0.7)
		return mat)


## Rough concrete for the stairs. Tile = 2 m.
static func concrete() -> StandardMaterial3D:
	return _cached("concrete", func() -> StandardMaterial3D:
		var noise := _noise(0.12, 51).get_seamless_image(SIZE, SIZE)
		var fine := _noise(0.6, 52).get_seamless_image(SIZE, SIZE)
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for y in SIZE:
			for x in SIZE:
				var v := 0.34 + noise.get_pixel(x, y).r * 0.15 + (fine.get_pixel(x, y).r - 0.5) * 0.08
				img.set_pixel(x, y, Color(v, v, v * 1.03))
		return _material(img, fine, 0.5, 0.0, 0.95))


static func _noise(frequency: float, seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.seed = seed_value
	return noise


static func _material(albedo: Image, bump: Image, uv_scale: float, normal_strength: float, roughness: float) -> StandardMaterial3D:
	albedo.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(albedo)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * uv_scale
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if bump != null and normal_strength > 0.0:
		bump.bump_map_to_normal_map(8.0)
		bump.generate_mipmaps(true)
		mat.normal_enabled = true
		mat.normal_texture = ImageTexture.create_from_image(bump)
		mat.normal_scale = normal_strength
	return mat


static func _cached(key: String, builder: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]
