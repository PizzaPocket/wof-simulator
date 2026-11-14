extends RefCounted
## Canonical anatomy contract used by Clay's movement solvers on other tribes.
## Geometry supplies joints and bone roles; the movement algorithms stay shared.
static func adapt(raw: Dictionary, scale: float) -> Dictionary:
	var out := raw.duplicate(true)
	var front: Array = raw.front
	var hind: Array = raw.hind
	out.front_joints = {"shoulder": front[0], "elbow": front[1], "wrist": front[2], "knuckles": front[3]}
	out.hind_joints = {"hip": hind[0], "knee": hind[1], "heel": hind[2], "ball": hind[3]}
	out.neck_bones = []
	out.tail_bones = []
	for name in raw.bones:
		var bone: Dictionary = raw.bones[name]
		var a := vector(bone.head)
		var b := vector(bone.tail)
		var segment := {"name": name, "head": bone.head, "end": bone.tail, "length": a.distance_to(b), "parent": bone.parent}
		if name.begins_with("neck"):
			out.neck_bones.append(segment)
		elif name.begins_with("tail"):
			var fraction := clampf((-a.z - 1.0) / 2.2, 0, 1)
			segment.radius = lerpf(0.19, 0.012, fraction)
			segment.ventral_radius = segment.radius
			out.tail_bones.append(segment)
	out.neck_bones.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	out.tail_bones.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	out.wing_stroke_bones = []
	out.wing_recovery_joints = []
	if raw.has("wing_rig"):
		for side in raw.wing_rig:
			var wing: Dictionary = raw.wing_rig[side]
			out.wing_stroke_bones.append({"bone": wing.root_bone, "side": wing.get("side",side), "share": 1.0})
	else:
		for side in ["L", "R"]:
			for bank in ["fore", "hind"]:
				var name: String = "wing_" + bank + "." + side
				if raw.bones.has(name):out.wing_stroke_bones.append({"bone": name, "side": side, "share": 1.0})
	var prototype: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clay_rig.json"))
	var front_ref: Dictionary = prototype.front_joints
	var hind_ref: Dictionary = prototype.hind_joints
	var front_ratio := (vector(front[0]).distance_to(vector(front[1]))+vector(front[1]).distance_to(vector(front[2]))) / (vector(front_ref.shoulder).distance_to(vector(front_ref.elbow))+vector(front_ref.elbow).distance_to(vector(front_ref.wrist)))
	var hind_ratio := (vector(hind[0]).distance_to(vector(hind[1]))+vector(hind[1]).distance_to(vector(hind[2]))) / (vector(hind_ref.hip).distance_to(vector(hind_ref.knee))+vector(hind_ref.knee).distance_to(vector(hind_ref.heel)))
	out.locomotion_scale = {"world": scale / 2.0 * minf(front_ratio,hind_ratio), "front_reach": front_ratio, "hind_reach": hind_ratio, "pad": maxf(0.015, float(front[3][1]) - float(raw.get("ground_plant_model", 0.01)))}
	return out

static func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
