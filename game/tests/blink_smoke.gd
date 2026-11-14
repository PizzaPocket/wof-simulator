extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
func _run() -> void:
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	var motion: Node = scene.get_node("Clay/Visual").motion
	motion.enabled = false
	var blink: RefCounted = motion.blink
	_check(not blink.meshes.is_empty(), "Export has no blink shapes")
	blink.rng.seed = 42
	blink.reset()
	var previous := 0.0
	var cycles := 0
	var intervals: Array[float] = []
	var durations: Array[float] = []
	var since := 0.0
	var was_active := false
	for frame in range(18000):
		blink.update(1.0 / 120.0)
		since += 1.0 / 120.0
		var active: bool = blink.elapsed >= 0.0
		if active and not was_active:
			cycles += 1
			intervals.append(since)
			durations.append(blink.duration_scale)
			_check(blink.duration_scale >= 0.85 and blink.duration_scale <= 1.15, "Blink speed outside configured range")
			since = 0.0
		# Smoothstep's peak slope is 1.5; use the fastest configured closure.
		var max_step: float = 1.5 / (120.0 * blink.settings.close_seconds * blink.settings.duration_scale[0])
		_check(absf(blink.amount - previous) <= max_step + 0.00001, "Blink snapped between frames")
		for i in range(blink.meshes.size()):
			var total := 0.0
			var nonzero := 0
			for step in blink.shapes[i]:
				var weight: float = blink.meshes[i].get_blend_shape_value(blink.shapes[i][step])
				total += weight
				nonzero += int(weight > 0.00001)
			_check(total <= 1.00001 and nonzero <= 2, "Lid in-betweens accumulated additively")
		previous = blink.amount
		was_active = active
	_check(cycles > 15 and cycles < 70, "Unexpected blink frequency")
	_check(intervals.max() - intervals.min() > 1.0, "Blink intervals repeat mechanically")
	_check(durations.max() - durations.min() > 0.1, "Blink speeds repeat mechanically")
	blink.apply_amount(1)
	motion.fold_amount = 0.4
	motion.apply_wings()
	for i in range(blink.meshes.size()):
		_check(is_equal_approx(blink.meshes[i].get_blend_shape_value(blink.shapes[i][6]), 1), "Wing sampling overwrote blink")
	motion.reset_motion()
	_check(blink.amount == 0, "Reset leaves eyes shut")
	# Exercise the actual pose pipeline without waiting for wall-clock timers.
	motion.enabled = true
	for state in [&"grounded", &"falling", &"flying"]:
		scene.get_node("Clay").locomotion_state = state
		blink.remaining = 0.0
		motion._physics_process(1.0 / 120.0)
		_check(blink.amount > 0.0, "Automatic blink did not run in %s state" % state)
		for frame in range(60):
			motion._physics_process(1.0 / 120.0)
		_check(blink.elapsed < 0.0 and blink.amount == 0.0, "Automatic blink did not reopen in %s state" % state)
		blink.reset()
	if failures.is_empty():
		print("PASS: %d varied blinks in 150 seconds; continuous absolute lid sampling; wing coexistence and reset" % cycles)
	else:
		for message in failures.slice(0, 8):
			push_error(message)
	quit(0 if failures.is_empty() else 1)
