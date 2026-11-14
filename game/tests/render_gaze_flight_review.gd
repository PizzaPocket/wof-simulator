extends SceneTree
## Graphical review of head tracking, staged jumping and flap/glide transitions.
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


func _view(offset: Vector3, target: Vector3) -> void:
	camera.position = offset
	camera.look_at(player.global_position + target, Vector3.UP)


func _press_jump() -> void:
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")


func _run() -> void:
	output = ProjectSettings.globalize_path("res://").path_join("../cache/gaze-flight-review").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion:
		printerr("Build Clay before rendering the gaze/flight review")
		quit(1)
		return
	scene.hud.hide()
	camera = Camera3D.new()
	player.add_child(camera)
	camera.current = true
	camera.fov = 58
	_view(Vector3(-7, 4.5, -10), Vector3(0, 2.7, -1.8))
	await _ticks(90)
	await _capture("01-neutral")
	player.pivot.rotation.y = PI / 2.0
	for i in range(100):
		await _ticks(1)
		if i % 4 == 0:
			await _capture("gaze-left-%03d" % i)
	await _capture("02-left-limit")
	player.pivot.rotation.y = PI
	for i in range(100):
		await _ticks(1)
		if i % 4 == 0:
			await _capture("gaze-front-%03d" % i)
	await _capture("03-front-stage-neutral")
	player.pivot.rotation.y = 0
	player.pivot.rotation.x = 0.4
	await _ticks(100)
	await _capture("04-look-up")
	player.pivot.rotation.x = -0.9
	await _ticks(100)
	await _capture("05-look-down")

	player.spawn_position = Vector3(0, 0.1, 30)
	player.reset_to_spawn()
	_view(Vector3(-11, 4, 0), Vector3(0, 1.9, 0))
	await _ticks(60)
	await _press_jump()
	for i in range(100):
		await _ticks(1)
		if i % 3 == 0:
			await _capture("jump-%03d" % i)
	await _ticks(20)
	player.pivot.rotation.x = 0
	await _press_jump()
	await _ticks(20)
	await _press_jump()
	_view(Vector3(-18, 8, 14), Vector3(0, 2, 1))
	await _ticks(100)
	await _capture("06-level-glide")
	player.pivot.rotation.x = 0.4
	for i in range(150):
		await _ticks(1)
		if i >= 24 and i % 6 == 0:
			await _capture("flap-%03d" % i)
	await _capture("07-climbing")
	player.pivot.rotation.x = -0.2
	await _ticks(130)
	await _capture("08-descending-glide")
	print("Gaze and flight review rendered: " + output)
	scene.queue_free()
	await process_frame
	quit()
