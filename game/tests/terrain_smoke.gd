extends SceneTree
## Actual baked terrain, physics, streaming, origin shift, travel and atlas routes.
const Data = preload("res://scripts/continent_data.gd")
var failures: Array[String] = []
var streaming_reports: Dictionary = {}
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for id in ["pyrrhia","pantala","forgotten_isles","nightwing_island"]:
		var data := Data.new()
		check(data.open(id),id+": baked data missing")
		check(is_equal_approx(data.extent.x / data.extent.y,float(data.definition.map_size[0])/data.definition.map_size[1]),id+": distorted aspect ratio")
		for entry in data.definition.entries:
			var p := data.map_to_world(entry.position)
			check(data.height_at(p)>data.water_level_at(p)+1,id+": entry underwater: "+entry.name)
		check(data.height_at(-data.extent*.5)<0,id+": ocean border must be submerged")
		var world = load("res://scenes/terrain_"+id+".tscn").instantiate()
		world.set_meta("startup_loader",true)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(world)
		current_scene = world
		var began := Time.get_ticks_msec()
		await world.initialize_world()
		world.process_mode = Node.PROCESS_MODE_INHERIT
		check(world.ready_to_explore,id+": initialization did not finish")
		if not world.ready_to_explore:
			quit(1)
			return
		if world.streamer:
			check(world.chunks.size()<100,id+": streamed tiles must be bounded")
		else:
			check(world.chunks.size() == world._chunk_count().x*world._chunk_count().y,id+": incomplete terrain coverage")
		for i in 60: await physics_frame
		var player = world.player
		var from: Vector3 = player.global_position+Vector3.UP*100
		var query := PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*5000,1,[player.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(),id+": spawn has no ground collision")
		if not hit.is_empty(): check(player.position.y>=hit.position.y-.5,id+": player fell through terrain")
		if id == "pyrrhia":
			var walk_start: Vector3 = player.position
			Input.action_press("move_forward")
			for i in 60: await physics_frame
			Input.action_release("move_forward")
			check(player.position.distance_to(walk_start)>1,"Pyrrhia: cannot walk on terrain")
			for i in 20: await physics_frame
			player.pivot.rotation.x = 0
			Input.action_press("jump")
			for i in 2: await physics_frame
			Input.action_release("jump")
			for i in 20: await physics_frame
			Input.action_press("jump")
			for i in 2: await physics_frame
			Input.action_release("jump")
			check(player.locomotion_state == &"flying","Pyrrhia: cannot enter flight above terrain")
			for i in 60: await physics_frame
			check(player.position.is_finite(),"Pyrrhia: nonfinite flight position")
			await world.travel_to(0)
		# Two adjacent detail levels have exactly matching geographic edge samples.
		var rect: Rect2 = world._rect_for(Vector2i(0,0))
		var rect2: Rect2 = world._rect_for(Vector2i(1,0))
		check(is_equal_approx(rect.end.x,rect2.position.x),id+": section gap")
		await world.travel_to(data.definition.entries.size()-1)
		for i in 10: await physics_frame
		var point: Vector2 = Vector2(player.position.x,player.position.z)+world.world_origin
		check(point.distance_to(data.map_to_world(data.definition.entries.back().position))<12,id+": travel coordinates incorrect")
		var old_origin: Vector2 = world.world_origin
		var old_position: Vector3 = player.position
		player.position.x += 2200
		world._process(0)
		var expected: Vector2 = Vector2(old_position.x+2200,old_position.z)+old_origin
		var actual: Vector2 = Vector2(player.position.x,player.position.z)+world.world_origin
		check(expected.distance_to(actual)<.01,id+": floating origin changed geographic position")
		check(world.world_origin != old_origin,id+": floating origin did not shift")
		await world.travel_to(0)
		player.position.y = -7
		world._process(0)
		while world.shifting: await process_frame
		check(player.position.y>0,id+": ocean recovery failed")
		var near_count := 0
		for chunk in world.chunks.values():
			if chunk.collision != null: near_count += 1
		check(near_count>=4 and near_count<=25,id+": nearby collision grew without bound")
		if world.streamer:
			var deadline := Time.get_ticks_msec()+15000
			while (world.streamer.active.size()>0 or not world.streamer.collision_queue.is_empty() or world.chunks.size()<world.streamer.desired.size()) and Time.get_ticks_msec()<deadline:
				await process_frame
			var metrics: Dictionary=world.streamer.stats()
			streaming_reports[id]=metrics
			check(metrics.peak_estimated_bytes<=data.definition.streaming.terrain_budget_bytes,id+": terrain budget exceeded")
			check(world.chunks.size()==world.streamer.desired.size(),id+": tile neighborhood failed to settle")
		print("CHECKED ",id," chunks=",world.chunks.size()," nearby=",near_count," init_ms=",Time.get_ticks_msec()-began)
		root.remove_child(world)
		world.queue_free()
		current_scene = null
		await process_frame
	change_scene_to_file("res://scenes/overworld.tscn")
	await process_frame
	var atlas = current_scene
	for id in ["pyrrhia","pantala","forgotten_isles","nightwing_island","world"]:
		atlas._select_continent(id)
		await process_frame
		check(atlas.atlas.locations.size()==(4 if id=="world" else (2 if id=="pyrrhia" else 1)),id+": missing atlas destination")
		check(not atlas.hover_tip.visible,id+": tooltip unexpectedly visible")
		root.size=Vector2i(800,500)
		await process_frame
		atlas.hotspots.back().mouse_entered.emit()
		check(Rect2(Vector2.ZERO,atlas.size).encloses(atlas.hover_tip.get_rect()),id+": tooltip clips")
	# Exercise the actual configured loader, including the selected map start.
	atlas._select_continent("pyrrhia")
	atlas.hotspots[1].pressed.emit()
	var deadline := Time.get_ticks_msec()+120000
	while not current_scene or current_scene.name != "Terrain_pyrrhia":
		if Time.get_ticks_msec()>deadline:
			check(false,"Configured terrain loader timed out")
			quit(1)
			return
		await process_frame
	check(current_scene.destination_menu.selected==2,"Terrain loader lost the desert entry selection")
	check(current_scene.ready_to_explore,"Terrain loader handed off before terrain was ready")
	Input.action_press("world_map")
	await process_frame
	await process_frame
	Input.action_release("world_map")
	while not current_scene or current_scene.name != "Overworld": await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Terrain return did not release the mouse")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../cache/streaming-review"))
	FileAccess.open("res://../cache/streaming-review/all_maps_metrics.json",FileAccess.WRITE).store_string(JSON.stringify(streaming_reports,"  "))
	if failures.is_empty(): print("PASS: four terrain worlds, proportions, dry spawns, physics, travel, bounded streaming, origin shifts, ocean recovery and atlas navigation")
	quit(0 if failures.is_empty() else 1)
