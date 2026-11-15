extends RefCounted
## Shoulder power stroke with separately timed elbow, wrist and digit recovery.
## A brief launch effort also runs when the camera is aimed level.

var rig: Skeleton3D
var body: CharacterBody3D
var settings: Dictionary
var phase: float = 0.0
var flap_blend: float = 0.0
var recovery: float = 0.0
var stroke: float = 0.0
var launch_effort: float = 0.0
var turn_effort: float = 0.0
var was_flying: bool = false
var recovery_joints: Array[Dictionary] = []
var stroke_bones: Array[Dictionary] = []


func setup(skeleton: Skeleton3D, character: CharacterBody3D, config: Dictionary, rig_design: Dictionary = {}) -> void:
	rig = skeleton
	body = character
	settings = config
	# Use a small measured articulation from the existing rig, without running
	# the whole storage-fold pose or moving bone attachment points during a flap.
	var anatomy: Dictionary = rig_design
	if anatomy.is_empty() and FileAccess.file_exists("res://assets/clay_rig.json"):
		anatomy = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clay_rig.json"))
	for track in anatomy.get("wing_animation", {}).get("tracks", []):
		var name: String = track.bone
		if track.property != "rotation" or not (name.begins_with("wing_forearm.") or name.begins_with("wing_carpal.") or name.begins_with("wing_finger")):
			continue
		var index := rig.find_bone(name)
		if index < 0 or track.values.size() < 2:
			continue
		var a: Array = track.values[0]
		# Sample by normalized fold position, independent of corrective density.
		var sample_time: float = float(track.times.back()) * 0.25
		var upper := 1
		while upper < track.times.size() - 1 and float(track.times[upper]) < sample_time:
			upper += 1
		var lower := upper - 1
		var fraction := inverse_lerp(float(track.times[lower]), float(track.times[upper]), sample_time)
		var b: Array = track.values[lower]
		var c: Array = track.values[upper]
		var partial := Quaternion(b[0], b[1], b[2], b[3]).normalized().slerp(Quaternion(c[0], c[1], c[2], c[3]).normalized(), fraction)
		add_recovery_sample(index,Quaternion(a[0],a[1],a[2],a[3]).normalized(),partial,
			0.0 if name.begins_with("wing_forearm.") else (0.055 if name.begins_with("wing_carpal.") else 0.10),
			5.0 if name.begins_with("wing_finger") else 14.0)

	for item in anatomy.get("wing_stroke_bones", []):
		var index := rig.find_bone(item.bone)
		if index >= 0:stroke_bones.append({"index": index, "side": item.side, "share": item.share})
	if stroke_bones.is_empty():
		for side in ["L", "R"]:
			for item in [["wing_socketBlend1", 1.0/3.0], ["wing_socketBlend2", 2.0/3.0], ["wing_humerus", 1.0]]:
				var index := rig.find_bone(item[0]+"."+side)
				if index >= 0:stroke_bones.append({"index": index, "side": side, "share": item[1]})
	for item in anatomy.get("wing_recovery_joints", []):
		var index := rig.find_bone(item.bone)
		if index < 0:continue
		var axis: Array = item.axis
		var local_axis := rig.get_bone_global_rest(index).basis.inverse() * Vector3(axis[0],axis[1],axis[2])
		recovery_joints.append({"index": index, "rotation": Quaternion(local_axis.normalized(), deg_to_rad(float(item.degrees))), "delay": item.delay})


func add_recovery_sample(index: int, rest: Quaternion, partial: Quaternion, delay: float, maximum_degrees: float) -> void:
	var rotation := rest.inverse()*partial
	var maximum := deg_to_rad(maximum_degrees)
	var angle := Quaternion.IDENTITY.angle_to(rotation)
	if angle>maximum:rotation=Quaternion.IDENTITY.slerp(rotation,maximum/angle)
	recovery_joints.append({"index":index,"rotation":rotation.normalized(),"delay":delay})


func update(delta: float) -> void:
	var flying: bool = body.locomotion_state == &"flying"
	var climbing: bool = flying and body.flight_mode == &"climbing"
	if flying and not was_flying:
		phase = 0.0
	was_flying = flying
	var launch_seconds := float(settings.get("launch_seconds", 1.7))
	launch_effort = 1.0 - smoothstep(launch_seconds - 0.6, launch_seconds, body.state_time) if flying else 0.0
	# Hard turns and air-braking make the wings work: beat faster and wider, as a bat or bird does
	# when it changes direction at speed.
	turn_effort = body.flight_turn_effort if flying else 0.0
	var wanted_blend := maxf(maxf(launch_effort, 1.0 if climbing else 0.0), turn_effort)
	flap_blend = lerpf(flap_blend, wanted_blend, 1.0 - exp(-float(settings.flap_response) * (1.0 + 1.6 * turn_effort) * delta))
	if flap_blend > 0.001:
		phase = fposmod(phase + delta * float(settings.flap_frequency_hz) * lerpf(1.0, 1.12, launch_effort) * (1.0 + 1.1 * turn_effort), 1.0)
	var split := float(settings.downstroke_fraction)
	var fraction := smoothstep(0.0, split, phase) if phase < split else smoothstep(split, 1.0, phase)
	var up := deg_to_rad(float(settings.flap_up_degrees))
	var down := deg_to_rad(float(settings.flap_down_degrees))
	stroke = (lerpf(up, down, fraction) if phase < split else lerpf(down, up, fraction)) * lerpf(1.0, 1.35, launch_effort) * (1.0 + 0.4 * turn_effort)
	recovery = sin(PI * clampf((phase - split) / (1.0 - split), 0, 1)) if phase >= split else 0.0


func fold_for_flight() -> float:
	# Powered flight and gliding both require a deployed wing.
	return 0.0


func apply_stroke(deployment: float, pose_solver: RefCounted) -> void:
	if body.locomotion_state != &"flying" and flap_blend < 0.001:
		return
	# Avoid a ground-scraping downstroke during deployment or a low landing.
	var clearance: float = smoothstep(0.8, 2.5, body.ground_distance)
	var glide := deg_to_rad(float(settings.glide_dihedral_degrees)) * deployment
	var turning_left: bool = body.flight_turn_rate > 0.0
	for item in stroke_bones:
		var sign_side := 1.0 if item.side == "L" else -1.0
		# The wing on the inside of the turn beats wider; the outside wing drives the yaw.
		var inside: bool = (item.side == "L") == turning_left
		var side_scale := 1.0 + turn_effort * (0.45 if inside else 0.12)
		var angle := glide + stroke * flap_blend * deployment * clearance * side_scale
		var index: int = item.index
		var pose := rig.get_bone_global_pose(index)
		pose.basis = Basis(Vector3.BACK, angle * sign_side * float(item.share)) * pose.basis
		pose_solver._set_global(index, pose)
	for joint in recovery_joints:
		var t := clampf((phase - 0.42 - float(joint.delay)) / (0.58 - float(joint.delay)), 0.0, 1.0)
		var envelope := pow(sin(PI * t), 2.0)
		var strength := envelope * flap_blend * deployment * clearance
		var rotation := rig.get_bone_pose_rotation(joint.index)
		rig.set_bone_pose_rotation(joint.index, rotation * Quaternion.IDENTITY.slerp(joint.rotation, strength))


func reset() -> void:
	phase = 0.0
	flap_blend = 0.0
	recovery = 0.0
	stroke = 0.0
	launch_effort = 0.0
	turn_effort = 0.0
	was_flying = false
