extends "res://tests/render_head_review.gd"

func _run() -> void:
	output = ProjectSettings.globalize_path("res://../cache/fire-review")
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("Clay").set_physics_process(false)
	motion = scene.get_node("Clay/Visual").motion
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	Input.action_press("fire_breath")
	for tick in range(60):
		await physics_frame
	_view(Vector3(5, 0.3, 0.1), Vector3(0, 1.0, 3.2), 6.3)
	await _capture("side")
	_view(Vector3(2, 0.05, 1), Vector3(0, 1.34, 1.73), 1.65)
	await _capture("internal-source")
	_view(Vector3(4, 0.5, 4), Vector3(0, 1.15, 3), 5.2)
	for tick in range(60):
		await physics_frame
		await _capture("jet-%03d" % tick)
	Input.action_release("fire_breath")
	quit()
