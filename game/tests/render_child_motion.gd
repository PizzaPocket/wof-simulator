extends SceneTree
var output:="res://../cache/child-motion"
func _initialize():_run.call_deferred()
func _run():
 var side_view:=OS.get_cmdline_user_args().has("side")
 if side_view:output="res://../cache/child-motion-side"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.size=Vector2i(1000,760)
 var scene:=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("36444b")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6
 scene.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,150,0);sun.light_energy=1.3;sun.shadow_enabled=true;scene.add_child(sun)
 var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(7,9);floor.mesh=plane;floor.position=Vector3(0,-.006,-1)
 var floor_material:=StandardMaterial3D.new();floor_material.albedo_color=Color("536064");floor_material.roughness=1;floor.material_override=floor_material;scene.add_child(floor)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.35
 scene.add_child(camera);camera.current=true
 var humans: Array=[]
 var ids: Array=["kai","camille","corinne"]
 for i in 3:
  var human=load("res://scripts/scavenger_visual.gd").new();human.character_id=ids[i];human.child_age=6 if i==2 else 9
  human.position.x=(i-1)*.90;scene.add_child(human);human.stride=i*.17;humans.append(human)
 for frame in 270:
  var t:=frame/30.0
  var speed:=minf(.65,t*1.3) if t<3 else .65*(1-smoothstep(3,3.5,t))
  var activity:="wandering" if t<3 else "looking around" if t<6 else "watching a dragon"
  for human in humans:
   human.position.z-=speed/30.0
   human.animate(1.0/30.0,speed,activity,false,null)
  var center_z: float=humans[1].position.z
  camera.position=Vector3(1.1,.95,center_z-5);camera.look_at(Vector3(0,.78,center_z))
  if side_view:
   camera.position=Vector3(4.5,.95,center_z-2);camera.look_at(Vector3(0,.78,center_z))
  await process_frame
  if frame%3==0:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join("frame-%03d.png"%(frame/3)))
 for human in humans:
  human.time=0;human.head_yaw=0;human.wave_weight=0;human.walk_blend=0
  human.animate(0,0,"looking around",false,null)
  camera.size=.32
  var center: Vector3=human.position+Vector3(0,human.height_m*.925,0)
  camera.position=center+Vector3(.14,.015,-1.5);camera.look_at(center)
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(human.character_id+"-face.png"))
 var child=humans[0]
 child.walk_blend=1;child.stride=.2;child.animate(0,.65,"wandering",false,null)
 camera.size=.23
 var center:Vector3=child.model.to_global((child._pose("wrist.R").origin+child._pose("finger3-2.R").origin)*.5)
 camera.position=center+Vector3(.15,.015,-.55);camera.look_at(center)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join("relaxed-hand.png"))
 print("Child motion frames saved ",ProjectSettings.globalize_path(output));quit()
