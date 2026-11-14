extends SceneTree
var failures: Array[String] = []
var previous_transfer := false
var previous_model := Transform3D.IDENTITY
var transfer_translation := 0.0
var transfer_rotation := 0.0
func sample_transfer(player):
	var current:Transform3D=player.visual.motion.model.global_transform
	if previous_transfer:
		if current.origin.distance_to(previous_model.origin)>.4:print("transfer discontinuity ",player.locomotion_state," time ",player.climb.mantle_time," model from ",previous_model.origin," to ",current.origin," body ",player.position)
		transfer_translation=maxf(transfer_translation,current.origin.distance_to(previous_model.origin))
		transfer_rotation=maxf(transfer_rotation,previous_model.basis.orthonormalized().get_rotation_quaternion().angle_to(current.basis.orthonormalized().get_rotation_quaternion()))
	previous_transfer=player.locomotion_state==&"climbing" and player.climb.mantle_time>.05
	previous_model=current
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	if not ok: failures.append(message); printerr("FAIL: ",message)
func ticks(n: int):
	for i in n:
		await physics_frame
		var world=root.get_child(root.get_child_count()-1)
		if world.has_node("Clay"):sample_transfer(world.get_node("Clay"))
func run():
	var world = load("res://scenes/mudwing_wetlands.tscn").instantiate();root.add_child(world)
	await ticks(3)
	var player = world.get_node("Clay")
	for npc in ["Umber","Kai","Camille","Corinne"]: world.get_node(npc).set_physics_process(false)
	var home: Vector2 = world.homes[0]
	var facing: float = (Vector2(world._path_x(home.y),home.y)-home).angle()
	var out := Vector3(cos(facing),0,sin(facing))
	var start := Vector3(home.x,world.VILLAGE_LEVEL+.15,home.y)+out*11
	player.position=start;player.velocity=Vector3.ZERO
	player.visual.rotation.y=atan2(out.x,out.z);player.pivot.rotation.y=player.visual.rotation.y
	player._set_state(&"grounded")
	Input.action_press("move_forward")
	var attached := false
	var maximum_height := start.y
	var entered := false
	var support_error:=0.0
	var head_vertical:=0.0
	for i in 900:
		await physics_frame
		sample_transfer(player)
		attached=attached or player.locomotion_state==&"climbing"
		if player.locomotion_state==&"climbing" and player.climb.acquire_age>.6 and player.climb.mantle_time<0:
			var gaze=player.visual.motion.gaze
			var rig:Skeleton3D=player.visual.motion.skeleton
			var head:int=rig.find_bone("head")
			var deformation:Basis=rig.get_bone_global_pose(head).basis*rig.get_bone_global_rest(head).basis.inverse()
			var aim:Vector3=(rig.global_basis*deformation*gaze.rest_aim).normalized()
			head_vertical=maxf(head_vertical,absf(aim.y))
			var errors:Array=[]
			for leg in player.visual.motion.gait.legs:
				if not leg.swing:errors.append(leg.contact_error)
			if errors.size()>=3:
				errors.sort();support_error=maxf(support_error,errors[2])
		maximum_height=maxf(maximum_height,player.position.y)
		if i%120==0:print("climb ",i," ",player.locomotion_state," ",player.position," normal ",player.climb.normal," velocity ",player.velocity," support ",player.visual.motion.gait.turn_support)
		if attached and Vector2(player.position.x-home.x,player.position.z-home.y).length()<6.1:
			entered=true;break
	Input.action_release("move_forward")
	check(attached,"Walking against the hut acquires a claw grip")
	check(maximum_height>5.3,"Climbing gains height without flight")
	check(entered,"Climb over the high sill into the actual hut")
	check(head_vertical<.45,"Climbing gaze stays near the horizon rather than pointing skyward")
	check(support_error<.15,"At least three planted paws remain within grip reach")
	print("support error ",support_error," head vertical ",head_vertical)
	print("entry=",entered," maxheight=",maximum_height," pos=",player.position)
	await ticks(150)
	check(player.position.y < world.VILLAGE_LEVEL+.5, "Climb entry ends on the room floor")
	player.visual.rotation.y=atan2(-out.x,-out.z);player.pivot.rotation.y=player.visual.rotation.y
	Input.action_press("move_forward")
	var exited:=false
	for i in 900:
		await physics_frame
		sample_transfer(player)
		if i%120==0:print("exit ",i," ",player.locomotion_state," ",player.position," mantle ",player.climb.mantle_time)
		if Vector2(player.position.x-home.x,player.position.z-home.y).length()>10.8:
			exited=true;break
	Input.action_release("move_forward")
	check(exited,"Climb the inner wall and mantle back outside")
	await ticks(30)
	check(transfer_translation<.40,"Mantle and release preserve continuous model position")
	check(transfer_rotation<deg_to_rad(15),"Mantle and release preserve continuous model orientation")
	print("mantle peak per-frame travel ",transfer_translation," turn ",rad_to_deg(transfer_rotation))
	print("exit=",exited," pos=",player.position)
	# Jumping detaches from the wall, without silently becoming flight.
	player.reset_to_spawn();player.position=start;player.velocity=Vector3.ZERO
	player.visual.rotation.y=atan2(out.x,out.z);player.pivot.rotation.y=player.visual.rotation.y
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
		if player.locomotion_state==&"climbing": break
	Input.action_release("move_forward")
	var departure:Vector3=player.climb.normal
	Input.action_press("jump");await ticks(2);Input.action_release("jump")
	check(player.locomotion_state==&"airborne" and player.velocity.dot(departure)>2,"Jump pushes away from a wall grip")
	await check_drop_facing(player, start, out)
	# A stored wing cannot provide flight lift during deployment.
	player.reset_to_spawn();player.position=Vector3(0,25,0);player.velocity=Vector3.ZERO
	player.visual.motion.fold_amount=1;player.visual.motion.apply_wings()
	player._activate_flight();await ticks(3)
	check(player.velocity.y<0 and player.flight_mode==&"deploying","Folded-wing deployment remains ballistic")
	await ticks(65)
	check(player.locomotion_state==&"flying" and player.visual.motion.fold_amount<.05,"Powered flight resumes with deployed wings")
	# Mud support must drive the actual four-leg stepping solver.
	player.reset_to_spawn()
	var p:=Vector3(-95,0,-70);p.y=world._height(p.x,p.z)+.04
	player.position=p;player.velocity=Vector3.ZERO;player._set_state(&"grounded")
	await ticks(200)
	player.pivot.rotation.y=0;player.visual.rotation.y=0
	Input.action_press("move_forward")
	var steps:=0
	for i in 120:
		await physics_frame
		for leg in player.visual.motion.gait.legs:
			if leg.swing:steps+=1
	Input.action_release("move_forward")
	check(steps>30,"Soft mud still produces alternating paw recovery")
	check(player.visual.motion.gait.weight>.5,"Mud-supported walk stays visible")
	check(not player.climb.can_grip(Vector3(0,-.5,.866)),"Overhang exceeds claw grip limit")
	print("Climbing and mud smoke: ","PASS" if failures.is_empty() else "FAIL"," steps=",steps)
	quit(0 if failures.is_empty() else 1)

