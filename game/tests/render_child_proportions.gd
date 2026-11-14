extends SceneTree
## Orthographic body review: accepted heads, fitted clothes, neutral and posed rigs.
var camera: Camera3D
var world: Node3D
var output := "res://../cache/child-proportions"
const CHAINS = [
 ["head", "neck01", "spine01", "spine02", "spine03", "spine04", "spine05", "root"],
 ["spine01", "clavicle.L", "upperarm01.L", "lowerarm01.L", "wrist.L", "finger3-3.L"],
 ["spine01", "clavicle.R", "upperarm01.R", "lowerarm01.R", "wrist.R", "finger3-3.R"],
 ["root", "upperleg01.L", "lowerleg01.L", "foot.L", "toe3-1.L"],
 ["root", "upperleg01.R", "lowerleg01.R", "foot.R", "toe3-1.R"]]
func _initialize():
 _run.call_deferred()
func capture(name: String, center: Vector3, eye: Vector3):
 camera.position = center + eye
 camera.look_at(center)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(name+".png"))
func overlay(human) -> MeshInstance3D:
 var mesh := ImmediateMesh.new()
 var mat := StandardMaterial3D.new()
 mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.no_depth_test = true
 mat.albedo_color = Color("ffb653")
 mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
 for chain in CHAINS:
  for i in range(chain.size()-1):
   if not human.bone_ids.has(chain[i]) or not human.bone_ids.has(chain[i+1]): continue
   mesh.surface_add_vertex(human._pose(chain[i]).origin)
   mesh.surface_add_vertex(human._pose(chain[i+1]).origin)
 mesh.surface_end()
 var ob := MeshInstance3D.new()
 ob.mesh = mesh
 human.add_child(ob)
 return ob
func _run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.size = Vector2i(800,1000)
 world=Node3D.new();root.add_child(world)
 var env := WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("343d46")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("eff3ff")
 env.environment.ambient_light_energy=.7
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world.add_child(env)
 var light := DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-35,150,0);light.light_energy=1.5;world.add_child(light)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.66;world.add_child(camera);camera.current=true
 for id in ["kai","camille","corinne"]:
  var selected=OS.get_cmdline_user_args()
  if not selected.is_empty() and not id in selected:continue
  var human=load("res://scripts/scavenger_visual.gd").new()
  human.character_id=id;human.child_age=6 if id=="corinne" else 9
  world.add_child(human)
  human.time=0;human.head_yaw=0
  human.animate(0,0,"looking around",false,null)
  var center=Vector3(0,.72,0)
  await capture(id+"-front",center,Vector3(0,0,-3))
  await capture(id+"-side",center,Vector3(3,0,0))
  camera.size=.27
  await capture(id+"-shoes",Vector3(0,.07,0),Vector3(.7,.16,-3))
  camera.size=.57
  await capture(id+"-shirt",Vector3(0,.965,0),Vector3(.8,0,-3))
  var saved_visible={}
  var clay=StandardMaterial3D.new();clay.albedo_color=Color(.58,.62,.64);clay.roughness=1
  for ob in human.model.find_children("*","MeshInstance3D",true,false):
   saved_visible[ob]=ob.visible
   ob.visible=ob.name.begins_with("Continuous anatomical skin")
   if ob.visible:ob.material_override=clay
  camera.size=.34
  await capture(id+"-plain-torso",Vector3(0,.96*human.height_m/1.35,0),Vector3(0,0,-3))
  for ob in saved_visible:
   ob.visible=saved_visible[ob];ob.material_override=null
  camera.size=1.66
  human.walk_blend=1;human.stride=.18
  human.animate(0,.65,"wandering",false,null)
  await capture(id+"-walk",center,Vector3(1.4,0,-3))
  human.walk_blend=0;human.time=0;human.head_yaw=0
  human.animate(0,0,"looking around",false,null)
  var lines=overlay(human)
  await capture(id+"-front-rig",center,Vector3(0,0,-3))
  await capture(id+"-side-rig",center,Vector3(3,0,0))
  lines.queue_free();await process_frame
  human.skeleton.reset_bone_poses()
  await capture(id+"-rest",center,Vector3(0,0,-3))
  human.queue_free();await process_frame
 print("Child proportion review: ",ProjectSettings.globalize_path(output))
 quit()
