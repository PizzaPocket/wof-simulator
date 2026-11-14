extends SceneTree
## Exercises the real village actor and captures the actual game, not a model viewer.
var failures: Array[String] = []
var world: Node3D
var moon: CharacterBody3D
var camera: Camera3D
var output := "res://../cache/moon-in-game"
var framing_scale := 1.0

func _initialize() -> void: run.call_deferred()
func ticks(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ", message)
func vec(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])
func tap(action: StringName) -> void:
	Input.action_press(action); await ticks(2); Input.action_release(action); await ticks(2)
func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(file + ".png"))
func frame_actor(offset: Vector3, target: Vector3, fov: float) -> void:
	camera.global_position = moon.global_position + offset * framing_scale
	camera.look_at(moon.global_position + target * framing_scale)
	camera.fov = fov

func nearest_skin_vertex(candidates: Array[Node], point: Vector3) -> Dictionary:
	var best := INF
	var result: Dictionary = {}
	for node in candidates:
		var mesh := node as MeshInstance3D
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var distance := vertices[i].distance_squared_to(point)
			if distance < best:
				best = distance
				result = {"mesh": mesh, "arrays": arrays, "index": i,"blends":mesh.mesh.surface_get_blend_shape_arrays(0)}
	return result

func skin_position(sample: Dictionary, rig: Skeleton3D) -> Vector3:
	var mesh: MeshInstance3D = sample.mesh
	var arrays: Array = sample.arrays
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride: int = bones.size() / points.size()
	var vertex:Vector3=points[sample.index]
	var blends:Array=sample.blends if sample.has("blends") else mesh.mesh.surface_get_blend_shape_arrays(0)
	for shape in mesh.mesh.get_blend_shape_count():
		var value:=mesh.get_blend_shape_value(shape)
		if absf(value)<.00001:continue
		var target:PackedVector3Array=blends[shape][Mesh.ARRAY_VERTEX]
		vertex+=(target[sample.index] if mesh.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE else target[sample.index]-points[sample.index])*value
	var position := Vector3.ZERO
	for i in stride:
		var slot: int = sample.index * stride + i
		if weights[slot] < .00001:continue
		var bind: int = bones[slot]
		var index := mesh.skin.get_bind_bone(bind)
		if index < 0:index = rig.find_bone(mesh.skin.get_bind_name(bind))
		position += (rig.get_bone_global_pose(index) * mesh.skin.get_bind_pose(bind) * vertex) * weights[slot]
	return position

