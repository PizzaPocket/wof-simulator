extends "res://tests/moon_game_pass.gd"
## Tests the future asset in isolation; never adds him to the village roster.
func run() -> void:
	var raw_model := (load("res://assets/dragons/darkstalker.glb") as PackedScene).instantiate()
	root.add_child(raw_model)
	for part: MeshInstance3D in raw_model.find_children("*", "MeshInstance3D", true, false):
		for index in part.mesh.get_blend_shape_count():
			check(absf(part.get_blend_shape_value(index)) < .0001, "Exported face starts neutral before animation initialization")
	raw_model.queue_free()
	var fixture := Node3D.new()
	root.add_child(fixture)
	var actor := preload("res://scripts/protagonist_factory.gd").make_actor("darkstalker")
	fixture.add_child(actor)
	await ticks(4)
	actor.set_physics_process(false)
	var motion = actor.visual.motion
	motion.enabled = false
	var rig: Skeleton3D = motion.skeleton
	var anatomy: Dictionary = motion.anatomy
	check(anatomy.ventral_fit.min_signed_clearance_model > -.0005, "Clipped belly plates stay outside the actual host triangles")
	check(not actor.playable, "Darkstalker remains a future model")
	check(actor.visual.model_scale > 6.0 * 1.65, "Ancient scale is far larger than Moon, not three times a juvenile")
	check(rig.get_bone_count() == 121 and motion.wing_rigs.size() == 2, "Complete corrected NightWing rig")
	check(motion.staged_eyelids.size() == 2, "Shared fitted staged eyelids")
	check(anatomy.face_fit.upper_teeth == 30 and anatomy.face_fit.lower_teeth == 29, "Seated complete upper and lower dental arcs")
	for eye in anatomy.face_fit.eyes:
		check(eye.closed_blink_uncovered_samples == 0, "Closed eyelids fully cover the globe")
	check(rig.find_children("Darkstalker left bone half hoop*", "MeshInstance3D", true, false).size() == 1, "One left-ear bone hoop")
	check(rig.find_children("Darkstalker fitted icy wing root scute*", "MeshInstance3D", true, false).size() == 24, "Pale scales fitted to both wing-root regions")
	check(absf(motion.model.position.y + anatomy.ground_plant_model * actor.visual.model_scale) < .015, "Measured ground offset")
	var membranes := rig.find_children("NightWingMembrane*", "MeshInstance3D", true, false)
	var webs := rig.find_children("Moon continuous axillary membrane*", "MeshInstance3D", true, false)
	check(rig.find_children("Moon arm patagium*", "MeshInstance3D", true, false).is_empty(), "No leading-side membrane triangle")
	var attachments: Array[Dictionary] = []
	var pairs: Array[Array] = []
	for wing in anatomy.wing_rig.values():
		var digit: Dictionary = wing.digits[-1]
		for step in [0, 9, 24, 36, 45]:
			var t := float(step) / 45.0
			var p := vec(wing.wrist).lerp(vec(digit.middle), t/.53) if t <= .53 else vec(digit.middle).lerp(vec(digit.tip), (t-.53)/.47)
			pairs.append([nearest_skin_vertex(membranes,p),nearest_skin_vertex(webs,p)])
		for step in [1,5,11,17,21]:
			var edge: Dictionary = wing.arm_attachment[step]
			attachments.append({"sample":nearest_skin_vertex(webs,vec(edge.point)),"edge":edge})
	for amount in [0.0,.25,.5,.75,1.0]:
		rig.reset_bone_poses()
		motion.fold_amount = amount
		motion.apply_wings()
		for attachment in attachments:
			var edge: Dictionary = attachment.edge
			check(skin_position(attachment.sample,rig).distance_to(skin_reference(vec(edge.point),edge.weights,rig))*actor.visual.model_scale<.001,"Trailing arm attachment stays fitted at ancient scale")
		for pair in pairs:
			check(skin_position(pair[0],rig).distance_to(skin_position(pair[1],rig)) * actor.visual.model_scale < .001, "Membrane attachments stay sealed at ancient world scale, fold %.2f" % amount)
		for wing in anatomy.wing_rig.values():
			var a := rig.get_bone_global_pose(rig.find_bone(wing.root_bone)).origin
			var b := rig.get_bone_global_pose(rig.find_bone(wing.elbow_bone)).origin
			check(absf(a.distance_to(b)-vec(wing.root).distance_to(vec(wing.elbow))) < .001, "Wing humerus preserves length")
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonists.json"))
	check(profiles.darkstalker.gameplay == false, "Future asset has no gameplay entitlement")
	fixture.queue_free()
	await process_frame
	print("Darkstalker anatomy and attachments: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
