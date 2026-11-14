extends SceneTree
var village: Node3D
var camera: Camera3D
var output := "res://../cache/village-review"
func _initialize() -> void:
	_run.call_deferred()
func ticks(count: int) -> void:
	for i in count:
		await physics_frame
func capture(title: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(title + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	village = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	root.add_child(village)
	root.size = Vector2i(1280, 800)
	await ticks(30)
	var player = village.get_node("Clay")
	var chat = village.get_node("Conversations")
	for npc in chat.villagers:
		npc.idle_time = 500
	player.position = Vector3(10, 1, 15)
	camera = Camera3D.new()
	village.add_child(camera)
	camera.current = true
	camera.fov = 48
	await capture("01-village", Vector3(5, 12, 15), Vector3(-10, 1.5, -5))
	await capture("02-umber", Vector3(-5, 5.2, -18), Vector3(-10, 2.5, -10))
	await capture("03-children", Vector3(-9, 3, -7), Vector3(-11, 1.6, 3))
	player.position = village.get_node("Camille").position + Vector3(4, 0.1, 0)
	chat.start_conversation(village.get_node("Camille"))
	await capture("04-conversation", Vector3(-8, 3.5, -7), Vector3(-12, 1.8, 3))
	chat.close_conversation()
	print("Village review saved to ", ProjectSettings.globalize_path(output))
	quit()
