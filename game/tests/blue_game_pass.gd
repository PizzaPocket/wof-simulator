extends "res://tests/moon_game_pass.gd"
## The replacement SilkWing in the actual village, plus the giant resident.
func curved_ray(wing:Dictionary,digit:Dictionary,t:float) -> Vector3:
	return pow(1-t,3)*vec(digit.get("origin",wing.wrist))+3*pow(1-t,2)*t*vec(digit.control1)+3*(1-t)*t*t*vec(digit.control2)+t*t*t*vec(digit.tip)

func posed_vertices(candidates:Array[Node],rig:Skeleton3D) -> PackedVector3Array:
	var points:=PackedVector3Array()
	for candidate in candidates:
		var mesh:=candidate as MeshInstance3D
		var arrays:Array=mesh.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var blends:Array=mesh.mesh.surface_get_blend_shape_arrays(0)
		for index in vertices.size():points.append(skin_position({"mesh":mesh,"arrays":arrays,"index":index,"blends":blends},rig))
	return points

func nearest_posed_distance(points:PackedVector3Array,target:Vector3) -> float:
	var distance:=INF
	for point in points:distance=minf(distance,point.distance_to(target))
	return distance

func bezier_point(a:Vector3,b:Vector3,c:Vector3,d:Vector3,t:float) -> Vector3:
	return pow(1-t,3)*a+3*pow(1-t,2)*t*b+3*(1-t)*t*t*c+t*t*t*d

