extends SceneTree
## Real rig integration checks. Run with --headless --path game --script this file.

var failures: Array[String] = []
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var maximum_contact_error: float = 0.0
var maximum_length_error: float = 0.0
var swing_frames: int = 0
var planted_frames: int = 0
var per_leg: Dictionary = {}
var maximum_airborne_paws: int = 0
var maximum_stance_error: float = 0.0
var paired_walk_frames: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion or not motion.skeleton or motion.anatomy.is_empty():
		printerr("Build Clay and clay_rig.json before running motion checks")
		quit(1)
		return
	await _ticks(90)
	_check(motion.wing_step_count >= 8, "Wing corrective samples are available")
	_check(motion.gait.legs.size() == 4, "All four measured limb chains are available")
	_check(motion.tail.bones.size() == 36 and motion.anatomy.tail.vertebrae == 36, "Game tail has one skinning bone per measured vertebra")
	# Scrub through every in-between, then return to folded; no additive drift.
	motion.enabled = false
	for amount in [0.0, 0.18, 0.5, 0.67, 1.0, 0.0, 1.0]:
		motion.fold_amount = amount
		motion.apply_wings()
		for mesh in motion.meshes:
			for i in range(mesh.mesh.get_blend_shape_count()):
				var name: String = mesh.mesh.get_blend_shape_name(i)
				if name.begins_with("wingFold"):
					var number := int(name.trim_prefix("wingFold"))
					var expected := maxf(0.0, 1.0 - absf(amount * motion.wing_step_count - number))
					_check(absf(mesh.get_blend_shape_value(i) - expected) < 0.00001, "Corrective shape follows viewer at fold=" + str(amount))
		for i in range(motion.skeleton.get_bone_count()):
			_check(motion.skeleton.get_bone_pose(i).is_finite(), "Wing scrub keeps bone poses finite")
	motion.enabled = true
	motion.fold_amount = 1.0
	motion.fold_target = 1.0
	Input.action_press("toggle_wings")
	await _ticks(1)
	Input.action_release("toggle_wings")
	await _ticks(90)
	_check(motion.fold_amount < 0.001, "Wing toggle fully spreads the wings")
	Input.action_press("fold_wings", 0.5)
	await _ticks(35)
	Input.action_release("fold_wings")
	_check(motion.fold_amount > 0.05 and motion.fold_amount < 0.9, "Fine wing input holds an intermediate fold")
	motion.fold_target = 1.0
	await _ticks(90)
	var tail_root := motion.tail._root_world() as Vector3
	var tip := motion.tail.points.back() as Vector3
	_check(tip.distance_to(tail_root) > motion.tail.total_length * 2.0 * 0.5, "Idle tail holds a comfortable open curve")
	var before := tip
	var idle_travel := 0.0
	for i in range(720):
		await _ticks(1)
		tip = motion.tail.points.back()
		idle_travel = maxf(idle_travel, tip.distance_to(before))
	_check(idle_travel < 0.04, "A resting tail stays quiet without an independent tip wiggle")

	# Use clear ground, then turn through a corner to exercise world-space contacts.
	player.spawn_position = Vector3(0, 0.1, 30)
	player.reset_to_spawn()
	await _ticks(20)
	Input.action_press("move_forward", 0.55)
	for i in range(140):
		await _ticks(1)
		_measure()
	Input.action_release("move_forward")
	Input.action_press("move_right", 0.55)
	for i in range(100):
		await _ticks(1)
		_measure()
	Input.action_release("move_right")
	await _ticks(60)
	_check(swing_frames > 20 and planted_frames > 100, "Walk includes lifted swing and planted stance phases")
	_check(maximum_contact_error < 0.05, "IK contact error stays below 5 cm through straight movement and turning")
	_check(maximum_stance_error < 0.03, "Actual posed paw pivots remain at planted contacts")
	_check(maximum_length_error < 0.001, "Tail solver preserves every exported segment length")
	_check(maximum_airborne_paws <= 2, "Ground walk always retains at least two stance paws")
	_check(paired_walk_frames == 0, "Turning synchronized the front or hind walking legs")
	for leg in motion.gait.legs:
		_check(not leg.swing, "Stopping completes recovery steps")
		for index in leg.indices:
			_check(motion.skeleton.get_bone_pose_scale(index).is_equal_approx(Vector3.ONE), "Gait does not stretch limb bones")
	var tail_count: int = motion.tail.history.size()
	_check(tail_count > 20, "Tail records the travelled path")
	player.reset_to_spawn()
	await _ticks(2)
	_check(motion.tail.history.size() < 5, "Reset clears the old tail trail")
	print("Rig metrics: max foot target error=%.4f m, max tail length error=%.6f m; swing frames=%d, planted frames=%d" % [maximum_contact_error, maximum_length_error, swing_frames, planted_frames])
	print("Per-leg maxima: ", per_leg, " idle tail travel: ", idle_travel)
	for failure in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: wing morph parity, toggle/scrub, tail extension/idle/lengths/reset, stance/swing and multi-joint IK")
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _measure() -> void:
	var airborne := 0
	var swinging_front := 0
	var swinging_hind := 0
	for leg in motion.gait.legs:
		maximum_contact_error = maxf(maximum_contact_error, float(leg.contact_error))
		if float(leg.contact_error) > float(per_leg.get(leg.name + ":error", 0.0)):
			per_leg[leg.name + ":error"] = leg.contact_error
			per_leg[leg.name + ":phase"] = leg.phase
			per_leg[leg.name + ":swing"] = leg.swing
			per_leg[leg.name + ":progress"] = leg.swing_progress
			per_leg[leg.name + ":body_position"] = player.position
		if leg.swing:
			swing_frames += 1
			airborne += 1
			swinging_front += int(leg.kind == "front")
			swinging_hind += int(leg.kind == "hind")
		else:
			planted_frames += 1
			var index: int = leg.indices[2]
			var deformation: Transform3D = motion.skeleton.get_bone_global_pose(index) * motion.skeleton.get_bone_global_rest(index).affine_inverse()
			var actual: Vector3 = motion.skeleton.to_global(deformation * (leg.end as Vector3))
			maximum_stance_error = maxf(maximum_stance_error, actual.distance_to(leg.anchor))
	maximum_airborne_paws = maxi(maximum_airborne_paws, airborne)
	paired_walk_frames += int(swinging_front == 2 or swinging_hind == 2)
	var start: Vector3 = motion.tail._root_world()
	for k in range(motion.tail.points.size()):
		var end: Vector3 = motion.tail.points[k]
		maximum_length_error = maxf(maximum_length_error, absf(start.distance_to(end) - float(motion.tail.lengths[k]) * 2.0))
		start = end


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
