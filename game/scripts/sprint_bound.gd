extends RefCounted
## Authored heavy sprint: hands catch the chest, hindquarters drive, then flight.
## This profile owns its poses and recovery paths; the easy lope stays separate.
var settings: Dictionary

func setup(config: Dictionary) -> void:
	settings = config

func body_pose(cycle: float) -> Dictionary:
	var keys: Array = settings.body_keys
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if cycle <= float(b[0]):
			var t := smoothstep(float(a[0]), float(b[0]), cycle)
			return {
				"height": lerpf(float(a[1]), float(b[1]), t),
				"pitch": deg_to_rad(lerpf(float(a[2]), float(b[2]), t)),
				"surge": lerpf(float(a[3]), float(b[3]), t),
				"hips": deg_to_rad(lerpf(float(a[4]), float(b[4]), t)),
				"spine": deg_to_rad(lerpf(float(a[5]), float(b[5]), t)),
				"chest_drop": lerpf(float(a[6]), float(b[6]), t),
			}
	return body_pose(0.0)

func swing_pose(kind: String, t: float) -> Dictionary:
	var front := kind == "front"
	# Hands open forward during flight and hold the reach before the next catch.
	# Hind feet recover earlier under the belly in preparation for the push.
	var travel := smoothstep(0.12, 0.88, t) if front else smoothstep(0.0, 0.85, t)
	var tuck := smoothstep(0.0, 0.22 if front else 0.28, t)
	tuck *= 1.0 - smoothstep(0.50, 0.94 if front else 1.0, t)
	var height := float(settings.front_recovery_height_model if front else settings.hind_recovery_height_model)
	var pitch := float(settings.front_recovery_pitch_degrees if front else settings.hind_recovery_pitch_degrees)
	return {"travel": travel, "height": height * tuck, "pitch": deg_to_rad(pitch) * tuck, "curl": deg_to_rad(26.0) * tuck}
