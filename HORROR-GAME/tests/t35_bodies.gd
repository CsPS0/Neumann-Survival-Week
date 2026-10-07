extends SceneTree
var fails := 0
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)

const Staff := preload("res://scripts/staff.gd")
const Lessons := preload("res://scripts/lessons.gd")
const TeacherScript := preload("res://scripts/teacher_npc.gd")

const NAMES := ["Menyhárt Erika", "Kaufmann Péter", "Dr Farkas József", "Kiss Renáta", "Varga Dávid", "Patik Kata",
		"Kárpáti Lajos", "Vörös Ildikó", "Dr. Szentgyörgyi Aranka", "Lázár Tivadar", "Mr. Bakó", "Caretaker"]

func _fresh() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile.path = "user://neu_test_%d.cfg" % Time.get_ticks_msec()
	await create_timer(1.5).timeout
	main._start_game()
	await create_timer(0.5).timeout
	return main

func _cleanup(main: Node) -> void:
	var p: String = main.profile.path
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	main.queue_free()
	await process_frame

func _meshes(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false)

## Name -> [head width, every mesh's colour in build order].
func _signature(main: Node) -> Dictionary:
	var out := {}
	for t in get_nodes_in_group("teachers"):
		if t.is_queued_for_deletion():
			continue
		var cols: Array = []
		for m: MeshInstance3D in _meshes(t):
			cols.append(m.material_override.albedo_color)
		out[t.npc_name] = [t.get_node("Rig/Head").scale, cols]
	return out

