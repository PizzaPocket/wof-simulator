extends SceneTree
# Export imported bone matrices for comparison with the original glTF samplers.
func _initialize():run.call_deferred()
func matrix(t):
	return [t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
func run():
	var scene=load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	var motion=scene.get_node("Clay/Visual").motion
	motion.enabled=false
	var output={}
	for amount in [0.0,0.125,0.375,0.5,0.625,0.875,1.0]:
		motion.skeleton.reset_bone_poses()
		motion.fold_amount=amount
		motion.apply_wings()
		var bones={}
		for i in range(motion.skeleton.get_bone_count()):bones[motion.skeleton.get_bone_name(i)]=matrix(motion.skeleton.get_bone_global_pose(i))
		output[str(amount)]=bones
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join("../cache").simplify_path())
	var f=FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../cache/wing_poses.json").simplify_path(),FileAccess.WRITE)
	f.store_string(JSON.stringify(output))
	quit()
