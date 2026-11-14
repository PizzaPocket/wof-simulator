extends SceneTree
var output := ProjectSettings.globalize_path("res://../cache/tail-rest-review")

func _initialize() -> void:
	_run.call_deferred()

func _ticks(count: int) -> void:
	for i in range(count): await physics_frame

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func _run() -> void:
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
	camera.position = Vector3(0, 16, 3)
	camera.look_at(player.global_position + Vector3(0, 0.9, 2), Vector3.FORWARD)
	await _ticks(90)
	motion.tail.settings.preview_curl_degrees = 140.0
	for mode in [1, 2]:
		motion.tail.preview_mode = mode
		await _ticks(240)
		motion.tail.preview_mode = 0
		await _ticks(240)
		await _capture("left-rest" if mode == 1 else "right-rest")
		await _ticks(300)
		await _capture("left-rest-later" if mode == 1 else "right-rest-later")
	scene.queue_free()
	await process_frame
	quit()
