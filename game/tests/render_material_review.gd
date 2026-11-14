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
	var tag := "after"
	if not OS.get_cmdline_user_args().is_empty(): tag = OS.get_cmdline_user_args()[0]
	output = ProjectSettings.globalize_path("res://../cache/material-review-" + tag)
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	scene.get_node("Clay/Visual").use_procedural_materials = tag != "before"
	root.add_child(scene)
	scene.get_node("Clay").set_physics_process(false)
	motion = scene.get_node("Clay/Visual").motion
	motion.enabled = false
	scene.hud.hide()
	if tag == "before":
		for world in scene.find_children("*", "WorldEnvironment", true, false):
			world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			world.environment.tonemap_exposure = 1.0
			world.environment.ambient_light_color = Color("d8e3e7")
			world.environment.ambient_light_energy = 0.35
			world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
		var lights := scene.find_children("*", "DirectionalLight3D", true, false)
		lights[0].rotation_degrees = Vector3(-45, -30, 0)
		lights[0].light_color = Color("fff0d3")
		lights[0].light_energy = 0.9
		for index in range(1, lights.size()): lights[index].hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	await physics_frame
	if tag == "studio":
		for child in scene.get_children():
			if child is StaticBody3D:
				for mesh in child.find_children("*", "MeshInstance3D", true, false): mesh.hide()
		for world in scene.find_children("*", "WorldEnvironment", true, false):
			world.environment.background_mode = Environment.BG_COLOR
			world.environment.background_color = Color("15110e")
			world.environment.ambient_light_color = Color("e8ecf2")
			world.environment.ambient_light_energy = 0.9
			world.environment.tonemap_exposure = 0.6
		for light in scene.find_children("*", "DirectionalLight3D", true, false):
			light.hide()
		for entry in [[Vector3(3, 4, 4), Color("fff4e6"), 1.5], [Vector3(-3, 2, -3), Color("b8c8ff"), 0.5]]:
			var light := DirectionalLight3D.new()
			root.add_child(light)
			light.light_color = entry[1]
			light.light_energy = entry[2]
			light.look_at_from_position(motion.skeleton.to_global(entry[0]), motion.skeleton.to_global(Vector3.ZERO))
	motion.skeleton.reset_bone_poses()
	motion.apply_wings()
	for name in ["full", "face", "neck", "leg", "belly", "wing"]:
		if name == "full": _view(Vector3(0, 1.1, -0.6), Vector3(10, 4, 9), 11.0)
		if name == "face": _view(Vector3(0.06, 1.55, 1.74), Vector3(2.2, 0.1, 1.8), 1.9)
		if name == "neck": _view(Vector3(0.1, 1.3, 1.0), Vector3(3, 0.3, 2), 2.8)
		if name == "leg": _view(Vector3(0.4, 0.65, 0.6), Vector3(3, 0.3, 1), 2.5)
		if name == "belly": _view(Vector3(0, 0.95, 0.55), Vector3(0.5, -1, 3), 3.4)
		if name == "wing":
			motion.fold_amount = 0.0
			motion.apply_wings()
			_view(Vector3(0.8, 1.15, -0.1), Vector3(4, 2, -3), 7.0)
		if tag == "studio" and name == "face":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 30
			camera.global_position = motion.skeleton.to_global(Vector3(2.3, 1.65, 3.55))
			camera.look_at(motion.skeleton.to_global(Vector3(0.06, 1.55, 1.74)))
		await _capture(name)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	if tag == "after":
		for mesh in motion.meshes:
			for i in range(mesh.mesh.get_surface_count()):
				var material = mesh.get_active_material(i)
				if material is ShaderMaterial: material.set_shader_parameter("clay_mode", true)
		_view(Vector3(0.06, 1.55, 1.74), Vector3(2.2, 0.1, 1.8), 1.9)
		await _capture("plain-clay")
	quit()
