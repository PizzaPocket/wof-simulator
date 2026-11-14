extends SceneTree
var world: Node3D
var camera: Camera3D
var output:="res://../cache/marsh-interaction"
func _initialize():_run.call_deferred()
func shot(name: String,eye: Vector3,target: Vector3):
 camera.position=eye;camera.look_at(target)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(name+".png"))
func _run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 world=load("res://scenes/mudwing_wetlands.tscn").instantiate();root.add_child(world);root.size=Vector2i(1300,850)
 await physics_frame;await physics_frame
 for ob in world.get_children():
  if ob is CanvasLayer:ob.hide()
 for id in ["Umber","Kai","Camille","Corinne"]:world.get_node(id).set_physics_process(false)
 var player=world.get_node("Clay")
 camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=58
 var home: Vector2=world.homes[0];var data: Array=world.design.homes[0]
 var facing: float=(Vector2(world._path_x(home.y),home.y)-home).angle()
 var out:=Vector3(cos(facing),0,sin(facing));var side:=Vector3(-out.z,0,out.x)
 var base:=Vector3(home.x,world.VILLAGE_LEVEL-.1,home.y)
 var radius: float=data[2];var height: float=data[3]
 var entry_y:=height*sin(.38)+1.1
 player.position=base+out*11+Vector3.UP*.25
 player.velocity=Vector3.ZERO;player.visual.rotation.y=atan2(out.x,out.z);player.pivot.rotation=Vector3(0,player.visual.rotation.y,0)
 player._set_state(&"grounded")
 Input.action_press("move_forward")
 for i in 120:await physics_frame
 await shot("01-climbing",base+out*23+side*14+Vector3.UP*8,base+Vector3.UP*6)
 for i in 400:
  await physics_frame
  if Vector2(player.position.x-home.x,player.position.z-home.y).length()<6.1:break
 Input.action_release("move_forward")
 for i in 150:await physics_frame
 player.set_physics_process(false);player.velocity=Vector3.ZERO
 await shot("02-inside",base+out*(radius*.58)+side*2+Vector3.UP*6,player.position+Vector3.UP*2.8)
 # The same actor then settles gradually through the visible marsh surface.
 var p:=Vector3(-42,world.MUD_LEVEL+.04,14)
 player.position=p;player.velocity=Vector3.ZERO;player._set_state(&"grounded");player.visual.rotation.y=.2;player.pivot.rotation=Vector3(-.35,.2,0);player.mud_sink=0;player.ground_distance=0
 player.visual.motion.reset_motion()
 player.visual.motion.fold_target=1;player.visual.motion.fold_amount=1;player.visual.motion.apply_wings()
 for i in 30:await physics_frame
 var eye:=p+Vector3(-11,5,-14);var target:=p+Vector3.UP*2
 await shot("03-mud-before",eye,target)
 player.set_physics_process(true)
 for i in 300:await physics_frame
 player.set_physics_process(false)
 await shot("04-mud-settled",eye,target)
 print("Marsh interaction evidence ",ProjectSettings.globalize_path(output));quit()
