extends SceneTree
var output := "res://../cache/terrain-review"
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(name+".png"))
func run() -> void:
	var streaming_review := "--streaming-review" in OS.get_cmdline_user_args()
	if streaming_review: output="res://../cache/streaming-review"
	elif "--forward-check" in OS.get_cmdline_user_args(): output += "/forward"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,800)
	change_scene_to_file("res://scenes/overworld.tscn")
	while current_scene == null: await process_frame
	await process_frame
	var atlas = current_scene
	for id in ["pyrrhia","pantala","forgotten_isles","nightwing_island","world"]:
		atlas._select_continent(id)
		root.size=Vector2i(1280,800)
		await capture(id+"_atlas_desktop")
		root.size=Vector2i(800,500)
		atlas.hotspots.back().mouse_entered.emit()
		await capture(id+"_atlas_small")
	if "--atlas-only" in OS.get_cmdline_user_args():
		quit()
		return
	root.remove_child(atlas)
	atlas.queue_free()
	current_scene=null
	root.size=Vector2i(1280,800)
	for id in ["pyrrhia","pantala","forgotten_isles","nightwing_island"]:
		var scene = load("res://scenes/terrain_"+id+".tscn").instantiate()
		scene.set_meta("startup_loader",true)
		root.add_child(scene)
		current_scene=scene
		await scene.initialize_world()
		for i in 45: await physics_frame
		if scene.streamer:
			scene.set_process(false)
			var deadline:=Time.get_ticks_msec()+15000
			while (scene.streamer.active.size()>0 or not scene.streamer.collision_queue.is_empty() or scene.chunks.size()<scene.streamer.desired.size()) and Time.get_ticks_msec()<deadline:
				scene.streamer.pump()
				await process_frame
		scene.player.process_mode=Node.PROCESS_MODE_DISABLED
		scene.set_process(false)
		var camera:=Camera3D.new()
		camera.far=1200000 if scene.streamer else 80000
		camera.near=500 if scene.streamer else 20
		camera.fov=48
		scene.add_child(camera)
		camera.current=true
		var extent: Vector2=scene.terrain_data.extent
		var origin: Vector2=scene.world_origin
		var center := Vector3(-origin.x,0,-origin.y)
		var environment: Environment=scene.get_world_3d().environment
		var fog_was_enabled:=environment.fog_enabled
		if scene.streamer: environment.fog_enabled=false
		camera.position=center+Vector3(0,extent.x*.70,extent.y*.48)
		camera.look_at(center)
		for child in scene.get_children():
			if child is CanvasLayer: child.hide()
		await capture(id+"_aerial")
		environment.fog_enabled=fog_was_enabled
		camera.near=5
		for child in scene.get_children():
			if child is CanvasLayer: child.show()
		# A low aerial view towards a principal terrain feature.
		var target_map: Array
		var eye_offset: Vector3
		match id:
			"pyrrhia": target_map=[1080,760]; eye_offset=Vector3(3200,2000,3800)
			"pantala": target_map=[410,225]; eye_offset=Vector3(2200,1400,3100)
			"forgotten_isles": target_map=[350,280]; eye_offset=Vector3(1800,1300,2400)
			_: target_map=[382,238]; eye_offset=Vector3(1900,1200,2300)
		var p: Vector2=scene.terrain_data.map_to_world(target_map)
		var target:=Vector3(p.x-origin.x,scene.terrain_data.height_at(p),p.y-origin.y)
		if scene.streamer: eye_offset*=3
		camera.position=target+eye_offset
		camera.look_at(target)
		await capture(id+"_terrain")
		# Real player camera at the initial spawn, with no inspection camera.
		camera.current=false
		camera.queue_free()
		scene.player.get_node("CameraPivot/SpringArm3D/Camera3D").current=true
		await capture(id+"_player")
		if scene.streamer:
			var metrics: Dictionary=scene.streamer.stats()
			metrics.engine_static_bytes=Performance.get_monitor(Performance.MEMORY_STATIC)
			metrics.video_mem_bytes=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
			FileAccess.open(output+"/"+id+"_graphics_metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
		print("CAPTURED ",id)
		root.remove_child(scene)
		scene.queue_free()
		current_scene=null
		await process_frame
	quit()
