extends SceneTree
var scene: Node3D
var motion: Node
var failures: Array[String] = []
var holding_fire: bool = false

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func():
		printerr("Fire breath test timed out")
		quit(1)
	)
	_run.call_deferred()

func _ticks(count: int) -> void:
	for i in range(count):
		if holding_fire: Input.action_press("fire_breath")
		await physics_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
	print(("PASS: " if ok else "FAIL: ") + message)

func _run() -> void:
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	motion = scene.get_node("Clay/Visual").motion
	if not motion or not motion.fire:
		printerr("Build Clay before checking fire breath")
		quit(1)
		return
	await _ticks(30)
	var fire = motion.fire
	_check(not fire.active and is_zero_approx(fire.jaw_angle), "Resting mouth stays closed")
	var mapped := false
	for event in InputMap.action_get_events("fire_breath"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			mapped = true
	_check(mapped, "R1/right bumper is mapped independently of wing triggers")
	holding_fire = true
	Input.action_press("fire_breath")
	await _ticks(4)
	_check(fire.jaw_angle > 0 and not fire.active, "Jaw opens before ignition")
	await _ticks(25)
	_check(fire.active and fire.stream.emitting and absf(fire.jaw_angle - fire.GAPE) < 0.001, "Held action reaches full gape and sustains fire")
	var guide: Transform3D = motion.skeleton.global_transform * motion.skeleton.get_bone_global_pose(fire.nozzle)
	_check(fire.stream.global_position.distance_to(guide.origin) < 0.0001, "Fire starts at the internal posterior-mouth bone with no forward offset")
	_check(not fire.stream.local_coords, "Released flame particles retain world-space motion")
	_check_emission_path()
	var old_direction: Vector3 = -fire.stream.global_basis.z
	scene.get_node("Clay").pivot.rotation.y = PI / 2
	await _ticks(130)
	_check(old_direction.angle_to(-fire.stream.global_basis.z) > 0.8, "Emitter follows head tracking")
	var index: int = motion.skeleton.find_bone("jaw")
	var head: int = motion.skeleton.find_bone("head")
	var head_delta: Transform3D = motion.skeleton.get_bone_global_pose(head) * motion.skeleton.get_bone_global_rest(head).affine_inverse()
	var expected: Vector3 = head_delta * motion.skeleton.get_bone_global_rest(index).origin
	_check(expected.distance_to(motion.skeleton.get_bone_global_pose(index).origin) < 0.0001, "Wide-gape jaw remains on its hinge during gaze")
	holding_fire = false
	Input.action_release("fire_breath")
	await _ticks(2)
	_check(not fire.active and not fire.stream.emitting, "Release stops new particles immediately")
	await _ticks(30)
	_check(is_zero_approx(fire.jaw_angle), "Jaw closes smoothly after release")
	holding_fire = true
	Input.action_press("fire_breath")
	await _ticks(25)
	holding_fire = false
	Input.action_release("fire_breath")
	motion.reset_motion()
	_check(not fire.active and is_zero_approx(fire.jaw_angle) and not fire.stream.emitting, "Respawn resets mouth and flame")
	print("Fire breath checks: %d failures" % failures.size())
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _check_emission_path() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: skinned emission-path check requires the graphical renderer")
		return
	var origin: Vector3 = motion.fire.stream.global_position
	var direction: Vector3 = -motion.fire.stream.global_basis.z
	var clear := true
	for mesh in motion.meshes:
		var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
		if not baked:
			_check(false, "Graphical renderer can bake the posed mouth for clearance")
			continue
		var triangles: TriangleMesh = baked.generate_triangle_mesh()
		for offset in [Vector3.ZERO, motion.fire.stream.global_basis.x * 0.04, -motion.fire.stream.global_basis.x * 0.04, motion.fire.stream.global_basis.y * 0.04, -motion.fire.stream.global_basis.y * 0.04]:
			var start: Vector3 = mesh.to_local(origin + offset + direction * 0.015)
			var end: Vector3 = mesh.to_local(origin + offset + direction * 1.5)
			var hit := triangles.intersect_segment(start, end)
			if not hit.is_empty():
				print("Emission obstruction: ", hit)
				clear = false
	_check(clear, "Internal flame path clears the posed mouth, lips and tongue")
