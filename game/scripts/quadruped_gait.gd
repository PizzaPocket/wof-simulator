extends RefCounted
## Four-beat lateral-sequence walk. Feet stay in world space during stance.
## Swing trajectories specify contact/clearance; a two-link solve coordinates
## proximal joints, and a separate distal link supplies wrist/hock/toe roll.

var rig: Skeleton3D
var body: CharacterBody3D
var model: Node3D
var settings: Dictionary
var legs: Array[Dictionary] = []
var cycle: float = 0.0
var weight: float = 0.0
var previous_position: Vector3
var model_home: Vector3
var model_home_yaw: float
var grounded_last: bool = false
var elapsed: float = 0.0
var turn_support: float = 1.0
var foot_anatomy: Dictionary = {}
var limb_settings: Dictionary = {}
var soft_helpers: Dictionary = {}
var soft_fraction: float = 0.5
var gallop: RefCounted
var transition_feet: Dictionary = {}
var transition_time: float = 1.0
var step_order := ["hind.L", "front.L", "hind.R", "front.R"]
var next_step := 0
var retarget_contacts := false
var step_clock := 1.0
var previous_yaw := 0.0
var yaw_velocity := 0.0
var frame_yaw_delta := 0.0


func setup(skeleton: Skeleton3D, character: CharacterBody3D, visual_model: Node3D, config: Dictionary, anatomy: Dictionary) -> void:
	rig = skeleton
	body = character
	model = visual_model
	settings = config
	retarget_contacts = anatomy.has("locomotion_scale")
	foot_anatomy = anatomy.get("feet", {})
	limb_settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/limbs.json"))
	soft_fraction = float(anatomy.get("limb_articulation", {}).get("soft_helper_fraction", 0.5))
	model_home = model.position
	model_home_yaw = model.rotation.y
	for side in ["L", "R"]:
		_make_leg("front", side, ["upperarm", "forearm", "hand"], "ftoe", anatomy.get("front_joints", {}), "knuckles")
		_make_leg("hind", side, ["thigh", "shin", "foot"], "htoe", anatomy.get("hind_joints", {}), "ball")
	gallop = preload("res://scripts/gallop_gait.gd").new()
	gallop.setup(self, anatomy.get("run_settings", JSON.parse_string(FileAccess.get_file_as_string("res://data/locomotion.json")).run))
	reset()


func _make_leg(kind: String, side: String, names: Array, toe_prefix: String, joints: Dictionary, end_name: String) -> void:
	if joints.is_empty():
		return
	var indices: Array[int] = []
	for name in names:
		var index := rig.find_bone(name + "." + side)
		if index < 0:
			return
		indices.append(index)
	var root := rig.get_bone_global_rest(indices[0]).origin
	var middle := rig.get_bone_global_rest(indices[1]).origin
	var wrist := rig.get_bone_global_rest(indices[2]).origin
	var values: Array = joints[end_name]
	var end := Vector3(values[0], values[1], values[2])
	if side == "R":
		end.x = -end.x
	var axis := (wrist - root).normalized()
	var pole := (middle - root - axis * (middle - root).dot(axis)).normalized()
	var helper := rig.find_bone(("shoulder_soft" if kind == "front" else "hip_soft") + "." + side)
	if helper >= 0:
		soft_helpers[indices[0]] = helper
	var twist := rig.find_bone("forearm_twist." + side) if kind == "front" else -1
	var wrist_helpers: Array[int] = []
	if kind == "front":
		for name in ["wrist_arc1", "wrist_arc2"]:
			var index := rig.find_bone(name + "." + side)
			if index >= 0:
				wrist_helpers.append(index)
	var toes: Array[int] = []
	var digit_bones: Array[int] = []
	var digits: Array[Dictionary] = []
	var meta_prefix := "fmeta" if kind == "front" else "hmeta"
	for index in range(rig.get_bone_count()):
		var name := rig.get_bone_name(index)
		if not name.ends_with("." + side):
			continue
		if name.begins_with(toe_prefix) or name.begins_with(meta_prefix) or (kind == "front" and name.begins_with("fthumb")):
			digit_bones.append(index)
		if name.begins_with(toe_prefix) and not "_p" in name:
			toes.append(index)
	var roots: Array[int] = toes.duplicate()
	if kind == "front" and rig.find_bone("fthumb." + side) >= 0:
		roots.append(rig.find_bone("fthumb." + side))
	for index in roots:
		var name := String(rig.get_bone_name(index)).trim_suffix("." + side)
		var chain: Array[int] = [index]
		for segment in [2, 3]:
			var next := rig.find_bone(name + "_p%d." % segment + side)
			if next >= 0:
				chain.append(next)
		var config_key := "thumb" if name == "fthumb" else "toes"
		var anatomy_config: Dictionary = foot_anatomy.get(kind, {}).get(config_key, {})
		digits.append({"bones": chain, "shares": anatomy_config.get("curl_shares", [0.45, 0.35, 0.2]),
			"limits": anatomy_config.get("flexion_limits_deg", [45, 55, 35])})
	legs.append({
		"name": kind + "." + side, "kind": kind, "indices": indices, "toes": toes,
		"digit_bones": digit_bones, "digits": digits,
		"soft": helper, "twist": twist, "forearm_twist": 0.0,
		"wrist_helpers": wrist_helpers,
		"hinge": (middle - root).cross(wrist - middle).normalized(),
		"root": root, "middle": middle, "wrist": wrist, "end": end,
		"pole": pole, "length_a": root.distance_to(middle), "length_b": middle.distance_to(wrist),
		"foot_vector": end - wrist, "anchor": Vector3.ZERO,
		"swing": false, "swing_progress": 0.0, "swing_cycle": -999,
		"offset": float(settings.touchdown_offsets[kind + "." + side]),
		"contact_error": 0.0, "phase": 0.0, "pitch": 0.0,
	})


