extends RefCounted
## Adjacent absolute lid samples keep the lid sliding over the globe.
var meshes: Array[MeshInstance3D] = []
var shapes: Array[Dictionary] = []
var settings: Dictionary
var rng := RandomNumberGenerator.new()
var amount := 0.0
var remaining := 0.0
var elapsed := -1.0
var paired := false
var duration_scale := 1.0

func setup(instances: Array[MeshInstance3D], config: Dictionary) -> void:
	settings = config
	rng.randomize()
	for mesh in instances:
		var indices: Dictionary = {}
		for index in range(mesh.mesh.get_blend_shape_count()):
			var name: String = String(mesh.mesh.get_blend_shape_name(index)).to_lower()
			if name.begins_with("blink") and name.trim_prefix("blink").is_valid_int():
				indices[int(name.trim_prefix("blink"))] = index
		if not indices.is_empty():
			meshes.append(mesh)
			shapes.append(indices)
	reset()

func reset() -> void:
	elapsed = -1.0
	paired = false
	duration_scale = 1.0
	remaining = rng.randf_range(settings.first_interval[0], settings.first_interval[1])
	apply_amount(0.0)

func update(delta: float) -> void:
	if elapsed < 0.0:
		remaining -= delta
		if remaining > 0.0:
			return
		elapsed = -remaining
		# Sample once per blink so the lids stay smooth throughout the motion.
		var variation: Array = settings.get("duration_scale", [0.85, 1.15])
		duration_scale = rng.randf_range(variation[0], variation[1])
	else:
		elapsed += delta
	var close_time: float = settings.close_seconds * duration_scale
	var hold_end: float = close_time + settings.hold_seconds * duration_scale
	var duration: float = hold_end + settings.open_seconds * duration_scale
	if elapsed < close_time:
		apply_amount(smoothstep(0.0, close_time, elapsed))
	elif elapsed < hold_end:
		apply_amount(1.0)
	elif elapsed < duration:
		apply_amount(1.0 - smoothstep(hold_end, duration, elapsed))
	else:
		apply_amount(0.0)
		elapsed = -1.0
		if not paired and rng.randf() < settings.double_probability:
			paired = true
			remaining = rng.randf_range(settings.double_interval[0], settings.double_interval[1])
		else:
			paired = false
			remaining = rng.randf_range(settings.interval[0], settings.interval[1])

func apply_amount(value: float) -> void:
	amount = clampf(value, 0.0, 1.0)
	for i in range(meshes.size()):
		var sample := amount * shapes[i].size()
		for step in shapes[i]:
			meshes[i].set_blend_shape_value(shapes[i][step], maxf(0.0, 1.0 - absf(sample - step)))
