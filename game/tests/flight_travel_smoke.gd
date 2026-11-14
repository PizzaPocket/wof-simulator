extends SceneTree
## Real physics: progressive boost, coasting, steep climb above every map peak.
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player = load("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	await physics_frame
	# Keep the real flight pose/deployment, without an arena's walls or ground.
	player.position = Vector3(0,300,0)
	player.spawn_position = player.position
	player.pivot.rotation.x = 0
	player._activate_flight()
	await ticks(420)
	check(player.locomotion_state==&"flying","Cruise remains in flight")
	check(absf(player.velocity.length()-60)<.5,"Level cruise settles at 60 m/s")
	var initial: float = player.velocity.length()
	Input.action_press("sprint")
	await ticks(60)
	var one_second: float = player.velocity.length()
	check(one_second>initial+10 and one_second<100,"Shift builds speed progressively rather than jumping to top speed")
	await ticks(420)
	check(absf(player.velocity.length()-180)<.5,"Sustained Shift reaches 180 m/s")
	Input.action_release("sprint")
	await ticks(60)
	check(player.velocity.length()>160 and player.velocity.length()<180,"Releasing Shift coasts without snapping to cruise")
	await ticks(720)
	check(absf(player.velocity.length()-60)<.5,"Coasting returns to cruise")
	Input.action_press("sprint")
	# Use the actual camera orbit limit, not a direct pitch beyond the controls.
	player._orbit(Vector2(0,-10))
	check(player.pivot.rotation.x>deg_to_rad(60),"Flight camera can aim steeply enough for mountain climbs")
	var start: float = player.position.y
	await ticks(2100)
	var peak := 0.0
	for id in ["pyrrhia","pantala","forgotten_isles","nightwing_island"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain/"+id+".json"))
		peak=maxf(peak,data.elevation_range_m[1])
	check(player.position.y>peak+300,"Boosted climb clears the tallest generated mountain")
	check(player.position.y>start+3000,"Climb does not hit an altitude cap")
	check(absf(player.velocity.y-110)<.5,"Boosted climb sustains 110 m/s")
	check(player.position.is_finite(),"Fast high-altitude flight remains finite")
	Input.action_release("sprint")
	print("Flight travel: cruise=60 m/s; boost after 1s=",one_second," m/s; altitude=",player.position.y," m; max terrain=",peak," m")
	scene.queue_free()
	await process_frame
	# Check the actual village boundary collider for an overhead obstruction.
	var village = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	village.set_meta("startup_loader",true)
	root.add_child(village)
	village._make_region_boundary()
	await ticks(2)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0,150,0),Vector3(0,5000,0))
	check(village.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Village boundary no longer has an overhead ceiling")
	var side := PhysicsRayQueryParameters3D.create(Vector3(0,1000,0),Vector3(600,1000,0))
	check(not village.get_world_3d().direct_space_state.intersect_ray(side).is_empty(),"Village side boundary is retained above the old ceiling")
	village.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: gradual boost, smooth coasting, mountain-height climb, steep camera aim and open village sky")
	quit(0 if failures.is_empty() else 1)
