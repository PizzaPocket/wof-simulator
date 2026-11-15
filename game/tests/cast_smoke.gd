extends SceneTree
## Characters stand where their story puts them, are unlocked by walking up and pressing X, and the
## saved collection is shared by every scene (Tab brings an unlocked character who is elsewhere).
var failures: Array[String] = []
var save_path := OS.get_temp_dir().path_join("wof-cast-test-%d.cfg" % OS.get_process_id())

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func load_scene(path: String, era: String) -> Node3D:
	Engine.set_meta("map_era", era)
	var world: Node3D = load(path).instantiate()
	if path.contains("mudwing"):
		world.roster_save_path = save_path
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if world.get("collision_ready") == true or (world.get("collision_ready") == null and world.get_node_or_null("Protagonists") != null and world.get_node("Protagonists").protagonists.size() > 3):
			break
	for i in 14: await physics_frame
	return world

func unload(world: Node3D) -> void:
	root.remove_child(world)
	world.queue_free()
	await process_frame

func press(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await physics_frame

func present(roster: Node) -> Array[String]:
	var ids: Array[String] = []
	for id in roster.protagonists:
		ids.append(str(id))
	return ids

func _run() -> void:
	root.size = Vector2i(1280, 800)
	Engine.set_meta("roster_save_path", save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	# --- Jade Mountain (Arc 2): the academy's people, with the blind Starflight ---
	var world := await load_scene("res://scenes/jade_mountain.tscn", "arc2")
	var roster = world.get_node("Protagonists")
	var ids := present(roster)
	for expected in ["starflight_blind", "tsunami", "sunny", "moon"]:
		check(expected in ids, "The academy should hold %s (has %s)" % [expected, str(ids)])
	check(not ("glory" in ids) and not ("starflight" in ids), "Glory belongs elsewhere and the sighted Starflight is Arc 1 (has %s)" % str(ids))
	check(roster.unlocked == PackedStringArray(["clay"]), "Nobody is unlocked until you meet them (%s)" % str(roster.unlocked))
	# Starflight keeps his post in the library.
	var library: Dictionary
	for chamber in world.design.chambers:
		if chamber.id == "library":
			library = chamber
	var star = roster.protagonists["starflight_blind"]
	check(Vector2(star.position.x - world.mouth.x, star.position.z - world.mouth.z).distance_to(Vector2(float(library.x), float(library.z))) < 12.0, "Starflight must stand in the library")
	# Walk up to Tsunami and press X: she unlocks and is played.
	var clay = world.player
	var tsunami = roster.protagonists["tsunami"]
	clay.position = tsunami.position + Vector3(0, 0.2, 4.0)
	clay.velocity = Vector3.ZERO
	for i in 4: await physics_frame
	check(roster.nearest_protagonist() == tsunami, "Tsunami should be in reach")
	await press("possess_protagonist")
	check(world.player == tsunami and roster.unlocked.has("tsunami"), "X must unlock and switch to Tsunami (playing %s)" % world.player.character_id)
	check(FileAccess.file_exists(save_path), "The collection must be saved")
	# Someone out of reach cannot be played, and Tab only cycles the unlocked.
	var before: String = world.player.character_id
	await press("cycle_protagonist")
	check(world.player.character_id == "clay" and before == "tsunami", "Tab must cycle between the unlocked (clay <-> tsunami)")
	await unload(world)

	# --- Scorpion Den (Arc 1): only Sunny belongs here; Tsunami was unlocked elsewhere ---
	world = await load_scene("res://scenes/scorpion_den.tscn", "arc1")
	roster = world.get_node("Protagonists")
	ids = present(roster)
	check("sunny" in ids and not ("tsunami" in ids) and not ("starflight" in ids), "The Den holds Sunny only (has %s)" % str(ids))
	check(roster.unlocked.has("tsunami") and roster.unlocked.size() == 2, "The saved collection must carry over (%s)" % str(roster.unlocked))
	await press("cycle_protagonist")
	check(world.player.character_id == "tsunami" and "tsunami" in present(roster), "Tab must bring an unlocked Tsunami to the player (playing %s)" % world.player.character_id)
	check(world.player.global_position.distance_to(roster.protagonists["clay"].global_position) < 12.0, "She joins at the player's side")
	await unload(world)

	# --- Sky palace (Arc 1) and Summer Palace (Arc 1): Starflight is sighted ---
	world = await load_scene("res://scenes/sky_palace.tscn", "arc1")
	ids = present(world.get_node("Protagonists"))
	check("starflight" in ids and not ("starflight_blind" in ids) and not ("tsunami" in ids), "The Arc 1 palace holds the sighted Starflight (has %s)" % str(ids))
	await unload(world)
	world = await load_scene("res://scenes/summer_palace.tscn", "arc1")
	ids = present(world.get_node("Protagonists"))
	check("starflight" in ids and "tsunami" in ids and not ("sunny" in ids), "The Summer Palace holds the captive dragonets (has %s)" % str(ids))
	await unload(world)

	# --- Places with nobody to meet still let you cycle to anyone you have unlocked ---
	world = await load_scene("res://scenes/ice_palace.tscn", "arc1")
	roster = world.get_node("Protagonists")
	check(present(roster) == ["clay"], "The ice palace has no point-of-view characters (has %s)" % str(present(roster)))
	await press("cycle_protagonist")
	check(world.player.character_id == "tsunami", "An unlocked character is available anywhere")
	await unload(world)

	# --- Marsh village (Arc 1): the dragonets with Clay, still locked ---
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	world = await load_scene("res://scenes/mudwing_wetlands.tscn", "arc1")
	roster = world.get_node("Protagonists")
	ids = present(roster)
	for expected in ["starflight", "tsunami", "glory", "sunny"]:
		check(expected in ids, "The village should hold %s (has %s)" % [expected, str(ids)])
	check(roster.unlocked == PackedStringArray(["clay"]), "The village's dragonets start locked (%s)" % str(roster.unlocked))
	await unload(world)

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if failures.is_empty():
		print("PASS: characters stand where their story puts them, X unlocks them, and the collection is shared across scenes")
	quit(0 if failures.is_empty() else 1)
