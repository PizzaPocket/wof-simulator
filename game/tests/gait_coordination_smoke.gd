extends SceneTree
## Exercise the real controller: walk rhythm, easy/sprint separation, contact
## convergence, sharp turns, and a lightly deflected stick recovering from a turn.
var player: CharacterBody3D
var gait: RefCounted
var failures: Array[String] = []
var max_error := 0.0
var walk_pairs := 0
var contact_count := 0
var contact_width := 0.0
var reached_speed := 0.0
var worst: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)

func _ticks(count: int, measure: bool = false) -> void:
	for i in range(count):
		await physics_frame
		if not measure:
			continue
		var front := 0
		var hind := 0
		reached_speed = maxf(reached_speed, Vector2(player.velocity.x, player.velocity.z).length())
		for leg in gait.legs:
			if float(leg.contact_error) > max_error:
				worst = {"leg": leg.name, "phase": leg.phase, "swing": leg.swing, "position": player.position, "speed": player.velocity.length(), "running": gait.gallop.active, "blend": gait.gallop.blend}
			max_error = maxf(max_error, float(leg.contact_error))
			if leg.swing:
				front += int(leg.kind == "front")
				hind += int(leg.kind == "hind")
			elif gait.gallop.active and leg.phase < 0.07:
				var local: Vector3 = gait.rig.to_local(leg.last_target)
				contact_width += absf(local.x / float(leg.end.x))
				contact_count += 1
		if not gait.gallop.active:
			walk_pairs += int(front == 2 or hind == 2)

func _reset(strength: float, sprint: bool = false) -> void:
	for action in ["move_forward", "move_left", "move_right", "sprint"]:
		Input.action_release(action)
	player.spawn_position = Vector3(-38, 0.1, 35)
	player.reset_to_spawn()
	await _ticks(20)
	Input.action_press("move_forward", strength)
	if sprint:
		Input.action_press("sprint")
	await _ticks(90)
	max_error = 0.0
	contact_count = 0
	contact_width = 0.0
	reached_speed = 0.0

func _run() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
		InputMap.action_erase_events(action)
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	gait = player.get_node("Visual").motion.gait
	for strength in [0.25, 0.55]:
		for direction in ["move_left", "move_right"]:
			await _reset(strength)
			await _ticks(90, true)
			Input.action_release("move_forward")
			Input.action_press(direction, strength)
			await _ticks(150, true)
			var late_position := player.global_position
			await _ticks(30, true)
			var late_distance := Vector2(player.position.x - late_position.x, player.position.z - late_position.z).length()
			_check(not gait.gallop.active, "Partial stick unexpectedly entered gallop")
			_check(max_error < 0.05, "Walk corner exceeds anatomical reach")
			_check(reached_speed > (0.3 if strength < 0.3 else 2.0), "Support pacing locked the walk")
			_check(late_distance > (0.08 if strength < 0.3 else 0.6), "Walking stalled after the turn")
			var expected: Vector3 = Vector3.LEFT if direction == "move_left" else Vector3.RIGHT
			var facing := Vector3(-sin(player.get_node("Visual").rotation.y), 0, -cos(player.get_node("Visual").rotation.y))
			_check(facing.dot(expected) > 0.95, "Walk did not finish its 90-degree turn")
	_check(walk_pairs == 0, "A turn synchronized both front or both hind walking legs")
	var widths: Array[float] = []
	for sprint in [false, true]:
		await _reset(1.0, sprint)
		await _ticks(120, true)
		_check(gait.gallop.active, "Full stick did not select a running gait")
		_check(contact_count > 8, "Insufficient running contacts to measure width")
		widths.append(contact_width / maxf(contact_count, 1))
		_check(max_error < 0.08, "Straight run exceeds anatomical reach")
		for direction in ["move_left", "move_right"]:
			Input.action_release("move_forward")
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press(direction)
			await _ticks(150, true)
		_check(max_error < 0.08, "Running corner exceeds anatomical reach")
		print("%s: max contact error %.4f m, relative track width %.3f" % ["Sprint" if sprint else "Easy run", max_error, widths.back()])
		if max_error >= 0.08:
			print("Worst corner contact: ", worst)
	_check(widths[0] < 0.98 and widths[0] > 0.8, "Easy run footprint convergence is out of range")
	_check(widths[1] < widths[0] - 0.08 and widths[1] > 0.6, "Sprint must converge further without collapsing onto the midline")
	for action in ["move_forward", "move_left", "move_right", "sprint"]:
		Input.action_release(action)
	await _ticks(150)
	_check(not gait.gallop.active, "Stopping did not return to the walk")
	for leg in gait.legs:
		_check(not leg.swing, "Stopping left a paw in recovery")
	for failure in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: staggered walking turns, light-stick recovery, speed-driven running, narrower sprint contacts, reachable running turns and settled stop")
	quit(0 if failures.is_empty() else 1)
