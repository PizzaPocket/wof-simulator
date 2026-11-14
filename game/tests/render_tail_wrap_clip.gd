extends SceneTree
## Animated overhead demonstration of the actual runtime tail solver.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../cache/tail-wrap-clip")
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Clay")
	var motion = player.get_node("Visual").motion
	scene.hud.hide()
	var camera := Camera3D.new()
	player.add_child(camera)
	camera.current = true
	camera.fov = 52
	camera.position = Vector3(0, 15, 2)
	camera.look_at(player.global_position + Vector3(0, 0.9, 2), Vector3.FORWARD)
	for i in range(120):
		await physics_frame
	for i in range(660):
		if i == 30:
			motion.tail.preview_mode = 1
		if i == 270:
			motion.tail.preview_mode = 2
		if i == 570:
			motion.tail.preview_mode = 0
		await physics_frame
		if i % 4 == 0:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("wrap-%03d.png" % i))
	scene.queue_free()
	await process_frame
	quit()
