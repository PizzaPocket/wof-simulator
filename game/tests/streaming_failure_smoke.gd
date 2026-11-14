extends SceneTree
const Data=preload("res://scripts/continent_data.gd")
const Stream=preload("res://scripts/terrain_streamer.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source=Data.new()
	if not source.open("pyrrhia"): quit(1); return
	var reader=source.fork_reader()
	reader.definition=source.definition.duplicate(true)
	reader.definition.streaming.page_dir="res://data/terrain/intentionally_missing_test_pages"
	var stream=Stream.new()
	root.add_child(stream)
	stream.configure(reader)
	var point=source.map_to_world(source.definition.entries[0].position)
	var failed_safely: bool=not await stream.prepare(point)
	if not failed_safely or stream.last_error.is_empty() or stream.collision_ready(point):
		printerr("FAIL: missing pages must not become landable fallback geometry")
		quit(1); return
	# Restore the source while old failed jobs may still be finishing. A new
	# generation must discard them, retry the real disk pages and restore safety.
	reader.definition=source.definition
	if not await stream.prepare(point) or not stream.neighborhood_ready(point) or not stream.last_error.is_empty():
		printerr("FAIL: page recovery did not retry and complete safely")
		quit(1); return
	root.remove_child(stream)
	stream.queue_free()
	await process_frame
	# Simulate delayed disk work beneath a steep dive. Even an undersampled
	# distant overview must never let the player cross an absent landing tile.
	var world=load("res://scenes/terrain_pyrrhia.tscn").instantiate()
	world.set_meta("startup_loader",true)
	root.add_child(world)
	current_scene=world
	await world.initialize_world()
	var p=world.player
	p.position.y=float(source.definition.elevation_range_m[1])+200
	p.velocity=Vector3(0,-130,0)
	var logical=Vector2(p.position.x,p.position.z)+world.world_origin
	world.streamer._unload(world.streamer.cell_at(logical))
	world.streamer.closing=true
	world._process(0)
	if p.is_physics_processing() or not world.waiting_for_ground:
		printerr("FAIL: steep dive was allowed over an unavailable collision tile")
		quit(1); return
	world.streamer.closing=false
	await world.travel_to(0)
	if not p.is_physics_processing() or not world.streamer.collision_ready(Vector2(p.position.x,p.position.z)+world.world_origin):
		printerr("FAIL: recovery did not resume physics on prepared terrain")
		quit(1); return
	root.remove_child(world)
	world.queue_free()
	current_scene=null
	await process_frame
	print("PASS: missing-page failure stays unlandable; restored pages retry safely despite stale failed jobs; steep dives wait for collision and recover")
	quit(0)
