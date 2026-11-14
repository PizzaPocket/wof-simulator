extends SceneTree
## Side/top and plain-clay review, plus an actual jump with the tail coiled.
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


func _view(offset: Vector3, target: Vector3, up: Vector3 = Vector3.UP) -> void:
	camera.position = offset
	camera.look_at(player.global_position + target, up)


func _jump() -> void:
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")


func _run() -> void:
	output = ProjectSettings.globalize_path("res://").path_join("../cache/tail-limbs-review").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	scene.hud.hide()
	camera = Camera3D.new()
	player.add_child(camera)
	camera.current = true
	camera.fov = 52
	_view(Vector3(-13, 3.5, 3), Vector3(0, 1.5, 2))
	await _ticks(150)
	await _capture("01-extended-side")
	_view(Vector3(-7, 2.5, 6), Vector3(0, 0.9, 5))
	await _capture("02-tail-close")
	for mesh in motion.meshes:
		preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, true)
	await _capture("03-tail-plain-clay")
	# Restore the normal portable colour material.
	for mesh in motion.meshes:
		preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, false)
	_view(Vector3(0, 14, 2), Vector3(0, 0.9, 2), Vector3.FORWARD)
	motion.tail.preview_mode = 1
	await _ticks(240)
	await _capture("04-left-curl")
	motion.tail.preview_mode = 2
	await _ticks(360)
	await _capture("05-right-curl")
	_view(Vector3(-12, 4, 3), Vector3(0, 1.6, 2))
	await _jump()
	for i in range(100):
		await _ticks(1)
		if i % 4 == 0:
			await _capture("curl-jump-%03d" % i)
	motion.tail.preview_mode = 0
	await _ticks(120)
	player.pivot.rotation.x = 0
	await _jump()
	await _ticks(20)
	await _jump()
	_view(Vector3(-12, 3, 0), Vector3(0, 1.6, 0.5))
	await _ticks(130)
	await _capture("06-flight-side")
	_view(Vector3(-9, 3.5, -9), Vector3(0, 1.4, -0.2))
	await _capture("07-flight-front")
	player.pivot.rotation.x = 0.3
	_view(Vector3(-14, 5, 8), Vector3(0, 1.8, 1))
	for i in range(120):
		await _ticks(1)
		if i % 6 == 0:
			await _capture("flight-%03d" % i)
	print("Tail/limb review rendered: " + output)
	scene.queue_free()
	await process_frame
	quit()
