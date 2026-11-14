extends "res://scripts/creature_motion.gd"
## Shared Clay movement pipeline, with an anatomy adapter for other tribes.
var antenna_flow: RefCounted
var wing_rigs: Array[Dictionary] = []
var folds: Array[Dictionary] = []
var lobe_shapes:Array[Dictionary]=[]
var staged_eyelids: Array[Dictionary] = []

func setup(instance: Node3D, owner_body: CharacterBody3D, raw: Dictionary = {}) -> void:
	var canonical: Dictionary = preload("res://scripts/dragon_rig_profile.gd").adapt(raw, instance.scale.y)
	super.setup(instance, owner_body, canonical)
	for mesh in meshes:
		var fold_keys := [mesh.find_blend_shape_by_name("fold1"),mesh.find_blend_shape_by_name("fold2"),mesh.find_blend_shape_by_name("fold3")]
		if fold_keys[0] >= 0:folds.append({"mesh":mesh,"keys":fold_keys})
		var lobe_keys:=[mesh.find_blend_shape_by_name("LobePose1"),mesh.find_blend_shape_by_name("LobePose2"),mesh.find_blend_shape_by_name("LobePose3"),mesh.find_blend_shape_by_name("LobePose4")]
		if lobe_keys[0]>=0:lobe_shapes.append({"mesh":mesh,"keys":lobe_keys})
		var keys := [mesh.find_blend_shape_by_name("Blink1"),mesh.find_blend_shape_by_name("Blink2"),mesh.find_blend_shape_by_name("Blink3")]
		if keys[0] >= 0:staged_eyelids.append({"mesh":mesh,"keys":keys})
	for source in raw.get("wing_rig",{}).values():
		var wing: Dictionary = source.duplicate(true)
		wing.root_index = skeleton.find_bone(wing.root_bone)
		wing.elbow_index = skeleton.find_bone(wing.elbow_bone)
		for digit in wing.digits:
			digit.first_index = skeleton.find_bone(digit.first)
			digit.second_index = skeleton.find_bone(digit.second)
		wing_rigs.append(wing)
	if not raw.get("antenna_rig",[]).is_empty():
		antenna_flow=preload("res://scripts/antenna_motion.gd").new()
		antenna_flow.setup(skeleton,raw.antenna_rig)
	# The common flight solver samples a quarter of this rig's real fold, just
	# as it samples Clay's authored track. Recovery timing/limits stay shared.
	fold_amount=0.0
	apply_wings()
	var rest: Dictionary = {}
	for wing in wing_rigs:
		rest[wing.elbow_index]=skeleton.get_bone_pose_rotation(wing.elbow_index)
		for digit in wing.digits:
			for index in [digit.first_index,digit.second_index]:rest[index]=skeleton.get_bone_pose_rotation(index)
	fold_amount=.25
	apply_wings()
	for wing in wing_rigs:
		flight.add_recovery_sample(wing.elbow_index,rest[wing.elbow_index],skeleton.get_bone_pose_rotation(wing.elbow_index),0.0,14.0)
		for digit in wing.digits:
			for index in [digit.first_index,digit.second_index]:
				flight.add_recovery_sample(index,rest[index],skeleton.get_bone_pose_rotation(index),.10,5.0)
	fold_amount=1.0
	apply_wings()

func _aim(index: int, source: Vector3, target: Vector3) -> void:
	if source.length_squared() < 0.000001 or target.length_squared() < 0.000001: return
	var rotation := Basis(Quaternion(source.normalized(), target.normalized()))
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local := parent_basis.inverse() * rotation * skeleton.get_bone_global_pose(index).basis
	skeleton.set_bone_pose_rotation(index, local.orthonormalized().get_rotation_quaternion())


