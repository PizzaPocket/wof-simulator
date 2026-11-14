extends SceneTree
var scene: Node3D
var motion: Node
var player: CharacterBody3D
var camera: Camera3D
var holding := false
var output := ProjectSettings.globalize_path("res://../cache/jaw-cheek-gaze-review")
func _initialize() -> void:
	physics_frame.connect(func():
		if holding: Input.action_press("fire_breath")
	)
	_run.call_deferred()
func _ticks(count: int) -> void:
	for i in range(count): await physics_frame
func _capture(label: String, quarter: bool = false, wide: bool = false) -> void:
	var head: Vector3 = motion.skeleton.to_global(motion.skeleton.get_bone_global_pose(motion.fire.head).origin)
	var forward: Vector3 = -player.visual.global_basis.z.normalized()
	var side: Vector3 = player.visual.global_basis.x.normalized()
	var target: Vector3 = head + forward * 0.55 + Vector3.DOWN * 0.35
	camera.size = 3.5
	camera.global_position = target + side * 8.0 + Vector3.UP * 0.2
	if quarter: camera.global_position = target + side * 6.0 + forward * 4.0 + Vector3.UP * 1.0
	if wide:
		var direction: Vector3 = -motion.fire.stream.global_basis.z.normalized()
		target = motion.fire.stream.global_position + direction * 3.0
		camera.size = 8.0
		camera.global_position = target + side * 12.0 + Vector3.UP * 0.5
	camera.look_at(target)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func _clay(enabled: bool) -> void:
	for mesh in motion.meshes:
		for i in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(i)
			if material is ShaderMaterial: material.set_shader_parameter("clay_mode",enabled)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	await _ticks(30)
	player.set_physics_process(false)
	motion.enabled = false
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	motion.skeleton.reset_bone_poses()
	motion.apply_wings()
	motion.fire.base_head_rotation = motion.skeleton.get_bone_pose_rotation(motion.fire.head)
	for angle in [0.0,0.45,0.9]:
		motion.fire.jaw_angle = angle
		motion.fire._apply_mouth()
		var label := "%02d" % roundi(angle*100)
		for clay in [false,true]:
			_clay(clay)
			var kind := "clay" if clay else "painted"
			await _capture("side-"+label+"-"+kind)
			await _capture("quarter-"+label+"-"+kind,true)
	_clay(false)
	motion.fire.jaw_angle = 0.0
	motion.fire._apply_mouth()
	motion.enabled = true
	player.pivot.rotation.y = player.visual.rotation.y
	for elevation in [0.0,0.35]:
		player.pivot.rotation.x = elevation
		holding = true
		await _ticks(150)
		await _capture("fire-level" if elevation==0.0 else "fire-up",false,true)
	holding = false
	Input.action_release("fire_breath")
	scene.queue_free()
	await process_frame
	quit()
