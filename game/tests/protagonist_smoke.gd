extends SceneTree
## Drives real input and checks ownership, camera, locomotion and the saved roster.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func tap(action: StringName) -> void:
	Input.action_press(action)
	await ticks(2)
	Input.action_release(action)
	await ticks(2)

func run() -> void:
	var village_scene := preload("res://scenes/mudwing_wetlands.tscn")
	var save_path := OS.get_temp_dir().path_join("wof-roster-test-%d.cfg" % OS.get_process_id())
	var world := village_scene.instantiate()
	world.roster_save_path = save_path
	world.install_cast = false # these tests cover the older meet-to-unlock behaviour
	root.add_child(world)
	await ticks(10)
	var clay = world.get_node("Clay")
	var umber = world.get_node("Umber")
	var kai = world.get_node("Kai")
	var roster = world.get_node("Protagonists")
	var chat = world.get_node("Conversations")
	var camera := root.get_camera_3d()
	var x_events := InputMap.action_get_events("possess_protagonist")
	check(x_events.any(func(event): return event is InputEventKey and event.physical_keycode == KEY_X), "Keyboard X switches protagonists")
	check(x_events.any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X), "Gamepad X switches protagonists")
	check(roster.unlocked == PackedStringArray(["clay"]), "Clay is the only starting unlock")
	clay.position = kai.position + Vector3(3, 0.05, 0)
	await ticks(10)
	var clay_before: Vector3 = clay.position
	await tap(&"possess_protagonist")
	await tap(&"cycle_protagonist")
	check(world.player == clay and clay.position.distance_to(clay_before) < 0.3,
		"X near a non-protagonist neither switches nor sends Clay to spawn")

	clay.position = umber.position + Vector3(0, 0.05, 4)
	await ticks(10)
	var umber_before: Vector3 = umber.position
	clay_before = clay.position
	await tap(&"possess_protagonist")
	check(world.player == umber and chat.player == umber and umber.player_controlled and not clay.player_controlled,
		"X near Umber transfers input and conversation ownership")
	check(root.get_camera_3d() == camera and camera.get_parent() == umber.arm, "The camera follows Umber's body")
	check(umber.position.distance_to(umber_before) < 0.3 and clay.position.distance_to(clay_before) < 0.3,
		"Possession keeps both dragons at their world positions")
	check(roster.unlocked.has("umber"), "Possessing Umber collects him")
	umber.pivot.rotation.y = 0
	umber.visual.rotation.y = 0
	Input.action_press("move_forward")
	await ticks(32)
	Input.action_release("move_forward")
	check(umber.position.z < umber_before.z - 0.5 and clay.position.distance_to(clay_before) < 0.3,
		"Movement controls only the possessed dragon")
	await tap(&"jump")
	await ticks(22)
	check(umber.locomotion_state == &"airborne" and umber.position.y > umber_before.y + 0.6, "Umber can jump")
	await tap(&"jump")
	check(umber.locomotion_state == &"flying", "Umber can start flight")
	umber.position = Vector3(-10, 20, -40)
	await ticks(2)
	check(roster.nearest_protagonist() == null, "Clay is out of range")
	await tap(&"cycle_protagonist")
	check(world.player == clay and camera.get_parent() == clay.arm and not umber.player_controlled,
		"The roster can switch back from the air and out of range")
	await tap(&"cycle_protagonist")
	check(world.player == umber and roster.unlocked.size() == 2, "The roster can reuse Umber without duplicate unlocks")
	world.queue_free()
	await process_frame
	world = village_scene.instantiate()
	world.roster_save_path = save_path
	world.install_cast = false # these tests cover the older meet-to-unlock behaviour
	root.add_child(world)
	await ticks(10)
	await tap(&"cycle_protagonist")
	check(world.player.character_id == "umber", "The collection survives reloading the village")
	DirAccess.remove_absolute(save_path)
	print("Protagonist smoke: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