func apply_wings() -> void:
	if not skeleton:return
	for wing in wing_rigs:
		skeleton.reset_bone_pose(wing.root_index)
		skeleton.reset_bone_pose(wing.elbow_index)
		for digit in wing.digits:
			skeleton.reset_bone_pose(digit.first_index)
			skeleton.reset_bone_pose(digit.second_index)
	for rig in wing_rigs:
		var a := fold_amount * fold_amount * (3.0 - 2.0 * fold_amount)
		var root_index: int = rig.root_index
		var elbow_index: int = rig.elbow_index
		var root_pos := skeleton.get_bone_global_pose(root_index).origin
		var elbow_pos := skeleton.get_bone_global_pose(elbow_index).origin
		var first_digit: int = rig.digits[0].first_index
		var rest_upper := _vec(rig.elbow) - _vec(rig.root)
		var rest_fore := _vec(rig.wrist) - _vec(rig.elbow)
		var upper_direction := rest_upper.normalized().lerp(_vec(rig.fold_upper).normalized(), a).normalized()
		_aim(root_index, elbow_pos - root_pos, upper_direction * rest_upper.length())
		elbow_pos = skeleton.get_bone_global_pose(elbow_index).origin
		var wrist_pos := skeleton.get_bone_global_pose(first_digit).origin
		var fore_direction := rest_fore.normalized().lerp(_vec(rig.fold_fore).normalized(), a).normalized()
		_aim(elbow_index, wrist_pos - elbow_pos, fore_direction * rest_fore.length())
		if rig.get("rest_fan_mode","")=="preserve_open_lobe":
			# SilkWing rest: rotate the whole curved lobe into an upright plane.
			# Every support shares this frame, preserving its curve and fan width.
			var source_leading:=(_vec(rig.digits[0].tip)-_vec(rig.wrist)).normalized()
			var source_normal:=(Vector3.UP-source_leading*source_leading.dot(Vector3.UP)).normalized()
			var target_leading:=_vec(rig.rest_fan_leading).normalized()
			var normal_hint:=_vec(rig.rest_fan_normal)
			var target_normal:=(normal_hint-target_leading*target_leading.dot(normal_hint)).normalized()
			var source_frame:=Basis(source_leading,source_normal,source_leading.cross(source_normal))
			var target_frame:=Basis(target_leading,target_normal,target_leading.cross(target_normal))
			var rotation:=Basis(Quaternion.IDENTITY.slerp((target_frame*source_frame.inverse()).get_rotation_quaternion(),a))
			for digit in rig.digits:
				if digit.get("attachment","wrist")=="proximal":continue
				var index:int=digit.first_index
				var parent_basis:=skeleton.get_bone_global_pose(skeleton.get_bone_parent(index)).basis
				var desired:=rotation*skeleton.get_bone_global_rest(index).basis
				skeleton.set_bone_pose_rotation(index,(parent_basis.inverse()*desired).orthonormalized().get_rotation_quaternion())
			continue
		for digit in rig.digits:
			var first: int = digit.first_index
			var second: int = digit.second_index
			var origin := skeleton.get_bone_global_pose(first).origin
			var middle := skeleton.get_bone_global_pose(second).origin
			var rest_a := _vec(digit.middle) - _vec(rig.wrist)
			var rest_b := _vec(digit.tip) - _vec(digit.middle)
			var direction_a := rest_a.normalized().lerp(_vec(digit.fold).normalized(), a).normalized()
			_aim(first, middle - origin, direction_a * rest_a.length())
			middle = skeleton.get_bone_global_pose(second).origin
			var tip := skeleton.get_bone_global_pose(second) * (skeleton.get_bone_global_rest(second).affine_inverse() * _vec(digit.tip))
			var direction_b := rest_b.normalized().lerp(_vec(digit.get("fold_distal", [digit.fold[0], digit.fold[1] - 0.04, digit.fold[2]])).normalized(), a).normalized()
			_aim(second, tip - middle, direction_b * rest_b.length())
	for entry in lobe_shapes:
		for stage in range(4):entry.mesh.set_blend_shape_value(entry.keys[stage],maxf(0.,1.-absf(fold_amount*4.-float(stage+1))))
	for entry in folds:
		for sample in range(3):
			entry.mesh.set_blend_shape_value(entry.keys[sample], maxf(0,1.0-absf(fold_amount*3-(sample+1))))

func _vec(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


func _physics_process(delta:float) -> void:
	super._physics_process(delta)
	if enabled and antenna_flow:antenna_flow.update(delta,body)

func reset_motion() -> void:
	super.reset_motion()
	if antenna_flow:antenna_flow.reset()
