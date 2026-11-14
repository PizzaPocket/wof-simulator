extends RefCounted
## Inspection of the same weight-bearing forelimb used as a reaching arm.
## This is an authored demonstration, not a grasp/interaction physics system.
var body: CharacterBody3D
var gait: RefCounted
var settings: Dictionary
var mode: int = 0
var weight: float = 0.0
var palm_amount: float = 0.0

func setup(character: CharacterBody3D, solver: RefCounted) -> void:
	body = character
	gait = solver
	settings = gait.limb_settings.arm

func update(delta: float) -> void:
	if body.locomotion_state != &"grounded":
		reset()
		return
	var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1
	if Input.is_action_just_pressed("arm_preview") and not moving:
		mode = (mode + 1) % 3
	if moving:
		mode = 0
	weight = move_toward(weight, 1.0 if mode > 0 else 0.0, delta / float(settings.blend_seconds))
	if mode > 0:
		palm_amount = move_toward(palm_amount, 1.0 if mode == 2 else 0.0, delta / float(settings.blend_seconds))
	if weight <= 0:
		return
	for leg in gait.legs:
		if leg.name != "front.L":
			continue
		var reach: Array = settings.reach_wrist_target
		var palm: Array = settings.palm_wrist_target
		var target := Vector3(reach[0], reach[1], reach[2]).lerp(Vector3(palm[0], palm[1], palm[2]), palm_amount)
		var foot: int = leg.indices[2]
		var current: Vector3 = gait.rig.get_bone_global_pose(foot).origin
		var blend := smoothstep(0, 1, weight)
		target = current.lerp(target, blend)
		var base_pitch: float = leg.pitch
		var base_orientation := Basis(Vector3.RIGHT, base_pitch)
		leg.forearm_twist = deg_to_rad(float(settings.palm_supination_degrees)) * palm_amount * weight
		leg.toe_curl = deg_to_rad(float(settings.toe_curl_degrees)) * weight
		var was_swing: bool = leg.swing
		leg.swing = true
		var pole: Array = settings.elbow_pole
		# Solve the wrist location first. A free hand follows the forearm's frame;
		# a planted paw instead uses the ground orientation supplied by the gait.
		var endpoint: Vector3 = target + base_orientation * (leg.foot_vector as Vector3)
		gait._solve_leg(leg, gait.rig.to_global(endpoint), base_pitch, Vector3(pole[0], pole[1], pole[2]))
		var lower: int = leg.indices[1]
		var forearm_delta: Transform3D = gait.rig.get_bone_global_pose(lower) * gait.rig.get_bone_global_rest(lower).affine_inverse()
		var flex := lerpf(float(settings.reach_wrist_flex_degrees), float(settings.palm_wrist_flex_degrees), palm_amount)
		var carried := forearm_delta.basis * Basis(Vector3.RIGHT, deg_to_rad(flex))
		var orientation := base_orientation.slerp(carried, blend)
		var wrist: Vector3 = gait.rig.get_bone_global_pose(foot).origin
		gait._set_distal(leg, wrist, orientation, float(leg.forearm_twist))
		gait._pose_digits(leg, base_pitch, float(leg.toe_curl), false)
		leg.swing = was_swing

func reset() -> void:
	mode = 0
	weight = 0
	palm_amount = 0