func reset() -> void:
	if gallop:
		gallop.reset()
	transition_time = 1.0
	previous_position = body.global_position
	cycle = 0.0
	weight = 0.0
	turn_support = 1.0
	next_step = 0
	step_clock = 1.0
	previous_yaw = model.global_rotation.y
	yaw_velocity = 0.0
	frame_yaw_delta = 0.0
	model.position = model_home
	model.rotation.x = 0.0
	model.rotation.z = 0.0
	for leg in legs:
		leg.swing = false
		leg.pitch = 0.0
		leg.toe_curl = 0.0
		leg.forearm_twist = 0.0
		leg.erase("previous_root")
		leg.erase("from_gallop")
		leg.swing_cycle = -999
		leg.anchor = _ground(rig.to_global(leg.end))
		_restore_leg(leg)
	grounded_last = false


func update(delta: float) -> void:
	elapsed += delta
	step_clock += delta
	var yaw := model.global_rotation.y
	var yaw_delta := angle_difference(previous_yaw, yaw)
	frame_yaw_delta = yaw_delta
	yaw_velocity = lerpf(yaw_velocity, yaw_delta / maxf(delta, 0.0001), 1.0 - exp(-12.0 * delta))
	previous_yaw = yaw
	var displacement := body.global_position - previous_position
	previous_position = body.global_position
	displacement.y = 0.0
	if displacement.length() > 4.0:
		reset()
		return
	var speed := displacement.length() / maxf(delta, 0.0001)
	if gallop.update(delta, speed, displacement):
		grounded_last = true
		return
	transition_time += delta
	var moving := speed > float(settings.start_speed_m_s)
	weight = move_toward(weight, 1.0 if moving and body._supported() else 0.0, delta * 5.0)
	# Counter-motion at planted feet prevents the small body bob moving the paws.
	model.position = model.position.lerp(model_home + Vector3.UP * sin(cycle * TAU * 2.0) * float(settings.body_bob_model) * model.scale.y * weight, 1.0 - exp(-18.0 * delta))
	model.rotation.x = lerp_angle(model.rotation.x, 0.0, minf(1.0, delta * 12.0))
	model.rotation.z = lerp_angle(model.rotation.z, sin(cycle * TAU) * deg_to_rad(float(settings.body_roll_degrees)) * weight, 1.0 - exp(-18.0 * delta))
	if not body._supported():
		for leg in legs:
			_restore_leg(leg)
		grounded_last = false
		return
	if not grounded_last:
		for leg in legs:
			leg.anchor = _ground(rig.to_global(leg.end))
			leg.swing = false
			leg.erase("previous_root")
	grounded_last = true
	var stride := float(settings.stride_length_m)
	cycle += displacement.length() / stride
	var velocity := displacement / maxf(delta, 0.0001)
	var airborne_paws := 0
	for leg in legs:
		if leg.swing:
			airborne_paws += 1
		leg.urgency = _reach_ratio(leg, velocity, delta)
	turn_support = 1.0
	var needs_recovery := false
	var maximum_stance_urgency := 0.0
	for leg in legs:
		if not leg.swing:
			needs_recovery = needs_recovery or float(leg.urgency) > 0.88
			maximum_stance_urgency = maxf(maximum_stance_urgency, float(leg.urgency))
			# Pause a pivot when a planted foot cannot follow safely. A positive
			# minimum kept rotating the torso across that foot while its partner
			# was still recovering, especially after braking from a long reach.
			turn_support = minf(turn_support, clampf((0.99 - float(leg.urgency)) / 0.14, 0.0, 1.0))
	# Support pacing can reduce a lightly deflected stick below the ordinary walk
	# threshold. Still allow recovery, otherwise the old stance locks the turn.
	moving = moving or (needs_recovery and (speed > 0.02 or absf(yaw_velocity) > 0.03 or maximum_stance_urgency > 0.94))
	var selected: String = step_order[next_step]
	var priority := 0.94
	for leg in legs:
		if not leg.swing and _can_walk_step(leg) and float(leg.urgency) > priority:
			selected = leg.name
			priority = float(leg.urgency)
	# Recovery requests advance the coordinated sequence, never an arbitrary pair.
	# A minimum separation and opposite-end support prevent front/front or hind/hind
	# synchronization when several planted feet reach their limits during a turn.
	for leg in legs:
		var phase := fposmod(cycle - float(leg.offset), 1.0)
		leg.toe_curl = 0.0
		leg.forearm_twist = 0.0
		var cycle_id := int(floor(cycle - float(leg.offset)))
		leg.phase = phase
		var scheduled := phase >= float(settings.stance_fraction) and int(leg.swing_cycle) != cycle_id
		var ready: bool = leg.name == selected and _can_walk_step(leg)
		var separation := clampf(stride / maxf(speed, 0.5) * 0.18, 0.10, 0.24)
		if priority > 0.94:
			separation *= 0.5
		if moving and ready and not leg.swing and airborne_paws < 2 and step_clock >= separation and (scheduled or needs_recovery):
			leg.swing = true
			next_step = (step_order.find(leg.name) + 1) % step_order.size()
			step_clock = 0.0
			airborne_paws += 1
			leg.swing_cycle = cycle_id
			leg.swing_progress = 0.0
			leg.swing_from = leg.anchor
			leg.swing_from_pitch = leg.pitch
			var period := stride / maxf(speed, 0.5)
			leg.duration = clampf(period * (1.0 - float(settings.stance_fraction)), float(settings.min_swing_seconds), float(settings.max_swing_seconds))
			# Land ahead of the body so the next stance can carry it over the paw.
			leg.swing_to = landing_target(leg, velocity, float(leg.duration) + period * float(settings.stance_fraction) * 0.5)
		var target: Vector3 = leg.anchor
		var pitch: float = 0.0
		if leg.swing:
			# An airborne paw follows the turning torso's arc. Keeping its entire
			# recovery in the old heading can pull it outside reach during a pivot.
			var pivot := body.global_position - displacement
			leg.swing_from = pivot + Basis(Vector3.UP, yaw_delta) * ((leg.swing_from as Vector3) - pivot)
			if leg.get("from_gallop", false):
				leg.swing_from += displacement
			var desired_duration := clampf(stride / maxf(speed, 0.5) * (1.0 - float(settings.stance_fraction)), float(settings.min_swing_seconds), float(settings.max_swing_seconds))
			leg.duration = minf(float(leg.duration), desired_duration)
			leg.swing_progress = minf(1.0, float(leg.swing_progress) + delta / float(leg.duration))
			var t: float = leg.swing_progress
			if moving:
				# Retarget the landing during acceleration/turns. A prediction made at
				# the first low-speed frame otherwise leaves the paw far behind.
				var remaining := (1.0 - t) * float(leg.duration)
				var next_stance := stride / maxf(speed, 0.5) * float(settings.stance_fraction)
				var landing := landing_target(leg, velocity, remaining + next_stance * 0.5)
				leg.swing_to = landing
			# Smooth horizontal endpoints; asymmetric lift peaks early for clearance.
			var ease := t * t * (3.0 - 2.0 * t)
			target = (leg.swing_from as Vector3).lerp(leg.swing_to, ease)
			var lift := pow(sin(PI * t), 1.35)
			if leg.get("from_gallop", false):
				# This paw is already tucked: adding a fresh ground-to-air lift
				# would fold the knee beyond its minimum anatomical angle.
				lift = 0.0
			leg.toe_curl = deg_to_rad(8.0) * sin(PI * t)
			target.y += lift * float(settings.step_height_model) * model.scale.y
			var distal_angle: float = settings.swing_wrist_degrees if leg.kind == "front" else settings.swing_hock_degrees
			pitch = lerpf(float(leg.get("swing_from_pitch", 0.0)), deg_to_rad(distal_angle) * sin(PI * t), smoothstep(0.0, 0.3, t))
			if t >= 1.0:
				leg.swing = false
				leg.erase("from_gallop")
				airborne_paws -= 1
				leg.anchor = leg.swing_to
		else:
			var toe_off := smoothstep(float(settings.stance_fraction) * 0.72, float(settings.stance_fraction), phase) if moving else 0.0
			pitch = deg_to_rad(float(settings.toe_off_degrees)) * toe_off
		leg.pitch = pitch
		if transition_time < 0.24 and transition_feet.has(leg.name) and leg.swing:
			var origin := body.global_position - displacement
			transition_feet[leg.name] = body.global_position + Basis(Vector3.UP, yaw_delta) * ((transition_feet[leg.name] as Vector3) - origin)
			target = (transition_feet[leg.name] as Vector3).lerp(target, smoothstep(0.0, 0.24, transition_time))
		_solve_leg(leg, target, pitch)


