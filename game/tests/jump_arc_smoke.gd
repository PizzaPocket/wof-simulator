extends SceneTree
## Actual physics and rig checks for the staged, higher quadruped jump.
var failures: Array[String] = []
var player: CharacterBody3D
var motion: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)

func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _trial(running: bool) -> void:
	for action in ["move_forward", "sprint", "jump"]:
		Input.action_release(action)
	player.spawn_position = Vector3(-38, 0.1, 35)
	player.reset_to_spawn()
	await _ticks(30)
	if running:
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await _ticks(150)
	var origin := player.global_position
	var height := origin.y
	var front_first := false
	var nose_up := false
	var nose_down := false
	var landed := false
	var max_support_error := 0.0
	Input.action_press("jump")
	for frame in range(120):
		await _ticks(1)
		if frame == 2:
			Input.action_release("jump")
		height = maxf(height, player.global_position.y)
		if player.locomotion_state == &"preparing":
			var front_released := true
			var hind_supported := true
			for leg in motion.gait.legs:
				if leg.kind == "front":
					front_released = front_released and leg.swing
				else:
					hind_supported = hind_supported and not leg.swing
				if not leg.swing:
					max_support_error = maxf(max_support_error, leg.contact_error)
			front_first = front_first or (front_released and hind_supported)
		elif player.locomotion_state == &"airborne":
			nose_up = nose_up or (player.velocity.y > 2.0 and motion.model.rotation.x < -0.12)
			nose_down = nose_down or (player.velocity.y < -2.0 and motion.model.rotation.x > 0.08)
		landed = landed or player.locomotion_state == &"landing"
		for index in range(motion.skeleton.get_bone_count()):
			_check(motion.skeleton.get_bone_pose(index).is_finite(), "Jump produced a non-finite bone pose")
	_check(height - origin.y > 3.6 and height - origin.y < 4.1, "Jump did not reach the intended higher apex")
	_check(front_first, "Forepaws did not release before hind-paw push-off")
	_check(max_support_error < 0.12, "Takeoff dragged a planted paw beyond anatomical reach")
	_check(nose_up and nose_down, "Body did not rotate from takeoff into the landing arc")
	_check(landed and player.locomotion_state == &"grounded", "Jump did not land and resume locomotion")
	print("%s jump: rise %.2f m; max supported-paw error %.3f m" % ["Running" if running else "Standing", height - origin.y, max_support_error])

func _run() -> void:
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion or not motion.jump or not motion.gait:
		printerr("Build Clay and load the jump/gait scripts before running jump arc checks")
		quit(1)
		return
	await _trial(false)
	await _trial(true)
	for message in failures:
		printerr("FAIL: " + message)
	if failures.is_empty():
		print("PASS: higher jump, fore-first takeoff, hind push, ascent/descent pitch and landing")
	quit(0 if failures.is_empty() else 1)
