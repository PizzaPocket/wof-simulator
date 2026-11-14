extends SceneTree
var scene: Node3D
var motion: Node
var camera: Camera3D
var output: String

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _view(center: Vector3, offset: Vector3, size: float) -> void:
	camera.size = size
	var target: Vector3 = motion.skeleton.to_global(center)
	camera.global_position = target + motion.skeleton.global_basis * offset
	camera.look_at(target)

func _run() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
		InputMap.action_erase_events(action)
	var tag := "after"
	if not OS.get_cmdline_user_args().is_empty():
		tag = OS.get_cmdline_user_args()[0]
	output = ProjectSettings.globalize_path("res://../cache/eye-tail-" + tag)
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	motion = scene.get_node("Clay/Visual").motion
	if tag in ["before", "needle"]:
		var visual: Node3D = scene.get_node("Clay/Visual")
		var old_model: Node3D = motion.model
		var saved_transform: Transform3D = old_model.transform
		visual.remove_child(old_model)
		old_model.queue_free()
		motion.free()
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var filename := "clay-before-gallop-tail.glb" if tag == "needle" else "clay-before-eye-tail.glb"
		var error := document.append_from_file(ProjectSettings.globalize_path("res://../cache/" + filename), state)
		if error != OK:
			push_error("Missing baseline model")
			quit(1)
			return
		var baseline := document.generate_scene(state)
		visual.add_child(baseline)
		baseline.transform = saved_transform
		visual._prepare_materials(baseline)
		motion = preload("res://scripts/creature_motion.gd").new()
		visual.add_child(motion)
		motion.setup(baseline, scene.get_node("Clay"))
		visual.motion = motion
	motion.enabled = false
	scene.get_node("Clay").set_physics_process(false)
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var fill := OmniLight3D.new()
	camera.add_child(fill)
	fill.light_energy = 0.7
	fill.omni_range = 20
	await physics_frame
	motion.skeleton.reset_bone_poses()
	motion.apply_wings()
	_view(Vector3(0.152, 1.6925, 1.6858), Vector3(1, -0.12, 0.12), 0.24)
	await _capture("eye-open")
	if tag == "after":
		for value in [0.5, 1.0]:
			motion.blink.apply_amount(value)
			await _capture("eye-%03d" % roundi(value * 100))
		motion.blink.reset()
		motion.blink.rng.seed = 73
		motion.blink.remaining = 1.1
		for frame in range(240):
			motion.blink.update(1.0 / 30.0)
			await _capture("blink-%03d" % frame)
		motion.blink.apply_amount(0)
	_view(Vector3(0, 1.04, -3.90), Vector3(1, 0.35, -0.3), 1.6)
	await _capture("tail-side")
	_view(Vector3(0, 1.04, -3.90), Vector3(0.6, 1.5, -0.3), 1.6)
	await _capture("tail-top")
	if tag != "before":
		for mesh in motion.meshes:
			preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, true)
		await _capture("tail-clay")
	quit()