func begin_transition() -> void:
	transition_time = 0.0
	step_clock = 0.0
	next_step = 0
	for leg in legs:
		transition_feet[leg.name] = leg.get("last_target", rig.to_global(leg.end))


func _can_walk_step(candidate: Dictionary) -> bool:
	for leg in legs:
		if leg.swing and leg.kind == candidate.kind:
			return false
	return true


func landing_target(leg: Dictionary, velocity: Vector3, horizon: float, convergence: float = 0.0, reach_offset: float = 0.0) -> Vector3:
	var local: Vector3 = leg.end
	local.x *= 1.0 - convergence
	var home := rig.to_global(local)
	# Rotate the expected contact around the body, so the outer feet take longer
	# arcs than the inner feet. Keep anticipation short enough for the current IK.
	var anticipation := minf(horizon, 0.32)
	var turn := Basis(Vector3.UP, clampf(yaw_velocity * anticipation, -0.45, 0.45))
	return landing_ground(body.global_position + turn * (home - body.global_position) + velocity * anticipation + velocity.normalized() * reach_offset)


func retarget_contact(leg: Dictionary, point: Vector3, pitch: float) -> Vector3:
	if not retarget_contacts:return point
	var parent := rig.get_bone_parent(leg.indices[0])
	var transform := rig.get_bone_global_pose(parent) * rig.get_bone_global_rest(parent).affine_inverse()
	var root: Vector3 = rig.to_global(transform * (leg.root as Vector3))
	var distal := rig.global_basis * (Basis(Vector3.RIGHT,pitch) * (leg.foot_vector as Vector3))
	var wrist := point-distal
	var a: float = leg.length_a
	var b: float = leg.length_b
	var limits: Dictionary = limb_settings[leg.kind]
	var radius := sqrt(a*a+b*b-2*a*b*cos(deg_to_rad(float(limits.joint_max_degrees)))) * model.scale.y - .015
	var dy := wrist.y-root.y
	var horizontal := Vector2(wrist.x-root.x,wrist.z-root.z)
	var available := sqrt(maxf(0.0,radius*radius-dy*dy))
	if horizontal.length()>available:
		horizontal=horizontal.limit_length(available)
		wrist.x=root.x+horizontal.x;wrist.z=root.z+horizontal.y
	return wrist+distal


