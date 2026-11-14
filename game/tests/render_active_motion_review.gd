extends SceneTree
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var camera: Camera3D
var output := ProjectSettings.globalize_path("res://../cache/active-motion-review")

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
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	scene.hud.hide()
	camera = Camera3D.new()
	player.add_child(camera)
	camera.current = true
	camera.fov = 50
	camera.position = Vector3(0, 15, 3)
	camera.look_at(player.global_position + Vector3(0, 1, 2), Vector3.FORWARD)
	await _ticks(90)
	motion.tail.preview_mode = 1
	await _ticks(240)
	await _capture("01-tail-curled")
	motion.tail.preview_mode = 0
	await _ticks(90)
	await _capture("02-tail-recovering")
	await _ticks(390)
	await _capture("03-tail-resting")
	# Hold the body in the air and step the real motion layers at fixed intervals.
	player.set_physics_process(false)
	motion.set_physics_process(false)
	player.position = Vector3(0, 12, 0)
	player.locomotion_state = &"flying"
	player.flight_mode = &"climbing"
	player.ground_distance = 12.0
	player.velocity = Vector3(0, 3, -24)
	player.state_time = 5.0
	motion.fold_amount = 0.0
	motion.fold_target = 0.0
	camera.position = Vector3(-13, 7, 13)
	camera.look_at(player.global_position + Vector3(0, 1.5, 1))
	for i in range(150): motion._physics_process(1.0 / 60.0)
	for i in range(8):
		motion.flight.phase = float(i) / 8.0
		motion._physics_process(0.0)
		await _capture("flap-%02d" % i)
	scene.queue_free()
	await process_frame
	quit()
