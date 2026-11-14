extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func _run() -> void:
	var village = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	root.add_child(village)
	await physics_frame
	for id in ["Kai", "Camille", "Corinne"]:
		var human = village.get_node(id).human
		check(human.model_loaded, id + " must load a generated anatomical model")
		if not human.model_loaded:
			continue
		check(human.skeleton.get_bone_count() >= 160, id + " full human rig")
		var has_shirt := false
		var has_trousers := false
		var has_shoes := false
		for mesh: MeshInstance3D in human.model.find_children("*", "MeshInstance3D", true, false):
			var title := mesh.name.to_lower()
			has_shirt = has_shirt or "loose woven shirt" in title
			has_trousers = has_trousers or "loose woven trousers" in title
			has_shoes = has_shoes or "closed leather shoe" in title
			check(not "backpack" in title and not "shoulder strap" in title, id + " backpacks must be removed")
			if title.begins_with("continuous anatomical skin") or "closed leather shoe" in title:
				var bottom := INF
				for surface in mesh.mesh.get_surface_count():
					for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						bottom = minf(bottom, vertex.y)
				if "skin" in title:
					check(bottom > 0.065 * human.height_m / 1.35, id + " enclosed foot skin must not show through shoes")
				else:
					check(bottom < 0, id + " closed soles must extend below the foot bottom")
		check(has_shirt and has_trousers and has_shoes, id + " separate cloth garments and closed footwear")
		for bone in ["spine01", "pelvis.L", "upperleg01.L", "lowerleg01.L", "wrist.R", "finger5-3.R", "toe5-3.L", "jaw"]:
			check(human.bone_ids.has(bone), id + " missing anatomical bone " + bone)
		check(human.eye_meshes.size() > 0, id + " fixed eye mesh")
		check(human.blink_shapes.size() == 18, id + " four eyelids and two margins, three absolute arc samples each")
		var eye_scales: Array[Vector3] = []
		for eye in human.eye_meshes:
			eye_scales.append(eye.scale)
		var blink_max := 0.0
		for i in 7200:
			human._update_blink(1.0 / 60.0)
			blink_max = maxf(blink_max, human.blink_amount)
			check(human.blink_amount >= 0 and human.blink_amount <= 1, id + " blink weight out of range")
		check(blink_max > 0.99 and human.blink_amount < 1, id + " blink cycle must close and reopen")
		for i in human.eye_meshes.size():
			check(human.eye_meshes[i].scale.is_equal_approx(eye_scales[i]), id + " eyes changed size after two minutes of blinking")
		var longest_error := 0.0
		for phase in [0.0, 0.2, 0.5, 0.7, 0.9]:
			human.stride = phase
			human.walk_blend = 1
			human.animate(0, 0.65, "wandering", false, null)
			for side in ["L", "R"]:
				var ankle: Vector3 = human._pose("foot." + side).origin
				var h: float = human.height_m / 1.35
				var expected_x: float = human._rest("upperleg01." + side).origin.x + (1.0 if side == "L" else -1.0) * 0.012 * h
				check(absf(ankle.x - expected_x) < 0.003, id + " ankle solve drifted laterally")
				for pair in [["upperleg01.", "lowerleg01."], ["lowerleg01.", "foot."]]:
					var a: String = pair[0] + side
					var b: String = pair[1] + side
					var rest_length: float = human._rest(a).origin.distance_to(human._rest(b).origin)
					var posed_length: float = human._pose(a).origin.distance_to(human._pose(b).origin)
					longest_error = maxf(longest_error, absf(rest_length - posed_length))
		check(longest_error < 0.0001, id + " leg bones must retain their fitted lengths")
		human.walk_blend = 0
		human.animate(0, 0, "looking around", false, null)
		for side in ["L", "R"]:
			var ankle: Vector3 = human._pose("foot." + side).origin
			check(absf(ankle.y - human.foot_rest[side].y) < 0.003, id + " standing feet must reach the floor")
		for side in ["L", "R"]:
			var hip: Vector3 = human._pose("upperleg01." + side).origin
			var knee: Vector3 = human._pose("lowerleg01." + side).origin
			var ankle: Vector3 = human._pose("foot." + side).origin
			var wrist: Vector3 = human._pose("wrist." + side).origin
			check(absf(knee.x - hip.x) < 0.015 and absf(ankle.x - hip.x) < 0.015, id + " standing legs must align under the hips")
			var line_z := lerpf(ankle.z, hip.z, (knee.y-ankle.y)/(hip.y-ankle.y))
			check(absf(knee.z-line_z)<0.025*human.height_m/1.35, id + " standing knees must not remain crouched")
			check(absf(wrist.x) > absf(hip.x) + 0.065 * human.height_m / 1.35, id + " hands must hang clear of the thighs")
		for i in human.skeleton.get_bone_count():
			check(human.skeleton.get_bone_pose(i).is_finite(), id + " nonfinite bone pose")
		print(id, ": ", human.skeleton.get_bone_count(), " bones; max limb length error ", longest_error, "; stable eye scale")
	print("Scavenger anatomy smoke: ", "PASS" if failures.is_empty() else "FAIL")
	village.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
