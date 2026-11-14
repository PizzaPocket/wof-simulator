extends "res://scripts/player.gd"
## Autonomous villagers share Clay's physics/pose contract, never his input.
var playable := false
var home := Vector3.ZERO
var route: Array[Vector3] = []
var route_index := 0
var activity := "watching the reeds"
var talking := false
var listener: Node3D
var idle_time := 3.0
var age := 0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var human: Node3D
var blocked_time := 0.0


func _ready() -> void:
	player_controlled = false
	rng.seed = hash(character_id)
	elapsed = rng.randf_range(0, 10)
	idle_time += rng.randf_range(0, 4)
	home = position
	spawn_position = home
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.5
	mud_load=.08 if is_human else .42
	mud_speed_limit=.55 if playable else .38
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.65 if playable and not is_human else 0.23
	capsule.height = 1.50 if is_human and playable else (1.8 if playable else (1.28 if age == 9 else 1.02))
	collider.shape = capsule
	collider.position.y = capsule.height * 0.5
	add_child(collider)
	if playable:
		_setup_locomotion()
		if visual.motion:
			visual.motion.player_controlled = false
	if character_id == "umber":
		_customize_umber()
	elif is_human and playable:
		human = visual.human
	elif is_human and not playable:
		human = preload("res://scripts/scavenger_visual.gd").new()
		human.character_id = character_id
		human.child_age = age
		visual.add_child(human)



func _physics_process(delta: float) -> void:
	if playable and (player_controlled or locomotion_state != &"grounded"):
		super._physics_process(delta)
		return
	_update_mud_contact(delta)
	var habitat:=get_parent()
	var seeking_dry: bool=is_human and habitat.has_method("is_dry_ground") and not habitat.is_dry_ground(global_position)
	if seeking_dry:idle_time=0
	elapsed += delta
	state_time += delta
	var moving := false
	var target_yaw := visual.rotation.y
	if talking and is_instance_valid(listener):
		var toward := listener.global_position - global_position
		if Vector2(toward.x, toward.z).length() > 0.1:
			target_yaw = atan2(-toward.x, -toward.z)
	elif idle_time > 0:
		idle_time -= delta
	else:
		var destination := route[route_index] if not route.is_empty() else home
		if seeking_dry or (is_human and habitat.has_method("is_dry_ground") and not habitat.is_dry_ground(destination)):
			destination=habitat.dry_refuge(global_position)
		var toward := destination - global_position
		toward.y = 0
		if toward.length() < 0.45 or blocked_time > 2.0:
			route_index = (route_index + 1) % maxi(1, route.size())
			idle_time = rng.randf_range(3.5, 8.0)
			blocked_time = 0
			var activities := ["watching the reeds", "looking around", "checking his pouch"] if character_id == "umber" else ["looking around", "watching a dragon"]
			activity = activities[rng.randi_range(0, activities.size() - 1)]
		else:
			moving = true
			activity = "wandering"
			target_yaw = atan2(-toward.x, -toward.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-delta * 2.5))
	var speed := 1.05 if not is_human else 0.65
	var forward := -visual.basis.z * speed if moving else Vector3.ZERO
	velocity.x = move_toward(velocity.x, forward.x, delta * 3)
	velocity.z = move_toward(velocity.z, forward.z, delta * 3)
	velocity.y -= gravity * delta
	_apply_mud_physics(delta)
	var before := position
	move_and_slide()
	if moving:
		blocked_time = blocked_time + delta if position.distance_to(before) < delta * speed * 0.2 else 0.0
	# A virtual gaze pivot feeds the same continuous cervical-chain solve as Clay.
	pivot.rotation.y = target_yaw if talking or moving else visual.rotation.y + sin(elapsed * 0.38) * 0.62
	pivot.rotation.x = -0.35 + sin(elapsed * 0.27) * 0.08
	if not talking and activity == "checking his pouch":
		pivot.rotation.y = visual.rotation.y + 0.45
		pivot.rotation.x = -0.62
	if human:
		human.animate(delta, Vector2(velocity.x, velocity.z).length(), activity, talking, listener)


func set_player_controlled(controlled: bool) -> void:
	super.set_player_controlled(controlled)
	mud_speed_limit = 2.4 if controlled else .55


func _customize_umber() -> void:
	if not visual.motion:
		return
	for mesh in visual.motion.meshes:
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if material is ShaderMaterial and visual.get_script() == preload("res://scripts/clay_visual.gd"):
				material.set_shader_parameter("umber_variant", true)
	# Attach the satchel to the chest bone so it follows breathing and walking.
	var rig: Skeleton3D = visual.motion.skeleton
	if not rig:
		return
	var bone := rig.find_bone("neck1")
	if bone < 0:
		bone = 0
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = rig.get_bone_name(bone)
	rig.add_child(attachment)
	var rest := rig.get_bone_global_rest(bone)
	var satchel := preload("res://scripts/scavenger_visual.gd").new()
	# Geometry lives in original model space, then follows the attachment's delta.
	var accessories := Node3D.new()
	attachment.add_child(accessories)
	accessories.transform = rest.affine_inverse()
	satchel.make_pouch(accessories)
	satchel.free()
