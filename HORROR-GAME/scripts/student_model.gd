extends RefCounted
## Student model for the crowd: one low-poly mesh (body, clothes, head and hair, about 1.7 m tall, feet at the origin,
## facing -Z) and a shader that animates it on the GPU, so 150 students cost one draw call.
## Per-instance custom data (MultiMesh): x = look seed (+2 when ill), y = 1 when seated, z = walk phase, w = walk speed.
## Part ids go in UV2.x so the shader knows which vertices to move and colour.

const TORSO := 0      ## Shirt (the instance colour).
const UPPER_ARM := 1  ## Shirt.
const FOREARM := 2    ## Skin.
const THIGH := 3      ## Trousers.
const SHIN := 4       ## Trousers.
const SHOE := 5
const NECK := 6       ## Skin (neck, head, nose).
const HAIR := 7
const EYE := 8
const LONG_HAIR := 9  ## Hidden for short-haired looks.

const HIP_Y := 0.92
const KNEE_Y := 0.46

const SHADER := """
shader_type spatial;
render_mode cull_back;

varying vec3 tint;

const vec3 SKIN[6] = vec3[](vec3(0.96, 0.8, 0.69), vec3(0.92, 0.74, 0.62), vec3(0.86, 0.68, 0.56),
		vec3(0.78, 0.6, 0.48), vec3(0.66, 0.48, 0.36), vec3(0.5, 0.35, 0.25));
const vec3 HAIR[7] = vec3[](vec3(0.07, 0.06, 0.05), vec3(0.2, 0.13, 0.08), vec3(0.38, 0.25, 0.14),
		vec3(0.75, 0.62, 0.38), vec3(0.45, 0.18, 0.09), vec3(0.6, 0.6, 0.58), vec3(0.1, 0.08, 0.07));
const vec3 TROUSERS[4] = vec3[](vec3(0.12, 0.12, 0.16), vec3(0.2, 0.18, 0.15), vec3(0.1, 0.13, 0.2), vec3(0.28, 0.3, 0.34));

float hash11(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

vec3 rot_x(vec3 v, vec3 pivot, float a) {
	vec3 d = v - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(d.x, d.y * c - d.z * s, d.y * s + d.z * c);
}

vec3 rot_x_dir(vec3 n, float a) {
	return rot_x(n, vec3(0.0), a);
}

void vertex() {
	float part = floor(UV2.x + 0.5);
	float sick = step(2.0, INSTANCE_CUSTOM.x);
	float look = fract(INSTANCE_CUSTOM.x);
	float seated = INSTANCE_CUSTOM.y;
	float speed = INSTANCE_CUSTOM.w;
	float amp = clamp(speed / 1.5, 0.0, 1.3) * (1.0 - seated);
	float p = TIME * speed * 3.2 + INSTANCE_CUSTOM.z;
	float side = VERTEX.x < 0.0 ? -1.0 : 1.0;
	float lead = side < 0.0 ? 0.0 : 3.14159;
	vec3 hip = vec3(side * 0.085, 0.92, 0.0);
	vec3 knee = vec3(side * 0.085, 0.46, 0.0);
	vec3 shoulder = vec3(side * 0.235, 1.44, 0.0);
	vec3 elbow = vec3(side * 0.235, 1.14, 0.0);
	vec3 pos = VERTEX;
	vec3 nrm = NORMAL;

	float thigh = mix(sin(p + lead) * 0.5 * amp, 1.45, seated);
	float shin = mix(-max(cos(p + lead), 0.0) * 0.6 * amp, -1.45, seated);
	if (part == 4.0 || part == 5.0) {
		pos = rot_x(pos, knee, shin);
		nrm = rot_x_dir(nrm, shin);
	}
	if (part >= 3.0 && part <= 5.0) {
		pos = rot_x(pos, hip, thigh);
		nrm = rot_x_dir(nrm, thigh);
	}

	float arm = mix(-sin(p + lead) * 0.45 * amp, 0.75, seated);
	if (part == 2.0) {
		float bend = 0.15 + 0.9 * seated;
		pos = rot_x(pos, elbow, bend);
		nrm = rot_x_dir(nrm, bend);
	}
	if (part == 1.0 || part == 2.0) {
		pos = rot_x(pos, shoulder, arm);
		nrm = rot_x_dir(nrm, arm);
	}

	if (part == 9.0 && look < 0.45) {
		pos = vec3(0.0, 1.5, 0.0);   // Short hair: the long back piece collapses.
	}

	if (part < 3.0 || part >= 6.0) {
		float lean = -(0.1 * seated + 0.35 * sick * (0.5 + 0.5 * seated));
		vec3 hip_centre = vec3(0.0, 0.92, 0.0);
		pos = rot_x(pos, hip_centre, lean);
		nrm = rot_x_dir(nrm, lean);
		if (part >= 6.0 && sick > 0.5) {
			vec3 neck = vec3(0.0, 1.5, 0.0);
			pos = rot_x(pos, neck, -0.35 * (0.4 + seated));   // Head hangs.
		}
		pos.y += cos(p * 2.0) * 0.012 * amp;
	}
	VERTEX = pos;
	NORMAL = nrm;

	vec3 skin = SKIN[int(hash11(look * 3.0) * 5.99)];
	if (sick > 0.5) {
		skin = mix(skin, vec3(0.6, 0.75, 0.52), 0.45);
	}
	if (part < 2.0) {
		tint = COLOR.rgb;
	} else if (part == 2.0 || part == 6.0) {
		tint = skin;
	} else if (part == 3.0 || part == 4.0) {
		tint = TROUSERS[int(hash11(look * 5.0) * 3.99)];
	} else if (part == 5.0) {
		tint = vec3(0.07, 0.06, 0.06);
	} else if (part == 8.0) {
		tint = vec3(0.05, 0.04, 0.04);
	} else {
		tint = HAIR[int(hash11(look * 7.0) * 6.99)];
	}
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
"""

