extends SceneTree
var failures: Array[String]=[]
func _initialize():_run.call_deferred()
func check(ok: bool,message: String):
 if not ok:failures.append(message);printerr("FAIL ",message)
func _run():
 var world=load("res://scenes/mudwing_wetlands.tscn").instantiate();root.add_child(world)
 await physics_frame;await physics_frame
 check(world.homes.size()>=10,"clustered nests")
 check(world._height(world._path_x(0),0)-world._height(-30,24)>.9,"causeway raised above flooded lowland")
 for z in [-145.0,145.0]:
  var center: float=62+19*sin(z/56)+8*sin(z/23+.6)
  check(world.WATER_LEVEL-world._height(center,z)>4,"deep main river bed")
 var low:=INF;var high:=-INF
 for i in 36:
  var radius: float=world._region_radius(TAU*i/36);low=minf(low,radius);high=maxf(high,radius)
 check(high-low>40,"irregular perimeter")
 check(world.get_node("TallMarshSedges").multimesh.instance_count>15000,"substantial marsh grass")
 var player=world.get_node("Clay");player.set_physics_process(false)
 for actor in ["Umber","Kai","Camille","Corinne"]:world.get_node(actor).set_physics_process(false)
 var home: Vector2=world.homes[0];var data: Array=world.design.homes[0]
 var facing: float=(Vector2(world._path_x(home.y),home.y)-home).angle()
 var direction:=Vector3(cos(facing),0,sin(facing))
 var base:=Vector3(home.x,world.VILLAGE_LEVEL-.1,home.y)
 var radius: float=data[2];var height: float=data[3]
 var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
 var low_start:=base+direction*(radius+5)+Vector3.UP*1.5
 var low_end:=base+direction*(radius*.20)+Vector3.UP*1.5
 var ray:=PhysicsRayQueryParameters3D.create(low_start,low_end);ray.exclude=[player.get_rid()]
 check(not space.intersect_ray(ray).is_empty(),"no ground-level doorway")
 # Climbing entry is exercised separately, with actual player movement.
 check(player.visual.motion.flight.fold_for_flight()==0.0,"Flight always requires deployed wings")
 print("Wetlands world smoke: ","PASS" if failures.is_empty() else "FAIL","; grass clumps ",world.get_node("TallMarshSedges").multimesh.instance_count)
 quit(0 if failures.is_empty() else 1)
