extends RefCounted
## Stand-in for the gitignored scripts/student_faces_local.gd (see scripts/student_faces_source.gd). Every name here is
## invented. Same shape as the real file: name, the look seed and shirt colour of the body (student_model.gd), and a
## texture path per expression ("neutral", "smile", "sad"). Without a texture path the face is drawn at runtime.

const STUDENTS := [
	{"name": "Pap Levente", "look": 0.8, "shirt": Color(0.78, 0.74, 0.66), "skin": Color(0.9, 0.75, 0.66), "hair": Color(0.42, 0.3, 0.2), "faces": {}},
	{"name": "Vass Eszter", "look": 0.045, "shirt": Color(0.58, 0.7, 0.54), "skin": Color(0.94, 0.8, 0.72), "hair": Color(0.88, 0.7, 0.58), "faces": {}},
]

const SIZE := 128

static var _cache := {}


## A flat oval face with eyes and a mouth for `state`, so the roster works with no photo files.
static func texture(state: String, tone: Color) -> Texture2D:
	var key := "%s|%s" % [state, tone.to_html()]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var mid := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := Vector2((x - mid) / (mid * 0.82), (y - mid) / (mid * 0.95)).length()
			image.set_pixel(x, y, Color(tone, clampf((1.0 - d) * 8.0, 0.0, 1.0)))
	var ink := Color(0.12, 0.08, 0.07)
	for side in [-1.0, 1.0]:
		_disc(image, Vector2(mid + side * 22.0, mid - 12.0), 5.0, ink)
	for i in range(-22, 23):
		var t := i / 22.0
		var curve := 0.0
		if state == "smile":
			curve = 8.0 * (1.0 - t * t)
		elif state == "sad":
			curve = -8.0 * (1.0 - t * t)
		_disc(image, Vector2(mid + i, mid + 32.0 + curve), 2.0, ink)
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result


static func _disc(image: Image, centre: Vector2, radius: float, colour: Color) -> void:
	for y in range(int(centre.y - radius), int(centre.y + radius) + 1):
		for x in range(int(centre.x - radius), int(centre.x + radius) + 1):
			if x >= 0 and y >= 0 and x < SIZE and y < SIZE and Vector2(x, y).distance_to(centre) <= radius:
				image.set_pixel(x, y, colour)
