extends SceneTree
var scene: Node3D
var output := "res://../cache/protagonist-review"
func _initialize() -> void: run.call_deferred()
func ticks(count: int) -> void:
	for i in count: await physics_frame
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(file + ".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	scene = load("res://scenes/character_review.tscn").instantiate()
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1400, 900)
	await ticks(4)
	for id in scene.IDS:
		scene.select_character(id)
		await ticks(40)
		await capture(id + "-body")
		scene.frame_face()
		await ticks(2)
		await capture(id + "-face")
		if not scene.player.is_human:
			scene.pose = 1
			scene.pose_selector.select(1)
			scene._apply_pose()
			scene.frame_body()
			await ticks(80)
			await capture(id + "-wings")
			scene.pose = 3
			scene.pose_selector.select(3)
			scene._apply_pose()
			await ticks(2)
			await capture(id + "-clay")
	scene.select_character("umber")
	scene.reference.show()
	root.size = Vector2i(800, 600)
	await ticks(2)
	await capture("review-small")
	print("Review viewport ", root.get_visible_rect().size, " window ", root.size)
	print("Character review saved to ", ProjectSettings.globalize_path(output))
	quit()
