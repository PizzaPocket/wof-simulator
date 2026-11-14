extends SceneTree
## Full player/rig integration for gaze, staged jump, deployment and flight modes.
var failures: Array[String] = []
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var max_gaze_step: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	# Continental flight speeds outgrow the small visual movement arena. Keep
	# a broad test-only landing surface for the cancellation/landing assertions.
	for child in scene.get_node("Ground").get_children():
		if child is CollisionShape3D: child.shape.size = Vector3(8000,1,8000)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion or not motion.gaze:
		printerr("Build Clay before running gaze/flight checks")
		quit(1)
		return
	await _ticks(60)
	var gaze = motion.gaze
	_check(gaze.indices.size() == 5, "Four measured neck sections and the head participate")
	player.pivot.rotation.y = PI / 2.0
	await _gaze_ticks(130)
	_check(absf(rad_to_deg(gaze.yaw) - 90.0) < 0.5, "Rear-side camera reaches the 90-degree yaw limit")
	var head: int = motion.skeleton.find_bone("head")
	var forward: Vector3 = motion.skeleton.get_bone_global_pose(head).basis.y.normalized()
	_check(rad_to_deg(atan2(forward.x, forward.z)) > 85.0, "Actual posed head turns with the distributed neck")
	var previous: float = gaze.yaw
	player.pivot.rotation.y = PI
	await _gaze_ticks(1)
	_check(gaze.front_stage and gaze.yaw > 0.5, "Front-stage entry starts a return instead of snapping")
	_check(absf(gaze.yaw - previous) < deg_to_rad(2.1), "Front-stage entry obeys the angular speed limit")
	await _gaze_ticks(150)
	_check(absf(gaze.yaw) < 0.003 and absf(gaze.pitch) < 0.003, "Front stage settles at authored neutral")
	player.pivot.rotation.y = -PI + 0.01
	await _gaze_ticks(2)
	_check(gaze.front_stage and absf(gaze.yaw) < 0.003, "Camera wrap behind front stage causes no gaze flip")
	player.pivot.rotation.y = -PI / 2.0
	await _gaze_ticks(130)
	_check(absf(rad_to_deg(gaze.yaw) + 90.0) < 0.5, "The opposite side tracks symmetrically")
	player.pivot.rotation.y = 0
	player.pivot.rotation.x = 0.75
	await _gaze_ticks(140)
	var up_delta: Transform3D = motion.skeleton.get_bone_global_pose(head) * motion.skeleton.get_bone_global_rest(head).affine_inverse()
	var up_aim: Vector3 = (motion.skeleton.global_basis * up_delta.basis * gaze.rest_aim).normalized()
	_check(absf(atan2(up_aim.y, Vector2(up_aim.x,up_aim.z).length()) - player.pivot.rotation.x) < 0.01, "Upward gaze aligns the mouth axis with camera elevation")
	player.pivot.rotation.x = -1.05
	await _gaze_ticks(100)
	var down_delta: Transform3D = motion.skeleton.get_bone_global_pose(head) * motion.skeleton.get_bone_global_rest(head).affine_inverse()
	var down_aim: Vector3 = (motion.skeleton.global_basis * down_delta.basis * gaze.rest_aim).normalized()
	_check(absf(atan2(down_aim.y, Vector2(down_aim.x,down_aim.z).length()) - player.pivot.rotation.x) < 0.01, "Downward gaze aligns the mouth axis with camera elevation")
	_check(max_gaze_step <= deg_to_rad(2.01), "Every measured gaze step is continuous and rate limited")
	for index in gaze.indices:
		_check(motion.skeleton.get_bone_pose_position(index).distance_to(motion.skeleton.get_bone_rest(index).origin) < 0.00001, "Gaze retains neck joint attachments")
		_check(motion.skeleton.get_bone_pose_scale(index).is_equal_approx(Vector3.ONE), "Gaze never stretches a neck segment")

	player.spawn_position = Vector3(0, 0.1, 30)
	player.reset_to_spawn()
	await _ticks(60)
	var home_height: float = motion.gait.model_home.y
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	_check(player.locomotion_state == &"preparing" and player.is_on_floor(), "Jump preparation precedes liftoff")
	var deepest := home_height
	for i in range(20):
		await _ticks(1)
		deepest = minf(deepest, motion.model.position.y)
	_check(deepest < home_height - 0.08, "Preparation visibly compresses the body over its paws")
	_check(player.locomotion_state == &"airborne" and player.velocity.y > 0, "Push-off launches a normal jump")
	await _ticks(10)
	_check(motion.jump.last_state == &"airborne", "Airborne recovery uses the jump pose layer")
	var saw_landing := false
	for i in range(100):
		await _ticks(1)
		saw_landing = saw_landing or player.locomotion_state == &"landing"
	_check(saw_landing and player.locomotion_state == &"grounded", "A single jump passes through landing back to walking")

	# Holding the button is one press, so it cannot accidentally enable flight.
	Input.action_press("jump")
	await _ticks(100)
	_check(player.locomotion_state != &"flying", "Holding jump never counts as a double jump")
	Input.action_release("jump")
	await _ticks(30)
	player.pivot.rotation.x = 0
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	await _ticks(20)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	_check(player.locomotion_state == &"flying", "A second airborne jump press activates flight")
	player.pivot.rotation.x = 0.2
	Input.action_press("recenter")
	await _ticks(2)
	Input.action_release("recenter")
	_check(absf(player.pivot.rotation.x) < 0.001, "Flight recenter levels the view for horizon glide")
	# Allow the initial powered launch strokes to finish before checking glide.
	await _ticks(180)
	_check(motion.fold_amount < 0.01, "Flight deploys the full glide span")
	_check(player.flight_mode == &"gliding" and motion.flight.flap_blend < 0.01, "Horizon aim glides without flapping")
	var level_height := player.position.y
	await _ticks(60)
	_check(absf(player.position.y - level_height) < 0.05, "Settled horizon glide maintains altitude")
	_check(Vector2(player.velocity.x, player.velocity.z).length() > 10.0, "Glide carries the dragon forward without requiring stick input")

	player.pivot.rotation.x = 0.4
	var climb_height := player.position.y
	var minimum_stroke := 10.0
	var maximum_stroke := -10.0
	for i in range(150):
		await _ticks(1)
		minimum_stroke = minf(minimum_stroke, motion.flight.stroke)
		maximum_stroke = maxf(maximum_stroke, motion.flight.stroke)
	_check(player.flight_mode == &"climbing" and player.position.y > climb_height + 5.0, "Upward camera aim produces sustained altitude gain")
	_check(motion.flight.flap_blend > 0.95 and maximum_stroke - minimum_stroke > 0.6, "Climbing has a steady articulated flap cycle")
	_check(player.velocity.y <= float(player.flight_settings.max_climb_m_s) + 0.01, "Climb speed respects its configured limit")
	player.pivot.rotation.x = -0.20
	var descent_height := player.position.y
	# Stronger ascent carries upward momentum while vertical acceleration
	# reverses it; allow the descent to recover that height before comparing.
	await _ticks(360)
	_check(player.flight_mode == &"gliding" and player.position.y < descent_height, "Downward aim descends in glide mode")
	_check(motion.flight.flap_blend < 0.001 and motion.fold_amount < 0.01, "Descending glide eases back to extended wings")
	for i in range(motion.skeleton.get_bone_count()):
		_check(motion.skeleton.get_bone_pose(i).is_finite(), "All flight poses remain finite")

	Input.action_press("cancel_flight")
	await _ticks(2)
	Input.action_release("cancel_flight")
	_check(player.locomotion_state == &"airborne", "End-flight input returns to falling/landing physics")
	await _ticks(210)
	_check(player.is_on_floor() and player.locomotion_state == &"grounded", "Flight cancellation lands safely and resumes the walk solver")
	# Fast double taps are buffered until takeoff, rather than ignored in crouch.
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	await _ticks(2)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	_check((player.queued_flight and player.locomotion_state == &"preparing") or player.locomotion_state == &"flying", "A rapid double tap queues or enters flight after the shortened preparation")
	await _ticks(20)
	_check(player.locomotion_state == &"flying", "Queued flight activates only after takeoff")
	player.reset_to_spawn()
	await _ticks(3)
	_check(player.locomotion_state != &"flying" and motion.flight.flap_blend < 0.001, "Reset clears flight and wing-cycle state")
	for failure in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: gaze limits/front-stage/continuity, cervical attachments, jump/landing, airborne and buffered double jump, climb flap, level/descent glide and reset")
	print("Max gaze step: %.3f degrees; sampled flap range: %.1f degrees" % [rad_to_deg(max_gaze_step), rad_to_deg(maximum_stroke - minimum_stroke)])
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _gaze_ticks(count: int) -> void:
	for i in range(count):
		var before: float = motion.gaze.yaw
		await physics_frame
		max_gaze_step = maxf(max_gaze_step, absf(motion.gaze.yaw - before))


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
