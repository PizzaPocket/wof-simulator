extends SceneTree
## Real gait/jump/flight checks for a connected, length-preserving digit hierarchy.
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var failures: Array[String] = []
var frames: int = 0
var max_joint_gap: float = 0.0
var max_segment_error: float = 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	await _ticks(60)
	for leg in motion.gait.legs:
		_check(leg.digits.size() == (5 if leg.kind == "front" else 4), "Correct authored main-digit/thumb count: " + leg.name)
		for digit in leg.digits:
			var root_name: String = motion.skeleton.get_bone_name(digit.bones[0])
			var thumb := root_name.begins_with("fthumb")
			_check(digit.bones.size() == (2 if thumb else 3), "Each digit has its modeled phalangeal controls: " + root_name)
			if not thumb:
				var parent: int = motion.skeleton.get_bone_parent(digit.bones[0])
				var parent_name: String = motion.skeleton.get_bone_name(parent)
				_check(parent_name.begins_with("fmeta" if leg.kind == "front" else "hmeta"), "Each main digit continues from its own metapodial ray")
	Input.action_press("move_forward")
	await _ticks(240)
	Input.action_press("move_right")
	await _ticks(90)
	Input.action_release("move_right")
	Input.action_release("move_forward")
	await _ticks(45)
	await _jump()
	await _ticks(100)
	await _jump()
	await _ticks(20)
	await _jump()
	player.pivot.rotation.x = 0.2
	await _ticks(160)
	_check(player.locomotion_state == &"flying", "Flight posture is reached")
	motion.enabled = false
	for leg in motion.gait.legs:
		motion.gait._pose_digits(leg, float(leg.pitch), 0.0, false)
		var neutral: Dictionary = {}
		for digit in leg.digits:
			for index in digit.bones:
				neutral[index] = motion.skeleton.get_bone_pose_rotation(index)
		motion.gait._pose_digits(leg, float(leg.pitch), float(leg.toe_curl), false)
		for digit in leg.digits:
			for index in digit.bones:
				var difference: Quaternion = (neutral[index] as Quaternion).inverse() * motion.skeleton.get_bone_pose_rotation(index)
				var angle: float = difference.get_angle()
				_check(angle > deg_to_rad(1.0), "Every phalanx contributes to flight curl")
	motion.enabled = true
	Input.action_press("cancel_flight")
	await _ticks(2)
	Input.action_release("cancel_flight")
	await _ticks(220)
	player.reset_to_spawn()
	await _ticks(30)
	_check(max_joint_gap < 0.0001, "Digit joint locations remain inherited through walk/jump/flight/landing")
	_check(max_segment_error < 0.0001, "Phalangeal controls never stretch their bones")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("Feet metrics: %d frames; max joint gap %.8f model units, max segment error %.8f model units" % [frames, max_joint_gap, max_segment_error])
	if failures.is_empty():
		print("PASS: per-digit metapodial/phalangeal hierarchy, continuous joint roots, distributed flexion, walk/jump/flight/landing/reset")
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _jump() -> void:
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")

func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		frames += 1
		for leg in motion.gait.legs:
			for digit in leg.digits:
				for index in digit.bones:
					var parent: int = motion.skeleton.get_bone_parent(index)
					var rest: Transform3D = motion.skeleton.get_bone_global_rest(index)
					var parent_rest: Transform3D = motion.skeleton.get_bone_global_rest(parent)
					var parent_pose: Transform3D = motion.skeleton.get_bone_global_pose(parent)
					var pose: Transform3D = motion.skeleton.get_bone_global_pose(index)
					var expected: Vector3 = parent_pose * parent_rest.affine_inverse() * rest.origin
					max_joint_gap = maxf(max_joint_gap, expected.distance_to(pose.origin))
					var children: PackedInt32Array = motion.skeleton.get_bone_children(index)
					if not children.is_empty():
						var next: int = children[0]
						var length: float = rest.origin.distance_to(motion.skeleton.get_bone_global_rest(next).origin)
						max_segment_error = maxf(max_segment_error, absf(length - pose.origin.distance_to(motion.skeleton.get_bone_global_pose(next).origin)))

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
