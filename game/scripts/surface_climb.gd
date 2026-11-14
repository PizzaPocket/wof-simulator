extends RefCounted
## Surface contact, traversal and a collision-tested ledge transfer.
var body: CharacterBody3D
var settings: Dictionary
var normal := Vector3.FORWARD
var forward := Vector3.UP
var cooldown := 0.0
var last_contact := Vector3.ZERO
var mantle_time := -1.0
var mantle_from := Vector3.ZERO
var mantle_to := Vector3.ZERO
var mantle_basis := Basis.IDENTITY
var release_pose: Dictionary = {}
var release_age := 1.0
var phase := 0.0
var contacts: Dictionary = {}
var effort := 0.0
var reach_weight := 0.0
var load_sag := 0.0
var acquire_age := 0.0
var acquire_origin := Vector3.ZERO
var neck_pose_pitch := 0.0
var collider: CollisionShape3D
var collider_home: Vector3

func setup(character: CharacterBody3D) -> void:
	body = character
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/climbing.json"))
	collider = body.get_node("CollisionShape3D")
	collider_home = collider.position

func ray(a: Vector3, b: Vector3) -> Dictionary:
	return body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1, [body.get_rid()]))

func climbable(hit: Dictionary) -> bool:
	return not hit.is_empty() and hit.collider.is_in_group("climbable")

func can_grip(n: Vector3) -> bool:
	return n.dot(Vector3.UP) >= cos(deg_to_rad(float(settings.maximum_slope_degrees)))

func try_attach(stick: Vector2) -> bool:
	if not body.visual.motion or not body.visual.motion.gait: return false
	if cooldown > 0 or body.conversation_locked or body.locomotion_state == &"preparing": return false
	if body.locomotion_state == &"grounded" and stick.length() < .1: return false
	var hit := ray(body.global_position+Vector3.UP, body.global_position+Vector3.UP-body.visual.global_basis.z*1.6)
	if not climbable(hit):
		for i in body.get_slide_collision_count():
			var contact := body.get_slide_collision(i)
			if contact.get_collider().is_in_group("climbable"):
				hit = {"normal":contact.get_normal(),"position":contact.get_position(),"collider":contact.get_collider()}
				break
	if not climbable(hit): return false
	var n: Vector3 = hit.normal
	if not can_grip(n) or n.dot(Vector3.UP) > cos(deg_to_rad(float(settings.minimum_slope_degrees))): return false
	normal = n
	forward = Vector3.UP.slide(normal).normalized()
	last_contact = hit.position
	acquire_origin = body.visual.motion.model.global_position
	acquire_age = 0
	body.global_position = last_contact + normal * .24
	body.velocity = Vector3.ZERO
	body.mud_supported = false
	body._set_state(&"climbing")
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	contacts.clear()
	phase = 0
	_orient(0.0)
	return true

func _orient(response: float = 1.0) -> void:
	var up_wall := Vector3.UP.slide(normal).normalized()
	if up_wall.length_squared() < .1: up_wall = forward.slide(normal).normalized()
	forward = forward.slide(normal).normalized()
	if forward.length_squared() < .1: forward = up_wall
	var right := forward.cross(normal).normalized()
	var basis := Basis(right, normal, -forward).orthonormalized()
	body.visual.global_basis = body.visual.global_basis.orthonormalized().slerp(basis, response)
	collider.basis = Basis(Quaternion(Vector3.UP, normal))
	collider.position = collider.basis * collider_home
	body.floor_snap_length = 0

func release(jump := false) -> void:
	var out := normal
	var motion = body.visual.motion
	if motion and motion.gait:
		release_pose.clear()
		for leg in motion.gait.legs:
			var indices: Array = leg.indices+leg.digit_bones+leg.wrist_helpers+[leg.soft,leg.twist]
			for i in indices:
				if i>=0:release_pose[i]=motion.skeleton.get_bone_pose_rotation(i)
		release_age=0
	mantle_time = -1
	body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	collider.basis = Basis.IDENTITY
	collider.position = collider_home
	var heading := Vector3(body.visual.global_basis.z.x, 0, body.visual.global_basis.z.z)
	body.visual.rotation = Vector3(0, atan2(heading.x, heading.z) if heading.length_squared() > .01 else body.pivot.rotation.y, 0)
	body._set_state(&"airborne")
	body.air_time = 0
	body.velocity = out * float(settings.jump_out_m_s) + Vector3.UP * float(settings.jump_up_m_s) if jump else out * 1.5
	cooldown = .6
	if motion:
		if motion.gait:
			motion.model.rotation.y = motion.gait.model_home_yaw
		if motion.gaze: motion.gaze.pitch = neck_pose_pitch
		motion.resume_ground_motion()

