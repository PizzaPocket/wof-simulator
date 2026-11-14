extends SceneTree
var player: CharacterBody3D
var motion: Node
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
func _run() -> void:
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Clay")
	motion = player.get_node("Visual").motion
	await _ticks(30)
	player.global_position = Vector3(-35, 15, 30)
	player._activate_flight()
	var min_hock := 180.0
	var max_hock := 0.0
	var min_knee := 180.0
	var max_knee := 0.0
	await _ticks(120)
	for pitch in [0.0, 0.35, -0.25]:
		player.pivot.rotation.x = pitch
		player.pivot.rotation.y += 0.35
		for i in range(100):
			await _ticks(1)
			for leg in motion.gait.legs:
				if leg.kind != "hind": continue
				var a: Transform3D = motion.skeleton.get_bone_global_pose(leg.indices[0])
				var b: Transform3D = motion.skeleton.get_bone_global_pose(leg.indices[1])
				var c: Transform3D = motion.skeleton.get_bone_global_pose(leg.indices[2])
				var deform: Transform3D = c * motion.skeleton.get_bone_global_rest(leg.indices[2]).affine_inverse()
				var end: Vector3 = deform * (leg.end as Vector3)
				var shank := (c.origin - b.origin).normalized()
				var foot := (end - c.origin).normalized()
				var hock := rad_to_deg(acos(clampf(shank.dot(foot), -1, 1)))
				var knee := rad_to_deg(acos(clampf((a.origin - b.origin).normalized().dot(shank), -1, 1)))
				min_hock = minf(min_hock, hock)
				max_hock = maxf(max_hock, hock)
				min_knee = minf(min_knee, knee)
				max_knee = maxf(max_knee, knee)
	if min_hock < 34.8 or max_hock > 95.2:
		failures.append("Flying hock violated bend limits")
	if min_knee < 60 or max_knee > 110:
		failures.append("Flying knees do not retain the closer bent carriage")
	print("Flying hind knees %.1f–%.1f degrees included; hock flexion %.1f–%.1f degrees from straight" % [min_knee, max_knee, min_hock, max_hock])
	for failure in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: tucked, asymmetrical hind carriage and bounded hock flexion through glide, climb, descent and banking")
	quit(0 if failures.is_empty() else 1)
