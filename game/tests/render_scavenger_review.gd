extends SceneTree
var scene: Node3D
var camera: Camera3D
var output := "res://../cache/scavenger-review"
var quick := "quick" in OS.get_cmdline_user_args()
func _initialize() -> void:
	_run.call_deferred()
func capture(title: String, center: Vector3, eye: Vector3, size: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.global_position = center + eye
	camera.look_at(center)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(title + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	scene = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1100, 1100)
	await physics_frame
	for child in scene.get_children():
		if child is CanvasLayer:
			child.hide()
	var player = scene.get_node("Clay")
	player.position = Vector3(50, 1, 40)
	player.set_physics_process(false)
	for npc_name in ["Umber", "Kai", "Camille", "Corinne"]:
		var npc = scene.get_node(npc_name)
		npc.set_physics_process(false)
		npc.visual.rotation.y = 0
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	for id in ["kai", "camille", "corinne"]:
		if "corinne" in OS.get_cmdline_user_args() and id != "corinne":
			continue
		for other in ["Umber", "Kai", "Camille", "Corinne"]:
			scene.get_node(other).visible = other.to_lower() == id
		var npc = scene.get_node(id.capitalize())
		var human = npc.human
		human.animate(0, 0, "looking around", false, null)
		print(id, " rig frame ", human.rig_frame, " head ", human._rest("head").origin, " left foot ", human._pose("foot.L").origin)
		var base: Vector3 = npc.global_position
		await capture(id + "-front", base + Vector3(0, human.height_m * 0.50, 0), Vector3(0, 0.08, -3), 1.65)
		if not quick:
			await capture(id + "-quarter", base + Vector3(0, human.height_m * 0.50, 0), Vector3(1.7, 0.28, -3), 1.65)
			await capture(id + "-rear", base + Vector3(0, human.height_m * 0.55, 0), Vector3(1.5, 0.15, 3), 1.55)
		await capture(id + "-face", base + Vector3(0, human.height_m * 0.92, 0), Vector3(0.65, 0.02, -3), 0.39)
		human.apply_blink(1)
		await capture(id + "-blink", base + Vector3(0, human.height_m * 0.92, 0), Vector3(0.65, 0.02, -3), 0.39)
		human.apply_blink(0)
		human.stride = 0.18
		human.walk_blend = 1
		human.animate(0, 0.65, "wandering", false, null)
		if not quick:
			await capture(id + "-walk", base + Vector3(0, human.height_m * 0.50, 0), Vector3(2, 0.12, -3), 1.65)
	var umber = scene.get_node("Umber")
	umber.show()
	await capture("umber-pouch", umber.global_position + Vector3(-0.85, 1.72, -1.32), Vector3(-3, .15, -2.0), 0.90)
	print("Scavenger review saved: ", ProjectSettings.globalize_path(output))
	quit()
