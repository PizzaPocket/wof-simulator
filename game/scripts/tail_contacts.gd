extends RefCounted
## Conservative swept capsules, excluding the continuous neighboring skin.
## Contacts use outer tail/armor radii exported from the measured design.
var lengths: Array[float] = []
var radii: Array[float] = []
var ventral: Array[float] = []
var pairs: Array[Vector2i] = []
var settings: Dictionary
var arcs: Array[float] = [0.0]
var minimum_self_clearance: float = 1000.0
var minimum_body_clearance: float = 1000.0
var fallback_count: int = 0
var safe_local: Array[Vector3] = []
var maximum_bend: float = 0.0


func setup(segments: Array, config: Dictionary) -> void:
	settings = config
	for segment in segments:
		lengths.append(float(segment.length))
		radii.append(float(segment.get("radius", 0.12)))
		ventral.append(float(segment.get("ventral_radius", 0.08)))
		arcs.append(arcs.back() + float(segment.length))
	for i in range(lengths.size()):
		for j in range(i + 2, lengths.size()):
			var distance := (arcs[j] + lengths[j] * 0.5) - (arcs[i] + lengths[i] * 0.5)
			# Nearby skin is one continuous tube, rather than two colliding objects.
			if distance > 2.0 * (radii[i] + radii[j]) + maxf(lengths[i], lengths[j]):
				pairs.append(Vector2i(i, j))


func solve(chain: Array[Vector3], floors: Array[float], transform: Transform3D, body_a: Vector3, body_b: Vector3) -> void:
	var desired := chain.duplicate()
	_constrain(chain, floors, transform, body_a, body_b)
	if not _admissible() and safe_local.size() == chain.size():
		# A long target step can cross a contact boundary even when a shorter
		# step is feasible. Backtrack from the safe shape before giving up.
		for step in [0.25, 0.08, 0.02]:
			for i in range(chain.size()):
				chain[i] = (transform * safe_local[i]).lerp(desired[i], step)
			chain[0] = desired[0]
			_constrain(chain, floors, transform, body_a, body_b)
			if _admissible():
				break
	if not _admissible() and safe_local.size() == chain.size():
		for i in range(chain.size()):
			chain[i] = transform * safe_local[i]
		fallback_count += 1
		measure(chain, transform.basis.get_scale().x, body_a, body_b)
	else:
		safe_local.clear()
		var inverse := transform.affine_inverse()
		for point in chain:
			safe_local.append(inverse * point)


func _admissible() -> bool:
	return minimum_self_clearance >= 0.0 and minimum_body_clearance >= 0.0 and maximum_bend <= deg_to_rad(float(settings.max_bend_degrees_per_bone)) + 0.01


func _constrain(chain: Array[Vector3], floors: Array[float], transform: Transform3D, body_a: Vector3, body_b: Vector3) -> void:
	var scale := transform.basis.get_scale().x
	var root := chain[0]
	var preferred := transform.basis.x.normalized()
	var behind := (-transform.basis.z).normalized()
	var margin := float(settings.self_collision_margin_m)
	var bend := deg_to_rad(float(settings.max_bend_degrees_per_bone))
	var body_radius := float(settings.body_radius_model) * scale
	# A little curvature regularization removes isolated hinge corners while
	# retaining the broad side curl. Exact lengths are restored afterwards.
	for pass_index in range(2):
		var copy := chain.duplicate()
		for i in range(1, chain.size() - 1):
			var fraction := lengths[i - 1] / (lengths[i - 1] + lengths[i])
			chain[i] = chain[i].lerp(copy[i - 1].lerp(copy[i + 1], fraction), 0.18)
	for iteration in range(int(settings.contact_iterations)):
		var corrected := false
		_project_lengths(chain, scale, root)
		var last := behind
		for i in range(lengths.size()):
			var direction := (chain[i + 1] - chain[i]).normalized()
			var angle := last.angle_to(direction)
			if angle > bend:
				corrected = true
				direction = last.slerp(direction, bend / angle).normalized()
				chain[i + 1] = chain[i] + direction * lengths[i] * scale
			last = direction
		for pair in pairs:
			var i := pair.x
			var j := pair.y
			var bound := (radii[i] + radii[j] + (lengths[i] + lengths[j]) * 0.5) * scale + margin
			var centers := (chain[i] + chain[i + 1] - chain[j] - chain[j + 1]) * 0.5
			if centers.length_squared() > bound * bound:
				continue
			var uv := closest_parameters(chain[i], chain[i + 1], chain[j], chain[j + 1])
			var delta := chain[i].lerp(chain[i + 1], uv.x) - chain[j].lerp(chain[j + 1], uv.y)
			var distance := delta.length()
			var penetration := (radii[i] + radii[j]) * scale + margin - distance
			if penetration <= 0.0:
				continue
			corrected = true
			var normal := delta / distance if distance > 0.00001 else preferred
			var a0 := 1.0 - uv.x if i > 0 else 0.0
			var a1 := uv.x
			var b0 := 1.0 - uv.y
			var b1 := uv.y
			var amount := penetration / maxf(0.001, a0 * a0 + a1 * a1 + b0 * b0 + b1 * b1)
			chain[i] += normal * amount * a0
			chain[i + 1] += normal * amount * a1
			chain[j] -= normal * amount * b0
			chain[j + 1] -= normal * amount * b1
		for i in range(1, chain.size()):
			corrected = corrected or chain[i].y < floors[i - 1] + ventral[i - 1] * scale + 0.015
			chain[i].y = maxf(chain[i].y, floors[i - 1] + ventral[i - 1] * scale + 0.015)
			if arcs[i] * scale < body_radius + radii[0] * scale + 0.10:
				continue
			var center := Geometry3D.get_closest_point_to_segment(chain[i], body_a, body_b)
			var offset := chain[i] - center
			var clearance := body_radius + radii[i - 1] * scale + margin
			if offset.length() < clearance:
				corrected = true
				chain[i] = center + (offset.normalized() if offset.length_squared() > 0.00001 else preferred) * clearance
		if iteration >= 2 and not corrected:
			break
	_project_exact(chain, scale, root, behind, bend)
	measure(chain, scale, body_a, body_b)


