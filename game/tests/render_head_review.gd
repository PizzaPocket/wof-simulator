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
func _view(offset: Vector3, center := Vector3(0, 1.56, 1.72), size := 1.8) -> void:
	camera.size = size
	var target: Vector3 = motion.skeleton.to_global(center)
	camera.global_position = target + motion.skeleton.global_basis * offset
	camera.look_at(target)
func _mouth(amount: float) -> void:
	for name in ["jaw", "oral1", "oral2"]:
		var index: int = motion.skeleton.find_bone(name)
		var pose: Transform3D = motion.skeleton.get_bone_global_rest(index)
		var share := 1.0 if name == "jaw" else (1.0 / 3.0 if name == "oral1" else 2.0 / 3.0)
		pose.basis = Basis(Vector3.RIGHT, amount * share) * pose.basis
		motion.gait._set_global(index, pose)
	for mesh in motion.meshes:
		var index: int = mesh.find_blend_shape_by_name("jawOpen")
		if index >= 0:
			mesh.set_blend_shape_value(index, amount / 0.6)
func _clay(enabled: bool) -> void:
	for mesh in motion.meshes:
		preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, enabled)

func _run() -> void:
	var tag := "after"
	if not OS.get_cmdline_user_args().is_empty():
		tag = OS.get_cmdline_user_args()[0]
	output = ProjectSettings.globalize_path("res://../cache/head-review-" + tag)
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("Clay").set_physics_process(false)
	motion = scene.get_node("Clay/Visual").motion
	if tag == "debug":
		var visual: Node3D = scene.get_node("Clay/Visual")
		var previous: Node3D = motion.model
		var transform: Transform3D = previous.transform
		visual.remove_child(previous)
		previous.queue_free()
		motion.free()
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		document.append_from_file(ProjectSettings.globalize_path("res://../cache/clay-head-part-debug.glb"), state)
		var replacement := document.generate_scene(state)
		visual.add_child(replacement)
		replacement.transform = transform
		visual._prepare_materials(replacement)
		motion = preload("res://scripts/creature_motion.gd").new()
		visual.add_child(motion)
		motion.setup(replacement, scene.get_node("Clay"))
		visual.motion = motion
	motion.enabled = false
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var light := OmniLight3D.new()
	camera.add_child(light)
	light.light_energy = 0.6
	light.omni_range = 12
	await physics_frame
	motion.skeleton.reset_bone_poses()
	motion.apply_wings()
	for angle in [0.0, 0.4, 0.9]:
		_mouth(angle)
		for view in ["side", "three-quarter", "under", "front"]:
			var offset := Vector3(2, 0, 0)
			if view == "three-quarter": offset = Vector3(1.5, 0.1, 1.5)
			if view == "under": offset = Vector3(1.3, -1.4, 1.0)
			if view == "front": offset = Vector3(0, -0.1, 2)
			_view(offset)
			await _capture("%s-%02d-painted" % [view, roundi(angle * 100)])
			_clay(true)
			await _capture("%s-%02d-clay" % [view, roundi(angle * 100)])
			_clay(false)
	if tag == "ear":
		_mouth(0.0)
		_view(Vector3(2, 0.03, 0.35), Vector3(0.20, 1.72, 1.44), 0.80)
		await _capture("rear-hook-painted")
		_clay(true)
		await _capture("rear-hook-clay")
		_clay(false)
	if tag == "resculpt":
		_mouth(0.65)
		_view(Vector3(1.1, 1.2, 1.7), Vector3(0, 1.25, 1.7), 1.2)
		await _capture("gum-arch")

		motion.enabled = true
		Input.action_press("fire_breath")
		for tick in range(50):
			await physics_frame
		_view(Vector3(5, 0.6, 0.3), Vector3(0, 1.0, 3.2), 6.5)
		await _capture("fire-side")
		_view(Vector3(4, 1.0, 4), Vector3(0, 1.25, 2.6), 5.0)
		for tick in range(60):
			await physics_frame
			await _capture("fire-%03d" % tick)
		Input.action_release("fire_breath")
	if tag == "after":
		_view(Vector3(1.5, -0.05, 1.5))
		for frame in range(120):
			_mouth(0.4 * (0.5 - 0.5 * cos(TAU * frame / 119.0)))
			await _capture("jaw-%03d" % frame)
	quit()
