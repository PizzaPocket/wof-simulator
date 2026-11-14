extends RefCounted
## Continuous camera-relative gaze over the measured cervical chain and head.
## The small front-stage hysteresis prevents chatter while orbiting past a side.

var rig: Skeleton3D
var body: CharacterBody3D
var settings: Dictionary
var indices: Array[int] = []
var shares: Array[float] = []
var yaw: float = 0.0
var pitch: float = 0.0
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var front_stage: bool = false
var rest_aim: Vector3 = Vector3.FORWARD


func setup(skeleton: Skeleton3D, character: CharacterBody3D, config: Dictionary, anatomy: Dictionary) -> void:
	rig = skeleton
	body = character
	settings = config
	var nozzle := rig.find_bone("fire_origin")
	if nozzle >= 0:
		var aim: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fire_breath.json"))
		var up: Array = aim.up_model
		rest_aim = (rig.get_bone_global_rest(nozzle).basis.y.normalized() - Vector3(up[0], up[1], up[2]).normalized() * float(aim.normal_slope)).normalized()
	var total := 0.0
	for segment in anatomy.get("neck_bones", []):
		var index := rig.find_bone(segment.name)
		if index >= 0:
			indices.append(index)
			shares.append(float(segment.length))
			total += float(segment.length)
	# Read actual rest positions when using an older locally built sidecar.
	if indices.is_empty():
		for name in ["neck1", "neck2", "neck3", "neck4"]:
			var index := rig.find_bone(name)
			if index >= 0:
				indices.append(index)
				shares.append(1.0)
				total += 1.0
	for index in range(shares.size()):
		shares[index] = shares[index] / maxf(total, 0.001) * (1.0 - float(settings.head_share))
	var head := rig.find_bone("head")
	if head >= 0:
		indices.append(head)
		shares.append(float(settings.head_share))


func update(delta: float) -> void:
	var camera: Node3D = body.get_node("CameraPivot")
	var visual: Node3D = body.get_node("Visual")
	var relative_yaw := wrapf(camera.rotation.y - visual.rotation.y, -PI, PI)
	var angle := absf(rad_to_deg(relative_yaw))
	if not front_stage and angle > float(settings.front_stage_enter_degrees):
		front_stage = true
	elif front_stage and angle < float(settings.front_stage_leave_degrees):
		front_stage = false
	target_yaw = 0.0 if front_stage else clampf(relative_yaw, -deg_to_rad(float(settings.yaw_limit_degrees)), deg_to_rad(float(settings.yaw_limit_degrees)))
	# The sculpt's muzzle points downward even at rest. Calibrate against its
	# actual emission axis so looking up produces an upward gaze and flame.
	var base_aim := (rig.global_basis * rest_aim).normalized()
	var base_pitch := atan2(base_aim.y, Vector2(base_aim.x, base_aim.z).length())
	var elevation := camera.rotation.x - base_pitch
	target_pitch = 0.0 if front_stage else clampf(elevation, -deg_to_rad(float(settings.pitch_limit_degrees)), deg_to_rad(float(settings.pitch_limit_degrees)))
	var rate := 1.0 - exp(-float(settings.response) * delta)
	var maximum_step := deg_to_rad(float(settings.max_speed_degrees_s)) * delta
	yaw += clampf((target_yaw - yaw) * rate, -maximum_step, maximum_step)
	pitch += clampf((target_pitch - pitch) * rate, -maximum_step, maximum_step)
	for index in indices:
		rig.reset_bone_pose(index)
	var accumulated := 0.0
	var previous_turn := Basis.IDENTITY
	for part in range(indices.size()):
		var index := indices[part]
		var parent := rig.get_bone_parent(index)
		var parent_pose := rig.get_bone_global_pose(parent)
		var pose := rig.get_bone_global_pose(index)
		accumulated += shares[part]
		var total_turn := Basis(Vector3.UP, yaw * accumulated) * Basis(Vector3.RIGHT, -pitch * accumulated)
		var turn := total_turn * previous_turn.inverse()
		previous_turn = total_turn
		var local := parent_pose.basis.inverse() * turn * pose.basis
		rig.set_bone_pose_rotation(index, local.orthonormalized().get_rotation_quaternion())


func reset() -> void:
	yaw = 0.0
	pitch = 0.0
	target_yaw = 0.0
	target_pitch = 0.0
	front_stage = false
