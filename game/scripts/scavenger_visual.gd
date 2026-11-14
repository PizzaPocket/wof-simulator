extends Node3D
## Authored child anatomy, fitted skeleton and absolute eyelid shapes.
## Source models are Y up, +Z forward. This node corrects the game-facing axis.
var character_id := "kai"
var child_age := 9
var model: Node3D
var skeleton: Skeleton3D
var skin_meshes: Array[MeshInstance3D] = []
var eye_meshes: Array[MeshInstance3D] = []
var blink_shapes: Array[Dictionary] = []
var bone_ids: Dictionary = {}
var rig_frame := Transform3D.IDENTITY
var time := 0.0
var stride := 0.0
var walk_blend := 0.0
var blink_wait := 2.0
var blink_time := -1.0
var blink_amount := 0.0
var rng := RandomNumberGenerator.new()
var foot_rest: Dictionary = {}
var model_loaded := false
var height_m := 1.35
var head_yaw := 0.0
var standing_root_lift := 0.0
var wave_weight := 0.0
var arm_pose_history: Dictionary = {}
var last_activity := ""
var activity_elapsed := 0.0
var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/child_walk.json"))

func _ready() -> void:
	rng.seed = hash(character_id)
	time = rng.randf_range(0, 8)
	blink_wait = rng.randf_range(1.2, 4.0)
	rotation.y = PI
	height_m = 1.57 if character_id == "wren" else (1.15 if child_age == 6 else 1.35)
	var path := "res://assets/scavengers/%s.glb" % character_id
	if not ResourceLoader.exists(path):
		var label := Label3D.new()
		label.text = "Build the scavenger assets\nSee game/README.md"
		label.position.y = 1
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		return
	model = (load(path) as PackedScene).instantiate()
	add_child(model)
	for candidate in model.find_children("*", "Skeleton3D", true, false):
		skeleton = candidate
		break
	if not skeleton:
		return
	rig_frame = model.global_transform.affine_inverse() * skeleton.global_transform
	for i in skeleton.get_bone_count():
		bone_ids[skeleton.get_bone_name(i)] = i
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_prepare_materials(mesh)
		if "eyeballs" in mesh.name.to_lower():
			eye_meshes.append(mesh)
		for i in mesh.mesh.get_blend_shape_count():
			if "blink" in mesh.mesh.get_blend_shape_name(i).to_lower():
				blink_shapes.append({"mesh": mesh, "index": i, "sample": int(mesh.mesh.get_blend_shape_name(i).trim_prefix("blink"))})
				skin_meshes.append(mesh)
	for side in ["L", "R"]:
		foot_rest[side] = _rest("foot." + side).origin
	# The source is modelled with splayed legs. Bringing the feet under the
	# hips requires raising the pelvis by the chain's geometric reach, otherwise
	# both knees stay crouched even in a standing idle.
	var hip := _rest("upperleg01.L").origin
	var knee := _rest("lowerleg01.L").origin
	var ankle := _rest("foot.L").origin
	var reach := hip.distance_to(knee) + knee.distance_to(ankle) - 0.0015
	var dx := 0.012 * height_m / 1.35
	var dz := ankle.z - hip.z
	standing_root_lift = maxf(0, ankle.y + sqrt(maxf(0, reach * reach - dx * dx - dz * dz)) - hip.y)
	model_loaded = true
	animate(0.0, 0.0, "looking around", false, null)

