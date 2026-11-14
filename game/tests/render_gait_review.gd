extends SceneTree
## Render side clips and front/rear/overhead poses for walk, lope and sprint.
## Run with --fixed-fps 60 --rendering-method gl_compatibility.
var player
var scene
var camera: Camera3D
var output := ProjectSettings.globalize_path("res://../cache/gait-review")
var view := Vector3(12,3,1.8)
var frame_ticks: Dictionary = {}
func _initialize():
	run.call_deferred()
func ticks(n):
	for i in range(n):
		await physics_frame
func capture(name):
	var target: Vector3 = player.global_position + Vector3(0,1.7,0)
	camera.global_position = target + view
	camera.look_at(target)
	await process_frame
	await RenderingServer.frame_post_draw
	frame_ticks[name] = Engine.get_physics_frames()
	root.get_texture().get_image().save_png(output.path_join(name+'.png'))
func reset():
	for action in ['move_forward','move_left','sprint']:
		Input.action_release(action)
	player.spawn_position = Vector3(-38,0.1,35)
	player.reset_to_spawn()
	await ticks(20)
func run():
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	if FileAccess.file_exists(output.path_join("frame-ticks.json")):
		frame_ticks = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("frame-ticks.json")))
	var modes := ['walk','lope','sprint']
	if args.size() > 1:
		modes = [args[1]]
	for action in InputMap.get_actions():
		Input.action_release(action)
		InputMap.action_erase_events(action)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960,600)
	Engine.max_fps = 60
	scene = load('res://scenes/playground.tscn').instantiate()
	root.add_child(scene)
	for child in scene.get_children():
		if child is StaticBody3D and child.name != 'Ground':
			child.queue_free()
	player = scene.get_node('Clay')
	scene.hud.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	for mode in modes:
		await reset()
		Input.action_press('move_forward', 0.5 if mode == 'walk' else 1.0)
		if mode == 'sprint':
			Input.action_press('sprint')
		await ticks(90)
		view = Vector3(12,3,1.8)
		for i in range(60):
			await ticks(2)
			await capture('%s-side-%03d' % [mode,i])
		for viewpoint in ['front','rear','overhead']:
			if viewpoint == 'front':
				view = Vector3(0,3,-12)
			elif viewpoint == 'rear':
				view = Vector3(0,3,12)
			else:
				view = Vector3(0.1,15,0.1)
			for i in range(8):
				await ticks(2)
				await capture('%s-%s-%03d' % [mode,viewpoint,i])
	if modes.size() == 1:
		finish()
		return
	await reset()
	Input.action_press('move_forward',0.5)
	await ticks(90)
	Input.action_release('move_forward')
	Input.action_press('move_left',0.5)
	view = Vector3(8,9,8)
	for i in range(75):
		await ticks(2)
		await capture('turn-%03d' % i)
	finish()

func finish():
	var manifest := FileAccess.open(output.path_join("frame-ticks.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify(frame_ticks, "\t"))
	quit()
