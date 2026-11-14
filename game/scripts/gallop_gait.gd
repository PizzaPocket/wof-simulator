extends RefCounted
## Easy transverse lope plus a separate hand-supported, hind-driven sprint.
## Shares the walk's anatomical IK, distal articulation and soft-tissue helpers.
var solver_ref: WeakRef
var gait: RefCounted:
	get:
		return solver_ref.get_ref()
var settings: Dictionary
var active := false
var phase := 0.0
var blend := 0.0
var contacts: Dictionary = {}
var transition_feet: Dictionary = {}
var transition_time := 0.0
var suspension := false
var planted_count := 4
var entry_position := Vector3.ZERO
var entry_rotation := Vector3.ZERO
var extension := 0.0
var trunk_bones: Array[int] = []
var sprint_motion := preload("res://scripts/sprint_bound.gd").new()

func setup(solver: RefCounted, config: Dictionary) -> void:
	solver_ref = weakref(solver)
	settings = config
	sprint_motion.setup(settings.sprint)
	for name in ["hips", "spine", "chest"]:
		var index: int = gait.rig.find_bone(name)
		if index >= 0:
			trunk_bones.append(index)

func reset() -> void:
	active = false
	blend = 0.0
	phase = 0.0
	contacts.clear()
	transition_feet.clear()
	suspension = false
	extension = 0.0
	_reset_trunk()

func _reset_trunk() -> void:
	for index in trunk_bones:
		gait.rig.reset_bone_pose(index)

