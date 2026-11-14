extends Node
## Owns pose evaluation order: wing tracks -> corrective shapes -> gait -> tail.
## AnimationPlayer is sampled manually so it cannot overwrite the procedural pose.

const Gait = preload("res://scripts/quadruped_gait.gd")
const Tail = preload("res://scripts/tail_motion.gd")
const Gaze = preload("res://scripts/neck_gaze.gd")
const Jump = preload("res://scripts/jump_motion.gd")
const Flight = preload("res://scripts/flight_motion.gd")
var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var animation_player: AnimationPlayer
var fold_clip: StringName
var fold_amount: float = 1.0
var fold_target: float = 1.0
var wing_deployment := preload("res://scripts/wing_deployment.gd").new()
var wing_step_count: int = 0
var gait: RefCounted
var tail: RefCounted
var body: CharacterBody3D
var model: Node3D
var config: Dictionary
var anatomy: Dictionary
var enabled: bool = true
var player_controlled: bool = true
var wing_tracks: Array[Dictionary] = []
var gaze: RefCounted
var jump: RefCounted
var flight: RefCounted
var blink: RefCounted
var fire: RefCounted
var arm_inspection: RefCounted


func setup(instance: Node3D, owner_body: CharacterBody3D, rig_design: Dictionary = {}) -> void:
	model = instance
	body = owner_body
	process_physics_priority = 10
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/locomotion.json"))
	if not rig_design.is_empty():
		anatomy = rig_design
	elif FileAccess.file_exists("res://assets/clay_rig.json"):
		anatomy = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clay_rig.json"))
	if not anatomy.has("locomotion_scale") and not is_equal_approx(model.scale.y,2.0):
		anatomy.locomotion_scale={"world":model.scale.y/2.0,"front_reach":1.0,"hind_reach":1.0,"pad":config.walk.pad_height_model}
	if anatomy.has("locomotion_scale"):
		var dimensions: Dictionary = anatomy.locomotion_scale
		config.walk.stride_length_m *= float(dimensions.world)
		config.walk.pad_height_model = float(dimensions.pad)
		config.run.easy_stride_length_m *= float(dimensions.world)
		config.run.sprint.stride_length_m *= float(dimensions.world)
		config.run.sprint.front_reach_model *= float(dimensions.front_reach)
		config.run.sprint.hind_reach_model *= float(dimensions.hind_reach)
		config.jump.crouch_depth_m *= float(dimensions.world)
		config.jump.landing_depth_m *= float(dimensions.world)
		anatomy.run_settings = config.run
	for rig in model.find_children("*", "Skeleton3D", true, false):
		skeleton = rig
		break
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mesh)
		for index in range(mesh.mesh.get_blend_shape_count()):
			var shape_name: String = mesh.mesh.get_blend_shape_name(index)
			if shape_name.begins_with("wingFold"):
				wing_step_count = maxi(wing_step_count, int(shape_name.trim_prefix("wingFold")))
	for animator in model.find_children("*", "AnimationPlayer", true, false):
		for clip in animator.get_animation_list():
			if "wings_fold" in clip:
				animation_player = animator
				fold_clip = clip
				animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				animator.play(clip)
				animator.pause()
				break
	if skeleton:
		for track in anatomy.get("wing_animation", {}).get("tracks", []):
			var index := skeleton.find_bone(track.bone)
			if index >= 0:
				track.index = index
				wing_tracks.append(track)
		gait = Gait.new()
		gait.setup(skeleton, body, model, config.walk, anatomy)
		arm_inspection = preload("res://scripts/arm_inspection.gd").new()
		arm_inspection.setup(body, gait)
		tail = Tail.new()
		tail.setup(skeleton, body, config.tail, anatomy)
		gaze = Gaze.new()
		gaze.setup(skeleton, body, config.gaze, anatomy)
		jump = Jump.new()
		jump.setup(skeleton, body, model, gait, config.jump)
		flight = Flight.new()
		flight.setup(skeleton, body, config.flight, anatomy)
		fire = preload("res://scripts/fire_breath.gd").new()
		fire.setup(skeleton, meshes)
	blink = preload("res://scripts/blink_cycle.gd").new()
	blink.setup(meshes, config.blink)
	apply_wings()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if gait and gait.gallop:
		gait.gallop._reset_trunk()
	var controls_active: bool = player_controlled and not body.conversation_locked
	var flying: bool = body.locomotion_state == &"flying"
	if flight:
		flight.update(delta)
	if controls_active and Input.is_action_just_pressed("toggle_wings") and not flying:
		fold_target = 0.0 if fold_target > 0.5 else 1.0
	var adjustment := Input.get_axis("spread_wings", "fold_wings") if controls_active else 0.0
	if absf(adjustment) > 0.01 and not flying:
		fold_target = clampf(fold_target + adjustment * delta / config.wings.seconds_to_fold, 0.0, 1.0)
	var desired_fold: float = flight.fold_for_flight() if flying and flight else 1.0 if body.locomotion_state == &"climbing" else fold_target
	var fold_seconds: float = config.flight.deployment_seconds if flying else config.wings.seconds_to_fold
	if not flying and desired_fold < fold_amount:
		fold_seconds = float(config.wings.get("seconds_to_spread", fold_seconds))
	fold_amount = wing_deployment.step(fold_amount, desired_fold, delta, fold_seconds)
	apply_wings()
	if gait:
		if body.locomotion_state == &"climbing":
			body.climb.animate_pose(delta, gait)
		elif body.locomotion_state == &"grounded":
			gait.update(delta)
		else:
			jump.update(delta)
		if body.climb:body.climb.blend_release(delta,gait)
	if arm_inspection and controls_active and body.locomotion_state != &"climbing":
		arm_inspection.update(delta)
	if flight and gait:
		flight.apply_stroke(pow(1.0 - fold_amount, 2), gait)
	if gaze and body.locomotion_state != &"climbing":
		gaze.update(delta)
	if fire and controls_active and body.can_breathe_fire:
		fire.update(delta)
	elif fire:
		fire.reset()
	if tail:
		if controls_active and Input.is_action_just_pressed("tail_preview"):
			tail.preview_mode = (tail.preview_mode + 1) % 3
		tail.update(delta)
	if blink:
		blink.update(delta)


