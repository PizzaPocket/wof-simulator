extends SceneTree
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var camera: Camera3D
var output: String

func _initialize() -> void:
	_run.call_deferred()

func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _view(center: Vector3, offset: Vector3, size: float) -> void:
	camera.size = size
	var target: Vector3 = motion.skeleton.to_global(center)
	camera.global_position = target + motion.skeleton.global_basis * offset
	camera.look_at(target)

func _clay(enabled: bool) -> void:
	for mesh in motion.meshes:
		preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, enabled)

func _bone_point(point: Array, weights: Dictionary) -> Vector3:
	var value := Vector3(point[0], point[1], point[2])
	var result := Vector3.ZERO
	for name in weights:
		var index: int = motion.skeleton.find_bone(name)
		if index < 0:
			index = motion.skeleton.find_bone(name + ".L")
		var deformation: Transform3D = motion.skeleton.get_bone_global_pose(index) * motion.skeleton.get_bone_global_rest(index).affine_inverse()
		result += (deformation * value) * float(weights[name])
	return motion.skeleton.to_global(result)

func _wrist_bone_overlay() -> MeshInstance3D:
	var lines := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = Color("34e5da")
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for bone in motion.anatomy.get("limb_bones", []):
		if not bone.name in ["radius", "ulna", "wrist"]:
			continue
		var from_weights: Dictionary = bone.rig
		var to_weights: Dictionary = bone.rig
		if bone.has("rig_path"):
			from_weights = {bone.rig_path[0][1]: 1.0}
			to_weights = {bone.rig_path[-1][1]: 1.0}
		lines.surface_add_vertex(_bone_point(bone.from, from_weights))
		lines.surface_add_vertex(_bone_point(bone.to, to_weights))
	lines.surface_end()
	var overlay := MeshInstance3D.new()
	overlay.mesh = lines
	root.add_child(overlay)
	return overlay

func _jump() -> void:
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")

func _run() -> void:
	# Keep hardware input from changing an automated review on a live desktop.
	# Synthetic action presses below still work in this isolated process.
	for action in InputMap.get_actions():
		Input.action_release(action)
		InputMap.action_erase_events(action)
	var tag := "after"
	if not OS.get_cmdline_user_args().is_empty():
		tag = OS.get_cmdline_user_args()[0]
	output = ProjectSettings.globalize_path("res://../cache/legs-review-" + tag)
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	scene.hud.hide()
	motion.fold_target = 0.0
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var fill := OmniLight3D.new()
	camera.add_child(fill)
	fill.omni_range = 14
	fill.light_energy = 1.0
	await _ticks(120)
	for kind in ["front", "hind"]:
		var center := Vector3(0.4, 0.68, 0.52) if kind == "front" else Vector3(0.45, 0.58, -0.64)
		for angle in ["side", "oblique"]:
			var offset := Vector3(2, 0.1, 0) if angle == "side" else Vector3(1.6, 0.5, 1.3)
			_view(center, offset, 3.4)
			await _capture(kind + "-" + angle + "-painted")
			_clay(true)
			await _capture(kind + "-" + angle + "-clay")
			_clay(false)
	for fold in [1.0, 0.5, 0.0]:
		motion.fold_target = fold
		await _ticks(100)
		_view(Vector3(0.25, 1.15, 0.6), Vector3(2.5, 0.7, 2.0), 4.0)
		await _capture("girdle-fold-%d" % roundi(fold * 100))
	if tag != "before":
		# A deliberate manipulation inspection while the other three paws support.
		for mode in [1, 2, 0]:
			motion.arm_inspection.mode = mode
			for i in range(120):
				await _ticks(1)
				_view(Vector3(0.15, 0.9, 0.75), Vector3(1.6, 0.3, 2.0), 4.1)
				if i % 4 == 0:
					await _capture("arm-%d-%03d" % [mode, i])
			await _capture("arm-mode-%d" % mode)
			if mode == 2:
				var wrist: int = motion.skeleton.find_bone("hand.L")
				var center: Vector3 = motion.skeleton.get_bone_global_pose(wrist).origin
				_view(center, Vector3(1.0, 0.25, 1.0), 1.7)
				await _capture("wrist-connection")
				_clay(true)
				await _capture("wrist-connection-clay")
				var overlay := _wrist_bone_overlay()
				await _capture("wrist-bone-paths")
				overlay.queue_free()
				_clay(false)
	Input.action_press("move_forward")
	for i in range(150):
		await _ticks(1)
		_view(Vector3(0, 0.8, 0.1), Vector3(3, 0.5, 2.5), 5.8)
		if i % 5 == 0:
			await _capture("walk-%03d" % i)
	Input.action_release("move_forward")
	player.reset_to_spawn()
	motion.fold_target = 0.0
	await _ticks(30)
	await _jump()
	await _ticks(20)
	await _jump()
	player.pivot.rotation.x = 0.18
	await _ticks(130)
	if player.locomotion_state != &"flying":
		printerr("Flight review failed to enter flying")
		quit(1)
		return
	for angle in ["side", "front"]:
		_view(Vector3(0, 0.65, -0.3), Vector3(4, 0.3, 0) if angle == "side" else Vector3(0, 0.3, 4), 7.2)
		await _capture("flight-" + angle)
		_clay(true)
		await _capture("flight-" + angle + "-clay")
		_clay(false)
	for i in range(180):
		await _ticks(1)
		_view(Vector3(0, 0.6, -0.2), Vector3(3.5, 0.5, 3.0), 7.5)
		if i % 5 == 0:
			await _capture("flight-%03d" % i)
	scene.queue_free()
	camera.queue_free()
	await process_frame
	quit()
