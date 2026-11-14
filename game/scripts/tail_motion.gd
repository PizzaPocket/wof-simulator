extends RefCounted
## Length-constrained caudal chain driven by a distance-sampled root trail.
## This is damped kinematic follow-through, not a rigid-body muscle simulation.

var rig: Skeleton3D
var body: CharacterBody3D
var settings: Dictionary
var bones: Array[int] = []
var lengths: Array[float] = []
var history: Array[Vector3] = []
var points: Array[Vector3] = []
var total_length: float = 0.0
var previous_root: Vector3
var previous_body_position: Vector3
var still_time: float = 0.0
var contacts: RefCounted
var preview_mode: int = 0
var air_blend: float = 0.0
var curl_amount: float = 0.0
var preview_weight: float = 0.0
var recovery_weight: float = 0.0
var curl_stress_time: float = 0.0
var stalled_time: float = 0.0
var rest_offsets: Array[Vector3] = []
var resting: bool = false
var previous_preview_mode: int = 0
var recovery_side: float = 1.0


func setup(skeleton: Skeleton3D, character: CharacterBody3D, config: Dictionary, anatomy: Dictionary) -> void:
	rig = skeleton
	body = character
	settings = config
	contacts = preload("res://scripts/tail_contacts.gd").new()
	var available_segments: Array = []
	for segment in anatomy.get("tail_bones", []):
		var index := rig.find_bone(segment.name)
		if index >= 0:
			available_segments.append(segment)
			bones.append(index)
			lengths.append(float(segment.length))
			total_length += float(segment.length)
	contacts.setup(available_segments, config)
	reset()


func reset() -> void:
	history.clear()
	points.clear()
	still_time = 0.0
	preview_mode = 0
	air_blend = 0.0
	curl_amount = 0.0
	preview_weight = 0.0
	recovery_weight = 0.0
	curl_stress_time = 0.0
	stalled_time = 0.0
	rest_offsets.clear()
	resting = false
	previous_preview_mode = 0
	recovery_side = 1.0
	if contacts:
		contacts.safe_local.clear()
	if bones.is_empty():
		return
	var root := _root_world()
	previous_root = root
	previous_body_position = body.global_position
	history.append(root)
	var behind := (rig.global_basis * Vector3.FORWARD).normalized()
	var distance := 0.0
	for length in lengths:
		distance += length * rig.global_basis.get_scale().x
		points.append(root + behind * distance)
	var inverse := rig.global_transform.affine_inverse()
	contacts.safe_local.append(inverse * root)
	for point in points:
		contacts.safe_local.append(inverse * point)
	_capture_rest(root)
	resting = true


func _root_world() -> Vector3:
	var parent := rig.get_bone_parent(bones[0])
	return rig.to_global((rig.get_bone_global_pose(parent) * rig.get_bone_rest(bones[0])).origin)


func update(delta: float) -> void:
	if bones.is_empty():
		return
	var root := _root_world()
	var flying: bool = body.locomotion_state == &"flying"
	var aerial: bool = flying or body.locomotion_state == &"airborne"
	air_blend = lerpf(air_blend, 1.0 if aerial else 0.0, 1.0 - exp(-6.0 * delta))
	var desired_curl := 1.0 if preview_mode == 1 else (-1.0 if preview_mode == 2 else 0.0)
	curl_amount = move_toward(curl_amount, desired_curl, delta * 0.5)
	preview_weight = move_toward(preview_weight, 1.0 if preview_mode > 0 else 0.0, delta * 1.5)
	if root.distance_to(previous_root) > float(settings.teleport_reset_m):
		reset()
		root = _root_world()
	var root_shift := root - previous_root
	var body_shift := body.global_position - previous_body_position
	previous_body_position = body.global_position
	var moved := Vector2(body_shift.x, body_shift.z).length()
	# Pelvis/gait settling can move the attachment a long way on a stationary
	# animal. Carry its path with that posture change instead of recording a turn.
	if moved / maxf(delta, 0.0001) < 0.12:
		for i in range(history.size()):
			history[i] += root_shift - body_shift
	previous_root = root
	still_time = still_time + delta if moved / maxf(delta, 0.0001) < 0.12 else 0.0
	if Vector2(root.x - history[0].x, root.z - history[0].z).length() >= float(settings.history_spacing_m):
		history.push_front(root)
		if history.size() > 500:
			history.pop_back()
	var behind := (rig.global_basis * Vector3.FORWARD).normalized()
	var side := (rig.global_basis * Vector3.RIGHT).normalized()
	var scale := rig.global_basis.get_scale().x
	var speed := moved / maxf(delta, 0.0001)
	if speed >= 0.12 or aerial or preview_mode != 0:
		resting = false
	elif not resting and (still_time > float(settings.rest_capture_seconds) or previous_preview_mode != 0):
		# Keep the broad shape the animal actually settled into, including either
		# side. Rest is a held posture, not a recurring tip-motion animation.
		_capture_rest(root, true)
		resting = true
	previous_preview_mode = preview_mode
	_update_posture(delta, root, total_length * scale)
	var distance := 0.0
	var start := root
	var alpha := 1.0 - exp(-float(settings.follow_response) * delta)
	var chain: Array[Vector3] = [root]
	var floors: Array[float] = []
	for k in range(bones.size()):
		distance += lengths[k] * scale
		var fraction := distance / (total_length * scale)
		var target := _trail_point(root, distance, behind)
		if resting and rest_offsets.size() == points.size():
			target = root + rig.global_basis * rest_offsets[k]
		if recovery_weight > 0.001:
			var turn := deg_to_rad(float(settings.recovery_turn_degrees))
			var radius := total_length * scale / turn
			var relaxed := root + behind * sin(turn * fraction) * radius + side * recovery_side * (1.0 - cos(turn * fraction)) * radius
			target = target.lerp(relaxed, recovery_weight)
		if preview_weight > 0.001:
			var total_turn := deg_to_rad(float(settings.preview_curl_degrees)) * absf(curl_amount)
			var preview := root + behind * distance
			if total_turn > 0.01:
				var turn := total_turn * fraction
				var radius := total_length * scale / total_turn
				preview = root + behind * sin(turn) * radius + side * signf(curl_amount) * (1.0 - cos(turn)) * radius
			target = target.lerp(preview, preview_weight)
		var ground := _floor_height(target)
		floors.append(ground)
		var ground_height := lerpf(root.y, ground + float(settings.clearance_m), smoothstep(0.0, 0.65, fraction))
		var aerial_height := target.y - 0.12 * fraction if flying else root.y - 0.25 * fraction
		target.y = lerpf(ground_height, aerial_height, air_blend)
		# Advect the attachment end with the root, leaving increasing distal lag.
		# Do not greedily aim each short vertebra at a fixed world point: that
		# creates an unstable zigzag when the body moves vertically during a jump.
		var previous: Vector3 = points[k] + root_shift * exp(-fraction * 3.0)
		chain.append(previous.lerp(target, alpha))
	var body_a := rig.to_global(rig.get_bone_global_pose(rig.find_bone("hips")).origin)
	var body_b := rig.to_global(rig.get_bone_global_pose(rig.find_bone("chest")).origin)
	var fallbacks_before: int = contacts.fallback_count
	contacts.solve(chain, floors, rig.global_transform, body_a, body_b)
	stalled_time = stalled_time + delta if contacts.fallback_count > fallbacks_before else maxf(0.0, stalled_time - delta * 2.0)
	start = root
	for k in range(bones.size()):
		var end: Vector3 = chain[k + 1]
		points[k] = end
		var index := bones[k]
		var rest := rig.get_bone_global_rest(index)
		var from := rest.basis.y.normalized()
		var to := (rig.global_basis.inverse() * (end - start)).normalized()
		# Match tangent AND dorsal frame, so uncoiling does not roll the spikes.
		var rotation := _frame(to) * _frame(from).inverse()
		var pose := Transform3D(rotation * rest.basis, rig.to_local(start))
		var parent := rig.get_bone_parent(index)
		var local := rig.get_bone_global_pose(parent).affine_inverse() * pose
		rig.set_bone_pose_position(index, local.origin)
		rig.set_bone_pose_rotation(index, local.basis.orthonormalized().get_rotation_quaternion())
		rig.set_bone_pose_scale(index, Vector3.ONE)
		start = end

	if resting and recovery_weight > 0.001:
		# Retain the recovered curve, so releasing muscle effort cannot summon
		# the old cramped pose again.
		_capture_rest(root, true)


