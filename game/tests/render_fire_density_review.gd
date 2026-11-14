extends SceneTree
var output := ProjectSettings.globalize_path("res://../cache/fire-density-review")
var camera: Camera3D
var fire: RefCounted
var tag := "after"
var holding_fire: bool = false

func _maintain_fire() -> void:
	if holding_fire: Input.action_press("fire_breath")

func _initialize() -> void:
	_run.call_deferred()

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(tag + "-" + label + ".png"))

func _view(kind: String) -> void:
	var origin: Vector3 = fire.stream.global_position
	var direction: Vector3 = -fire.stream.global_basis.z
	var side := direction.cross(Vector3.UP).normalized()
	var target := origin + direction * 3.1
	camera.global_position = target + side * 11.0 + Vector3.UP * 1.4
	camera.size = 7.7
	if kind == "oblique":
		camera.global_position = origin + side * 9.0 - direction * 4.0 + Vector3.UP * 3.0
		camera.size = 9.0
	camera.look_at(target)

func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty(): tag = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	var player = scene.get_node("Clay")
	for i in range(90): await physics_frame
	player.set_physics_process(false)
	player.pivot.rotation.x = 0.35
	scene.hud.hide()
	if tag == "before":
		# Recreate the baseline from the saved script without editing shared files.
		var motion = player.get_node("Visual").motion
		motion.fire.stream.queue_free()
		var previous_jet: Node = motion.fire.get("jet")
		if is_instance_valid(previous_jet): previous_jet.queue_free()
		var baseline := GDScript.new()
		baseline.source_code = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../cache/fire-density-review/fire_before.gd"))
		baseline.reload()
		motion.fire = baseline.new()
		motion.fire.setup(motion.skeleton, motion.meshes)
	fire = player.get_node("Visual").motion.fire
	camera = Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	physics_frame.connect(_maintain_fire)
	holding_fire = true
	Input.action_press("fire_breath")
	for i in range(90):
		Input.action_press("fire_breath")
		await physics_frame
	print("Wetlands fire review: active=",fire.active," jaw=",fire.jaw_angle)
	_view("side")
	await _capture("side")
	_view("oblique")
	await _capture("oblique")
	if tag != "before":
		_view("side")
		for frame in range(48):
			Input.action_press("fire_breath")
			await physics_frame
			await _capture("motion-%03d" % frame)
	holding_fire = false
	Input.action_release("fire_breath")
	for i in range(40): await physics_frame
	await _capture("released")
	scene.queue_free()
	await process_frame
	quit()
