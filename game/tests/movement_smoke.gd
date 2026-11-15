extends SceneTree
## Run: godot --headless --path game --script res://tests/movement_smoke.gd
## Uses real physics ticks and injected input; no Bluetooth hardware is required.

var failures: Array[String] = []
var player: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	# Isolate controller physics from the gait's support-driven pacing. The
	# separate motion test exercises the complete player + gait integration.
	if player.get_node("Visual").motion:
		player.get_node("Visual").motion.enabled = false
	await _ticks(45)
	_check(player.is_on_floor(), "Player settles on the ground")
	_check(InputMap.action_get_events("move_forward").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_W), "W uses a physical keyboard binding")
	_check(InputMap.action_get_events("move_forward").any(func(e): return e is InputEventJoypadMotion and e.device == -1 and e.axis == JOY_AXIS_LEFT_Y), "Left stick accepts any controller")

	var origin := player.position
	Input.action_press("move_forward")
	await _ticks(60)
	_check(player.position.z < origin.z - 3.0, "Forward input moves forward relative to camera")
	_check(absf(_speed() - player.walk_speed) < 0.15, "Walk reaches configured speed")
	Input.action_press("move_right")
	await _ticks(25)
	_check(_speed() <= player.walk_speed + 0.05, "Diagonal input does not increase speed")
	Input.action_release("move_right")
	Input.action_press("sprint")
	await _ticks(35)
	_check(_speed() > player.walk_speed + 3.0, "Sprint accelerates above walking speed")
	_release()
	await _ticks(30)
	_check(_speed() < 0.05, "Releasing input brakes to a stop")

	player.reset_to_spawn()
	await _ticks(5)
	Input.action_press("move_forward", 0.5)
	await _ticks(35)
	var analog_speed := _speed()
	_check(analog_speed > 0.5 and analog_speed < player.walk_speed * 0.65, "Partial stick input gives slower movement")
	_release()
	player.reset_to_spawn()
	await _ticks(5)
	var axis := InputEventJoypadMotion.new()
	axis.device = 0
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.1
	Input.parse_input_event(axis)
	await _ticks(5)
	_check(_speed() < 0.05, "Stick drift inside the deadzone does not move Clay")
	axis = axis.duplicate()
	axis.axis_value = 0.7
	Input.parse_input_event(axis)
	await _ticks(25)
	_check(player.velocity.x > 1.0 and player.velocity.x < player.walk_speed, "Joypad axis events drive analog movement")
	axis = axis.duplicate()
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	_release()
	player.reset_to_spawn()
	await _ticks(5)
	player.get_node("CameraPivot").rotation.y = PI / 2.0
	origin = player.position
	Input.action_press("move_forward")
	await _ticks(30)
	_check(player.position.x < origin.x - 1.0, "Movement follows a rotated camera")
	_release()
	player.reset_to_spawn()
	await _ticks(10)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	_check(player.locomotion_state == &"preparing", "Jump starts with a grounded preparation")
	await _ticks(18)
	_check(player.position.y > 0.1 and player.velocity.y > 0, "Jump leaves the ground")
	await _ticks(80)
	_check(player.is_on_floor(), "Jump lands on solid ground")

	# Move into the arena wall; the physics capsule must stay inside it.
	player.position = Vector3(57, 0.05, 10)
	Input.action_press("move_right")
	await _ticks(60)
	# Any solid surface can be climbed, so walking into a wall either stops against it or grips it.
	_check(player.position.x < 59.5 and (player.is_on_wall() or player.locomotion_state == &"climbing"), "Collision prevents walking through walls (the claws may grip it)")
	_release()
	player.position.y = -25
	await _ticks(2)
	_check(player.position.distance_to(player.spawn_position) < 0.2, "Falling out of bounds respawns safely")
	_check(player.get_node("CameraPivot/SpringArm3D").get_child(0).current, "Follow camera is active")

	# A generated GLB must include the rig and portable vertex colours.
	var visual := player.get_node("Visual")
	if FileAccess.file_exists("res://assets/clay.glb"):
		_check(visual.model_loaded, "Generated Clay model loads")
		var rigs := visual.find_children("*", "Skeleton3D", true, false)
		_check(not rigs.is_empty(), "Clay retains the imported skeleton")
		var meshes := visual.find_children("*", "MeshInstance3D", true, false)
		_check(not meshes.is_empty(), "Clay has a rendered mesh")
		if not meshes.is_empty():
			_check(meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null, "Clay carries portable vertex colours")
			var material: Material = meshes[0].get_active_material(0)
			_check(material is ShaderMaterial or (material is StandardMaterial3D and material.vertex_color_use_as_albedo), "Clay displays its procedural material or portable color fallback")
	else:
		_check(not visual.model_loaded and visual.get_child_count() > 0, "Fresh clone has a visible placeholder")

	for failure in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: movement, analog speed, camera, jump, collision, reset and model integration")
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _release() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(action)


func _speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