func update(delta: float, stick: Vector2) -> bool:
	cooldown = maxf(0, cooldown - delta)
	if body.locomotion_state != &"climbing": return false
	acquire_age += delta
	if Input.is_action_just_pressed("jump"):
		release(true)
		return true
	if Input.is_action_just_pressed("cancel_flight"):
		release()
		return true
	if mantle_time >= 0:
		mantle_time += delta
		var t := clampf(mantle_time / float(settings.mantle_seconds), 0, 1)
		# Lift clear of the sill before rolling the capsule upright and bringing
		# the hips across. A simultaneous diagonal move catches the inner lip.
		var across := mantle_to-mantle_from
		var rise := across.y
		across.y=0
		var target := mantle_from + across*smoothstep(.30,1,t)
		target.y += 1.35*smoothstep(0,.35,t)+(rise-1.35)*smoothstep(.35,1,t)
		# Rotate the trunk and capsule continuously from wall support to a
		# horizontal body, rather than switching frames on the release tick.
		var upright := Basis(Vector3.UP.cross(normal).normalized(),Vector3.UP,Vector3(normal.x,0,normal.z).normalized()).orthonormalized()
		body.visual.global_basis=mantle_basis.slerp(upright,smoothstep(.30,.95,t))
		collider.basis=Basis(Quaternion(Vector3.UP,normal)).slerp(Basis.IDENTITY,smoothstep(.30,.95,t))
		collider.position=(normal*collider_home.y).lerp(collider_home,smoothstep(.30,.95,t))
		var collision := body.move_and_collide(target - body.global_position)
		if collision and collision.get_normal().dot(Vector3.UP) < .3:
			release()
		elif t >= 1:
			release()
			body.velocity = -normal * 1.8
		return true
	var hit := ray(body.global_position + normal * .8, body.global_position - normal * float(settings.surface_probe_m))
	if not climbable(hit):
		if stick.y < -.1 and _begin_mantle(): return true
		release()
		return true
	var next_normal: Vector3 = hit.normal
	# Mud coils are small grip ridges, not whole-wall overhangs. Measure the
	# supporting patch across a claw span before deciding the wall is too steep.
	for offset in [Vector3.UP*.35, Vector3.DOWN*.35, Vector3.UP*.65, Vector3.DOWN*.65]:
		var neighbor:=ray(body.global_position+offset+normal*.8,body.global_position+offset-normal*float(settings.surface_probe_m))
		if climbable(neighbor): next_normal+=neighbor.normal
	next_normal=next_normal.normalized()
	if not can_grip(next_normal):
		release()
		return true
	last_contact = hit.position
	normal = normal.lerp(next_normal, 1-exp(-delta*12)).normalized()
	if normal.dot(Vector3.UP) > .78:
		if stick.y<-.1 and _begin_mantle():return true
		release()
		body.velocity = forward * 1.2
		return true
	var up_wall := Vector3.UP.slide(normal).normalized()
	var right := up_wall.cross(normal).normalized()
	var travel := up_wall * -stick.y + right * stick.x
	if travel.length() > .05:
		forward = forward.lerp((up_wall+right*stick.x*.25).normalized(), 1-exp(-delta*5)).normalized()
	_orient(1-exp(-delta*9))
	effort = move_toward(effort, minf(1, travel.length()), delta*4)
	phase += delta * effort * float(settings.speed_m_s) / float(settings.stride_m)
	var step := fposmod(phase*4, 1)
	reach_weight = (1-smoothstep(.28,.43,step)) * smoothstep(0,.12,step) * effort
	var pull := clampf((step-.38)/.62,0,1)
	var transfer := .18 + 1.55 * sin(PI*pull)
	load_sag = lerpf(load_sag, (.07+.13*reach_weight)*effort, 1-exp(-delta*8))
	var separation_error: float = ((hit.position as Vector3) + normal * .24 - body.global_position).dot(normal)
	body.velocity = travel * float(settings.speed_m_s) * transfer + normal * clampf(separation_error * 10, -float(settings.adhesion_m_s), 2.4)
	body.move_and_slide()
	body.ground_distance = 0
	return true

func _begin_mantle() -> bool:
	# Find a real upward-facing sill behind the opening before committing.
	var inward := Vector3(-normal.x, 0, -normal.z).normalized()
	var sill: Dictionary = {}
	for depth in [.25,.65,1.1]:
		var over: Vector3 = body.global_position + inward * float(depth)
		var hit := ray(over + Vector3.UP * 2.0, over - Vector3.UP * 1.5)
		if climbable(hit) and hit.normal.dot(Vector3.UP) > .3 and hit.position.y-body.position.y < 1.6:
			sill = hit
			break
	if sill.is_empty():
		return false
	mantle_from = body.global_position
	mantle_to = body.global_position + inward * 3.0
	mantle_to.y = maxf(body.position.y+.9, float(sill.position.y)+.9)
	mantle_time = 0
	mantle_basis = body.visual.global_basis.orthonormalized()
	return true

func blend_release(delta: float, gait: RefCounted) -> void:
	if release_age>=.30 or body.locomotion_state==&"climbing":return
	release_age+=delta
	var weight:=smoothstep(0,.30,release_age)
	for i in release_pose:
		var goal:Quaternion=gait.rig.get_bone_pose_rotation(i)
		gait.rig.set_bone_pose_rotation(i,(release_pose[i] as Quaternion).slerp(goal,weight))

