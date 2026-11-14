extends SceneTree
var output := "res://../cache/climb-review"
func _initialize():run.call_deferred()
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var world=load("res://scenes/mudwing_wetlands.tscn").instantiate();root.add_child(world)
	root.size=Vector2i(1200,850)
	await physics_frame;await physics_frame
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	for id in ["Umber","Kai","Camille","Corinne"]:world.get_node(id).set_physics_process(false)
	var player=world.get_node("Clay")
	var home:Vector2=world.homes[0]
	var facing:float=(Vector2(world._path_x(home.y),home.y)-home).angle()
	var out:=Vector3(cos(facing),0,sin(facing));var side:=Vector3(-out.z,0,out.x)
	var base:=Vector3(home.x,world.VILLAGE_LEVEL,home.y)
	player.position=base+out*11+Vector3.UP*.15;player.velocity=Vector3.ZERO
	player.visual.rotation.y=atan2(out.x,out.z);player.pivot.rotation.y=player.visual.rotation.y
	player._set_state(&"grounded")
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=21
	camera.position=base+out*23+side*15+Vector3.UP*9
	camera.look_at(base+Vector3.UP*7)
	Input.action_press("move_forward")
	for frame in 420:
		Input.action_press("move_forward")
		await physics_frame
		if frame%6==0:
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join("frame-%03d.png"%(frame/6)))
		if frame==100 or frame==180:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join("climb.png" if frame==100 else "mantle.png"))
	Input.action_release("move_forward")
	print("Climb review: ",player.locomotion_state," ",player.position)
	quit()
