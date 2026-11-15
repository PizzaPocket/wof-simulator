extends SceneTree
## One draggable, zoomable world map: pan, zoom, pins for every start, then the real
## loader into the wetlands and an island, and the return path. Graphical runs also
## save captures to cache/overworld-review/.
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

func mouse_button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	return event

func pin_named(atlas: Control, name: String) -> int:
	for i in atlas.pins.size():
		if atlas.pins[i].name == name:
			return i
	return -1

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Engine.remove_meta("world_map_view")
	if Engine.has_meta("map_era"): Engine.remove_meta("map_era")
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/overworld.tscn")
	await wait_for_scene("Overworld")
	var atlas: Control = current_scene
	var map: Control = atlas.map
	await process_frame
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Map must release the mouse")

	# Every start location of every landmass is a pin, plus the detailed village.
	var expected := 8 # the village, academy, palace, Scorpion Den, stronghold, ice palace, Summer Palace, NightWing fortress
	for id in ["pyrrhia", "pantala", "forgotten_isles", "nightwing_island"]:
		var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain/%s.json" % id))
		expected += definition.entries.size()
	check(atlas.pins.size() == expected and atlas.hotspots.size() == expected, "Expected %d pins, found %d" % [expected, atlas.pins.size()])
	check(atlas.pins.size() >= 30, "Islands and every kingdom start should be on the map")
	# The timeline: eras load from data, Arc 1 is the default, and the academy only opens in Arc 2.
	check(atlas.eras.size() >= 3 and atlas.era == "arc1", "The map opens on Arc 1 with a timeline of eras")
	check(atlas.era_buttons["arc1"].button_pressed, "The current era must be selected on the timeline")
	var academy := pin_named(atlas, "Jade Mountain Academy")
	check(academy >= 0, "Jade Mountain Academy needs a pin")
	check(not atlas._open_in_era(atlas.pins[academy]), "The academy must be closed in Arc 1")
	check(atlas._open_in_era(atlas.pins[pin_named(atlas, "Mud Kingdom")]), "Ordinary terrain starts are open in every era")
	check(map.zoom == map.min_zoom, "The map opens on the whole world")
	check(not atlas.hover_tip.visible, "Destination details must be hidden on arrival")
	var visible_at_world := 0
	for button in atlas.hotspots:
		if button.visible:
			visible_at_world += 1
	check(visible_at_world >= 5 and visible_at_world < expected, "World view should show a decluttered subset (%d of %d)" % [visible_at_world, expected])
	await capture("world")

	# Pins resolve to the right continent and sit on land inside the world.
	for pin in atlas.pins:
		check(Rect2(Vector2.ZERO, map.WORLD_SIZE).has_point(pin.world), "%s is outside the world" % pin.name)

	# Mouse wheel zooms around the pointer, drag pans, double-click zooms.
	var anchor := Vector2(640, 400)
	var world_under_pointer: Vector2 = map.screen_to_world(anchor)
	for i in 4:
		map._gui_input(mouse_button(MOUSE_BUTTON_WHEEL_UP, true, anchor))
	check(map.target_zoom > map.min_zoom * 1.9, "Scroll wheel must zoom in")
	check((map.target_center + (anchor - map.size * 0.5) / map.target_zoom).distance_to(world_under_pointer) < 1.0, "Zoom must stay anchored under the pointer")
	map.set_view(map.target_center, map.target_zoom, true)
	var before: Vector2 = map.center
	map._gui_input(mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(600, 400)))
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(500, 380)
	drag.relative = Vector2(-100, -20)
	map._gui_input(drag)
	map._gui_input(mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(500, 380)))
	check(map.center != before and map.center.x > before.x, "Dragging left must move the view east")
	var magnify := InputEventMagnifyGesture.new()
	magnify.position = anchor
	magnify.factor = 1.5
	var zoom_before: float = map.target_zoom
	map._gui_input(magnify)
	check(map.target_zoom > zoom_before, "Pinch must zoom in")
	map.zoom_at(anchor, 0.0001)
	check(is_equal_approx(map.target_zoom, map.min_zoom), "Zoom must stop at the whole-world view")
	map.zoom_at(anchor, 1000000.0)
	check(is_equal_approx(map.target_zoom, map.MAX_ZOOM), "Zoom must stop at the closest view")
	map.fit_world(true)

	# The chosen pin is revealed at street level for each landmass, and no pin is unreachable.
	for index in atlas.pins.size():
		map.set_view(atlas.pins[index].world, map.MAX_ZOOM, true)
		atlas._update_pins()
		check(atlas.hotspots[index].visible, "%s cannot be reached on the map" % atlas.pins[index].name)
		var rect := Rect2(Vector2.ZERO, atlas.size)
		check(rect.encloses(atlas.hotspots[index].get_rect()), "%s pin is clipped at the closest zoom" % atlas.pins[index].name)
	# A closed pin explains itself and does not travel.
	map.set_view(atlas.pins[academy].world, 1.0 / 200.0, true)
	atlas._update_pins()
	atlas.hotspots[academy].mouse_entered.emit()
	check(atlas.tip_copy.text.contains("Opens in Arc 2"), "A closed pin's tip must name its era")
	atlas.hotspots[academy].mouse_exited.emit()
	atlas.hotspots[academy].pressed.emit()
	await process_frame
	check(current_scene == atlas and not atlas.entering and atlas.message.text.contains("Arc 2"), "A closed pin must stay on the map and say when it opens")
	var mud := pin_named(atlas, "Mud Kingdom")
	var village := pin_named(atlas, "MudWing village")
	check(mud >= 0 and village >= 0, "Mud Kingdom and the village need pins")
	map.set_view(atlas.pins[village].world, 1.0 / 200.0, true)
	atlas._update_pins()
	check(atlas.hotspots[village].visible and atlas.hotspots[mud].visible, "The village and the nearby Mud Kingdom start should both show once zoomed in")
	await capture("pyrrhia-zoom")
	atlas.hotspots[village].mouse_entered.emit()
	check(atlas.hover_tip.visible, "Hover must reveal the destination")
	await capture("hover-desktop")
	atlas.hotspots[village].mouse_exited.emit()
	check(not atlas.hover_tip.visible, "Pointer exit must hide the destination")
	atlas.hotspots[village].grab_focus()
	check(atlas.hover_tip.visible, "Keyboard/controller focus must reveal the destination")
	atlas.hotspots[village].release_focus()
	check(not atlas.hover_tip.visible, "Focus exit must hide the destination")

	# The places menu flies to a pin and focuses it.
	var island := pin_named(atlas, "Northern island")
	check(island >= 0, "The Forgotten Isles' northern island needs a pin")
	map.fit_world(true)
	atlas._fly_to_pin(island)
	await create_timer(1.2).timeout
	check(atlas.hotspots[island].visible and atlas.hotspots[island].has_focus(), "Places menu must reveal and focus the pin")
	await capture("island-zoom")

	root.size = Vector2i(800, 500)
	await capture("small")
	atlas.hotspots[island].mouse_entered.emit()
	check(Rect2(Vector2.ZERO, atlas.size).encloses(atlas.hover_tip.get_rect()), "Small-window hover tip clips")
	atlas.hotspots[island].mouse_exited.emit()
	map.fit_world(true)
	atlas._update_pins()
	await capture("small-world")
	if "--atlas-only" in OS.get_cmdline_user_args():
		print("PASS: world map pan, zoom, pins and small-window bounds")
		quit(0 if failures.is_empty() else 1)
		return

	# Real loader into an island start: the selected entry must be where the player lands.
	root.size = Vector2i(1280, 800)
	map.set_view(atlas.pins[island].world, 1.0 / 200.0, true)
	atlas._update_pins()
	atlas.hotspots[island].pressed.emit()
	await wait_for_scene("Terrain_forgotten_isles")
	var deadline := Time.get_ticks_msec() + 120000
	while not current_scene.ready_to_explore and Time.get_ticks_msec() < deadline:
		await process_frame
	check(current_scene.ready_to_explore, "Island terrain must finish loading")
	check(current_scene.destination_menu.get_item_text(current_scene.destination_menu.selected) == "Northern island", "The island pin must start at its own entry")
	var return_island := current_scene.find_child("WorldMapButton", true, false) as Button
	check(return_island != null, "Missing return-to-map button")
	return_island.pressed.emit()
	await wait_for_scene("Overworld")
	check(current_scene.map.target_zoom > current_scene.map.min_zoom * 2.0, "Returning to the map must restore the previous view")

	# Choose Arc 2 on the timeline, then travel to the academy.
	atlas = current_scene
	atlas.era_buttons["arc2"].pressed.emit()
	check(atlas.era == "arc2" and atlas._open_in_era(atlas.pins[academy]), "Selecting Arc 2 must open the academy")
	atlas.map.set_view(atlas.pins[academy].world, 1.0 / 200.0, true)
	atlas._update_pins()
	atlas.hotspots[academy].pressed.emit()
	await wait_for_scene("JadeMountain")
	deadline = Time.get_ticks_msec() + 60000
	while not current_scene.collision_ready and Time.get_ticks_msec() < deadline:
		await process_frame
	check(current_scene.collision_ready, "Jade Mountain must settle its collision")
	for i in 20: await physics_frame
	check(current_scene.player.position.distance_to(current_scene.mouth + Vector3(0, 0.2, 24)) < 3.0 and current_scene.player.position.y > current_scene.mouth.y - 1.0, "The player must arrive on the ledge")
	await capture("academy")
	var return_academy := current_scene.find_child("WorldMapButton", true, false) as Button
	check(return_academy != null, "Missing return-to-map button")
	return_academy.pressed.emit()
	await wait_for_scene("Overworld")
	check(current_scene.era == "arc2" and current_scene.era_buttons["arc2"].button_pressed, "The chosen era must persist after returning")

	# The palace and the Scorpion Den also travel through the real loader in this era.
	atlas = current_scene
	for site in [["Sky Kingdom palace and arena", "SkyPalace"], ["Scorpion Den", "ScorpionDen"]]:
		atlas = current_scene # the map is rebuilt after every visit
		var index := pin_named(atlas, site[0])
		check(index >= 0 and atlas._open_in_era(atlas.pins[index]), "%s needs an open pin in Arc 2" % site[0])
		atlas.map.set_view(atlas.pins[index].world, 1.0 / 200.0, true)
		atlas._update_pins()
		atlas.hotspots[index].pressed.emit()
		await wait_for_scene(site[1])
		deadline = Time.get_ticks_msec() + 60000
		while current_scene.get("collision_ready") == false and Time.get_ticks_msec() < deadline:
			await process_frame
		for i in 20: await physics_frame
		check(current_scene.player.position.y > -5.0, "%s: the player must not fall through the world" % site[0])
		var back := current_scene.find_child("WorldMapButton", true, false) as Button
		check(back != null, "Missing return-to-map button in " + site[0])
		back.pressed.emit()
		await wait_for_scene("Overworld")
	atlas = current_scene
	atlas.map.fit_world(true)
	atlas._update_pins()
	atlas.hotspots[village].pressed.emit()
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
		print("PASS: world map pan/zoom, every start pinned and reachable, era gating, island, academy and village loading, view restore and return navigation")
	quit(0 if failures.is_empty() else 1)
