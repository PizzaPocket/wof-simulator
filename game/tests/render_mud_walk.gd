extends SceneTree
func _initialize():run.call_deferred()
func run():
	var folder:=ProjectSettings.globalize_path("res://../cache/mud-walk-final")
	DirAccess.make_dir_recursive_absolute(folder)
	var world=load("res://scenes/mudwing_wetlands.tscn").instantiate();root.add_child(world)
	root.size=Vector2i(1100,750)
	await physics_frame;await physics_frame
	for ob in world.get_children():
		if ob is CanvasLayer:ob.hide()
	var player=world.get_node("Clay")
	player.reset_to_spawn();player.position=Vector3(-42,world.MUD_LEVEL+.04,14)
	for i in 250:await physics_frame
	player.visual.rotation.y=PI;player.pivot.rotation.y=PI
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=58
	for frame in 240:
		Input.action_press("move_forward")
		await physics_frame
		camera.position=player.position+Vector3(-11,5,14)
		camera.look_at(player.position+Vector3.UP*1.8)
		if frame%4==0:
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("frame-%03d.png"%(frame/4)))
		if player.position.z>22:break
	Input.action_release("move_forward")
	print("Mud walk recorded; support=",player.mud_supported," gait=",player.visual.motion.gait.weight)
	quit()
