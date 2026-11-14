extends SceneTree
## Real map → configured loader → wetlands → map, plus atlas layout captures.
var failures: Array[String] = []
var output := "res://../cache/overworld-review"

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(filename + ".png"))

func wait_for_scene(scene_name: String) -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while not current_scene or current_scene.name != scene_name:
		if Time.get_ticks_msec() > deadline:
			printerr("Timed out waiting for ", scene_name)
			quit(1)
			return
		await process_frame
	await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/overworld.tscn")
	await wait_for_scene("Overworld")
	var atlas: Control = current_scene
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Map must release the mouse")
	check(atlas.hotspots.size() == 2, "Expected village and bare Pyrrhia terrain destinations")
	check(not atlas.hover_tip.visible, "Destination details must be hidden on arrival")
	check(atlas.region_labels.size() == 7, "Vector atlas must retain kingdom labels")
	await capture("desktop")
	atlas.hotspots[0].mouse_entered.emit()
	check(atlas.hover_tip.visible, "Hover must reveal the destination")
	await capture("hover-desktop")
	atlas.hotspots[0].mouse_exited.emit()
	check(not atlas.hover_tip.visible, "Pointer exit must hide the destination")
	atlas.hotspots[0].grab_focus()
	check(atlas.hover_tip.visible, "Keyboard/controller focus must reveal the destination")
	atlas.hotspots[0].release_focus()
	check(not atlas.hover_tip.visible, "Focus exit must hide the destination")
	root.size = Vector2i(800, 500)
	await capture("small")
	atlas.hotspots[0].mouse_entered.emit()
	await capture("hover-small")
	check(Rect2(Vector2.ZERO, atlas.size).encloses(atlas.hover_tip.get_rect()), "Small-window hover tip clips")
	atlas.hotspots[0].mouse_exited.emit()
	var button: Button = atlas.hotspots[0]
	check(Rect2(Vector2.ZERO, atlas.size).encloses(button.get_rect()), "Small-window hotspot clips")
	if "--atlas-only" in OS.get_cmdline_user_args():
		print("PASS: vector atlas hidden/hover/focus states and small-window bounds")
		quit(0 if failures.is_empty() else 1)
		return
	root.size = Vector2i(1280, 800)
	atlas.hotspots[0].pressed.emit()
	await wait_for_scene("MudwingWetlands")
	check(current_scene.get_node("Clay/Visual").model_loaded, "Destination must load the actual Clay model")
	await capture("village")
	var return_button := current_scene.find_child("WorldMapButton", true, false) as Button
	check(return_button != null, "Missing return-to-map button")
	return_button.pressed.emit()
	await wait_for_scene("Overworld")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Return must release the mouse")
	# The keyboard/controller route is shared by scenes deriving Playground.
	change_scene_to_file("res://scenes/playground.tscn")
	await wait_for_scene("Playground")
	Input.action_press("world_map")
	await process_frame
	await process_frame
	Input.action_release("world_map")
	await wait_for_scene("Overworld")
	if failures.is_empty():
		print("PASS: native vector map, hidden/hover/focus details, tip bounds, real village loading and return navigation")
	quit(0 if failures.is_empty() else 1)
