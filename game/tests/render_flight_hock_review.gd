extends SceneTree
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var camera: Camera3D
var output := ProjectSettings.globalize_path("res://../cache/flight-hock-review")
func _initialize() -> void:
	_run.call_deferred()
func _ticks(count: int) -> void:
	for i in range(count): await physics_frame
func _view(offset: Vector3, size := 8.0, center := Vector3(0, 1.2, 0)) -> void:
	camera.size = size
	var target: Vector3 = motion.skeleton.to_global(center)
	camera.global_position = target + motion.skeleton.global_basis * offset
	camera.look_at(target)
func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func _clay(enabled: bool) -> void:
	for mesh in motion.meshes:
		preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, enabled)

func _run() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
		InputMap.action_erase_events(action)
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps = 60
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	await _ticks(20)
	player.position = Vector3(-35, 18, 35)
	player._activate_flight()
	player.pivot.rotation.x = 0
	await _ticks(150)
	player.set_physics_process(false)
	motion.enabled = false
	for view in ["side", "rear-quarter", "front"]:
		var offset := Vector3(8, 1, 0)
		if view == "rear-quarter": offset = Vector3(5, 1.2, -5)
		if view == "front": offset = Vector3(0, -0.5, 8)
		_view(offset)
		await _capture(view + "-painted")
		_clay(true)
		await _capture(view + "-clay")
		_clay(false)
	_view(Vector3(6, 0, -3), 3.5, Vector3(0, 0.65, -0.45))
	await _capture("hind-close")
	motion.enabled = true
	player.set_physics_process(true)
	for frame in range(90):
		player.pivot.rotation.x = 0.25 if frame < 45 else 0
		await _ticks(2)
		_view(Vector3(9, 2, 5), 10.5)
		await _capture("flight-%03d" % frame)
	quit()