func landing_ground(point: Vector3) -> Vector3:
	# A downward ray can hit the top of a wall beside the body. Retract the
	# proposed step onto nearby reachable ground instead of trying to climb it.
	var contact := _ground(point)
	var pad := float(settings.pad_height_model) * model.scale.y
	for i in range(10):
		if contact.y <= body.global_position.y + pad + 0.55:
			return contact
		var inward := Vector3(body.global_position.x - point.x, 0, body.global_position.z - point.z)
		point += inward.limit_length(0.25)
		contact = _ground(point)
	return contact


func _reach_ratio(leg: Dictionary, velocity: Vector3, delta: float, anticipation: float = 0.10) -> float:
	var parent := rig.get_bone_parent(leg.indices[0])
	var transform := rig.get_bone_global_pose(parent) * rig.get_bone_global_rest(parent).affine_inverse()
	var root: Vector3 = rig.to_global(transform * (leg.root as Vector3))
	var distal := Basis(Vector3.RIGHT, float(leg.pitch)) * (leg.foot_vector as Vector3)
	var wrist: Vector3 = (leg.anchor as Vector3) - rig.global_basis * distal
	var reach := (float(leg.length_a) + float(leg.length_b)) * model.scale.y
	var root_velocity: Vector3 = (root - (leg.previous_root as Vector3)) / delta if leg.has("previous_root") else velocity
	leg.previous_root = root
	# Anticipate the next fraction of stance, instead of waiting for a knee to
	# straighten completely. This also requests recovery steps during a tight turn.
	return (root + root_velocity * anticipation).distance_to(wrist) / reach


