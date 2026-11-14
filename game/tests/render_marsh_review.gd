extends SceneTree
var scene: Node3D
var camera: Camera3D
var output:="res://../cache/marsh-review"
func _initialize():_run.call_deferred()
func capture(name: String,eye: Vector3,target: Vector3):
 camera.position=eye;camera.look_at(target)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(name+".png"))
func _run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 scene=load("res://scenes/mudwing_wetlands.tscn").instantiate();root.add_child(scene);root.size=Vector2i(1400,900)
 await physics_frame
 for child in scene.get_children():
  if child is CanvasLayer:child.hide()
 scene.get_node("Clay").set_physics_process(false);scene.get_node("Clay").position=Vector3(0,1,10)
 for name in ["Umber","Kai","Camille","Corinne"]:scene.get_node(name).set_physics_process(false)
 camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=57
 await capture("01-marsh-village",Vector3(95,75,105),Vector3(-23,1,12))
 await capture("02-raised-causeway",Vector3(-3,6,27),Vector3(-34,2,-18))
 await capture("03-river-pools",Vector3(98,42,44),Vector3(30,-1,14))
 await capture("04-mud-nests",Vector3(-10,20,-39),Vector3(-53,8,-26))
 await capture("05-wetland-trees",Vector3(-67,12,114),Vector3(-100,14,88))
 await capture("06-irregular-boundary",Vector3(240,340,260),Vector3(0,-1,0))
 await capture("09-stagnant-marsh",Vector3(-23,5,35),Vector3(-34,-.3,46))
 var umber=scene.get_node("Umber");var base: Vector3=umber.position
 await capture("07-umber-eye",base+Vector3(-.95,2.85,-3.35),base+Vector3(-.23,2.72,-2.62))
 await capture("08-umber-profile",base+Vector3(-1.25,2.78,-2.58),base+Vector3(-.23,2.72,-2.62))
 print("Marsh review ",ProjectSettings.globalize_path(output));quit()
