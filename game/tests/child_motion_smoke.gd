extends SceneTree
var failures: Array[String]=[]
func _initialize():_run.call_deferred()
func check(ok: bool,message: String):
 if not ok and not message in failures:failures.append(message);printerr("FAIL ",message)
func _run():
 for id in ["kai","camille","corinne"]:
  var human=load("res://scripts/scavenger_visual.gd").new();human.character_id=id;human.child_age=6 if id=="corinne" else 9
  root.add_child(human);await process_frame
  var previous: Dictionary={};var maximum:=0.0;var peaks: Dictionary={}
  for frame in 720:
   var t:=frame/60.0
   var speed:=.65 if t<4 else 0.0
   var activity:="wandering" if t<4 else "waving" if t<8 else "looking around"
   human.animate(1.0/60.0,speed,activity,false,null)
   for bone in ["upperarm01.L","upperarm01.R","lowerarm01.R","wrist.R","upperleg01.L","lowerleg01.L","foot.L"]:
    var q: Quaternion=human._pose(bone).basis.get_rotation_quaternion()
    if previous.has(bone):
     var angle: float=previous[bone].angle_to(q)
     maximum=maxf(maximum,angle)
     peaks[bone]=maxf(peaks.get(bone,0.0),rad_to_deg(angle))
     check(angle<deg_to_rad(16),id+" sudden pose flip in "+bone)
    previous[bone]=q
   for side in ["L","R"]:
    var a: Vector3=human._pose("upperarm01."+side).origin
    var b: Vector3=human._pose("lowerarm01."+side).origin
    var c: Vector3=human._pose("wrist."+side).origin
    var angle: float=(a-b).angle_to(c-b)
    check(angle<deg_to_rad(173),id+" locked elbow")
   if frame==330:
    check(human._pose("finger3-3.R").origin.y>human._pose("wrist.R").origin.y+.01,id+" wave fingers must follow raised forearm")
  print(id," maximum per-frame joint turn: ",rad_to_deg(maximum)," degrees; ",peaks)
  human.queue_free();await process_frame
 print("Child motion smoke: ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
