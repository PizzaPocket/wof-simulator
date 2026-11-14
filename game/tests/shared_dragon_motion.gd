extends SceneTree
## Real actors on an isolated flat fixture: shared gait, jump, climb and flight.
var failures: Array[String] = []
var world: Node3D
var moon: CharacterBody3D
func _initialize() -> void: run.call_deferred()
func ticks(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);printerr("FAIL: ",message)
func box(name: String, size: Vector3, position: Vector3, climbable := false) -> StaticBody3D:
	var body := StaticBody3D.new();body.name=name;body.position=position
	var shape := CollisionShape3D.new();var geometry := BoxShape3D.new();geometry.size=size;shape.shape=geometry;body.add_child(shape)
	world.add_child(body)
	if climbable:body.add_to_group("climbable")
	return body
func reset_moon() -> void:
	for action in ["move_forward","sprint","jump"]:Input.action_release(action)
	if moon.locomotion_state==&"climbing":moon.climb.release()
	moon.spawn_position=Vector3(0,50.7,0);moon.reset_to_spawn();moon.climb.cooldown=0
	moon.pivot.rotation=Vector3.ZERO;moon.visual.rotation=Vector3.ZERO
	await ticks(25)
func run() -> void:
	world=load("res://scenes/mudwing_wetlands.tscn").instantiate();world.roster_save_path="";root.add_child(world)
	await ticks(8)
	moon=world.get_node("Moon")
	var clay=world.get_node("Clay");var roster=world.get_node("Protagonists")
	box("MotionTestFloor",Vector3(500,1,500),Vector3(0,50,0))
	roster._switch(moon)
	var motion=moon.visual.motion
	for component in ["gait","jump","flight","gaze","tail","blink"]:
		check(motion.get(component).get_script().resource_path==clay.visual.motion.get(component).get_script().resource_path,"Moon reuses Clay's "+component+" implementation")
	check(motion.gait.legs.size()==4,"Anatomy profile maps all four limb chains")
	check(motion.gait.legs[0].digits.size()>=4,"Moon's toes participate in the shared distal articulation")
	await reset_moon()
	Input.action_press("move_forward");await ticks(100)
	check(moon.position.z < -6,"Shared locomotion produces sustained forward travel")
	Input.action_press("sprint")
	var error:=0.0;var suspension:=false;var worst:Dictionary={}
	for i in 150:
		await ticks(1)
		suspension=suspension or motion.gait.gallop.suspension
		for leg in motion.gait.legs:
			if not leg.swing and float(leg.contact_error)>error:
				error=float(leg.contact_error);worst={"leg":leg.name,"phase":leg.phase,"pitch":leg.pitch,"extension":motion.gait.gallop.extension,"root":leg.root,"target":leg.last_target,"a":leg.length_a,"b":leg.length_b}
	check(motion.gait.gallop.active and motion.gait.gallop.extension>.9,"Moon enters Clay's full sprint cycle")
	check(suspension,"Sprint includes the shared unsupported travel phase")
	check(error<.08,"Mapped sprint contacts stay within anatomical reach (%.3f m)"%error)
	await reset_moon()
	Input.action_press("jump");await ticks(2);Input.action_release("jump");await ticks(15)
	check(moon.locomotion_state==&"airborne" and moon.position.y>51,"Moon uses the staged jump without entering flight")
	moon.position=Vector3(0,125,0);moon.velocity=Vector3.ZERO
	moon._activate_flight();moon.pivot.rotation.x=-.30
	await ticks(30)
	check(motion.flight.flap_blend>.25,"Launch produces the shared initial powered effort")
	await ticks(210)
	check(moon.locomotion_state==&"flying" and moon.flight_mode==&"gliding" and motion.flight.flap_blend<.05,"Descending flight settles into a glide")
	moon.pivot.rotation.x=.30;await ticks(90)
	check(motion.flight.flap_blend>.90,"Gaining altitude restores powered flapping")
	check(motion.jump.limb_carriage.directions.size()==4,"Flight uses Clay's four-limb carriage system")
	await reset_moon()
	box("MotionTestClimbWall",Vector3(12,12,1),Vector3(0,56.5,-8),true)
	Input.action_press("move_forward")
	var attached:=false;var initial_height:=moon.position.y
	for i in 200:
		await ticks(1)
		if moon.locomotion_state==&"climbing":attached=true;break
	check(attached,"Moon acquires a wall through the shared claw-contact system")
	if attached:
		await ticks(90)
		check(moon.position.y>initial_height+.8,"Mapped climbing gains height")
		Input.action_press("jump");await ticks(2);Input.action_release("jump")
		check(moon.locomotion_state==&"airborne","Jump releases Moon from the wall without entering flight")
	Input.action_release("move_forward")
	var blue=world.get_node("Blue")
	check(blue.visual.motion.gait.legs.size()==4 and blue.visual.motion.flight.stroke_bones.size()==4,"The same profile system maps all four SilkWing wings and four legs")
	print("Shared dragon motion: ","PASS" if failures.is_empty() else "FAIL", "; peak sprint contact error ",error,"; worst ",worst)
	quit(0 if failures.is_empty() else 1)