func _run() -> void:
	# Every named person has a body type.
	var everyone: Array = Staff.roster_names() + Lessons.TEACHER_NAMES.values() + ["Mr. Bakó", "Caretaker"]
	check(everyone.size() == 89, "89 named people")
	var counts := {"f": 0, "m": 0}
	for n: String in everyone:
		check(Staff.GENDER.has(n) and Staff.GENDER[n] in ["f", "m"], "gender tag for " + n)
		counts[Staff.gender_of(n)] += 1
	check(counts["f"] > 30 and counts["m"] > 30, "both body types common: %s" % str(counts))
	check(Staff.gender_of("Kiss Renáta") == "f" and Staff.gender_of("Varga Dávid") == "m", "sample genders")
	check(Staff.gender_of("Tabányiné Kovács Barbara") == "f" and Staff.gender_of("Nobody") == "m", "-né and default")
	# Staff data untouched (4-field rows).
	for p: Array in Staff.ROSTER:
		check(p.size() == 4, "roster row unchanged: " + str(p[0]))

	# Face parameters are stable.
	for n: String in NAMES:
		var a := TeacherScript.face_params(n, Staff.gender_of(n))
		var b := TeacherScript.face_params(n, Staff.gender_of(n))
		check(a == b, "stable face for " + n)
	check(TeacherScript.face_params(NAMES[0], "f") != TeacherScript.face_params(NAMES[1], "f"), "different names differ")
	var skins := {}
	var hairs := {}
	for id: String in Lessons.SUSPECT_IDS:
		var n: String = Lessons.TEACHER_NAMES[id]
		var f := TeacherScript.face_params(n, Staff.gender_of(n))
		skins[f["skin"]] = true
		hairs[f["hair"]] = true
	check(skins.size() >= 3, "3+ skin tones across suspects: %d" % skins.size())
	check(hairs.size() >= 3, "3+ hair colours across suspects: %d" % hairs.size())

	# Male and female bodies differ, same capsule, modest node count, shared materials.
	var holder := Node3D.new()
	root.add_child(holder)
	var bodies := {}
	for n: String in ["Kiss Renáta", "Varga Dávid", "Kiss Anikó", "Simon Tibor"]:
		var t: CharacterBody3D = TeacherScript.new()
		t.npc_name = n
		holder.add_child(t)
		bodies[n] = t
	await create_timer(0.3).timeout
	var f_t: Node = bodies["Kiss Renáta"]
	var m_t: Node = bodies["Varga Dávid"]
	check(f_t.gender == "f" and m_t.gender == "m", "gender resolved from the name")
	var f_w: float = (f_t.get_node("Rig/Torso").mesh as BoxMesh).size.x
	var m_w: float = (m_t.get_node("Rig/Torso").mesh as BoxMesh).size.x
	check(f_w < m_w and absf(f_w - 0.36) < 0.01, "female torso narrower: %.2f vs %.2f" % [f_w, m_w])
	check(f_t.get_node("Rig").scale.y < m_t.get_node("Rig").scale.y, "female rig shorter")
	check(not m_t.has_node("Rig/Skirt"), "no skirt on a man")
	for t: Node in [f_t, m_t]:
		var cap: CapsuleShape3D = (t.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D).shape
		check(is_equal_approx(cap.radius, 0.3) and is_equal_approx(cap.height, 1.75), "capsule unchanged on " + t.npc_name)
		check(_meshes(t).size() <= 40, "mesh count %d on %s" % [_meshes(t).size(), t.npc_name])
		check(t._arms.size() == 2 and t._legs.size() == 2, "arms and legs kept")
		check(t.prompt == "Talk to " + t.npc_name, "prompt text unchanged")
	var skirts := 0
	var women := 0
	for n: String in Staff.GENDER:
		if Staff.GENDER[n] == "f":
			women += 1
			if TeacherScript.face_params(n, "f")["skirt"]:
				skirts += 1
	check(skirts > women / 4 and skirts < women * 3 / 4, "about half the women wear a skirt: %d of %d" % [skirts, women])
	var mat_ids := {}
	var mat_count := 0
	for t: Node in bodies.values():
		for m: MeshInstance3D in _meshes(t):
			mat_ids[m.material_override.get_instance_id()] = true
			mat_count += 1
	check(mat_ids.size() < mat_count / 3, "materials shared: %d unique for %d meshes" % [mat_ids.size(), mat_count])
	m_t._animate(0.1, 1.5)
	f_t._animate(0.1, 1.5)
	check(absf(m_t._arms[0].rotation.x) > 0.0 and absf(f_t._legs[0].rotation.x) > 0.0, "limbs animate")
	holder.queue_free()

	# Two fresh scenes build the same suspects.
	var main: Node = await _fresh()
	var sig_a := _signature(main)
	check(sig_a.size() == 8, "8 suspects built: %d" % sig_a.size())
	check(main.porter.get_node("Rig/Head") != null and main.porter.gender == "m", "porter has a face")

	# Scare flash: hidden NPCs do not collide and get their own layer back.
	var scare: Node = main.scare
	main.campaign._resolved.fill(true)
	main.campaign._ended.fill(true)
	var odd: Node = get_nodes_in_group("teachers")[0]
	odd.collision_layer = 32 | 4
	check(scare.trigger(), "flash fires")
	await process_frame
	for t in get_nodes_in_group("teachers") + [main.csoki, main.porter]:
		check(t.collision_layer == 0, "no collision while hidden: " + t.npc_name)
	main.entity.sleep()
	await create_timer(2.5).timeout
	check(not scare.npcs_hidden, "NPCs returned")
	check(odd.collision_layer == 36, "custom layer restored: %d" % odd.collision_layer)
	check(main.csoki.collision_layer == 16 and main.porter.collision_layer == 32, "csoki 16 and porter 32 restored")
	for t in get_nodes_in_group("teachers"):
		if t != odd:
			check(t.collision_layer == 32, "teacher layer restored")
		check(not t.has_meta(&"flash_layer"), "meta cleared")
	await _cleanup(main)

	var main2: Node = await _fresh()
	var sig_b := _signature(main2)
	check(sig_a == sig_b, "same faces in a second fresh scene")
	await _cleanup(main2)
