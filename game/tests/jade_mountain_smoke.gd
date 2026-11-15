extends SceneTree
## Loads Jade Mountain directly, checks that the ledge and every cave are solid, open and
## joined, then (in a graphical run) saves exterior and interior captures to cache/jade-review/.
var failures: Array[String] = []
var output := "res://../cache/jade-review"
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	# Characters standing in the scene must not read as floor or wall.
	var bodies: Array[RID] = [world.player.get_rid()]
	for resident in world.residents:
		bodies.append(resident.get_rid())
	query.exclude = bodies
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(filename + ".png"))

func place(position: Vector3, yaw_degrees: float, pitch := -0.25) -> void:
	player.position = position
	player.velocity = Vector3.ZERO
	player.pivot.rotation = Vector3(pitch, deg_to_rad(yaw_degrees), 0)
	player.visual.rotation.y = deg_to_rad(yaw_degrees)
	for i in 8: await physics_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 800)
	Engine.set_meta("map_era", "arc2") # the academy is an Arc 2 place
	var began := Time.get_ticks_msec()
	world = load("res://scenes/jade_mountain.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	while not is_instance_valid(world.mountain) or world.player.position.distance_to(world.player.spawn_position) > 50.0:
		await process_frame
	var deadline := Time.get_ticks_msec() + 20000
	while not world.collision_ready and Time.get_ticks_msec() < deadline: await physics_frame
	check(world.collision_ready, "Ledge collision never became ready")
	var player_camera := world.player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	check(player_camera.far >= 10000.0, "The mountain must be visible from afar (camera far %.0f)" % player_camera.far)
	var star_found := false
	for resident in world.residents:
		if resident.character_id == "starflight_blind":
			star_found = true
			var library: Dictionary
			for chamber in world.design.chambers:
				if chamber.id == "library":
					library = chamber
			check(Vector2(resident.position.x - world.mouth.x, resident.position.z - world.mouth.z).distance_to(Vector2(float(library.x), float(library.z))) < 12.0, "The blind Starflight must keep his post in the library")
	check(star_found, "The blind Starflight must be present in Arc 2")
	for i in 6: await physics_frame
	player = world.player
	print("Loaded in ms: ", Time.get_ticks_msec() - began)
	var mouth: Vector3 = world.mouth
	# The arrival ledge is solid.
	var ledge_hit := ray(mouth + Vector3(0, 10, 24), mouth + Vector3(0, -10, 24))
	check(not ledge_hit.is_empty() and absf(ledge_hit.position.y - mouth.y) < 0.6, "Ledge must be solid at the ledge height")
	# Every chamber has a floor at ledge level and clear headroom to its roof.
	for chamber in world.chamber_floors:
		var centre: Vector3 = chamber.position
		var floor_hit := ray(centre + Vector3(0, 6, 0), centre + Vector3(0, -6, 0))
		check(not floor_hit.is_empty() and absf(floor_hit.position.y - mouth.y) < 0.6, "%s needs a floor at ledge level" % chamber.id)
		var roof_hit := ray(centre + Vector3(0, 1, 0), centre + Vector3(0, 200, 0))
		check(not roof_hit.is_empty() and roof_hit.position.y - mouth.y > chamber.height * 0.85, "%s needs headroom (%.1f of %.1f)" % [chamber.id, roof_hit.position.y - mouth.y if not roof_hit.is_empty() else 0.0, chamber.height])
	# Every tunnel is open along its length at dragon height and floored.
	for tunnel in world.design.tunnels:
		var a := mouth + Vector3(tunnel.from[0], 0, tunnel.from[1])
		var b := mouth + Vector3(tunnel.to[0], 0, tunnel.to[1])
		for step in 9:
			# Offset slightly so a ray never lands exactly on a triangle edge.
			var point := a.lerp(b, step / 8.0) + Vector3(0.37, 0, 0.21)
			var floor_hit := ray(point + Vector3(0, 6, 0), point + Vector3(0, -6, 0))
			if point.z > mouth.z: continue
			check(not floor_hit.is_empty() and absf(floor_hit.position.y - mouth.y) < 0.6, "Tunnel %s->%s lacks a floor at step %d" % [str(tunnel.from), str(tunnel.to), step])
		var walk := ray(a + Vector3(0, 5, 0), b + Vector3(0, 5, 0))
		check(walk.is_empty() or a.z > mouth.z, "Tunnel %s->%s is blocked at 5 m: %s" % [str(tunnel.from), str(tunnel.to), str(walk.get("position", ""))])
	# Exterior and interior captures from a free camera.
	var camera := Camera3D.new()
	camera.fov = 72
	camera.far = 20000
	world.add_child(camera)
	camera.make_current()
	var views := [
		["ledge", Vector3(0, 14, 62), Vector3(0, 12, -20)],
		["approach", Vector3(260, 120, 1500), Vector3(0, 480, 600)],
		["massif", Vector3(1400, 600, 2300), Vector3(0, 900, 0)],
		["gate", Vector3(0, 8, 30), Vector3(0, 10, -90)],
		["central", Vector3(0, 12, -150), Vector3(0, 16, -250)],
		["central-wide", Vector3(0, 40, -170), Vector3(-60, 15, -250)],
		["library", Vector3(-120, 10, -215), Vector3(-190, 12, -215)],
		["gallery", Vector3(0, 8, -300), Vector3(120, 8, -310)],
		["arena", Vector3(0, 14, -400), Vector3(0, 16, -470)],
	]
	for view in views:
		var from: Vector3 = mouth + view[1]
		if view[0] == "approach" or view[0] == "massif":
			from = Vector3(view[1].x, view[1].y + 400.0 if view[0] == "approach" else view[1].y, view[1].z)
		camera.position = from
		camera.look_at(mouth + view[2] if view[0] != "approach" and view[0] != "massif" else view[2])
		await capture(view[0])
	camera.queue_free()
	if failures.is_empty():
		print("PASS: Jade Mountain ledge, %d chambers and %d tunnels are solid, open and joined" % [world.chamber_floors.size(), world.design.tunnels.size()])
	quit(0 if failures.is_empty() else 1)
