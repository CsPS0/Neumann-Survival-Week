extends SceneTree
## Final review probe: every 0.9 m table (clue/find/item/form/red/note) must not overlap any other collider.
var fails := 0
func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)
func _initialize() -> void:
	await _run()
	print("PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(fails)
func _run() -> void:
	for run in 6:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.profile.path = "user://neu_test_overlap_%d.cfg" % Time.get_ticks_msec()
		await create_timer(1.5).timeout
		var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		var tables := 0
		for body in main._region.get_children():
			if not (body is StaticBody3D):
				continue
			var shape_node: CollisionShape3D = null
			for c in body.get_children():
				if c is CollisionShape3D:
					shape_node = c
			if shape_node == null or not (shape_node.shape is BoxShape3D):
				continue
			if not (shape_node.shape as BoxShape3D).size.is_equal_approx(Vector3(0.9, 0.75, 0.9)):
				continue
			tables += 1
			var q := PhysicsShapeQueryParameters3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(0.85, 0.6, 0.85)
			q.shape = b
			q.transform = Transform3D(Basis(), body.global_position)
			q.collision_mask = 1 | 8
			q.exclude = [body.get_rid()]
			var hits := space.intersect_shape(q, 8)
			for h in hits:
				var other: Object = h["collider"]
				check(false, "run %d table at %s overlaps %s" % [run, body.global_position, other])
		var spots: Array = main._find_spots.values() + main._item_spots.values() + main._clue_spots + [main._form_spot]
		print("run %d tables=%d form=%d:%s red=%s" % [run, tables, main._form_room_floor, main._form_room_label, main.quest.red_room_label])
		var p: String = main.profile.path
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		main.queue_free()
		await create_timer(0.2).timeout