func run() -> void:
	output="res://../cache/blue-in-game"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	world=load("res://scenes/mudwing_wetlands.tscn").instantiate()
	world.roster_save_path=""
	root.add_child(world)
	await ticks(10)
	moon=world.get_node("Blue")
	var clay=world.get_node("Clay")
	var roster=world.get_node("Protagonists")
	check(moon.position.distance_to(clay.position)<12,"Blue is visible on the starting approach")
	var dark=world.get_node("Darkstalker")
	check(dark.visual.model_scale>6*moon.visual.model_scale,"Darkstalker is an ancient-scale scene resident")
	check(not roster.protagonists.has("darkstalker"),"Darkstalker remains outside the collectible roster")
	clay.position=moon.position+Vector3(0,.1,3)
	clay.velocity=Vector3.ZERO
	await ticks(5)
	await tap(&"possess_protagonist")
	check(world.player==moon,"X possesses rebuilt Blue")
	clay.position=Vector3(3,world._height(3,16)+.08,16)
	clay.velocity=Vector3.ZERO
	var motion=moon.visual.motion
	var rig:Skeleton3D=motion.skeleton
	check(motion.wing_rigs.size()==4,"Exactly four articulated SilkWing wings")
	check(motion.folds.is_empty(),"No old compressed-wing morph rig remains")
	check(motion.antenna_flow!=null,"Soft antenna flow is active")
	check(motion.staged_eyelids.size()==2,"Two fitted staged eyelids")
	check(rig.find_children("SilkWing brow antenna*","MeshInstance3D",true,false).size()==2,"Distinct slender brow antennae")
	check(rig.find_children("SilverTearScale*","MeshInstance3D",true,false).is_empty(),"No NightWing silver tears")
	check(rig.find_children("NightWingMembrane*","MeshInstance3D",true,false).is_empty(),"No leftover NightWing wing fan")
	check(rig.find_children("Moon arm patagium*","MeshInstance3D",true,false).is_empty(),"No leading-side membrane triangle")
	check(rig.get_bone_count()==131,"Full segmented replacement rig")
	for wing in motion.anatomy.wing_rig.values():
		check(wing.digits.size()==(3 if wing.bank=="fore" else 2),"Distinct forewing/hindwing support counts")
		check(wing.membrane_attachment_side.begins_with("trailing"),"Trailing articulated arm attachment")
		if wing.bank=="hind":
			check(wing.digits[1].attachment=="proximal","Small wing support begins at its base")
			check(vec(wing.digits[1].origin).distance_to(vec(wing.elbow))<.001,"Basal hook is seated at the proximal arm bend")
			check(vec(wing.digits[1].tip).distance_to(vec(wing.digits[1].origin))<.45,"Small wing basal support stays short rather than becoming a second full ray")
		check(wing.edge_style=="continuous_spline_lobes","Smooth continuous outer wing lobe")
		for digit in wing.digits:check(digit.smooth_arc,"Curved supports without visible knuckle swellings")
	for eye in motion.anatomy.face_fit.eyes:
		check(eye.closed_blink_uncovered_samples==0,"Closed blink covers the globe")
	var pairs:Array[Array]=[]
	var attachments:Array[Dictionary]=[]
	var membranes:=rig.find_children("SilkWingMembrane*","MeshInstance3D",true,false)
	var webs:=rig.find_children("Moon continuous axillary membrane*","MeshInstance3D",true,false)
	for web:MeshInstance3D in webs:
		check((web.mesh.surface_get_format(0)&Mesh.ARRAY_FORMAT_COLOR)!=0,"Proximal wing webs have their blue-violet color attributes")
	var colored_crown:=false
	for host:MeshInstance3D in rig.find_children("MoonSkin Nasal*","MeshInstance3D",true,false):
		var colors:PackedColorArray=host.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for color in colors:
			if color.r>color.g*1.1 and color.b>color.g*1.4:colored_crown=true
	check(colored_crown,"Bright-color cleanup preserves the violet crown palette")
	for wing in motion.anatomy.wing_rig.values():
		var digit:Dictionary=wing.digits[-1]
		for step in [0,9,24,36,45]:
			var t:=float(step)/45
			var p:=curved_ray(wing,digit,t)
			pairs.append([nearest_skin_vertex(membranes,p),nearest_skin_vertex(webs,p)])
		for step in [1,5,11,17,21]:
			var edge:Dictionary=wing.arm_attachment[step]
			attachments.append({"sample":nearest_skin_vertex(membranes+webs,vec(edge.point)),"edge":edge})
	for amount in [0.,.125,.25,.375,.5,.625,.75,.875,1.]:
		rig.reset_bone_poses();motion.fold_amount=amount;motion.apply_wings()
		for pair in pairs:check(skin_position(pair[0],rig).distance_to(skin_position(pair[1],rig))<.001,"Continuous fore/hind membrane at fold %.2f"%amount)
		for attachment in attachments:
			var edge:Dictionary=attachment.edge
			check(skin_position(attachment.sample,rig).distance_to(skin_reference(vec(edge.point),edge.weights,rig))<.001,"Trailing arm attachment at fold %.2f"%amount)
		var fore_top:=-INF
		var hind_top:=-INF
		if amount==0.:
			var flight_points:=posed_vertices(membranes+webs,rig)
			var low:=INF
			var high:=-INF
			for point in flight_points:
				low=minf(low,point.y);high=maxf(high,point.y)
			check(high-low<1.2,"Spread cloth stays in the flight surface instead of ballooning upward")
		for wing in motion.anatomy.wing_rig.values():
			var endpoints:Array[Vector3]=[]
			for digit in wing.digits:
				var index:=rig.find_bone(digit.second)
				endpoints.append(rig.get_bone_global_pose(index)*(rig.get_bone_global_rest(index).affine_inverse()*vec(digit.tip)))
			if wing.bank=="fore":check(absf(endpoints[0].distance_to(endpoints[-1])-vec(wing.digits[0].tip).distance_to(vec(wing.digits[-1].tip)))<.002,"Rest transition preserves the clustered open forewing arches")
			for endpoint in endpoints:
				if wing.bank=="fore":fore_top=maxf(fore_top,endpoint.y)
				else:hind_top=maxf(hind_top,endpoint.y)
			var a:=rig.get_bone_global_pose(rig.find_bone(wing.root_bone)).origin
			var b:=rig.get_bone_global_pose(rig.find_bone(wing.elbow_bone)).origin
			check(absf(a.distance_to(b)-vec(wing.root).distance_to(vec(wing.elbow)))<.001,"Fixed wing-arm length")
		if amount==1.0:
			var points:=posed_vertices(membranes+webs,rig)
			for wing in motion.anatomy.wing_rig.values():
				if wing.side!="L":continue
				var ends:Array[Vector3]=[]
				for digit in wing.digits:
					var index:=rig.find_bone(digit.second)
					ends.append(rig.get_bone_global_pose(index)*(rig.get_bone_global_rest(index).affine_inverse()*vec(digit.tip)))
				var first:Vector3=ends[-1] if wing.bank=="fore" else ends[0]
				var last:Vector3=vec(wing.root)+vec(wing.web_end_offset) if wing.bank=="fore" else ends[1]
				var yz:Array=wing.rest_trailing_lobe_yz if wing.bank=="fore" else wing.rest_main_lobe_yz
				var a:=Vector3(lerpf(first.x,last.x,1./3.),yz[0][0],yz[0][1])
				var b:=Vector3(lerpf(first.x,last.x,2./3.),yz[1][0],yz[1][1])
				var target:=bezier_point(first,a,b,last,.5)
				check(nearest_posed_distance(points,target)<.003,"Imported %s lobe reaches the traced reference curve"%wing.bank)
			check(fore_top>3.4 and fore_top>hind_top+.8,"Upright resting forewings rise above the lower hindwing lobes")
	motion.reset_motion();motion.enabled=false
	var antenna_meshes:=rig.find_children("SilkWing brow antenna*","MeshInstance3D",true,false)
	for entry in motion.anatomy.antenna_rig:
		var base_point:=rig.get_bone_global_rest(rig.find_bone(entry.bones[0])).origin
		var tip_point:=vec(motion.anatomy.bones[entry.bones[-1]].tail)
		var base_sample:=nearest_skin_vertex(antenna_meshes,base_point)
		var tip_sample:=nearest_skin_vertex(antenna_meshes,tip_point)
		var before_base:=skin_position(base_sample,rig);var before_tip:=skin_position(tip_sample,rig)
		for i in 120:motion.antenna_flow.update(1.0/60.0,moon)
		check(skin_position(base_sample,rig).distance_to(before_base)<.0001,"Soft antenna keeps its skull attachment fixed")
		var travel:=skin_position(tip_sample,rig).distance_to(before_tip)
		check(travel>.0005 and travel<.12,"Soft antenna tip %s has restrained idle flow (%.6f model units)"%[entry.side,travel])
	motion.enabled=true
	motion.reset_motion();moon.visual.rotation.y=0;moon.pivot.rotation=Vector3.ZERO
	var start:=moon.position
	Input.action_press("move_forward");await ticks(35);Input.action_release("move_forward")
	check(moon.position.distance_to(start)>.6,"Rebuilt Blue walks in the village")
	moon.position=Vector3(world._path_x(2)-3,world._height(world._path_x(2)-3,2)+.08,2)
	moon.velocity=Vector3.ZERO;moon._set_state(&"grounded")
	moon.set_physics_process(false);motion.enabled=false;motion.reset_motion()
	camera=roster.camera;camera.reparent(world);camera.make_current()
	framing_scale=1.45
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1400,900)
	frame_actor(Vector3(7.4,3.8,-7.4),Vector3(0,1.35,0),48)
	await capture("blue-grounded")
	frame_actor(Vector3(12,3.5,.4),Vector3(0,2.1,0),42)
	await capture("blue-side")
	frame_actor(Vector3(1.45,2.25,-3.5),Vector3(0,2.05,-1.75),40)
	await capture("blue-face")
	frame_actor(Vector3(0,2.25,-4.9),Vector3(0,2.05,-1.75),34)
	await capture("blue-front")
	for amount in [0.,.5]:
		rig.reset_bone_poses();motion.fold_amount=amount;motion.apply_wings()
		frame_actor(Vector3(7.5,5,-8),Vector3(0,1.4,0),55)
		await capture("blue-wings" if amount==0 else "blue-half-fold")
	camera.global_position=dark.global_position+Vector3(65,38,65)
	camera.look_at(dark.global_position+Vector3(0,12,0));camera.fov=48
	await capture("darkstalker-in-village")
	check(failures.is_empty(),"Replacement Blue and scene presentation")
	print("Blue full game pass: ","PASS" if failures.is_empty() else "FAIL")
	if failures.is_empty() and "--keep-playing" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		motion.reset_motion();motion.enabled=true;moon.set_physics_process(true)
		moon.visual.rotation.y=0;moon.pivot.rotation=Vector3(-.22,0,0)
		camera.reparent(moon.arm,false);moon.arm.spring_length=moon.default_camera_distance
		camera.position=Vector3.BACK*moon.default_camera_distance;camera.rotation=Vector3.ZERO;camera.fov=75
		print("Village ready: rebuilt Blue controlled, Darkstalker in the clearing; collection save untouched.")
		return
	quit(0 if failures.is_empty() else 1)