func skin_reference(point: Vector3, weights: Array, rig: Skeleton3D) -> Vector3:
	var result := Vector3.ZERO
	for item in weights:
		var index := rig.find_bone(item[0])
		result += (rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse() * point) * float(item[1])
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	world = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	world.roster_save_path = ""
	root.add_child(world)
	await ticks(10)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1400, 900)
	moon = world.get_node("Moon")
	framing_scale = moon.visual.model_scale / 1.1
	var clay = world.get_node("Clay")
	var roster = world.get_node("Protagonists")
	clay.position = moon.position + Vector3(0, 0.1, 3)
	clay.velocity = Vector3.ZERO
	await ticks(8)
	await tap(&"possess_protagonist")
	check(world.player == moon, "X possesses the real Moon village actor")
	var motion = moon.visual.motion
	var rig: Skeleton3D = motion.skeleton
	check(motion.wing_rigs.size() == 2, "Moon has two articulated NightWing wings")
	check(motion.folds.is_empty(), "Moon wings no longer use vertex-compression fold shapes")
	check(motion.anatomy.get("wing_rest_style", "") == "raised_fan", "Moon uses the raised resting wing fan")
	check(motion.staged_eyelids.size() == 2, "Both fitted upper lids have staged blink shapes")
	check(rig.find_children("SilverTearScale*", "MeshInstance3D", true, false).size() == 2, "Both silver tear scales are present")
	check(rig.find_children("Moon fitted nasal cap*", "MeshInstance3D", true, false).size() == 1, "The nasal cap is a fitted anatomical part")
	check(rig.find_children("Moon recessed nostril cavity*", "MeshInstance3D", true, false).size() == 2, "Two recessed nostril cavities are present")
	check(rig.find_children("Moon lower dental arcade*", "MeshInstance3D", true, false).size() == 1, "The lower jaw carries a complete dental arcade")
	check(world.has_node("Darkstalker") and not roster.protagonists.has("darkstalker"), "Darkstalker is a scene resident outside the collectible roster")
	var seam_samples: Array[Array] = []
	var arm_samples: Array[Dictionary] = []
	var membranes := rig.find_children("NightWingMembrane*", "MeshInstance3D", true, false)
	var webs := rig.find_children("Moon continuous axillary membrane*", "MeshInstance3D", true, false)
	check(rig.find_children("Moon arm patagium*", "MeshInstance3D", true, false).is_empty(), "No leading-side shoulder/wrist triangle")
	for design in motion.anatomy.wing_rig.values():
		var digit: Dictionary = design.digits[-1]
		for step in [0, 9, 24, 36, 45]:
			var t := float(step) / 45.0
			var point := vec(design.wrist).lerp(vec(digit.middle), t / .53) if t <= .53 else vec(digit.middle).lerp(vec(digit.tip), (t-.53)/.47)
			seam_samples.append([nearest_skin_vertex(membranes,point),nearest_skin_vertex(webs,point)])
		for step in [1,5,11,17,21]:
			var attachment: Dictionary = design.arm_attachment[step]
			check(vec(attachment.point).z<=vec(attachment.axis_point).z+.00001,"Membrane attachment is behind the anatomical wing-arm axis")
			arm_samples.append({"sample":nearest_skin_vertex(webs,vec(attachment.point)),"attachment":attachment})
	var folded_width := 0.0
	var spread_width := 0.0
	for amount in [0.0, 0.25, 0.5, 0.75, 1.0]:
		rig.reset_bone_poses()
		motion.fold_amount = amount
		motion.apply_wings()
		for sample in arm_samples:
			var attachment: Dictionary=sample.attachment
			var expected:=skin_reference(vec(attachment.point),attachment.weights,rig)
			var axis_point:=skin_reference(vec(attachment.axis_point),attachment.weights,rig)
			check(skin_position(sample.sample,rig).distance_to(expected)<.001,"Membrane follows the trailing articulated arm edge at fold %.2f"%amount)
			check(expected.distance_to(axis_point)<.065,"Trailing attachment stays embedded in wing-arm tissue")
		for pair in seam_samples:
			check(skin_position(pair[0],rig).distance_to(skin_position(pair[1],rig)) < .001, "Exported membrane boundaries stay sealed at fold %.2f" % amount)
		for design in motion.anatomy.wing_rig.values():
			var upper := rig.find_bone(design.root_bone)
			var fore := rig.find_bone(design.elbow_bone)
			var a := rig.get_bone_global_pose(upper).origin
			var b := rig.get_bone_global_pose(fore).origin
			check(absf(a.distance_to(b) - vec(design.root).distance_to(vec(design.elbow))) < 0.001, "Wing humerus length stays fixed at fold %.2f" % amount)
			if amount == 1.0:
				var wrist := rig.get_bone_global_pose(rig.find_bone(design.digits[0].first)).origin
				check(wrist.y > 2.3, "Resting wing arm holds the wrist above the head/back line")
				var inner: Dictionary = design.digits[-1]
				var outer: Dictionary = design.digits[0]
				var inner_index := rig.find_bone(inner.second)
				var outer_index := rig.find_bone(outer.second)
				var inner_tip := rig.get_bone_global_pose(inner_index) * (rig.get_bone_global_rest(inner_index).affine_inverse() * vec(inner.tip))
				var outer_tip := rig.get_bone_global_pose(outer_index) * (rig.get_bone_global_rest(outer_index).affine_inverse() * vec(outer.tip))
				var second_digit: Dictionary = design.digits[1]
				var second_index := rig.find_bone(second_digit.second)
				var second_tip := rig.get_bone_global_pose(second_index) * (rig.get_bone_global_rest(second_index).affine_inverse() * vec(second_digit.tip))
				check(outer_tip.y < second_tip.y - .08, "Pointer ray sits below the second ray in the folded arc")
				check(absf(outer_tip.x) > absf(inner_tip.x) + 0.25, "Folded fan keeps the body-side finger inward and the outer flight finger outward")
			for digit in design.digits:
				var first := rig.find_bone(digit.first)
				var second := rig.find_bone(digit.second)
				var origin := rig.get_bone_global_pose(first).origin
				var middle := rig.get_bone_global_pose(second).origin
				var tip := rig.get_bone_global_pose(second) * (rig.get_bone_global_rest(second).affine_inverse() * vec(digit.tip))
				check(absf(origin.distance_to(middle) - vec(design.wrist).distance_to(vec(digit.middle))) < 0.001, "Wing digit proximal length stays fixed")
				check(absf(middle.distance_to(tip) - vec(digit.middle).distance_to(vec(digit.tip))) < 0.001, "Wing digit distal length stays fixed")
				if amount == 0.0: spread_width = maxf(spread_width, absf(tip.x))
				if amount == 1.0: folded_width = maxf(folded_width, absf(tip.x))
	check(folded_width < spread_width * 0.45, "Fold stows the fixed-length supports beside the body (%.2f vs %.2f)" % [folded_width, spread_width])
	var path_x: float = world._path_x(-50)
	moon.position = Vector3(path_x, world._height(path_x, -50) + 0.12, -50)
	moon.velocity = Vector3.ZERO
	moon._set_state(&"grounded")
	moon.pivot.rotation = Vector3.ZERO
	moon.visual.rotation = Vector3.ZERO
	await ticks(8)
	var start := moon.position
	Input.action_press("move_forward")
	await ticks(35)
	Input.action_release("move_forward")
	check(moon.position.distance_to(start) > 0.6, "Moon walks using her in-game body")
	await ticks(30)
	Input.action_press("fire_breath")
	await ticks(28)
	check(motion.fire.active and motion.fire.jaw_angle > 0.68, "Moon's fitted jaw opens and fire emits from her muzzle")
	Input.action_release("fire_breath")
	await ticks(20)
	check(motion.fire.jaw_angle < 0.01, "Moon's jaw returns to its resting bite")
	motion.reset_motion()
	check(absf(motion.model.position.y+float(motion.anatomy.ground_plant_model)*moon.visual.model_scale)<.015,"Resting skin is grounded without the previous visual hover")
	# Real village scene, paused actor for repeatable screenshots.
	moon.set_physics_process(false)
	motion.enabled = false
	rig.reset_bone_poses()
	motion.fold_amount = 1.0
	motion.apply_wings()
	camera = roster.camera
	camera.reparent(world, true)
	camera.h_offset = 0
	frame_actor(Vector3(7.4, 3.8, -7.4), Vector3(0, 1.35, 0), 48)
	await capture("moon-grounded")
	frame_actor(Vector3(8, 3.5, 0.4), Vector3(0, 1.35, 0), 50)
	await capture("moon-side")
	frame_actor(Vector3(1.45, 2.25, -3.25), Vector3(0, 2.05, -1.75), 40)
	await capture("moon-face")
	frame_actor(Vector3(0, 2.18, -4.5), Vector3(0, 2.05, -1.75), 34)
	await capture("moon-front")
	frame_actor(Vector3(0, 4.65, -1.8), Vector3(0, 2.0, -1.75), 35)
	await capture("moon-top")
	motion.fold_amount = .5
	rig.reset_bone_poses()
	motion.apply_wings()
	frame_actor(Vector3(7.4,3.8,-7.4),Vector3(0,1.35,0),48)
	await capture("moon-half-fold")
	motion.fold_amount = 1.0
	rig.reset_bone_poses()
	motion.apply_wings()
	frame_actor(Vector3(2.2, 2.20, -1.65), Vector3(0, 2.04, -1.58), 34)
	await capture("moon-eye-rest")
	for entry in motion.staged_eyelids:
		entry.mesh.set_blend_shape_value(entry.keys[1], 1.0)
	await capture("moon-eye-partial")
	for entry in motion.staged_eyelids:
		entry.mesh.set_blend_shape_value(entry.keys[1], 0.0)
		entry.mesh.set_blend_shape_value(entry.keys[2], 1.0)
	await capture("moon-eye-closed")
	for entry in motion.staged_eyelids:
		entry.mesh.set_blend_shape_value(entry.keys[2], 0.0)
	motion.fire.jaw_angle = 0.58
	motion.fire._apply_mouth()
	frame_actor(Vector3(1.45, 2.25, -3.25), Vector3(0, 1.98, -1.75), 36)
	await capture("moon-mouth-open")
	motion.fire.jaw_angle = 0.0
	motion.fire._apply_mouth()
	motion.fold_amount = 0.0
	rig.reset_bone_poses()
	motion.apply_wings()
	frame_actor(Vector3(7.5, 4, -8), Vector3(0, 1.4, 0), 52)
	await capture("moon-wings")
	moon.set_physics_process(true)
	motion.enabled = true
	motion.reset_motion()
	motion.fold_target = 1.0
	Input.action_press("move_forward")
	await ticks(45)
	frame_actor(Vector3(8,3.5,.4),Vector3(0,1.35,0),50)
	await capture("moon-walk")
	Input.action_press("sprint")
	await ticks(100)
	frame_actor(Vector3(8,3.5,.4),Vector3(0,1.35,0),50)
	await capture("moon-run")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await ticks(30)
	moon.position = Vector3(path_x,world._height(path_x,-50)+.12,-50)
	moon.velocity = Vector3.ZERO
	motion.reset_motion()
	moon.position.y += 20
	moon.velocity = Vector3.ZERO
	moon._set_state(&"airborne")
	await ticks(2)
	await tap(&"jump")
	await ticks(15)
	check(moon.locomotion_state == &"flying", "Moon can enter actual player flight")
	frame_actor(Vector3(7.5, 4, -8), Vector3(0, 1.4, 0), 52)
	await capture("moon-flight")
	print("Moon full game pass: ", "PASS" if failures.is_empty() else "FAIL")
	if failures.is_empty() and "--keep-playing" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		moon.position = Vector3(path_x, world._height(path_x, -50) + 0.12, -50)
		moon.velocity = Vector3.ZERO
		moon._set_state(&"grounded")
		moon.pivot.rotation = Vector3.ZERO
		moon.visual.rotation = Vector3.ZERO
		motion.reset_motion()
		camera.reparent(moon.arm, false)
		camera.position = Vector3.BACK * moon.default_camera_distance
		camera.rotation = Vector3.ZERO
		camera.fov = 75
		camera.make_current()
		camera.reset_physics_interpolation()
		print("Actual village ready: Moon controlled; collection save left untouched.")
		return
	quit(0 if failures.is_empty() else 1)
