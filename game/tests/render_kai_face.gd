extends SceneTree
func _initialize():run.call_deferred()
func run():
 var output:=ProjectSettings.globalize_path("res://../cache/kai-nose-review")
 DirAccess.make_dir_recursive_absolute(output)
 var tag:="after" if "after" in OS.get_cmdline_user_args() else "before"
 root.size=Vector2i(800,850)
 var scene:=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("36444b")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;scene.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,150,0);sun.light_energy=1.3;scene.add_child(sun)
 var h=load("res://scripts/scavenger_visual.gd").new();h.character_id="kai";scene.add_child(h)
 h.time=0;h.head_yaw=0;h.animate(0,0,"looking around",false,null);h.apply_blink(0)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.30;scene.add_child(camera);camera.current=true
 var center:=Vector3(0,1.245,-.04)
 for view in ["front","quarter","profile"]:
  var direction:=Vector3(0,0,-1) if view=="front" else Vector3(.6,0,-.8) if view=="quarter" else Vector3(1,0,0)
  camera.position=center+direction*1.5;camera.look_at(center)
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join(tag+"-"+view+".png"))
 print("Kai facial review: ",tag);quit()
