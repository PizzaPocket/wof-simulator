extends SceneTree
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var failures: Array[String] = []
var maximum_length_error: float = 0.0
var maximum_socket_error: float = 0.0
var frames: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	await _ticks(90)
	for leg in motion.gait.legs:
		_check(leg.soft >= 0, "Each proximal limb has a volume/attachment helper")
		_check((leg.twist >= 0) == (leg.kind == "front"), "Forearm rotation is available to arms, not the hind shanks")
		_check(leg.wrist_helpers.size() == (2 if leg.kind == "front" else 0), "Foreleg carpus has intermediate volume controls")
	var anchors: Dictionary = {}
	for leg in motion.gait.legs:
		anchors[leg.name] = leg.anchor
	Input.action_press("arm_preview")
	await _ticks(2)
	Input.action_release("arm_preview")
	await _ticks(100)
	_check(motion.arm_inspection.mode == 1 and motion.arm_inspection.weight > 0.99, "Reach inspection blends in through the user control")
	Input.action_press("arm_preview")
	await _ticks(2)
	Input.action_release("arm_preview")
	await _ticks(100)
	for leg in motion.gait.legs:
		if leg.name == "front.L":
			_check(float(leg.forearm_twist) > deg_to_rad(50), "Palm inspection rotates the forearm, not only the wrist")
			var shoulder: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[0]).origin
			var elbow: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[1]).origin
			_check(elbow.y < shoulder.y - .2, "Arm-use elbow stays below the shoulder")
			_check(absf(elbow.x - shoulder.x) < .3, "Arm-use elbow does not corkscrew far out from the body")
			var hand_pose: Transform3D = motion.skeleton.get_bone_global_pose(leg.indices[2])
			var hand_delta: Transform3D = hand_pose * motion.skeleton.get_bone_global_rest(leg.indices[2]).affine_inverse()
			var palm_axis: Vector3 = (hand_delta.basis * (leg.foot_vector as Vector3)).normalized()
			var shaft: Vector3 = (hand_pose.origin - elbow).normalized()
			_check(acos(clampf(shaft.dot(palm_axis), -1, 1)) < deg_to_rad(35), "Palm inspection retains a modest wrist bend relative to the forearm")
		else:
			_check((leg.anchor as Vector3).distance_to(anchors[leg.name]) < .01, "Other paws retain their support contacts")
	Input.action_press("move_forward")
	await _ticks(120)
	Input.action_release("move_forward")
	_check(motion.arm_inspection.mode == 0 and motion.arm_inspection.weight < .01, "Walking returns the inspected arm to support")
	await _ticks(45)
	await _jump()
	await _ticks(20)
	await _jump()
	player.pivot.rotation.x = .25
	await _ticks(150)
	_check(player.locomotion_state == &"flying", "Flight pose is reached")
	var heights: Dictionary = {}
	for leg in motion.gait.legs:
		var a: Vector3 = motion.skeleton.to_global(motion.skeleton.get_bone_global_pose(leg.indices[0]).origin)
		var b: Vector3 = motion.skeleton.to_global(motion.skeleton.get_bone_global_pose(leg.indices[1]).origin)
		var c: Vector3 = motion.skeleton.to_global(motion.skeleton.get_bone_global_pose(leg.indices[2]).origin)
		_check((b - a).normalized().dot(Vector3.DOWN) > (0.25 if leg.kind == "hind" else 0.40), "Carried upper limbs have a controlled downward component")
		_check((c - b).normalized().dot(Vector3.DOWN) > .55, "Carried lower limbs stay engaged without horizontal forced folds")
		var knee := acos(clampf((a - b).normalized().dot((c - b).normalized()), -1, 1))
		_check(knee > deg_to_rad(60 if leg.kind == "hind" else 75) and knee < deg_to_rad(135), "Flight elbow/knee retains active flexion rather than a limp near-straight hang")
		heights[leg.name] = c.y
	_check(absf(heights["hind.L"] - heights["hind.R"]) > .04, "Hind flight carriage retains deliberate asymmetry")
	_check(absf(heights["front.L"] - heights["front.R"]) > .01, "Forelimb carriage also retains modest asymmetry")
	player.pivot.rotation.x = -.25
	await _ticks(100)
	Input.action_press("cancel_flight")
	await _ticks(2)
	Input.action_release("cancel_flight")
	await _ticks(240)
	player.reset_to_spawn()
	await _ticks(15)
	_check(motion.arm_inspection.mode == 0 and motion.arm_inspection.weight == 0, "Reset clears arm inspection")
	_check(maximum_length_error < .0001, "All full-leg poses preserve measured link lengths")
	_check(maximum_socket_error < .0001, "Wing sockets stay at the configured placement without frame-to-frame drift")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("Limb metrics: %d frames, max length error %.8f model units" % [frames, maximum_length_error])
	if failures.is_empty():
		print("PASS: support-to-arm use, forearm-relative wrist pose/volume controls, stable sockets, engaged asymmetrical flight, landing and reset")
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
		var target: Array = motion.config.wings.socket_target_model
		for side in ["L", "R"]:
			var index: int = motion.skeleton.find_bone("wing_humerus." + side)
			var expected := Vector3(target[0] * (1 if side == "L" else -1), target[1], target[2])
			maximum_socket_error = maxf(maximum_socket_error, expected.distance_to(motion.skeleton.get_bone_global_pose(index).origin))
		for leg in motion.gait.legs:
			var a: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[0]).origin
			var b: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[1]).origin
			var c: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[2]).origin
			for helper in leg.wrist_helpers:
				_check(motion.skeleton.get_bone_global_pose(helper).origin.distance_to(c) < .0001, "Carpal volume controls remain centered on the actual wrist joint")
			maximum_length_error = maxf(maximum_length_error, absf(a.distance_to(b) - float(leg.length_a)))
			maximum_length_error = maxf(maximum_length_error, absf(b.distance_to(c) - float(leg.length_b)))

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
