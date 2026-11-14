extends SceneTree
const Data=preload("res://scripts/continent_data.gd")
var failures: Array[String]=[]
var world
var reports: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
func wait_for_tiles() -> void:
	var deadline=Time.get_ticks_msec()+30000
	while world.streamer.active.size()>0 or not world.streamer.collision_queue.is_empty() or world.chunks.size()<world.streamer.desired.size():
		if Time.get_ticks_msec()>deadline:
			check(false,"Streaming queue did not settle")
			return
		await process_frame
func run() -> void:
	var data=Data.new()
	check(data.open("pyrrhia"),"Streamed dataset opens")
	check(data.streaming and data.extent.x==320000,"Expanded 320 km streaming map is active")
	check(data.heights.size()<100000,"Only small overview, not full continent heightfield, is resident")
	for i in 24:
		data.height_at(Vector2(-150000+i*12000,-100000+i*7000))
	check(data.pages.size()<=4 and data.page_evictions>0,"Disk page cache evicts old pages")
	check(data.resident_data_bytes()<1024*1024,"Overview plus bounded page cache stay below 1 MiB")
	var boundary=Vector2(-140000,-30000)
	check(absf(data.height_at(boundary-Vector2(.01,0))-data.height_at(boundary+Vector2(.01,0)))<.1,"Independent disk pages share continuous borders")
	world=load("res://scenes/terrain_pyrrhia.tscn").instantiate()
	world.set_meta("startup_loader",true)
	root.add_child(world)
	current_scene=world
	var began=Time.get_ticks_msec()
	await world.initialize_world()
	check(world.ready_to_explore and world.streamer.neighborhood_ready(data.map_to_world(data.definition.entries[0].position)),"Initial landing neighborhood is ready before handoff")
	print("STREAM INIT ms=",Time.get_ticks_msec()-began)
	await wait_for_tiles()
	check(world.chunks.size()<100 and world.chunks.size()<world._chunk_count().x*world._chunk_count().y/100,"Detailed meshes cover only a bounded fraction of the world")
	var player=world.player
	await ticks(60)
	check(player.is_on_floor(),"Player stands on streamed collision")
	# Start above the real ground, enter full flight and cross tile boundaries.
	player.position.y+=450
	player.pivot.rotation.x=0
	player._activate_flight()
	Input.action_press("sprint")
	await ticks(1500)
	check(player.locomotion_state==&"flying" and player.velocity.length()>175,"Full boost survives streamed tile crossings")
	var point=Vector2(player.position.x,player.position.z)+world.world_origin
	check(world.streamer.collision_ready(point),"Collision follows fast flight")
	# Sudden reversal invalidates forward predictions while old jobs are active.
	player.pivot.rotation.y+=PI
	await ticks(600)
	check(player.position.is_finite(),"Abrupt high-speed reversal remains stable")
	check(world.world_origin.length()>0,"Streaming preserves floating-origin travel")
	Input.action_release("sprint")
	# Dive onto a known broad landing area at the actual selected start.
	await world.travel_to(2)
	await ticks(60)
	player.position.y+=160
	player.pivot.rotation.x=-.6
	player._activate_flight()
	await ticks(150)
	Input.action_press("cancel_flight")
	await ticks(2)
	Input.action_release("cancel_flight")
	await ticks(300)
	check(player.is_on_floor(),"Dive and flight cancellation land on streamed ground")
	# Repeated long-distance teleports exercise eviction, stale work, and shutdown.
	for index in [3,4,1,0]:
		await world.travel_to(index)
		check(world.streamer.neighborhood_ready(Vector2(player.position.x,player.position.z)+world.world_origin),"Teleport waits for its collision neighborhood")
	await wait_for_tiles()
	reports=world.streamer.stats()
	reports.landing_waits=world.landing_waits
	reports.engine_static_bytes=Performance.get_monitor(Performance.MEMORY_STATIC)
	reports.extent_m=[data.extent.x,data.extent.y]
	check(reports.max_tiles<=int(data.definition.streaming.max_resident_tiles),"Resident tile count remains bounded")
	check(reports.peak_estimated_bytes<=int(data.definition.streaming.terrain_budget_bytes),"Terrain payload stays within 64 MiB working budget")
	check(reports.unloaded_tiles>20 and reports.page_reads>20,"Travel performs real disk loads and unloading")
	check(world.streamer.last_error.is_empty(),"No terrain page failures")
	# A missing page fails closed instead of silently producing landable fallback.
	var broken=data.fork_reader()
	broken.definition=data.definition.duplicate(true)
	broken.definition.streaming.page_dir="res://data/terrain/missing_pages"
	broken.height_at(Vector2.ZERO)
	check(broken.read_failed,"Missing page is detected for collision safety")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../cache/streaming-review"))
	FileAccess.open("res://../cache/streaming-review/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	print("STREAM METRICS ",JSON.stringify(reports))
	# Exit while workers are active; shutdown must join them before freeing data.
	world.streamer.update_interest(data.map_to_world([1190,600]),Vector2(180,0))
	world.streamer.pump()
	root.remove_child(world)
	world.queue_free()
	current_scene=null
	await process_frame
	if failures.is_empty(): print("PASS: paged I/O, bounded memory, fast flight, reversal, dive/landing, teleport, origin shift, missing-page detection and worker cleanup")
	quit(0 if failures.is_empty() else 1)