func _restore_leg(leg: Dictionary) -> void:
	for index in leg.wrist_helpers:
		rig.reset_bone_pose(index)
	for index in [leg.soft, leg.twist]:
		if index >= 0:
			rig.reset_bone_pose(index)
	for index in leg.indices:
		rig.reset_bone_pose(index)
	for index in leg.digit_bones:
		rig.reset_bone_pose(index)


func _ground(point: Vector3) -> Vector3:
	# Mud is a load-bearing volume above the hard collision bed.
	if body.mud_supported:
		var habitat := body.get_parent()
		if habitat.has_method("sample_soft_mud"):
			var sample: Dictionary = habitat.sample_soft_mud(point)
			if not sample.is_empty():
				point.y = float(sample.surface_y) - body.mud_sink + float(settings.pad_height_model) * model.scale.y
				return point
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point + Vector3.DOWN * 8.0, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		point.y = hit.position.y + float(settings.pad_height_model) * model.scale.y
	return point


func _solve_leg(leg: Dictionary, world_target: Vector3, pitch: float, pole_hint: Vector3 = Vector3.ZERO) -> void:
	leg.last_target = world_target
	var first: int = leg.indices[0]
	var parent := rig.get_bone_parent(first)
	var parent_rest := rig.get_bone_global_rest(parent)
	var parent_pose := rig.get_bone_global_pose(parent)
	var body_delta := parent_pose * parent_rest.affine_inverse()
	var root: Vector3 = body_delta * (leg.root as Vector3)
	var target := rig.to_local(world_target)
	var foot_rotation := Basis(Vector3.RIGHT, pitch)
	var foot_vector: Vector3 = foot_rotation * (leg.foot_vector as Vector3)
	var wrist_goal := target - foot_vector
	var axis := wrist_goal - root
	var a: float = leg.length_a
	var b: float = leg.length_b
	var limits: Dictionary = limb_settings[leg.kind]
	var min_reach := sqrt(a * a + b * b - 2.0 * a * b * cos(deg_to_rad(float(limits.joint_min_degrees))))
	var max_reach := sqrt(a * a + b * b - 2.0 * a * b * cos(deg_to_rad(float(limits.joint_max_degrees))))
	var distance := clampf(axis.length(), min_reach, minf(max_reach, a + b - 0.003))
	axis = axis.normalized()
	var pole: Vector3 = body_delta.basis * ((leg.pole as Vector3) if pole_hint.length_squared() < 0.001 else pole_hint.normalized())
	pole = (pole - axis * pole.dot(axis)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, a * a - along * along))
	var middle := root + axis * along + pole * height
	var wrist := root + axis * distance
	var hinge := (middle - root).cross(wrist - middle).normalized()
	_pose_link(first, leg.root, leg.middle, root, middle, hinge, leg.hinge)
	_pose_link(leg.indices[1], leg.middle, leg.wrist, middle, wrist, hinge, leg.hinge)
	_set_distal(leg, wrist, foot_rotation, float(leg.get("forearm_twist", 0.0)))
	_pose_digits(leg, pitch, float(leg.get("toe_curl", 0.0)), not leg.swing)
	leg.contact_error = rig.to_global(wrist + foot_vector).distance_to(world_target)