func _prepare_materials(mesh: MeshInstance3D) -> void:
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/child_complexion.json"))
	var profile: Dictionary = profiles.get(character_id, {"skin": "a86e50", "skin_variation": 0.018})
	var painted:=character_id != "wren" and mesh.name.to_lower().begins_with("continuous anatomical skin")
	var painted_eyes:=character_id=="kai" and "eyeballs" in mesh.name.to_lower()
	if painted or painted_eyes:
		mesh.mesh=preload("res://scripts/child_complexion.gd").paint(mesh.mesh,profile,painted_eyes)
	for i in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(i) as StandardMaterial3D
		if not source:
			continue
		var material := source.duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo = (mesh.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var title := source.resource_name.to_lower()
		if "skin" in title:
			material.albedo_color=Color.WHITE if painted else Color(profile.skin)
			if painted:
				material.albedo_texture=load("res://assets/scavengers/%s_skin.png"%character_id)
			material.vertex_color_is_srgb=false
			material.subsurf_scatter_enabled = true
			material.subsurf_scatter_strength = 0.04
		elif painted_eyes:
			material.albedo_color=Color.WHITE
			material.vertex_color_is_srgb=false
		elif "hair" in title:
			material.roughness = 0.90
			material.metallic = 0.0
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			if character_id == "corinne":
				# This authored card texture includes its own strand lighting.
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.18
			material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		elif "leather" in title or "woven" in title or "canvas" in title:
			var sewn := ShaderMaterial.new()
			sewn.shader = preload("res://shaders/sewn_material.gdshader")
			sewn.set_shader_parameter("base_color", material.albedo_color)
			sewn.set_shader_parameter("is_leather", "leather" in title)
			mesh.set_surface_override_material(i, sewn)
			continue
		mesh.set_surface_override_material(i, material)

func _rest(bone: String) -> Transform3D:
	return rig_frame * skeleton.get_bone_global_rest(bone_ids[bone])

func _pose(bone: String) -> Transform3D:
	return rig_frame * skeleton.get_bone_global_pose(bone_ids[bone])

func _turn(bone: String, axis: Vector3, angle: float) -> void:
	if not bone_ids.has(bone):
		return
	var index: int = bone_ids[bone]
	var local_axis := skeleton.get_bone_global_rest(index).basis.inverse() * (rig_frame.basis.inverse() * axis)
	var current := skeleton.get_bone_pose_rotation(index)
	skeleton.set_bone_pose_rotation(index, current * Quaternion(local_axis.normalized(), angle))

func _aim(bone: String, from: Vector3, to: Vector3) -> void:
	var index: int = bone_ids[bone]
	var frame := rig_frame.basis.inverse()
	var rotate := Basis(Quaternion((frame * from).normalized(), (frame * to).normalized()))
	var global_basis := rotate * skeleton.get_bone_global_pose(index).basis
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local := parent_basis.inverse() * global_basis
	skeleton.set_bone_pose_rotation(index, local.orthonormalized().get_rotation_quaternion())

func _leg_ik(side: String, target: Vector3, roll: float) -> void:
	var hip_name := "upperleg01." + side
	var knee_name := "lowerleg01." + side
	var foot_name := "foot." + side
	var hip := _pose(hip_name).origin
	var knee := _pose(knee_name).origin
	var ankle := _pose(foot_name).origin
	var a := hip.distance_to(knee)
	var b := knee.distance_to(ankle)
	var to := target - hip
	var distance := clampf(to.length(), absf(a - b) + 0.001, a + b - 0.0005)
	var direction := to.normalized()
	var pole := Vector3.BACK - direction * direction.dot(Vector3.BACK)
	pole = pole.normalized()
	var along := (a * a + distance * distance - b * b) / (2.0 * distance)
	var height := sqrt(maxf(0, a * a - along * along))
	var knee_target := hip + direction * along + pole * height
	_aim(hip_name, knee - hip, knee_target - hip)
	knee = _pose(knee_name).origin
	ankle = _pose(foot_name).origin
	_aim(knee_name, ankle - knee, target - knee)
	# Keep the shoe planted while the femur and tibia articulate above it.
	var index: int = bone_ids[foot_name]
	var desired := rig_frame.basis.inverse() * Basis(Vector3.RIGHT, roll) * _rest(foot_name).basis
	var parent := skeleton.get_bone_parent(index)
	var local := skeleton.get_bone_global_pose(parent).basis.inverse() * desired
	skeleton.set_bone_pose_rotation(index, local.orthonormalized().get_rotation_quaternion())

func _arm_ik(side: String, target: Vector3, pole_hint: Vector3) -> void:
	var upper := "upperarm01." + side
	var lower := "lowerarm01." + side
	var wrist := "wrist." + side
	var shoulder := _pose(upper).origin
	var elbow := _pose(lower).origin
	var hand := _pose(wrist).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(hand)
	var toward := target - shoulder
	var distance := clampf(toward.length(), absf(a - b) + 0.001, a + b - 0.0005)
	var direction := toward.normalized()
	var pole := pole_hint - direction * direction.dot(pole_hint)
	pole = pole.normalized()
	var along := (a * a + distance * distance - b * b) / (2.0 * distance)
	var elbow_target := shoulder + direction * along + pole * sqrt(maxf(0, a * a - along * along))
	_aim(upper, elbow - shoulder, elbow_target - shoulder)
	elbow = _pose(lower).origin
	hand = _pose(wrist).origin
	_aim(lower, hand - elbow, target - elbow)


func _rotate_world(bone: String, axis: Vector3, angle: float) -> void:
	var index: int = bone_ids[bone]
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var desired := Basis(axis.normalized(), angle) * skeleton.get_bone_global_pose(index).basis
	skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * desired).orthonormalized().get_rotation_quaternion())