func update(delta: float, speed: float, displacement: Vector3) -> bool:
	_reset_trunk()
	var should_run: bool = speed > float(settings.exit_speed_m_s if active else settings.enter_speed_m_s)
	should_run = should_run and gait.body.is_on_floor()
	if not active and should_run:
		active = true
		extension = smoothstep(float(settings.extension_start_m_s), float(settings.extension_full_m_s), speed)
		transition_time = 0.0
		phase = 0.0
		entry_position = gait.model.position
		entry_rotation = gait.model.rotation
		contacts.clear()
		for leg in gait.legs:
			transition_feet[leg.name] = leg.get("last_target", gait.rig.to_global(leg.end))
	if not active:
		blend = move_toward(blend, 0.0, delta / float(settings.transition_seconds))
		return false
	if not should_run:
		active = false
		suspension = false
		for leg in gait.legs:
			var current: Vector3 = leg.get("last_target", gait.rig.to_global(leg.end))
			if leg.swing:
				# Finish airborne recovery instead of declaring an elevated paw
				# planted below its current position when braking out of a gallop.
				leg.swing_from = current
				leg.swing_from_pitch = leg.pitch
				leg.swing_progress = 0.0
				leg.duration = 0.18
				leg.from_gallop = true
				leg.swing_to = gait.landing_target(leg, displacement / maxf(delta, 0.0001), float(leg.duration))
			else:
				leg.anchor = current
			leg.erase("previous_root")
		# The walk blends its new contacts from the last gallop targets.
		gait.begin_transition()
		return false
	transition_time += delta
	blend = smoothstep(0.0, float(settings.transition_seconds), transition_time)
	# Blend into a separately authored hand-supported sprint, rather than speeding
	# up the lope. The common phase starts at the first hind contact in both gaits.
	extension = move_toward(extension, smoothstep(float(settings.extension_start_m_s), float(settings.extension_full_m_s), speed), delta * 2.5)
	var sprint: Dictionary = settings.sprint
	var origin: float = sprint.touchdown_offsets["hind.L"]
	var stride := lerpf(float(settings.easy_stride_length_m), float(sprint.stride_length_m), extension)
	phase += displacement.length() / stride
	var cycle := fposmod(phase, 1.0)
	var bound: Dictionary = sprint_motion.body_pose(fposmod(cycle + origin, 1.0))
	var period := stride / maxf(speed, 0.1)
	var velocity := displacement / maxf(delta, 0.0001)
	# Keep the accepted easy-run motion exactly at extension=0. The sprint instead
	# catches low on the hands, loads the hindquarters, then travels through flight.
	var bounce := (0.5 - 0.5 * cos(TAU * (cycle - 0.29)))
	var easy_height := float(settings.easy_body_lift_model) * (bounce - 0.5)
	var easy_pitch := deg_to_rad(float(settings.easy_body_pitch_degrees)) * sin(TAU * (cycle - 0.15))
	gait.model.rotation.x = lerp_angle(entry_rotation.x, lerpf(easy_pitch, float(bound.pitch), extension), blend)
	gait.model.rotation.z = lerp_angle(entry_rotation.z, deg_to_rad(0.6) * sin(TAU * cycle), blend)
	var pivot: Vector3 = Vector3(0.0, 1.05, 0.0) * gait.model.scale
	var position: Vector3 = gait.model_home + pivot - Basis.from_euler(gait.model.rotation) * pivot
	position.y += lerpf(easy_height, float(bound.height), extension) * gait.model.scale.y
	position += Basis(Vector3.UP, gait.model.rotation.y) * Vector3(0.0, 0.0, float(bound.surge) * extension * gait.model.scale.y)
	gait.model.position = entry_position.lerp(position, blend)
	# Independent chest and pelvis poses let the elbows absorb the hand catch and
	# the hindquarters compress later. Start from rest every frame to avoid drift.
	for index in trunk_bones:
		var rest: Transform3D = gait.rig.get_bone_global_rest(index)
		var parent: int = gait.rig.get_bone_parent(index)
		var parent_delta := Transform3D.IDENTITY
		if parent >= 0:
			parent_delta = gait.rig.get_bone_global_pose(parent) * gait.rig.get_bone_global_rest(parent).affine_inverse()
		var name: String = gait.rig.get_bone_name(index)
		var angle := float(bound.get(name, 0.0)) * extension * blend
		var joint := rest.origin
		if name == "chest":
			joint.y -= float(bound.chest_drop) * extension * blend
		gait._set_global(index, parent_delta * Transform3D(Basis(Vector3.RIGHT, angle) * rest.basis, joint))
	gait.turn_support = 1.0
	planted_count = 0
	for leg in gait.legs:
		var sprint_offset := fposmod(float(sprint.touchdown_offsets[leg.name]) - origin, 1.0)
		var offset := lerpf(float(settings.easy_touchdown_offsets[leg.name]), sprint_offset, extension)
		var p := fposmod(phase - offset, 1.0)
		var sprint_duty := float(sprint.front_stance_fraction if leg.kind == "front" else sprint.hind_stance_fraction)
		var duty := lerpf(float(settings.easy_stance_fraction), sprint_duty, extension)
		var swinging := p >= duty
		var convergence := lerpf(float(settings.easy_convergence), float(settings.sprint_convergence), extension)
		# Leading and trailing feet have different reach as well as different timing.
		var lead := 1.0 if String(leg.name).ends_with("R") else -1.0
		var reach_model := float(sprint.front_reach_model if leg.kind == "front" else sprint.hind_reach_model)
		var reach: float = (reach_model + lead * 0.07) * extension * gait.model.scale.y
		var landing: Vector3 = gait.landing_target(leg, velocity, period * duty * 0.5, convergence, reach)
		if not contacts.has(leg.name):
			var initial: Vector3 = gait.landing_ground(transition_feet[leg.name])
			contacts[leg.name] = {"was_swing": swinging, "anchor": initial, "from": initial, "to": landing}
		var contact: Dictionary = contacts[leg.name]
		if p < float(contact.get("previous_phase", p)) - 0.5:
			contact.erase("early_lift")
		if not swinging and contact.was_swing and not contact.has("early_lift"):
			contact.to = gait.retarget_contact(leg,contact.to,leg.pitch)
			contact.anchor = contact.to
		# Stride and body posture change during acceleration. Let a planted limb
		# unload slightly early if the new pose would otherwise overextend it;
		# keep that recovery active until its next scheduled touchdown.
		leg.anchor = contact.anchor
		var reach_ratio: float = gait._reach_ratio(leg, velocity, delta, 0.025)
		if (extension > 0.05 or blend < 0.999) and p > 0.06 and not swinging and reach_ratio > 0.96 and not contact.has("early_lift"):
			contact.early_lift = p
		var lift_phase := minf(duty, float(contact.get("early_lift", duty)))
		swinging = p >= lift_phase
		if swinging and not contact.was_swing:
			contact.from = contact.anchor
			contact.from_pitch = leg.pitch
		if not swinging and contact.was_swing:
			contact.to = gait.retarget_contact(leg,contact.to,leg.pitch)
			contact.anchor = contact.to
		var target: Vector3 = contact.anchor
		var foot_pitch := 0.0
		var curl := 0.0
		if swinging:
			var t := (p - lift_phase) / (1.0 - lift_phase)
			# Recover relative to the moving torso. A world-fixed lift-off point
			# leaves the paw behind the hip on longer, faster bounds.
			var recovery_pivot: Vector3 = gait.body.global_position - displacement
			contact.from = gait.body.global_position + Basis(Vector3.UP, gait.frame_yaw_delta) * ((contact.from as Vector3) - recovery_pivot)
			contact.to = landing
			var recovery_pose: Dictionary = sprint_motion.swing_pose(leg.kind, t)
			var ease := lerpf(t * t * (3.0 - 2.0 * t), float(recovery_pose.travel), extension)
			target = (contact.from as Vector3).lerp(contact.to, ease)
			var recovery := pow(t, 0.8 if leg.kind == "front" else 1.2)
			var easy_lift := pow(sin(PI * recovery), 1.25) * float(settings.easy_step_height_model)
			target.y += lerpf(easy_lift, float(recovery_pose.height), extension) * gait.model.scale.y
			var easy_foot_pitch := deg_to_rad(float(settings.swing_wrist_degrees if leg.kind == "front" else settings.swing_hock_degrees)) * sin(PI * recovery)
			foot_pitch = lerpf(easy_foot_pitch, float(recovery_pose.pitch), extension)
			foot_pitch = lerpf(float(contact.get("from_pitch", 0.0)), foot_pitch, smoothstep(0.0, 0.3, t))
			curl = lerpf(deg_to_rad(12.0) * sin(PI * recovery), float(recovery_pose.curl), extension)
			leg.swing_progress = t
		else:
			planted_count += 1
			var toe_off := lerpf(float(settings.toe_off_degrees), float(sprint.front_toe_off_degrees if leg.kind == "front" else sprint.hind_toe_off_degrees), extension)
			foot_pitch = deg_to_rad(toe_off) * smoothstep(duty * 0.55, duty, p)
		contact.was_swing = swinging
		contact.previous_phase = p
		leg.phase = p
		leg.swing = swinging
		leg.pitch = lerpf(float(leg.pitch), foot_pitch, minf(1.0, delta * 32.0))
		leg.toe_curl = curl
		leg.forearm_twist = 0.0
		leg.anchor = contact.anchor
		var entry: Vector3 = transition_feet[leg.name]
		# Move the initial pose with the torso during the short crossfade.
		var previous_body: Vector3 = gait.body.global_position - displacement
		transition_feet[leg.name] = gait.body.global_position + Basis(Vector3.UP, gait.frame_yaw_delta) * (entry - previous_body)
		if swinging:
			target = (transition_feet[leg.name] as Vector3).lerp(target, blend)
		gait._solve_leg(leg, target, leg.pitch)
	suspension = planted_count == 0
	return true
