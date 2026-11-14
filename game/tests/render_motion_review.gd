extends SceneTree
## Run with a graphical renderer, not --headless. Outputs ignored review PNGs.
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


func _camera_pose(offset: Vector3, target: Vector3) -> void:
	camera.position = offset
	camera.look_at(player.global_position + target, Vector3.UP)


func _run() -> void:
	output = ProjectSettings.globalize_path("res://").path_join("../cache/motion-review").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion:
		printerr("Build Clay before rendering the motion review")
		quit(1)
		return
	for child in scene.get_children():
		if child is CanvasLayer:
			child.hide()
	camera = Camera3D.new()
	player.add_child(camera)
	camera.current = true
	camera.fov = 58
	_camera_pose(Vector3(-14, 5, 6), Vector3(0, 1.8, 1))
	await _ticks(120)
	await _capture("01-folded")
	motion.fold_target = 0.5
	await _ticks(100)
	await _capture("02-half")
	motion.fold_target = 0.0
	await _ticks(100)
	_camera_pose(Vector3(-19, 9, 13), Vector3(0, 1.8, 1))
	await _capture("03-spread")
	player.spawn_position = Vector3(0, 0.1, 30)
	player.reset_to_spawn()
	_camera_pose(Vector3(-12, 3.3, 1), Vector3(0, 1.9, 1))
	await _ticks(30)
	Input.action_press("move_forward")
	for i in range(150):
		await _ticks(1)
		if i >= 30 and i < 126 and i % 4 == 0:
			await _capture("walk-%03d" % i)
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _ticks(40)
	await _capture("04-turn")
	Input.action_release("move_right")
	await _ticks(90)
	await _capture("05-settle")
	print("Motion review rendered: " + output)
	scene.queue_free()
	await process_frame
	quit()
