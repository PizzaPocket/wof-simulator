extends SceneTree
## Runtime close-ups in the same framing before/after a source anatomy change.
var player: CharacterBody3D
var motion: Node
var camera: Camera3D
var output: String

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _view(center: Vector3, offset: Vector3) -> void:
	var target: Vector3 = motion.skeleton.to_global(center)
	camera.global_position = target + motion.skeleton.global_basis * offset
	camera.look_at(target)

func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _follow_foot(kind: String) -> void:
	var bone: int = motion.skeleton.find_bone("foot.L" if kind == "hind" else "hand.L")
	var toe: int = motion.skeleton.find_bone("htoe2.L" if kind == "hind" else "ftoe2.L")
	var center: Vector3 = motion.skeleton.get_bone_global_pose(bone).origin.lerp(motion.skeleton.get_bone_global_pose(toe).origin, 0.65)
	_view(center, Vector3(0.65, 0.4, 0.65))

func _run() -> void:
	var tag := "after"
	if not OS.get_cmdline_user_args().is_empty():
		tag = OS.get_cmdline_user_args()[0]
	output = ProjectSettings.globalize_path("res://../cache/feet-review-" + tag)
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	motion.fold_target = 0.0
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var fill := OmniLight3D.new()
	camera.add_child(fill)
	fill.omni_range = 6.0
	fill.light_energy = 1.5
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.3
	await _ticks(120)
	for kind in ["front", "hind"]:
		var center := Vector3(0.41, 0.09, 0.68) if kind == "front" else Vector3(0.45, 0.13, -0.65)
		_view(center, Vector3(0.65, 0.40, 0.65))
		await _capture(kind + "-painted")
		_view(center, Vector3(0.95, 0.08, 0))
		await _capture(kind + "-side")
		_view(center, Vector3(0.05, 0.9, 0.30))
		await _capture(kind + "-top")
	for mesh in motion.meshes:
		preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, true)
	for kind in ["front", "hind"]:
		var center := Vector3(0.41, 0.09, 0.68) if kind == "front" else Vector3(0.45, 0.13, -0.65)
		_view(center, Vector3(0.65, 0.40, 0.65))
		await _capture(kind + "-clay")
	# Model-space camera follows the paw during real game movement.
	Input.action_press("move_forward")
	for i in range(120):
		await _ticks(1)
		_view(Vector3(0.45, 0.20, -0.63), Vector3(0.85, 0.35, 0.75))
		if i % 4 == 0:
			await _capture("walk-%03d" % i)
	Input.action_release("move_forward")
	await _ticks(60)
	# Pose a single foot through its range, so every joint is visible.
	motion.enabled = false
	var leg: Dictionary
	for candidate in motion.gait.legs:
		if candidate.name == "hind.L":
			leg = candidate
	for i in range(120):
		var angle := deg_to_rad(35.0) * sin(float(i) / 119.0 * PI)
		leg.swing = true
		leg.pitch = 0.0
		leg.toe_curl = angle
		motion.gait._restore_leg(leg)
		motion.jump.limb_carriage.apply_toe_curl(leg)
		var center := Vector3(0.45, 0.13, -0.65)
		_view(center, Vector3(0.65, 0.40, 0.65))
		if i % 3 == 0:
			await _capture("digits-%03d" % i)
	motion.enabled = true
	player.reset_to_spawn()
	motion.fold_target = 0.0
	await _ticks(30)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	for i in range(100):
		await _ticks(1)
		_follow_foot("hind")
		if i % 4 == 0:
			await _capture("jump-%03d" % i)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	await _ticks(20)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	player.pivot.rotation.x = 0.2
	await _ticks(120)
	if player.locomotion_state != &"flying":
		printerr("Foot flight review did not reach flying state")
		quit(1)
		return
	player.set_physics_process(false)
	motion.enabled = false
	for kind in ["front", "hind"]:
		_follow_foot(kind)
		await _capture(kind + "-flight-clay")
	scene.queue_free()
	camera.queue_free()
	await process_frame
	quit()
