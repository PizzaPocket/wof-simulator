extends RefCounted
## R1 / right bumper opens the jaw before emitting a sustained flame jet.
## Visual recipe adapted from local eleblorb/scripts/suit_power_fx.gd and
## particle_fx.gd: one dense particle plume, additive heat ramp, mild turbulence.
var rig: Skeleton3D
var meshes: Array[MeshInstance3D]
var stream: GPUParticles3D
var glow: OmniLight3D
var jaw_angle: float = 0.0
var active: bool = false
var head: int
var nozzle: int
var aim: Dictionary
var base_head_rotation := Quaternion.IDENTITY
const GAPE := 0.9
const IGNITION_GAPE := 0.68


func setup(skeleton: Skeleton3D, surfaces: Array[MeshInstance3D]) -> void:
	rig = skeleton
	aim = JSON.parse_string(FileAccess.get_file_as_string("res://data/fire_breath.json"))
	meshes = surfaces
	head = rig.find_bone("head")
	if head >= 0:
		base_head_rotation = rig.get_bone_pose_rotation(head)
	nozzle = rig.find_bone("fire_origin")
	stream = _make_stream()
	rig.add_child(stream)
	stream.top_level = true
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.09)
	glow.omni_range = 5.0
	glow.light_energy = 0.0
	stream.add_child(glow)


func update(delta: float) -> void:
	var held := Input.is_action_pressed("fire_breath") and head >= 0 and nozzle >= 0
	jaw_angle = move_toward(jaw_angle, GAPE if held else 0.0, delta * (3.8 if held else 4.8))
	# Gaze is evaluated immediately before fire. Preserve its unlifted aim.
	base_head_rotation = rig.get_bone_pose_rotation(head) if head >= 0 else Quaternion.IDENTITY
	var aim_guide := rig.global_transform * rig.get_bone_global_pose(nozzle) if nozzle >= 0 else Transform3D.IDENTITY
	var aim_head_delta := rig.get_bone_global_pose(head) * rig.get_bone_global_rest(head).affine_inverse() if head >= 0 else Transform3D.IDENTITY
	_apply_mouth()
	active = held and jaw_angle >= IGNITION_GAPE
	stream.emitting = active
	if nozzle >= 0:
		var guide := rig.global_transform * rig.get_bone_global_pose(nozzle)
		var direction := aim_guide.basis.y.normalized()
		var rest_up: Array = aim.up_model
		var mouth_up := (rig.global_basis * aim_head_delta.basis * Vector3(rest_up[0], rest_up[1], rest_up[2])).normalized()
		direction = (direction - mouth_up * float(aim.normal_slope)).normalized()
		stream.global_position = guide.origin
		var up := guide.basis.z.normalized()
		if absf(up.dot(direction)) > 0.95:
			up = guide.basis.x.normalized()
		stream.look_at(stream.global_position + direction, up)
	glow.light_energy = (1.6 + 0.22 * sin(Time.get_ticks_msec() * 0.037)) if active else 0.0


func _apply_mouth() -> void:
	if head < 0:
		return
	rig.set_bone_pose_rotation(head, base_head_rotation)
	var skull := rig.get_bone_global_pose(head)
	var lift := deg_to_rad(float(aim.get("skull_lift_degrees", 5.0))) * smoothstep(0.0, GAPE, jaw_angle)
	var skull_right := (skull.basis * rig.get_bone_global_rest(head).basis.inverse() * Vector3.RIGHT).normalized()
	skull.basis = Basis(skull_right, -lift) * skull.basis
	var head_parent := rig.get_bone_parent(head)
	var skull_local := rig.get_bone_global_pose(head_parent).basis.inverse() * skull.basis if head_parent >= 0 else skull.basis
	rig.set_bone_pose_rotation(head, skull_local.orthonormalized().get_rotation_quaternion())
	# Apply in skeleton space after gaze. Each oral helper shares the hinge;
	# retain the original head-space joint origin through neck/head tracking.
	var head_delta := rig.get_bone_global_pose(head) * rig.get_bone_global_rest(head).affine_inverse()
	for item in [["jaw", 1.0], ["oral1", 1.0 / 3.0], ["oral2", 2.0 / 3.0]]:
		var index := rig.find_bone(item[0])
		if index < 0:
			continue
		var pose := rig.get_bone_global_rest(index)
		pose.basis = Basis(Vector3.RIGHT, jaw_angle * float(item[1])) * pose.basis
		pose = head_delta * pose
		var parent := rig.get_bone_parent(index)
		var local := rig.get_bone_global_pose(parent).affine_inverse() * pose
		rig.set_bone_pose_position(index, local.origin)
		rig.set_bone_pose_rotation(index, local.basis.orthonormalized().get_rotation_quaternion())
	for mesh in meshes:
		var index := mesh.find_blend_shape_by_name("jawOpen")
		if index >= 0:
			mesh.set_blend_shape_value(index, jaw_angle / 0.6)
		for sample in range(1, 4):
			var cheek := mesh.find_blend_shape_by_name("cheekOpen" + str(sample))
			if cheek >= 0:
				mesh.set_blend_shape_value(cheek, maxf(0.0, 1.0 - absf(jaw_angle / 0.3 - sample)))


func reset() -> void:
	jaw_angle = 0.0
	active = false
	stream.restart()
	stream.emitting = false
	glow.light_energy = 0.0
	_apply_mouth()


func _make_stream() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "FireBreath"
	particles.amount = 800
	particles.lifetime = 0.4
	particles.randomness = 0.12
	particles.emitting = false
	# Detached particles stay in the world when Clay turns or moves.
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.FORWARD
	process.spread = 4.5
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.045
	process.initial_velocity_min = 19.0
	process.initial_velocity_max = 23.0
	process.gravity = Vector3(0, 0.8, 0)
	process.scale_min = 0.75
	process.scale_max = 1.1
	process.particle_flag_align_y = true
	process.angle_min = -12
	process.angle_max = 12
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.0
	process.turbulence_noise_scale = 2.0
	process.turbulence_influence_min = 0.04
	process.turbulence_influence_max = 0.15
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(1, 0.95, 0.75, 0.55), Color(1, 0.55, 0.1, 0.65), Color(0.85, 0.25, 0.05, 0.5), Color(0.35, 0.06, 0.02, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.45))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.25))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = curve
	process.scale_curve = scale_texture
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _flame_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.6)
	quad.material = material
	particles.draw_pass_1 = quad
	return particles


func _flame_texture() -> ImageTexture:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in range(48):
		for x in range(48):
			var p := (Vector2(x, y) + Vector2.ONE * 0.5 - Vector2.ONE * 24.0) / 24.0
			var angle := p.angle()
			var radius := 1.0 + 0.2 * (sin(angle * 3) * 0.5 + sin(angle * 5 + 1.7) * 0.3)
			var alpha := pow(clampf(1.0 - p.length() / radius, 0, 1), 1.7)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)