func check_drop_facing(player, start: Vector3, out: Vector3) -> void:
	player.reset_to_spawn()
	player.position = start
	player.visual.rotation.y = atan2(out.x, out.z)
	player.pivot.rotation.y = player.visual.rotation.y
	var model: Node3D = player.visual.motion.model
	Input.action_press("move_forward")
	for i in 150:
		await physics_frame
		if player.locomotion_state == &"climbing" and player.position.y > start.y + 1.5:
			break
	Input.action_release("move_forward")
	check(player.locomotion_state == &"climbing", "Clay is on the wall before dropping")
	Input.action_press("move_right")
	await ticks(24)
	Input.action_release("move_right")
	Input.action_press("cancel_flight")
	await ticks(2)
	Input.action_release("cancel_flight")
	check(player.locomotion_state == &"airborne", "Letting go drops Clay from the wall")
	await ticks(85)
	check(player.locomotion_state == &"grounded", "Clay lands after dropping from the wall")
	# Walk along the wall so neither direction sends Clay back into it.
	player.pivot.rotation.y = atan2(out.x, out.z) + PI / 2.0
	var landed_at: Vector3 = player.position
	var landed_heading: float = player.visual.rotation.y
	for action in ["move_forward", "move_back"]:
		if action == "move_back":
			# Test both directions from the same landing, before reaching other huts.
			player.position = landed_at
			player.visual.rotation.y = landed_heading
			player.velocity = Vector3.ZERO
			await ticks(8)
		Input.action_press(action)
		await ticks(110)
		Input.action_release(action)
		var travel: Vector3 = player.velocity.slide(Vector3.UP)
		# The imported mesh faces +Z; the controller faces -Z.
		var nose := model.global_basis.z.slide(Vector3.UP).normalized()
		var alignment := nose.dot(travel.normalized())
		var desired: Vector3 = -player.pivot.basis.z.slide(Vector3.UP).normalized()
		if action == "move_back":
			desired = -desired
		check(travel.dot(desired) > 0.15 and alignment > 0.95,
			"Clay faces his direction of travel after dropping (%s: speed %.2f, alignment %.2f)" % [action, travel.length(), alignment])