func grip_near(home: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	var right := forward.cross(normal).normalized()
	for offset in [Vector3.ZERO,forward*.45,-forward*.45,right*.6,-right*.6,forward*.8,-forward*.8]:
		var hit := ray(home+offset+normal*2.5, home+offset-normal*4.5)
		if climbable(hit):
			var d: float = home.distance_to(hit.position)
			if d < distance: distance=d;best=hit
	return best

func animate_pose(delta: float, gait: RefCounted) -> void:
	gait.model.position = gait.model_home
	# World-space wall lean can add local yaw while the body turns. Start
	# from the authored heading so that offset cannot accumulate each tick.
	gait.model.rotation = Vector3(0, gait.model_home_yaw, 0)
	var right := forward.cross(normal).normalized()
	var mantle_blend := smoothstep(0,1,clampf(mantle_time/float(settings.mantle_seconds),0,1)) if mantle_time>=0 else 0.0
	# Gravity loads the shoulders while a limb reaches. The hips hang out;
	# the planted hind limbs extend as the torso is pulled toward the next grip.
	var lean := (-.065 + .045*reach_weight)*(1-mantle_blend)
	gait.model.global_basis = Basis(right,lean) * gait.model.global_basis
	gait.model.global_position += (normal * (-.55+.06*reach_weight) - Vector3.UP * load_sag)*(1-mantle_blend)
	if acquire_age < .32:
		gait.model.global_position = acquire_origin.lerp(gait.model.global_position,smoothstep(0,.32,acquire_age))
	var order := ["front.L","hind.R","front.R","hind.L"]
	var selected: String = order[posmod(int(floor(phase*4)),4)]
	var step := fposmod(phase*4,1)
	# Contact acquisition rotates the whole body onto the wall. Establish the
	# fixed anchors after that frame has settled, not in the old ground frame.
	if acquire_age<.34:contacts.clear()
	for leg in gait.legs:
		gait._restore_leg(leg)
		var home: Vector3 = gait.rig.to_global(leg.end)
		var hit := grip_near(home + forward*float(settings.grip_lead_m))
		var destination: Vector3 = hit.position+hit.normal*.06 if climbable(hit) else home-normal*.12
		if not contacts.has(leg.name):
			var initial:=grip_near(home)
			var anchor:Vector3=initial.position+initial.normal*.06 if climbable(initial) else destination
			contacts[leg.name]={"anchor":anchor,"from":anchor,"to":anchor,"swing":false}
		var contact: Dictionary = contacts[leg.name]
		var swing: bool = leg.name==selected and step<.40 and effort>.05 and mantle_time<0
		if swing and not contact.swing:
			contact.from=contact.anchor;contact.to=destination
		var target: Vector3 = contact.anchor
		if swing:
			var t := step/.40
			target=(contact.from as Vector3).lerp(contact.to,smoothstep(0,1,t))+normal*sin(PI*t)*float(settings.paw_clearance_m)
		elif contact.swing:
			contact.anchor=contact.to;target=contact.anchor
		if mantle_time>=0:
			var t:=clampf(mantle_time/float(settings.mantle_seconds),0,1)
			var transfer:=smoothstep(.0,.65,t) if leg.kind=="front" else smoothstep(.25,.95,t)
			target=(contact.anchor as Vector3).lerp(home,transfer)+Vector3.UP*sin(PI*transfer)*.35
		contact.swing=swing
		leg.swing=swing
		leg.toe_curl=.24 if not swing else .08
		gait._solve_leg(leg,target,.13 if leg.kind=="front" else .08)
	# Hold the muzzle near the world horizon, independent of wall/trunk pitch.
	# The reference aim is the actual mouth axis, not the trunk's forward axis.
	var current_aim:Vector3 = gait.rig.global_basis * body.visual.motion.gaze.rest_aim
	var horizontal:Vector3 = Vector3(-normal.x,0,-normal.z).normalized()
	var desired_aim:Vector3 = (horizontal+Vector3.UP*.18).normalized()
	if mantle_time>=0: desired_aim=horizontal
	var current_plane:Vector3=current_aim.slide(right).normalized()
	var desired_plane:Vector3=desired_aim.slide(right).normalized()
	var neck_angle:float=clampf(current_plane.signed_angle_to(desired_plane,right),-1.35,1.35)
	neck_pose_pitch=neck_angle
	var axis:Vector3=gait.rig.global_basis.inverse()*right
	for name in ["neck1","neck2","neck3","neck4","head"]:
		var index:int=gait.rig.find_bone(name)
		if index<0:continue
		gait.rig.reset_bone_pose(index)
		var pose:Transform3D=gait.rig.get_bone_global_pose(index)
		pose.basis=Basis(axis.normalized(),neck_angle*.20)*pose.basis
		gait._set_global(index,pose)