func _pose_digits(leg: Dictionary, pitch: float, curl: float, supported: bool) -> void:
	# Every ray/phalange inherits its parent's joint location. Rotate only; never
	# independently relocate distal joints or claws to fake a connected pose.
	for index in leg.digit_bones:
		rig.reset_bone_pose(index)
	for digit in leg.digits:
		for segment in range(digit.bones.size()):
			var index: int = digit.bones[segment]
			var pose := rig.get_bone_global_pose(index)
			if segment == 0 and supported:
				pose.basis = Basis(Vector3.RIGHT, -pitch) * pose.basis
			var rest := rig.get_bone_global_rest(index)
			var axis := Vector3.UP.cross(rest.basis.y).normalized()
			var deformation := pose.basis * rest.basis.inverse()
			axis = (deformation * axis).normalized()
			var angle := clampf(curl * float(digit.shares[segment]), 0.0, deg_to_rad(float(digit.limits[segment])))
			pose.basis = Basis(axis, angle) * pose.basis
			_set_global(index, pose)


func _pose_link(index: int, from: Vector3, to: Vector3, posed_from: Vector3, posed_to: Vector3, hinge: Vector3 = Vector3.ZERO, rest_hinge: Vector3 = Vector3.ZERO) -> void:
	var rotation := Basis(Quaternion((to - from).normalized(), (posed_to - posed_from).normalized()))
	if hinge.length_squared() > 0.5 and rest_hinge.length_squared() > 0.5:
		rotation = _link_frame(posed_to - posed_from, hinge) * _link_frame(to - from, rest_hinge).inverse()
	_set_global(index, Transform3D(rotation * rig.get_bone_global_rest(index).basis, posed_from))
	if soft_helpers.has(index):
		_update_soft(index, soft_helpers[index])


func _link_frame(direction: Vector3, normal: Vector3) -> Basis:
	var y := direction.normalized()
	var x := (normal - y * normal.dot(y)).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()


func _update_soft(index: int, helper: int) -> void:
	var parent := rig.get_bone_parent(index)
	var parent_delta := rig.get_bone_global_pose(parent) * rig.get_bone_global_rest(parent).affine_inverse()
	var limb_delta := rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse()
	var relative := parent_delta.basis.inverse() * limb_delta.basis
	var half := Quaternion.IDENTITY.slerp(relative.orthonormalized().get_rotation_quaternion(), soft_fraction)
	var rest := rig.get_bone_global_rest(helper)
	_set_global(helper, Transform3D(parent_delta.basis * Basis(half) * rest.basis, parent_delta * rest.origin))


func _set_distal(leg: Dictionary, wrist: Vector3, orientation: Basis, twist: float = 0.0) -> void:
	var turn := Basis.IDENTITY
	if leg.twist >= 0:
		rig.reset_bone_pose(leg.twist)
		var pose := rig.get_bone_global_pose(leg.twist)
		var axis := rig.get_bone_global_pose(leg.indices[1]).basis.y.normalized()
		turn = Basis(axis, twist)
		pose.basis = turn * pose.basis
		_set_global(leg.twist, pose)
	var rest := rig.get_bone_global_rest(leg.indices[2])
	_set_global(leg.indices[2], Transform3D(turn * orientation * rest.basis, wrist))
	if leg.twist >= 0:
		var forearm_delta := rig.get_bone_global_pose(leg.twist) * rig.get_bone_global_rest(leg.twist).affine_inverse()
		var hand_delta := rig.get_bone_global_pose(leg.indices[2]) * rest.affine_inverse()
		var relative := forearm_delta.basis.inverse() * hand_delta.basis
		for i in range(leg.wrist_helpers.size()):
			var index: int = leg.wrist_helpers[i]
			var fraction := float(i + 1) / 3.0
			var arc := Quaternion.IDENTITY.slerp(relative.orthonormalized().get_rotation_quaternion(), fraction)
			var helper_rest := rig.get_bone_global_rest(index)
			_set_global(index, Transform3D(forearm_delta.basis * Basis(arc) * helper_rest.basis, wrist))


func _set_global(index: int, pose: Transform3D) -> void:
	var parent := rig.get_bone_parent(index)
	var local := rig.get_bone_global_pose(parent).affine_inverse() * pose if parent >= 0 else pose
	rig.set_bone_pose_position(index, local.origin)
	rig.set_bone_pose_rotation(index, local.basis.orthonormalized().get_rotation_quaternion())
	rig.set_bone_pose_scale(index, Vector3.ONE)
