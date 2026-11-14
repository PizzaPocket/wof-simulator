extends SceneTree
## Actual rig stress: side curls, reversal, jumping with a curl, and flight turns.
var scene: Node3D
var player: CharacterBody3D
var motion: Node
var failures: Array[String] = []
var self_clearance: float = 1000.0
var body_clearance: float = 1000.0
var maximum_bend: float = 0.0
var maximum_length_error: float = 0.0
var frames: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	scene = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	if not motion:
		quit(1)
		return
	await _ticks(120)
	_check(motion.tail.bones.size() == 36, "Game export retains all measured caudal joints")
	_check(motion.anatomy.tail_envelope.vertices > 1000, "Collision envelopes were checked against exported skin and armor")
	var tail_root: Vector3 = motion.tail._root_world()
	var tip: Vector3 = motion.tail.points.back()
	_check(tip.distance_to(tail_root) > motion.tail.total_length * 2.0 * 0.5, "Resting tail has a comfortable open shape rather than a cramped knot")
	motion.tail.preview_mode = 1
	await _ticks(240)
	var left_tip: Vector3 = motion.skeleton.to_local(motion.tail.points.back())
	_check(left_tip.x > 0.4, "Tail can curl around the left side")
	motion.tail.preview_mode = 2
	await _ticks(360)
	var right_tip: Vector3 = motion.skeleton.to_local(motion.tail.points.back())
	_check(right_tip.x < -0.4, "Tail can reverse into a right-side curl")
	await _jump()
	await _ticks(100)
	_check(player.is_on_floor(), "A curled-tail jump returns to the ground")
	motion.tail.preview_mode = 0
	await _ticks(160)
	for direction in ["move_forward", "move_right", "move_back", "move_left"]:
		Input.action_press(direction)
		await _ticks(55)
		Input.action_release(direction)
	await _ticks(60)
	await _jump()
	await _ticks(20)
	await _jump()
	player.pivot.rotation.x = 0.25
	await _ticks(130)
	_check(player.locomotion_state == &"flying", "Flight activates for limb-carriage inspection")
	var front_carried := false
	var hind_carried := false
	for leg in motion.gait.legs:
		var foot: int = leg.indices[2]
		var deformation: Transform3D = motion.skeleton.get_bone_global_pose(foot) * motion.skeleton.get_bone_global_rest(foot).affine_inverse()
		var actual: Vector3 = deformation * (leg.end as Vector3)
		if leg.kind == "front":
			front_carried = front_carried or actual.y < motion.skeleton.get_bone_global_pose(foot).origin.y - 0.08
			_check(float(leg.pitch) > deg_to_rad(40.0) and float(leg.pitch) < deg_to_rad(80.0), "Flying hands hang with moderate wrist flexion")
		else:
			hind_carried = hind_carried or actual.y < motion.skeleton.get_bone_global_pose(foot).origin.y - 0.08
			var ankle: Vector3 = motion.skeleton.get_bone_global_pose(foot).origin
			var knee: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[1]).origin
			var flexion := acos(clampf((ankle - knee).normalized().dot((actual - ankle).normalized()), -1, 1))
			_check(flexion >= deg_to_rad(34.8) and flexion <= deg_to_rad(95.2), "Flying hocks retain bend between the actual shank and metatarsal")
		var a: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[0]).origin
		var b: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[1]).origin
		var c: Vector3 = motion.skeleton.get_bone_global_pose(leg.indices[2]).origin
		_check(absf(a.distance_to(b) - float(leg.length_a)) < 0.0001 and absf(b.distance_to(c) - float(leg.length_b)) < 0.0001, "Flight carriage preserves anatomical limb lengths")
	_check(front_carried and hind_carried, "Both forelimbs and hindlimbs have relaxed unsupported hanging feet")
	motion.tail.preview_mode = 1
	await _ticks(90)
	motion.tail.preview_mode = 2
	await _ticks(150)
	motion.tail.preview_mode = 0
	await _ticks(100)
	for target in [PI * 0.8, -PI * 0.8, 0.0]:
		player.pivot.rotation.y = target
		await _ticks(100)
	player.pivot.rotation.x = -0.20
	await _ticks(100)
	Input.action_press("cancel_flight")
	await _ticks(2)
	Input.action_release("cancel_flight")
	await _ticks(200)
	_check(self_clearance >= -0.0001, "No non-neighbor tail capsules penetrate through curls/jump/flight")
	_check(body_clearance >= -0.0001, "The free tail retains torso clearance")
	_check(maximum_bend < deg_to_rad(17.0), "No isolated tail hinge can form a sharp kink")
	_check(maximum_length_error < 0.001, "Contact corrections never stretch vertebra lengths")
	print("Tail stress: %d frames, self clearance %.4f m, torso clearance %.4f m, max bend %.2f deg, length error %.6f m, safe-shape carries %d" % [frames, self_clearance, body_clearance, rad_to_deg(maximum_bend), maximum_length_error, motion.tail.contacts.fallback_count])
	for failure in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: reference-led flight carriage and length-preserving, nonintersecting extended/side-curled/jumping/flying tail")
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _jump() -> void:
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		_measure()


func _measure() -> void:
	frames += 1
	var tail = motion.tail
	self_clearance = minf(self_clearance, tail.contacts.minimum_self_clearance)
	body_clearance = minf(body_clearance, tail.contacts.minimum_body_clearance)
	maximum_bend = maxf(maximum_bend, tail.contacts.maximum_bend)
	var start: Vector3 = tail._root_world()
	for i in range(tail.points.size()):
		var end: Vector3 = tail.points[i]
		maximum_length_error = maxf(maximum_length_error, absf(start.distance_to(end) - float(tail.lengths[i]) * 2.0))
		start = end


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