func _hand_frame(forward: Vector3, thumb: Vector3) -> Basis:
	var y := forward.normalized()
	var x := thumb-y*y.dot(thumb)
	if x.length_squared()<.01:x=Vector3.RIGHT-y*y.x
	if x.length_squared()<.01:x=Vector3.UP-y*y.y
	x=x.normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()

func _relax_hand(side: String, gesture: float, holding: float) -> void:
	var wrist := "wrist." + side
	var finger := "finger3-1." + side
	var forward := (_pose(wrist).origin - _pose("lowerarm01." + side).origin).normalized()
	# Fingers continue the forearm. Turning the palm uses forearm pronation,
	# not a forced wrist flip; the small remaining bend stays near neutral.
	var thumb := Vector3.BACK.lerp(Vector3.RIGHT,gesture).lerp(Vector3.LEFT,holding).normalized()
	var across := (_pose("finger2-1."+side).origin-_pose("finger5-1."+side).origin).normalized()
	var desired_across := (thumb-forward*forward.dot(thumb)).normalized()
	var projected := (across-forward*forward.dot(across)).normalized()
	var twist := projected.signed_angle_to(desired_across, forward)
	var forearm_turn:=clampf(twist,-1.20,1.20)
	_rotate_world("lowerarm01."+side,forward,forearm_turn)
	var allowed_thumb:=Basis(forward,forearm_turn)*projected
	var rest_forward := (_rest(finger).origin - _rest(wrist).origin).normalized()
	var rest_thumb := (_rest("finger2-1."+side).origin-_rest("finger5-1."+side).origin).normalized()
	var inherited := (_pose(wrist).origin-_pose("lowerarm01."+side).origin).normalized()
	var outward:=Vector3(.14 if side=="L" else -.14,0,0)*(1-gesture)*(1-holding)
	var hanging:Vector3=(inherited+outward).normalized()
	var target_frame := _hand_frame(hanging,allowed_thumb)
	var rest_frame := _hand_frame(rest_forward, rest_thumb)
	var desired := target_frame * rest_frame.inverse() * _rest(wrist).basis
	var index: int = bone_ids[wrist]
	var parent := skeleton.get_bone_parent(index)
	var local := skeleton.get_bone_global_pose(parent).basis.inverse() * desired
	skeleton.set_bone_pose_rotation(index, local.orthonormalized().get_rotation_quaternion())
	# Close the source's spread finger fan, then curl each joint in the palm's
	# anatomical plane. Ring/little fingers hang slightly more flexed.
	var middle := (_pose("finger3-2."+side).origin-_pose(finger).origin).normalized()
	var sign_side := -1.0 if side == "L" else 1.0
	for digit in range(2,6):
		var base := "finger%d-1.%s" % [digit, side]
		var next := "finger%d-2.%s" % [digit, side]
		var direction := (_pose(next).origin-_pose(base).origin).normalized()
		_aim(base, direction, direction.lerp(middle, .91).normalized())
	var axis := (_pose("finger2-1."+side).origin-_pose("finger5-1."+side).origin).normalized()
	for digit in range(2,6):
		var curl := (.26 + .050*(digit-2))*(1.0-.60*gesture)+.35*holding
		for segment in range(1,4):
			var amount: float = curl * [1.0,1.25,.65][segment-1]
			_rotate_world("finger%d-%d.%s" % [digit,segment,side], axis, sign_side*amount)
	var thumb_base:="finger1-1."+side
	var thumb_dir:=(_pose("finger1-2."+side).origin-_pose(thumb_base).origin).normalized()
	_aim(thumb_base,thumb_dir,thumb_dir.lerp(middle,.50*(1-gesture)+holding*.10).normalized())
	_rotate_world("finger1-2."+side, axis, sign_side*(.18+.20*holding))

