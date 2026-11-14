extends SceneTree
## Actual exported-wing sampling checks; add --render for review PNGs/animation.
var motion: Node
var rig: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var camera: Camera3D
var failures: Array[String] = []
var output := ProjectSettings.globalize_path("res://../cache/wing-fold-review/renders")
var materials: Array[ShaderMaterial] = []

func _initialize() -> void:
	_run.call_deferred()

func _pose(amount: float) -> void:
	motion.fold_amount = amount
	motion.apply_wings()

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func _camera(offset: Vector3, target: Vector3, size: float, clay: bool, left_only: bool) -> void:
	camera.position = offset
	camera.size = size
	camera.look_at(target)
	for material in materials:
		material.set_shader_parameter("clay_mode", clay)
		material.set_shader_parameter("preview_left_only", left_only)

func _run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := ProjectSettings.globalize_path("res://../cache/wing-fold-review/wing.glb")
	if document.append_from_file(path, state) != OK:
		printerr("Build the isolated wing preview first")
		quit(1)
		return
	var model := document.generate_scene(state)
	root.add_child(model)
	for node in model.find_children("*", "Skeleton3D", true, false): rig = node
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/clay.gdshader").replace("uniform bool clay_mode", "uniform bool preview_left_only = false;\n    uniform bool clay_mode").replace("void fragment() {", "void fragment() {\nif (preview_left_only && vObj.x < 0.0) discard;")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node)
		for surface in range(node.mesh.get_surface_count()):
			var material := preload("res://scripts/clay_materials.gd").make_material(rig)
			material.shader = shader
			node.set_surface_override_material(surface, material)
			materials.append(material)
	motion = preload("res://scripts/creature_motion.gd").new()
	motion.enabled = false
	motion.skeleton = rig
	motion.meshes = meshes
	motion.anatomy = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../cache/wing-fold-review/wing_rig.json")))
	for track in motion.anatomy.wing_animation.tracks:
		track.index = rig.find_bone(track.bone)
		if track.index >= 0: motion.wing_tracks.append(track)
	for mesh in meshes:
		for i in range(mesh.mesh.get_blend_shape_count()):
			var shape_name: String = mesh.mesh.get_blend_shape_name(i)
			if shape_name.begins_with("wingFold"): motion.wing_step_count = maxi(motion.wing_step_count, int(shape_name.trim_prefix("wingFold")))
	root.add_child(motion)
	_pose(0.0)
	var attachment_positions: Dictionary = {}
	for i in range(rig.get_bone_count()):
		if rig.get_bone_name(i).begins_with("wing_"): attachment_positions[i] = rig.get_bone_pose_position(i)
	var maximum_attachment_drift := 0.0
	var maximum_mirror_error := 0.0
	for frame in range(201):
		_pose(float(frame) / 200.0)
		for index in attachment_positions:
			var name := rig.get_bone_name(index)
			if not name.begins_with("wing_elbowclaw."):
				maximum_attachment_drift = maxf(maximum_attachment_drift, rig.get_bone_pose_position(index).distance_to(attachment_positions[index]))
			_check(rig.get_bone_pose(index).is_finite(), "All sampled wing poses are finite")
			if name.ends_with(".L"):
				var other := rig.find_bone(name.trim_suffix(".L") + ".R")
				var left := rig.get_bone_global_pose(index).origin * Vector3(-1, 1, 1)
				maximum_mirror_error = maxf(maximum_mirror_error, left.distance_to(rig.get_bone_global_pose(other).origin))
	_check(motion.wing_step_count == 16, "The export includes every corrective pose")
	_check(maximum_attachment_drift < 0.0001, "Exported joints retain fixed local attachment points")
	_check(maximum_mirror_error < 0.0001, "Imported left/right wings remain mirrored throughout the fold")
	var driver := preload("res://scripts/wing_deployment.gd").new()
	var amount := 0.0
	var elapsed := 0.0
	while amount < 1.0 and elapsed < 2.0:
		amount = driver.step(amount, 1.0, 1.0 / 60.0, 0.65)
		elapsed += 1.0 / 60.0
	_check(amount == 1.0 and elapsed < 0.9, "Folding completes with a short muscular settle")
	var fold_seconds := elapsed
	elapsed = 0.0
	while amount > 0.0 and elapsed < 2.0:
		amount = driver.step(amount, 0.0, 1.0 / 60.0, 0.55)
		elapsed += 1.0 / 60.0
	_check(amount == 0.0 and elapsed < 0.8, "Spreading is brisker than stowing")
	for i in range(15): amount = driver.step(amount, 1.0, 1.0 / 60.0, 0.65)
	var previous_speed := driver.velocity
	amount = driver.step(amount, 0.0, 1.0 / 60.0, 0.55)
	_check(driver.velocity > 0.0 and driver.velocity < previous_speed, "Reversal first brakes the moving wing instead of snapping its direction")
	print("Wing export: attachment drift %.7f, mirror error %.7f; fold/spread %.3f/%.3f s" % [maximum_attachment_drift, maximum_mirror_error, fold_seconds, elapsed])
	if OS.get_cmdline_user_args().has("--render"):
		await _render(driver)
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: exported wing attachments, symmetry, corrective count and responsive reversible deployment")
	model.queue_free()
	motion.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _render(driver: RefCounted) -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("353c3b")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.65
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	root.add_child(camera)
	for amount in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_pose(amount)
		var label := "%03d" % roundi(amount * 100)
		_camera(Vector3(8, 2.3, -0.8), Vector3(0.6, 2.3, -0.8), 5.4, false, true)
		await _capture("side-" + label)
		_camera(Vector3(5, 7, 6), Vector3(1.6, 1.7, -0.7), 5.8, true, true)
		await _capture("clay-" + label)
		_camera(Vector3(0, 2.1, 10), Vector3(0, 2.1, -0.7), 7.0, false, false)
		await _capture("front-" + label)
		_camera(Vector3(0, 10, 2), Vector3(0, 1.5, -0.7), 7.0, false, false)
		await _capture("top-" + label)
		_camera(Vector3(3.3, 2.3, 3.0), Vector3(0.65, 1.25, 0.1), 2.1, true, true)
		await _capture("joint-" + label)
	_camera(Vector3(5, 7, 6), Vector3(1.6, 1.7, -0.7), 5.8, false, true)
	driver.velocity = 0.0
	var amount := 0.0
	for frame in range(126):
		var target := 1.0 if frame < 62 else 0.0
		amount = driver.step(amount, target, 1.0 / 60.0, 0.65 if target > amount else 0.55)
		_pose(amount)
		if frame % 2 == 0: await _capture("motion-%03d" % frame)