static var _body: ArrayMesh
static var _material: ShaderMaterial


static func mesh() -> ArrayMesh:
	if _body == null:
		_body = _build()
	return _body


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


static func _build() -> ArrayMesh:
	var acc := {"v": [], "n": [], "u": [], "i": []}   # Plain arrays: packed ones are copied out of a dictionary.
	for side in [-1.0, 1.0]:
		_add(acc, _cylinder(0.08, 0.062, 0.46), Vector3(0.085 * side, 0.69, 0.0), Vector3.ONE, THIGH)
		_add(acc, _cylinder(0.058, 0.045, 0.46), Vector3(0.085 * side, 0.23, 0.0), Vector3.ONE, SHIN)
		_add(acc, _box(Vector3(0.095, 0.07, 0.27)), Vector3(0.085 * side, 0.035, -0.05), Vector3.ONE, SHOE)
		_add(acc, _cylinder(0.045, 0.038, 0.3), Vector3(0.235 * side, 1.29, 0.0), Vector3.ONE, UPPER_ARM)
		_add(acc, _cylinder(0.037, 0.03, 0.27), Vector3(0.235 * side, 1.005, 0.0), Vector3.ONE, FOREARM)
		_add(acc, _sphere(0.036), Vector3(0.235 * side, 0.85, 0.0), Vector3(0.9, 1.15, 0.7), FOREARM)
		_add(acc, _sphere(0.058), Vector3(0.222 * side, 1.43, 0.0), Vector3.ONE, UPPER_ARM)
		_add(acc, _sphere(0.014), Vector3(0.04 * side, 1.69, -0.1), Vector3.ONE, EYE)
	_add(acc, _box(Vector3(0.28, 0.18, 0.19)), Vector3(0.0, 0.92, 0.0), Vector3.ONE, TORSO)
	_add(acc, _box(Vector3(0.3, 0.22, 0.19)), Vector3(0.0, 1.03, 0.0), Vector3.ONE, TORSO)
	_add(acc, _box(Vector3(0.38, 0.36, 0.21)), Vector3(0.0, 1.29, 0.0), Vector3.ONE, TORSO)
	_add(acc, _cylinder(0.05, 0.05, 0.1), Vector3(0.0, 1.52, 0.0), Vector3.ONE, NECK)
	_add(acc, _sphere(0.11), Vector3(0.0, 1.67, 0.0), Vector3(1.0, 1.14, 1.02), NECK)
	_add(acc, _box(Vector3(0.022, 0.045, 0.03)), Vector3(0.0, 1.66, -0.113), Vector3.ONE, NECK)
	_add(acc, _sphere(0.118), Vector3(0.0, 1.715, 0.024), Vector3(1.04, 0.74, 1.0), HAIR)
	_add(acc, _box(Vector3(0.22, 0.3, 0.06)), Vector3(0.0, 1.58, 0.09), Vector3.ONE, LONG_HAIR)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(acc["v"])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(acc["n"])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(acc["u"])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(acc["i"])
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


static func _add(acc: Dictionary, source: Mesh, centre: Vector3, scale: Vector3, part: int) -> void:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base: int = acc["v"].size()
	for i in verts.size():
		acc["v"].append(verts[i] * scale + centre)
		acc["n"].append((normals[i] / scale).normalized())
		acc["u"].append(Vector2(part, 0.0))
	for index in indices:
		acc["i"].append(index + base)


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 8
	m.rings = 1
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 10
	m.rings = 6
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