func _swing_position(t: float, amplitude: float) -> float:
	# Hermite swing meets the planted foot's backward velocity at both ends.
	var m := -2.0*amplitude*.38/.62
	return (2*t*t*t-3*t*t+1)*(-amplitude)+(t*t*t-2*t*t+t)*m+(-2*t*t*t+3*t*t)*amplitude+(t*t*t-t*t)*m

func animate(delta: float, speed: float, activity: String, talking: bool, listener: Node3D) -> void:
	if not model_loaded:return
	time += delta
	if activity!=last_activity:activity_elapsed=0;last_activity=activity
	activity_elapsed+=delta
	var h := height_m / 1.35
	var running := smoothstep(2.1, 4.5, speed) if character_id == "wren" else 0.0
	stride += delta * speed / (lerpf(.82, 1.5, running)*h if character_id == "wren" else .72*h)
	walk_blend = lerpf(walk_blend,clampf(speed/.65,0,1),1-exp(-delta*6))
	wave_weight = move_toward(wave_weight, 1.0 if activity=="waving" and activity_elapsed<2.4 and not talking and walk_blend<.1 else 0.0, delta*1.8)
	skeleton.reset_bone_poses()
	var root_index: int = bone_ids["root"]
	var root_position := skeleton.get_bone_pose_position(root_index)
	var cycle := stride*TAU
	root_position.y += standing_root_lift - (walk.pelvis_drop_m+walk.vertical_amplitude_m*cos(cycle*2))*h*walk_blend
	root_position.x += sin(cycle)*walk.lateral_amplitude_m*h*walk_blend
	skeleton.set_bone_pose_position(root_index,root_position)
	_turn("root",Vector3.UP,sin(cycle)*walk.pelvis_yaw_rad*walk_blend)
	_turn("root",Vector3.BACK,sin(cycle)*walk.pelvis_roll_rad*walk_blend)
	_turn("spine02",Vector3.RIGHT,sin(time*1.65)*.006)
	_turn("spine01",Vector3.UP,-sin(cycle-.12)*walk.chest_counter_yaw_rad*walk_blend)
	_turn("spine03",Vector3.BACK,-sin(cycle-.10)*walk.chest_counter_roll_rad*walk_blend)
	_turn("spine02",Vector3.RIGHT,sin(cycle*2-.25)*walk.chest_pitch_rad*walk_blend)
	_turn("spine02",Vector3.RIGHT,-running*.10)
	_turn("spine04",Vector3.BACK,sin(time*.83)*.007*(1-walk_blend))
	for side in ["L","R"]:
		var sign_side := 1.0 if side=="L" else -1.0
		var phase := fposmod(stride+(.5 if side=="R" else 0.0),1.0)
		var swing := clampf((phase-.62)/.38,0,1)
		var amplitude := lerpf(.72*.62*.5, .40, running)*h
		var z := lerpf(amplitude,-amplitude,phase/.62) if phase<.62 else _swing_position(swing,amplitude)
		var target: Vector3 = foot_rest[side]
		target.x = _rest("upperleg01."+side).origin.x+sign_side*.012*h
		target.z += z*walk_blend
		target.y += pow(sin(swing*PI),2)*lerpf(.040,.12,running)*h*walk_blend
		# Heel contact, a quiet flat support, then roll over the forefoot.
		var roll := -.24*(1-smoothstep(0,.15,phase))+.42*smoothstep(.42,.62,phase) if phase<.62 else lerpf(.42,-.24,smoothstep(0,.72,swing))-.12*pow(sin(swing*PI),2)
		target.y += maxf(sin(roll)*.16,-sin(roll)*.035)*h*walk_blend
		_leg_ik(side,target,roll*walk_blend)
		var shoulder := _pose("upperarm01."+side).origin
		var elbow := _pose("lowerarm01."+side).origin
		var wrist := _pose("wrist."+side).origin
		var upper_length := shoulder.distance_to(elbow)
		var lower_length := elbow.distance_to(wrist)
		var length := upper_length+lower_length
		var hand_target := shoulder+Vector3(sign_side*length*.14,-length*.96,.025*h)
		# Let the elbow fold on the forward swing and open on the return.
		# Derive the hand's height from the two link lengths, so a larger swing
		# cannot pull the arm taut or ask IK to reach beyond its chain.
		var arm_swing := -cos(phase*TAU-.12)
		var flex := lerpf(walk.elbow_back_rad,walk.elbow_forward_rad,(arm_swing+1)*.5)
		var reach_sq := upper_length*upper_length+lower_length*lower_length+2*upper_length*lower_length*cos(flex)
		var offset := Vector3(sign_side*length*.14,0,.025*h+arm_swing*float(walk.hand_swing_m)*lerpf(1.0,2.0,running)*h)
		offset.y = -sqrt(maxf(.001,reach_sq-offset.x*offset.x-offset.z*offset.z))
		hand_target = hand_target.lerp(shoulder+offset,walk_blend)
		var pole := Vector3(sign_side*.12,-.06,-1)
		var gesture := smoothstep(0,1,wave_weight) if side=="R" else 0.0
		var holding := 0.0
		if side=="R":
			hand_target = hand_target.lerp(shoulder+Vector3(-.18,.08,.18)*h,gesture)
			pole = pole.lerp(Vector3(-.6,-1.2,0),gesture).lerp(Vector3(-.1,-1,.12),holding)
			_turn("clavicle.R",Vector3.BACK,-gesture*.06)
		_arm_ik(side,hand_target,pole)
		_relax_hand(side,gesture,holding)
		if side=="R" and gesture>.01:
			_rotate_world("wrist.R",Vector3.BACK,sin(time*4.5)*.10*gesture)
	var yaw := sin(time*.57)*.25*(1-walk_blend)
	var pitch := sin(time*.43)*.025
	if talking and is_instance_valid(listener):
		var local := to_local(listener.global_position)
		yaw=clampf(atan2(local.x,local.z),-.6,.6);pitch=-.20
	elif activity=="watching a dragon" and is_instance_valid(listener) and global_position.distance_to(listener.global_position)<12:
		var local:=to_local(listener.global_position+Vector3.UP*2.5)
		yaw=clampf(atan2(local.x,local.z),-.6,.6)
		pitch=-.18
	head_yaw=lerp_angle(head_yaw,yaw,1-exp(-delta*4))
	_turn("neck01",Vector3.UP,head_yaw*.4)
	_turn("head",Vector3.UP,head_yaw*.6)
	_turn("head",Vector3.RIGHT,pitch)
	# Filter local arm/hand rotations together. This removes rapid pronation
	# changes near a gesture transition without disturbing planted foot IK.
	for i in skeleton.get_bone_count():
		var name:=skeleton.get_bone_name(i)
		if not (name.begins_with("clavicle") or name.begins_with("upperarm") or name.begins_with("lowerarm") or name.begins_with("wrist") or name.begins_with("finger")):continue
		var goal:=skeleton.get_bone_pose_rotation(i)
		var previous: Quaternion=arm_pose_history.get(i,goal)
		if delta>0:
			var angle:=previous.angle_to(goal)
			var weight:=minf(1-exp(-delta*12),delta*5/maxf(.00001,angle))
			goal=previous.slerp(goal,weight).normalized()
			skeleton.set_bone_pose_rotation(i,goal)
		arm_pose_history[i]=goal
	_update_blink(delta)

func _update_blink(delta: float) -> void:
	blink_wait -= delta
	if blink_wait <= 0 and blink_time < 0:
		blink_time = 0
	if blink_time >= 0:
		blink_time += delta
		if blink_time < 0.08:
			blink_amount = smoothstep(0, 0.08, blink_time)
		else:
			blink_amount = 1 - smoothstep(0.10, 0.22, blink_time)
		if blink_time >= 0.22:
			blink_time = -1
			blink_wait = rng.randf_range(2.3, 5.5)
			blink_amount = 0
	apply_blink(blink_amount)

func apply_blink(amount: float) -> void:
	blink_amount = clampf(amount, 0, 1)
	for entry in blink_shapes:
		entry.mesh.set_blend_shape_value(entry.index, maxf(0, 1.0 - absf(blink_amount * 3.0 - entry.sample)))

func make_pouch(parent: Node3D) -> void:
	var path := "res://assets/scavengers/umber_pouch.glb"
	if not ResourceLoader.exists(path):
		return
	var pouch := (load(path) as PackedScene).instantiate()
	parent.add_child(pouch)
	for mesh: MeshInstance3D in pouch.find_children("*", "MeshInstance3D", true, false):
		_prepare_materials(mesh)
