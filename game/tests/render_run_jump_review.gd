extends SceneTree
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var camera: Camera3D
var output := ProjectSettings.globalize_path("res://../cache/run-jump-review")
func _initialize() -> void:
	_run.call_deferred()
func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
func _view() -> void:
	var target := player.global_position + Vector3(0, 1.7, 1.0)
	camera.global_position = target + Vector3(12, 3, 1.8)
	camera.look_at(target)
func _capture(name: String) -> void:
	_view()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func _reset() -> void:
	for action in ["sprint", "jump", "move_forward"]:
		Input.action_release(action)
	player.spawn_position = Vector3(-38, 0.1, 35)
	player.reset_to_spawn()
	await _ticks(30)
func _run() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
		InputMap.action_erase_events(action)
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	await _reset()
	Input.action_press("move_forward")
	await _ticks(45)
	for frame in range(60):
		await _ticks(2)
		await _capture("walk-%03d" % frame)
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(60)
	for frame in range(90):
		await _ticks(2)
		await _capture("gallop-%03d" % frame)
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(60)
	# 60 fps makes the short grounded compression visible in the review.
	Input.action_press("jump")
	for frame in range(80):
		await _ticks(1)
		if frame == 2:
			Input.action_release("jump")
		await _capture("jump-%03d" % frame)
	quit()
