extends RefCounted
## Reference-led, unweighted limb carriage. Three independently oriented links
## preserve the rig's anatomy instead of lifting the stance paw target alone.
var rig: Skeleton3D
var body: CharacterBody3D
var gait: RefCounted
var settings: Dictionary
var directions: Dictionary = {}
var elapsed: float = 0.0


func setup(skeleton: Skeleton3D, character: CharacterBody3D, solver: RefCounted) -> void:
	rig = skeleton
	body = character
	gait = solver
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/flight_limbs.json"))


func capture() -> void:
	directions.clear()
	for leg in gait.legs:
		var a := rig.get_bone_global_pose(leg.indices[0]).origin
		var b := rig.get_bone_global_pose(leg.indices[1]).origin
		var c := rig.get_bone_global_pose(leg.indices[2]).origin
		directions[leg.name] = {"upper": (b - a).normalized(), "lower": (c - b).normalized()}


func begin_frame(delta: float) -> void:
	elapsed += delta


func pose_leg(leg: Dictionary, delta: float) -> void:
	var profile: Dictionary = settings[leg.kind]
	var side_name := "L" if String(leg.name).ends_with(".L") else "R"
	var side := 1.0 if side_name == "L" else -1.0
	var offsets: Dictionary = profile[side_name]
	var a: Array = profile.upper_direction
	var b: Array = profile.lower_direction
	var upper := Vector3(a[0] * side, a[1], a[2]).normalized()
	var lower := Vector3(b[0] * side, b[1], b[2]).normalized()
	upper = Basis(Vector3.RIGHT, deg_to_rad(float(offsets.upper_pitch))) * upper
	lower = Basis(Vector3.RIGHT, deg_to_rad(float(offsets.lower_pitch))) * lower
	var phase := 0.6 if leg.kind == "hind" else 0.0
	phase += 0.8 if side < 0 else 0.0
	var drift := sin(elapsed * TAU * 0.35 + phase) * deg_to_rad(float(settings.drift_degrees))
	upper = Basis(Vector3.RIGHT, drift) * upper
	lower = Basis(Vector3.RIGHT, -drift * 0.7) * lower
	# Partially gravity-align a held pose, retaining engaged flexion with the torso.
	var up := (rig.global_basis.orthonormalized().inverse() * Vector3.UP).normalized()
	up = Vector3.UP.lerp(up, float(settings.gravity_alignment)).normalized()
	var forward := (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
	var right := up.cross(forward).normalized()
	var gravity_frame := Basis(right, up, forward)
	upper = gravity_frame * upper
	lower = gravity_frame * lower
	var carriage := 1.0
	if body.velocity.y < 0:
		carriage = smoothstep(0.3, 2.0, body.ground_distance)
	var rest_upper: Vector3 = ((leg.middle as Vector3) - (leg.root as Vector3)).normalized()
	var rest_lower: Vector3 = ((leg.wrist as Vector3) - (leg.middle as Vector3)).normalized()
	upper = rest_upper.slerp(upper, carriage).normalized()
	lower = rest_lower.slerp(lower, carriage).normalized()
	var response := 1.0 - exp(-float(settings.response) * delta)
	var state: Dictionary = directions[leg.name]
	state.upper = (state.upper as Vector3).slerp(upper, response).normalized()
	state.lower = (state.lower as Vector3).slerp(lower, response).normalized()
	var parent := rig.get_bone_parent(leg.indices[0])
	var transform := rig.get_bone_global_pose(parent) * rig.get_bone_global_rest(parent).affine_inverse()
	var root: Vector3 = transform * (leg.root as Vector3)
	var middle: Vector3 = root + (state.upper as Vector3) * float(leg.length_a)
	var wrist: Vector3 = middle + (state.lower as Vector3) * float(leg.length_b)
	var desired := deg_to_rad(float(profile.distal_pitch_degrees) + float(offsets.distal_pitch)) * carriage
	leg.pitch = lerp_angle(float(leg.get("pitch", 0.0)), desired, response)
	leg.toe_curl = lerpf(float(leg.get("toe_curl", 0.0)), deg_to_rad(float(profile.toe_curl_degrees) + float(offsets.toe_curl)) * carriage, response)
	leg.forearm_twist = lerpf(float(leg.get("forearm_twist", 0.0)), deg_to_rad(float(profile.forearm_twist_degrees)) * side * carriage, response)
	var gravity_rotation := Basis(Quaternion(Vector3.UP, up))
	var distal := Basis.IDENTITY.slerp(gravity_rotation, carriage) * Basis(Vector3.RIGHT, float(leg.pitch))
	if leg.kind == "hind":
		# Measure hock bend from the actual posed shank and metatarsal axes.
		# A body-space pitch alone can still straighten the ankle during banking.
		var shank := (wrist - middle).normalized()
		var foot := (distal * (leg.foot_vector as Vector3)).normalized()
		var bend := acos(clampf(shank.dot(foot), -1.0, 1.0))
		var minimum := deg_to_rad(float(profile.minimum_hock_flexion_degrees))
		var maximum := deg_to_rad(float(profile.maximum_hock_flexion_degrees))
		var correction := clampf(bend, minimum, maximum) - bend
		if absf(correction) > 0.00001:
			var axis := shank.cross(foot).normalized()
			if axis.length_squared() < 0.5:
				axis = Vector3.RIGHT
			distal = Basis(axis, correction) * distal
	var hinge := (middle - root).cross(wrist - middle).normalized()
	gait._pose_link(leg.indices[0], leg.root, leg.middle, root, middle, hinge, leg.hinge)
	gait._pose_link(leg.indices[1], leg.middle, leg.wrist, middle, wrist, hinge, leg.hinge)
	gait._set_distal(leg, wrist, distal, float(leg.forearm_twist))
	leg.swing = true
	apply_toe_curl(leg)


func apply_toe_curl(leg: Dictionary) -> void:
	gait._pose_digits(leg, float(leg.get("pitch", 0.0)), float(leg.get("toe_curl", 0.0)), not leg.swing)
