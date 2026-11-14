extends SceneTree
var player: CharacterBody3D
var motion: Node
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _check(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
func _speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()
func _reset() -> void:
	for action in ["move_forward", "sprint", "jump"]:
		Input.action_release(action)
	player.spawn_position = Vector3(-38, 0.1, 35)
	player.reset_to_spawn()
	await _ticks(30)
func _jump_trial(running: bool) -> void:
	await _reset()
	Input.action_press("move_forward")
	if running:
		Input.action_press("sprint")
	await _ticks(150 if running else 75)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	var delay := 2
	while player.locomotion_state == &"preparing" and delay < 30:
		await _ticks(1)
		delay += 1
	_check(delay <= 10, "Staged takeoff delayed longer than 167 ms")
	var origin := player.global_position
	var takeoff := _speed()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var min_air_speed := takeoff
	for i in range(90):
		await _ticks(1)
		if player.is_on_floor():
			break
		min_air_speed = minf(min_air_speed, _speed())
	var distance := Vector2(player.global_position.x - origin.x, player.global_position.z - origin.z).length()
	_check(min_air_speed >= takeoff * 0.98, "Releasing input erased takeoff momentum")
	_check(distance > (13.0 if running else 3.8), "Jump horizontal range too short")
	_check(player.locomotion_state != &"flying", "Single jump activated flight")
	await _ticks(12)
	_check(player.locomotion_state == &"grounded", "Moving landing delayed resuming the ground gait")
	print("%s jump: takeoff %d ticks; speed %.2f m/s; reach %.2f m" % ["Run" if running else "Walk", delay, takeoff, distance])
func _run() -> void:
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion or not motion.jump or not motion.gait:
		printerr("Build Clay and load the jump/gait scripts before running run/jump checks")
		quit(1)
		return
	await _reset()
	Input.action_press("move_forward")
	await _ticks(60)
	# Support pacing briefly slows individual steps; measure sustained travel
	# instead of sampling one arbitrary foot-contact phase.
	var walk_origin := player.global_position
	await _ticks(60)
	var walk_distance := Vector2(player.global_position.x - walk_origin.x, player.global_position.z - walk_origin.z).length()
	_check(walk_distance > 5.3, "Full-rig walk remains too slow over a full second")
	_check(motion.gait.gallop.active and motion.gait.gallop.extension < 0.1, "Full stick must enter the easy run without sprint")
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = true
	Input.parse_input_event(event)
	await _ticks(2)
	_check(Input.is_action_pressed("sprint"), "Controller LB/L1 does not map to run")
	var suspensions := 0
	var contacts := 0
	var max_error := 0.0
	var peak_speed := 0.0
	var suspension_distance := 0.0
	var max_bound_distance := 0.0
	var worst: Dictionary = {}
	var sprint_low := INF
	var sprint_high := -INF
	var forearm_min := INF
	var forearm_max := -INF
	var hand_reach := 0.0
	for i in range(180):
		var previous_position := player.global_position
		await _ticks(1)
		peak_speed = maxf(peak_speed, _speed())
		var gallop: RefCounted = motion.gait.gallop
		if gallop.active and gallop.blend > 0.99:
			if gallop.extension > 0.95:
				sprint_low = minf(sprint_low, motion.model.position.y)
				sprint_high = maxf(sprint_high, motion.model.position.y)
			if gallop.suspension:
				suspension_distance += player.global_position.distance_to(previous_position)
			else:
				max_bound_distance = maxf(max_bound_distance, suspension_distance)
				suspension_distance = 0.0
			suspensions += int(gallop.suspension)
			contacts += int(gallop.planted_count > 0)
			for leg in motion.gait.legs:
				if gallop.extension > 0.95 and leg.kind == "front" and not leg.swing:
					var shoulder: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[0]).origin
					var elbow: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[1]).origin
					var wrist: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[2]).origin
					var angle := rad_to_deg((shoulder - elbow).angle_to(wrist - elbow))
					forearm_min = minf(forearm_min, angle)
					forearm_max = maxf(forearm_max, angle)
					var forward := Vector3(-sin(player.get_node("Visual").rotation.y), 0, -cos(player.get_node("Visual").rotation.y))
					hand_reach = maxf(hand_reach, (motion.skeleton.to_global(wrist) - motion.skeleton.to_global(shoulder)).dot(forward))
				if leg.contact_error > max_error:
					worst = {"leg": leg.name, "phase": leg.phase, "swing": leg.swing, "pitch": leg.pitch}
				max_error = maxf(max_error, leg.contact_error)
				for index in leg.indices:
					_check(motion.skeleton.get_bone_pose_scale(index).is_equal_approx(Vector3.ONE), "Gallop stretches limb bones")
	_check(peak_speed > 17.5, "Run does not build to the faster gallop speed")
	_check(motion.gait.gallop.extension > 0.95, "Sprint must extend the gallop rather than replay the easy run")
	_check(max_bound_distance > 3.0, "Sprint lacks a distinct forward bound")
	_check(sprint_high - sprint_low > 0.32, "Sprint lacks whole-body compression and flight")
	_check(forearm_max - forearm_min > 15.0, "Planted sprint forearms do not load and extend")
	_check(hand_reach > 1.1, "Sprint hands do not reach far enough ahead of the shoulders")
	_check(suspensions > 5 and contacts > 20, "Run lacks alternating support and suspension")
	_check(max_error < 0.08, "Gallop targets exceed anatomical limb reach")
	print("Gallop: peak %.2f m/s; suspension %d, support %d frames; max paw target error %.4f m" % [peak_speed, suspensions, contacts, max_error])
	print("Worst gallop target: ", worst)
	print("Longest gallop suspension: %.2f m" % max_bound_distance)
	print("Sprint body travel: %.3f m; supported elbow range: %.1f to %.1f degrees" % [sprint_high - sprint_low, forearm_min, forearm_max])
	print("Sprint wrist reach ahead of shoulder: %.3f m" % hand_reach)
	# Releasing input in suspension must not brake until the next contact.
	for i in range(60):
		if motion.gait.gallop.suspension:
			break
		await _ticks(1)
	var carried_speed := _speed()
	Input.action_release("move_forward")
	await _ticks(1)
	_check(absf(_speed() - carried_speed) < 0.01, "Gallop brakes in mid-bound")
	Input.action_press("move_forward")
	event.pressed = false
	Input.parse_input_event(event)
	Input.action_press("move_forward", 0.5)
	await _ticks(60)
	_check(not motion.gait.gallop.active, "Walk transition remained in gallop")
	await _jump_trial(false)
	await _jump_trial(true)
	await _reset()
	Input.action_press("jump")
	await _ticks(1)
	Input.action_release("jump")
	await _ticks(2)
	Input.action_press("jump")
	await _ticks(1)
	Input.action_release("jump")
	await _ticks(12)
	_check(player.locomotion_state == &"flying", "Rapid double jump lost buffered flight activation")
	for failure in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: faster walk, distinct supported/suspended gallop, controller run, responsive jumps, preserved air momentum and double-jump flight")
	quit(0 if failures.is_empty() else 1)
