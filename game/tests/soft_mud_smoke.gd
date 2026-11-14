extends SceneTree
var failures: Array[String]=[]
func _initialize():_run.call_deferred()
func check(ok: bool,message: String):
 if not ok:failures.append(message);printerr("FAIL ",message)
func _run():
 var world=load("res://scenes/mudwing_wetlands.tscn").instantiate();root.add_child(world)
 await physics_frame;await physics_frame
 var player=world.get_node("Clay")
 var point:=Vector3(-95,0,-70);point.y=world._height(point.x,point.z)+.04
 var sample: Dictionary=world.sample_soft_mud(point)
 check(not sample.is_empty(),"lowland is soft mud")
 if sample.is_empty():quit(1);return
 player.position=point;player.velocity=Vector3.ZERO;player._set_state(&"grounded")
 for i in 300:await physics_frame
 var depth: float=float(sample.surface_y)-player.position.y
 check(depth>.20 and depth<.75,"body gradually sinks into marsh soil")
 check(player.mud_supported,"mud provides soft support above hard bed")
 check(player.locomotion_state==&"grounded","soft support retains walking/jumping state")
 var kai=world.get_node("Kai")
 var wet:=Vector3(-25,0,3);wet.y=world._height(wet.x,wet.z)+.03
 kai.position=wet;kai.velocity=Vector3.ZERO;kai.idle_time=500
 var refuge: Vector3=world.dry_refuge(wet)
 var before: float=Vector2(wet.x-refuge.x,wet.z-refuge.z).length()
 for i in 180:await physics_frame
 var after: float=Vector2(kai.position.x-refuge.x,kai.position.z-refuge.z).length()
 check(after<before-.4,"child seeks dry causeway rather than idling in mud")
 for id in ["Camille","Corinne"]:
  for waypoint in world.get_node(id).route:check(world.is_dry_ground(waypoint),id+" routes stay dry")
 print("Soft mud smoke: ","PASS" if failures.is_empty() else "FAIL","; sinking ",depth," m; child refuge progress ",before-after," m")
 quit(0 if failures.is_empty() else 1)
