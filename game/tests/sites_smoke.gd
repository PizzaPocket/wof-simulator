extends SceneTree
## Rough Sky Kingdom palace and Scorpion Den: they build, settle their collision, differ by
## era, and their key spaces are solid and open. Captures go to cache/sites-review/ when graphical.
var failures: Array[String] = []
var output := "res://../cache/sites-review"
var world: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	if world.get("player") != null:
		query.exclude = [world.player.get_rid()] # the player's own body must not read as floor
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func capture(filename: String, from: Vector3, at: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera := Camera3D.new()
	camera.far = 20000
	world.add_child(camera)
	camera.make_current()
	camera.position = from
	camera.look_at(at)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(filename + ".png"))
	camera.queue_free()

func load_site(path: String, era: String) -> void:
	Engine.set_meta("map_era", era)
	world = load(path).instantiate()
	root.add_child(world)
	current_scene = world

func unload_site() -> void:
	root.remove_child(world)
	world.queue_free()
	await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 800)
	# --- Sky Kingdom palace, in both eras ---
	for era in ["arc1", "arc2"]:
		load_site("res://scenes/sky_palace.tscn", era)
		var deadline := Time.get_ticks_msec() + 30000
		while not (is_instance_valid(world.mountain) and world.collision_ready) and Time.get_ticks_msec() < deadline:
			await physics_frame
		check(world.collision_ready, "Palace collision never settled (%s)" % era)
		for i in 8: await physics_frame
		var mouth: Vector3 = world.mouth
		var gold: float = world.rock_interior.get_shader_parameter("gold_veins")
		check((gold > 0.5) == (era == "arc1"), "Gold veins must follow the era (%s: %.2f)" % [era, gold])
		check(world.location_label.text.contains("Scarlet" if era == "arc1" else "Ruby"), "The palace label must name the ruler (%s)" % era)
		var plateau := ray(mouth + Vector3(0.3, 10, 300), mouth + Vector3(0.3, -10, 300))
		check(not plateau.is_empty() and absf(plateau.position.y - mouth.y) < 0.6, "The plateau must be solid at the arrival point")
		for chamber in world.chamber_floors:
			var hit := ray(chamber.position + Vector3(0.37, 6, 0.21), chamber.position + Vector3(0.37, -6, 0.21))
			check(not hit.is_empty() and absf(hit.position.y - mouth.y) < 0.6, "%s needs a floor" % chamber.id)
		var arena: Dictionary = world.design.arena
		var bowl := mouth + Vector3(arena.x + 0.37, 0, arena.z + 0.21)
		var arena_floor := ray(bowl + Vector3(0, 20, 0), bowl + Vector3(0, -100, 0))
		var expected_depth: float = float(arena.step_height) * int(arena.steps)
		check(not arena_floor.is_empty() and absf(mouth.y - arena_floor.position.y - expected_depth) < 1.0, "The arena floor should sit %.0f m below the plateau" % expected_depth)
		var hall := ray(mouth + Vector3(0.4, 5, -10), mouth + Vector3(0.4, 5, -230))
		check(hall.is_empty(), "The throne hall passage must be open at 5 m")
		if era == "arc1":
			await capture("palace-arena", mouth + Vector3(0, 60, 260), mouth + Vector3(0, -30, 110))
		await unload_site()
	# --- Scorpion Den, in both eras ---
	for era in ["arc1", "arc2"]:
		load_site("res://scenes/scorpion_den.tscn", era)
		for i in 40: await physics_frame
		check(world.building_count >= 60, "The Den needs a dense town (%d buildings)" % world.building_count)
		var ground := ray(Vector3(0.3, 10, 360), Vector3(0.3, -10, 360))
		check(not ground.is_empty() and absf(ground.position.y) < 0.6, "The Den's spawn must stand on sand")
		var gate_road := ray(Vector3(0.4, 5, 380), Vector3(0.4, 5, 100))
		check(gate_road.is_empty(), "The main gate road must be open to the plaza")
		check((world.find_child("CompoundWall", true, false) != null) == (era == "arc2"), "Vulture's compound is an Arc 2 feature (%s)" % era)
		check(world.find_child("GateTower", true, false) != null, "The Den needs gate towers")
		if era == "arc2":
			await capture("den-overview", Vector3(0, 520, 380), Vector3.ZERO)
		await unload_site()
	if failures.is_empty():
		print("PASS: palace and Scorpion Den build, differ by era and keep their key spaces solid and open")
	quit(0 if failures.is_empty() else 1)
