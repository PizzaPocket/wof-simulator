extends SceneTree
## Behavioral checks on the actual rig: recovery, quiet idle, launch and speed.
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion:
		quit(1)
		return
	await _ticks(90)
	var tail = motion.tail
	tail.preview_mode = 1
	await _ticks(240)
	var wrapped_reach: float = tail._root_world().distance_to(tail.points.back())
	_check(wrapped_reach < tail.total_length * 2.0 * 0.7, "Preview actually forms a substantial wrap before the recovery check")
	tail.preview_mode = 0
	await _ticks(480)
	var recovered_reach: float = tail._root_world().distance_to(tail.points.back())
	_check(recovered_reach > wrapped_reach + 0.5 and recovered_reach > tail.total_length * 2.0 * 0.5, "A cramped wrap relaxes without requiring a perfectly straight tail")
	print("Tail reach: wrapped %.2f m, recovered %.2f m; carries %d" % [wrapped_reach, recovered_reach, tail.contacts.fallback_count])
	# Comfortable side curves should persist without a separate tip animation.
	var maximum_idle_drift := 0.0
	var original_curl: float = tail.settings.preview_curl_degrees
	tail.settings.preview_curl_degrees = 140.0
	for mode in [1, 2]:
		tail.preview_mode = mode
		await _ticks(240)
		tail.preview_mode = 0
		await _ticks(240)
		var lateral: float = (tail.points.back() - tail._root_world()).dot(motion.skeleton.global_basis.x.normalized())
		_check(lateral > 0.7 if mode == 1 else lateral < -0.7, "A comfortable curve can rest on either side")
		var initial: Vector3 = motion.skeleton.global_basis.inverse() * (tail.points.back() - tail._root_world())
		for i in range(600):
			await _ticks(1)
			var tip: Vector3 = motion.skeleton.global_basis.inverse() * (tail.points.back() - tail._root_world())
			maximum_idle_drift = maxf(maximum_idle_drift, initial.distance_to(tip))
		_check(tail.recovery_weight < 0.01, "Comfortable curved rest does not trigger untangling")
	tail.settings.preview_curl_degrees = original_curl
	_check(maximum_idle_drift < 0.04, "Resting tip stays quiet instead of wiggling or straightening")

	player.spawn_position = Vector3(0, 0.1, 35)
	player.reset_to_spawn()
	await _ticks(60)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	await _ticks(20)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	player.pivot.rotation.x = 0.0
	await _ticks(25)
	_check(motion.flight.flap_blend > 0.7 and motion.flight.launch_effort > 0.9, "Level takeoff begins with powered wingbeats")
	var forearm: int = motion.skeleton.find_bone("wing_forearm.L")
	var wrist: int = motion.skeleton.find_bone("wing_carpal.L")
	var forearm_rotation: Quaternion = motion.skeleton.get_bone_pose_rotation(forearm)
	var wrist_rotation: Quaternion = motion.skeleton.get_bone_pose_rotation(wrist)
	var elbow_excursion := 0.0
	var wrist_excursion := 0.0
	for i in range(60):
		await _ticks(1)
		elbow_excursion = maxf(elbow_excursion, forearm_rotation.angle_to(motion.skeleton.get_bone_pose_rotation(forearm)))
		wrist_excursion = maxf(wrist_excursion, wrist_rotation.angle_to(motion.skeleton.get_bone_pose_rotation(wrist)))
	_check(elbow_excursion > 0.03 and wrist_excursion > 0.03, "Recovery articulates elbow and wrist relative to their parents")
	await _ticks(120)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check(speed > player.sprint_speed + 3.0, "Cruise is meaningfully faster than ground sprinting")
	_check(motion.flight.flap_blend < 0.01 and motion.fold_amount < 0.01, "Launch effort settles into a fully spread level glide")
	Input.action_press("sprint")
	await _ticks(60)
	Input.action_release("sprint")
	_check(Vector2(player.velocity.x, player.velocity.z).length() > speed + 7.0, "Flight boost increases traversal speed promptly")
	player.pivot.rotation.x = 0.3
	await _ticks(90)
	_check(player.velocity.y > 5.0 and motion.flight.flap_blend > 0.95, "Climbing restores sustained powered flight")
	player.reset_to_spawn()
	await _ticks(2)
	_check(motion.flight.launch_effort == 0.0 and tail.recovery_weight == 0.0, "Reset clears active flight and tail posture state")
	for failure in failures: printerr("FAIL: " + failure)
	print("Quiet rest drift %.4f m; cruise %.1f m/s; elbow/wrist excursion %.1f/%.1f degrees" % [maximum_idle_drift, speed, rad_to_deg(elbow_excursion), rad_to_deg(wrist_excursion)])
	if failures.is_empty(): print("PASS: cramped-tail recovery, stable left/right resting curves, quiet tip, articulated takeoff and flight")

	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _ticks(count: int) -> void:
	for i in range(count): await physics_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