func _update_posture(delta: float, root: Vector3, length: float) -> void:
	# A living tail maintains muscle tone even while following a tight turn.
	# Chord compression detects a broad wrap; accumulated bend catches S-crinkles.
	var reach := root.distance_to(points.back()) / maxf(length, 0.001)
	var bend := 0.0
	var previous_direction := (points[0] - root).normalized()
	for i in range(1, points.size()):
		var direction := (points[i] - points[i - 1]).normalized()
		bend += previous_direction.angle_to(direction)
		previous_direction = direction
	var stressed := reach < 0.36 or bend > deg_to_rad(float(settings.tangle_turn_degrees)) or stalled_time > 0.4
	curl_stress_time = curl_stress_time + delta if stressed else maxf(0.0, curl_stress_time - delta)
	var recovering := curl_stress_time > 0.6 or (recovery_weight > 0.2 and reach < 0.6)
	if recovering and recovery_weight < 0.05:
		var lateral := (points[points.size() / 2] - root).dot(rig.global_basis.x.normalized())
		if absf(lateral) > 0.05:
			recovery_side = signf(lateral)
	var target := 0.95 if recovering and preview_mode == 0 else 0.0
	recovery_weight = move_toward(recovery_weight, target, delta * (0.65 if recovering else 0.25))


func _capture_rest(root: Vector3, refresh_trail: bool = false) -> void:
	rest_offsets.clear()
	var inverse := rig.global_basis.inverse()
	for point in points:
		rest_offsets.append(inverse * (point - root))
	if refresh_trail:
		# Resume movement from the held tail shape, not a stale coiled path.
		history.assign([root])
		history.append_array(points)


func _frame(direction: Vector3) -> Basis:
	var x := direction.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, direction, x.cross(direction).normalized()).orthonormalized()


func _trail_point(root: Vector3, distance: float, behind: Vector3) -> Vector3:
	# A lone sample plus tiny settling motion has no meaningful trail heading.
	# Extending that numerical direction over the whole tail creates a false curl.
	if history.size() == 1 and Vector2(root.x - history[0].x, root.z - history[0].z).length() < float(settings.history_spacing_m):
		return root + behind * distance
	var cursor := root
	var remaining := distance
	var previous_direction := behind
	for sample in history:
		# Gravity, breathing and gait bob are not travel along the trail.
		if body.locomotion_state != &"flying":
			sample.y = root.y
			cursor.y = root.y
		var length := cursor.distance_to(sample)
		if length > 0.0001:
			previous_direction = (sample - cursor).normalized()
			if remaining <= length:
				return cursor.lerp(sample, remaining / length)
			remaining -= length
		cursor = sample
	return cursor + previous_direction * remaining


func _floor_height(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 4.0, point + Vector3.DOWN * 12.0, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return float(hit.position.y)
	return body.global_position.y - 1000.0 if body.locomotion_state == &"flying" else body.global_position.y