func _project_lengths(chain: Array[Vector3], scale: float, root: Vector3) -> void:
	chain[0] = root
	for i in range(lengths.size()):
		var delta := chain[i + 1] - chain[i]
		var distance := delta.length()
		if distance < 0.00001:
			continue
		var correction := delta * (distance - lengths[i] * scale) / distance
		if i == 0:
			chain[i + 1] -= correction
		else:
			chain[i] += correction * 0.5
			chain[i + 1] -= correction * 0.5


func _project_exact(chain: Array[Vector3], scale: float, root: Vector3, behind: Vector3, bend: float) -> void:
	chain[0] = root
	var previous_direction := behind
	for i in range(lengths.size()):
		var delta := chain[i + 1] - chain[i]
		var direction := delta.normalized() if delta.length_squared() > 0.000001 else previous_direction
		var angle := previous_direction.angle_to(direction)
		if angle > bend:
			direction = previous_direction.slerp(direction, bend / angle).normalized()
		chain[i + 1] = chain[i] + direction * lengths[i] * scale
		previous_direction = direction


func measure(chain: Array[Vector3], scale: float, body_a: Vector3, body_b: Vector3) -> void:
	minimum_self_clearance = 1000.0
	minimum_body_clearance = 1000.0
	maximum_bend = 0.0
	for i in range(1, lengths.size()):
		maximum_bend = maxf(maximum_bend, (chain[i] - chain[i - 1]).angle_to(chain[i + 1] - chain[i]))
	for pair in pairs:
		var i := pair.x
		var j := pair.y
		var uv := closest_parameters(chain[i], chain[i + 1], chain[j], chain[j + 1])
		var distance := chain[i].lerp(chain[i + 1], uv.x).distance_to(chain[j].lerp(chain[j + 1], uv.y))
		minimum_self_clearance = minf(minimum_self_clearance, distance - (radii[i] + radii[j]) * scale)
	var body_radius := float(settings.body_radius_model) * scale
	for i in range(lengths.size()):
		if arcs[i] * scale < body_radius + radii[0] * scale + 0.10:
			continue
		var uv := closest_parameters(chain[i], chain[i + 1], body_a, body_b)
		var distance := chain[i].lerp(chain[i + 1], uv.x).distance_to(body_a.lerp(body_b, uv.y))
		minimum_body_clearance = minf(minimum_body_clearance, distance - body_radius - radii[i] * scale)


static func closest_parameters(p: Vector3, q: Vector3, a: Vector3, b: Vector3) -> Vector2:
	var first := q - p
	var second := b - a
	var relative := p - a
	var aa := first.length_squared()
	var ee := second.length_squared()
	var ff := second.dot(relative)
	var s := 0.0
	var t := 0.0
	if aa <= 0.0000001:
		t = clampf(ff / maxf(ee, 0.0000001), 0, 1)
	else:
		var cc := first.dot(relative)
		if ee <= 0.0000001:
			s = clampf(-cc / aa, 0, 1)
		else:
			var bb := first.dot(second)
			var denominator := aa * ee - bb * bb
			if absf(denominator) > 0.0000001:
				s = clampf((bb * ff - cc * ee) / denominator, 0, 1)
			t = (bb * s + ff) / ee
			if t < 0:
				t = 0.0
				s = clampf(-cc / aa, 0, 1)
			elif t > 1:
				t = 1.0
				s = clampf((bb - cc) / aa, 0, 1)
	return Vector2(s, t)