func apply_wings() -> void:
	if not wing_tracks.is_empty():
		var time := fold_amount * float(anatomy.wing_animation.duration)
		for track in wing_tracks:
			_sample_track(track, time)
	elif animation_player:
		var animation := animation_player.get_animation(fold_clip)
		animation_player.seek(clampf(fold_amount, 0, 1) * animation.length, true)
	# The viewer uses adjacent *absolute samples*, never additive accumulation.
	# At fold=1 only the final sample is 1; at 0 all corrective weights are 0.
	var sample := fold_amount * wing_step_count
	for mesh in meshes:
		for index in range(mesh.mesh.get_blend_shape_count()):
			var shape_name: String = mesh.mesh.get_blend_shape_name(index)
			if shape_name.begins_with("wingFold"):
				var number := int(shape_name.trim_prefix("wingFold"))
				mesh.set_blend_shape_value(index, maxf(0.0, 1.0 - absf(sample - number)))
	_apply_socket_target()


func _apply_socket_target() -> void:
	# Small socket-placement revisions can be previewed immediately. Once the
	# matching source mesh is rebuilt the bind metadata makes this offset zero.
	if not gait or not anatomy.has("wing_socket") or not config.wings.has("socket_target_model"):
		return
	var source: Array = anatomy.wing_socket
	var target: Array = config.wings.socket_target_model
	var offset := Vector3(target[0] - source[0], target[1] - source[1], target[2] - source[2])
	if offset.length_squared() < 0.00000001:
		return
	offset = offset.limit_length(0.1)
	for side in ["L", "R"]:
		var mirrored := Vector3(offset.x * (1 if side == "L" else -1), offset.y, offset.z)
		for name in ["wing_humerus", "wing_socketBlend1", "wing_socketBlend2"]:
			var index := skeleton.find_bone(name + "." + side)
			if index >= 0:
				var pose := skeleton.get_bone_global_pose(index)
				var parent := skeleton.get_bone_parent(index)
				var parent_delta := skeleton.get_bone_global_pose(parent) * skeleton.get_bone_global_rest(parent).affine_inverse()
				pose.origin = parent_delta * skeleton.get_bone_global_rest(index).origin + mirrored
				gait._set_global(index, pose)


func _sample_track(track: Dictionary, time: float) -> void:
	var times: Array = track.times
	var low := 0
	var high := times.size() - 1
	while low + 1 < high:
		var middle := (low + high) / 2
		if float(times[middle]) <= time:
			low = middle
		else:
			high = middle
	var amount := clampf((time - float(times[low])) / maxf(0.000001, float(times[high]) - float(times[low])), 0, 1)
	if track.interpolation == "STEP":
		amount = 1.0 if time >= float(times[high]) else 0.0
	var a: Array = track.values[low]
	var b: Array = track.values[high]
	if track.property == "rotation":
		var first := Quaternion(a[0], a[1], a[2], a[3]).normalized()
		var second := Quaternion(b[0], b[1], b[2], b[3]).normalized()
		skeleton.set_bone_pose_rotation(track.index, first.slerp(second, amount))
	else:
		var value := Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), amount)
		if track.property == "translation":
			skeleton.set_bone_pose_position(track.index, value)
		elif track.property == "scale":
			skeleton.set_bone_pose_scale(track.index, value)


func reset_motion() -> void:
	wing_deployment.velocity = 0.0
	if fire:
		fire.reset()
	if blink:
		blink.reset()
	if arm_inspection:
		arm_inspection.reset()
	model.rotation.x = 0.0
	model.rotation.z = 0.0
	if gait:
		gait.reset()
	if tail:
		tail.reset()
	if gaze:
		gaze.reset()
	if flight:
		flight.reset()
	if jump:
		jump.reset()


func resume_ground_motion() -> void:
	var carried_position := model.position
	var carried_rotation := model.rotation
	if gait:
		gait.reset()
	# Let the walk/gallop blend out the last landing pose instead of snapping
	# the torso to its home height as soon as the landing timer finishes.
	model.position = carried_position
	model.rotation = carried_rotation
	if jump:
		jump.reset()
