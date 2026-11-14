extends RefCounted
## Contact-aware prepare/push, airborne recovery, and a buffered landing.
## Reuses the measured limb lengths and anatomical bend planes from the walk IK.

var rig: Skeleton3D
var body: CharacterBody3D
var model: Node3D
var gait: RefCounted
var settings: Dictionary
var anchors: Dictionary = {}
var last_state: StringName = &""
var air_feet: Dictionary = {}
var limb_carriage: RefCounted
var hip_pivot := Vector3.ZERO
var home_basis := Basis.IDENTITY


func setup(skeleton: Skeleton3D, character: CharacterBody3D, visual_model: Node3D, gait_solver: RefCounted, config: Dictionary) -> void:
	rig = skeleton
	body = character
	model = visual_model
	home_basis=model.basis.orthonormalized()
	gait = gait_solver
	settings = config
	limb_carriage = preload("res://scripts/flight_limbs.gd").new()
	limb_carriage.setup(skeleton, character, gait_solver)
	var count := 0
	for leg in gait.legs:
		if leg.kind == "hind":
			hip_pivot += model.to_local(rig.to_global(leg.root))
			count += 1
	if count > 0:
		hip_pivot /= count


func update(delta: float) -> void:
	var state: StringName = body.locomotion_state
	if state != last_state:
		_capture_contacts()
		if state == &"flying":
			limb_carriage.capture()
		last_state = state
	limb_carriage.begin_frame(delta)
	var home: Vector3 = gait.model_home
	var depth := 0.0
	var pitch := 0.0
	var roll := 0.0
	if state == &"preparing":
		var preparation: float = body.jump_settings.preparation_seconds
		if body.state_time < preparation:
			depth = smoothstep(0.0, preparation, body.state_time) * float(settings.crouch_depth_m)
		else:
			depth = (1.0 - smoothstep(preparation, preparation + float(settings.push_seconds), body.state_time)) * float(settings.crouch_depth_m)
		# Lift the chest around the hips while the hind paws finish pushing.
		pitch = -deg_to_rad(float(settings.takeoff_pitch_degrees)) * smoothstep(preparation, preparation + float(settings.push_seconds), body.state_time)
	elif state == &"landing":
		var t := clampf(body.state_time / body.landing_duration, 0, 1)
		var envelope := smoothstep(0.0, 0.28, t) * (1.0 - smoothstep(0.28, 1.0, t))
		depth = envelope * float(settings.landing_depth_m) * body.landing_strength
		pitch = deg_to_rad(float(settings.landing_pitch_degrees)) * (1.0 - smoothstep(0.0, 1.0, t))
	elif state == &"flying":
		pitch = -body.flight_body_pitch
		roll = body.flight_bank
	else:
		# Nose-up departure, level at the apex, then forequarters down to land.
		var ascent := clampf(body.velocity.y / body.jump_speed, 0.0, 1.0)
		var descent := clampf(-body.velocity.y / body.jump_speed, 0.0, 1.0)
		pitch = -deg_to_rad(float(settings.takeoff_pitch_degrees)) * ascent + deg_to_rad(float(settings.landing_pitch_degrees)) * descent
	var pose_rate := 40.0 if state == &"preparing" else float(settings.pose_response)
	var response := 1.0 - exp(-pose_rate * delta)
	model.rotation.x = lerp_angle(model.rotation.x, pitch, response)
	model.rotation.z = lerp_angle(model.rotation.z, roll, response)
	var position_target := home - Vector3.UP * depth
	if state != &"flying":
		# Keep the hip pivot steady instead of rotating around the floor origin.
		var pivot := hip_pivot * model.scale
		position_target += home_basis*pivot - Basis.from_euler(model.rotation) * pivot
	model.position = model.position.lerp(position_target, response)
	for leg in gait.legs:
		if state == &"flying":
			limb_carriage.pose_leg(leg, delta)
			continue
		var target: Vector3
		var distal := 0.0
		var released := state == &"airborne"
		if state == &"preparing" or state == &"landing":
			var contact: Dictionary = anchors[leg.name]
			var settle := smoothstep(0.0, minf(0.10, float(settings.preparation_seconds) + float(settings.push_seconds)), body.state_time)
			target = (contact.start as Vector3).lerp(contact.ground, settle)
			if state == &"preparing":
				var push_start: float = settings.preparation_seconds
				var speed := Vector2(body.velocity.x, body.velocity.z).length()
				if speed > 1.0:
					# Gather the paws under a moving body, then plant for the final
					# push. Holding the old gallop contact for the whole windup
					# drags it several metres behind a running jump.
					var plant_time := 0.015 if leg.kind == "front" else push_start + float(settings.push_seconds) - 0.04
					var support_seconds := float(settings.fore_release_seconds) - plant_time if leg.kind == "front" else 0.04
					var velocity := Vector3(body.velocity.x, 0.0, body.velocity.z)
					var plant: Vector3 = gait._ground(rig.to_global(leg.end) + velocity * support_seconds * 0.5)
					if body.state_time < plant_time:
						var carried: Vector3 = contact.start + body.global_position - contact.body_position
						var gather := smoothstep(0.0, plant_time, body.state_time)
						target = carried.lerp(plant, gather)
						target.y += sin(PI * gather) * 0.12
						released = true
					else:
						if not contact.planted:
							contact.ground = plant
							contact.planted = true
						target = contact.ground
				distal = deg_to_rad(15.0 if leg.kind == "hind" else 8.0) * smoothstep(push_start, push_start + float(settings.push_seconds), body.state_time)
				if leg.kind == "front":
					var release: float = settings.fore_release_seconds
					var lift := smoothstep(release, push_start + float(settings.push_seconds), body.state_time)
					var folded: Vector3 = leg.end + Vector3(0.0, float(settings.front_tuck_model), 0.08)
					target = target.lerp(rig.to_global(folded), lift)
					released = released or body.state_time > release
			elif leg.kind == "hind":
				target.y += 0.10 * (1.0 - smoothstep(0.0, 0.08, body.state_time))
		else:
			var tuck: float = settings.front_tuck_model if leg.kind == "front" else settings.hind_tuck_model
			var delay: float = settings.hind_recovery_delay_seconds if leg.kind == "hind" else 0.0
			var blend := smoothstep(delay, delay + 0.22, body.air_time)
			if body.velocity.y < 0:
				# Forepaws reach down first; hind legs follow later in descent.
				var reach_height := float(settings.anticipate_landing_height_m) * (1.0 if leg.kind == "front" else 0.65)
				blend *= smoothstep(0.25, reach_height, body.ground_distance)
			var home_foot: Vector3 = leg.end
			home_foot += Vector3(0, tuck * blend, (0.08 if leg.kind == "front" else 0.12) * blend)
			var previous: Vector3 = air_feet.get(leg.name, home_foot)
			air_feet[leg.name] = previous.lerp(home_foot, response)
			target = rig.to_global(air_feet[leg.name])
			distal = deg_to_rad(-16.0 if leg.kind == "front" else -11.0) * blend
		leg.swing = released
		leg.pitch = lerp_angle(float(leg.get("pitch", 0.0)), distal, response)
		leg.toe_curl = lerpf(float(leg.get("toe_curl", 0.0)), deg_to_rad(6.0) if leg.swing else 0.0, response)
		leg.forearm_twist = lerpf(float(leg.get("forearm_twist", 0.0)), 0.0, response)
		if state == &"airborne" and body.velocity.y < 0.0:
			# The pitched forequarters may reach the ground before the capsule.
			# Keep the reaching paws above terrain during that final approach.
			var ground: Vector3 = gait._ground(target)
			target.y = maxf(target.y, ground.y)
		gait._solve_leg(leg, target, float(leg.pitch))


func _capture_contacts() -> void:
	anchors.clear()
	for leg in gait.legs:
		var foot: int = leg.indices[2]
		var deformation := rig.get_bone_global_pose(foot) * rig.get_bone_global_rest(foot).affine_inverse()
		var current: Vector3 = leg.get("last_target", rig.to_global(deformation * (leg.end as Vector3)))
		anchors[leg.name] = {"start": current, "ground": gait._ground(current), "body_position": body.global_position, "planted": false}
		air_feet[leg.name] = rig.to_local(current)


func reset() -> void:
	last_state = &""
	anchors.clear()
	air_feet.clear()
