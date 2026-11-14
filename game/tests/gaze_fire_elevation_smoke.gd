extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _ticks(count: int) -> void:
	for i in range(count): await physics_frame
func _check(ok: bool, text: String) -> void:
	if not ok: failures.append(text)
func _run() -> void:
	var scene = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	var player = scene.get_node("Clay")
	var motion = player.get_node("Visual").motion
	await _ticks(90)
	for sample in range(1,4):
		var found := false
		for mesh in motion.meshes:
			found = found or mesh.find_blend_shape_by_name("cheekOpen"+str(sample))>=0
		_check(found,"Default QA asset includes the curved cheek corrective samples")
	player.set_physics_process(false)
	for aim in [Vector2(0,-0.4),Vector2(0,0),Vector2(0,0.35),Vector2(0,0.65),Vector2(0.9,0.35),Vector2(-0.9,0.35)]:
		var elevation: float = aim.y
		player.pivot.rotation.x = elevation
		player.pivot.rotation.y = aim.x
		await _ticks(150)
		var before: Basis = motion.skeleton.get_bone_global_pose(motion.fire.head).basis
		for i in range(40):
			Input.action_press("fire_breath")
			await _ticks(1)
		var direction: Vector3 = -motion.fire.stream.global_basis.z.normalized()
		var actual := atan2(direction.y, Vector2(direction.x,direction.z).length())
		var skull: Basis = motion.skeleton.get_bone_global_pose(motion.fire.head).basis
		var lift := before.get_rotation_quaternion().angle_to(skull.get_rotation_quaternion())
		print("Camera %.1f deg: fire %.1f deg, skull lift %.1f deg" % [rad_to_deg(elevation),rad_to_deg(actual),rad_to_deg(lift)])
		_check(absf(actual-elevation)<deg_to_rad(4), "Flame follows camera elevation in the rear hemisphere")
		_check(absf(lift-deg_to_rad(5))<0.003,"Fire breathing raises the upper skull five degrees")
		Input.action_release("fire_breath")
		await _ticks(60)
	player.pivot.rotation.y = PI
	await _ticks(150)
	_check(motion.gaze.front_stage and absf(motion.gaze.pitch)<0.001,"Front camera hemisphere retains a neutral display pose")
	for message in failures: printerr("FAIL: "+message)
	if failures.is_empty(): print("PASS: level/upward fire aim, separate skull lift and front-stage neutral")
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
