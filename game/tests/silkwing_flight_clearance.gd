extends "res://tests/blue_game_pass.gd"
## Export the actual shared flight solver's skinned membrane poses for triangle
## intersection checks. Static spread and folded silhouettes alone miss clipping.
func run() -> void:
	var fixture:=Node3D.new()
	root.add_child(fixture)
	moon=preload("res://scripts/protagonist_factory.gd").make_actor("blue")
	fixture.add_child(moon)
	await ticks(2)
	moon.set_physics_process(false)
	moon.locomotion_state=&"flying"
	moon.ground_distance=10.
	var motion=moon.visual.motion
	motion.enabled=false
	var rig:Skeleton3D=motion.skeleton
	var parts:Array[Node]=rig.find_children("SilkWingMembrane*","MeshInstance3D",true,false)+rig.find_children("Moon continuous axillary membrane*","MeshInstance3D",true,false)
	var meshes:Array[Node]=[]
	var topology:Array=[]
	for part:MeshInstance3D in parts:
		var arrays:Array=part.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var centroid:=Vector3.ZERO
		for v in vertices:centroid+=v
		if centroid.x<=0:continue
		meshes.append(part)
		topology.append({"name":str(part.name),"bank":"hind" if "hind" in part.name else "fore","indices":Array(arrays[Mesh.ARRAY_INDEX])})
	var poses:Array=[]
	for launch in [false,true]:
		for phase in [0.,.125,.25,.375,.5,.625,.75,.875]:
			motion.reset_motion()
			motion.fold_amount=0.
			motion.apply_wings()
			moon.state_time=0. if launch else 3.
			motion.flight.was_flying=true
			motion.flight.phase=phase
			motion.flight.flap_blend=1.
			motion.flight.update(0.)
			motion.flight.apply_stroke(1.,motion.gait)
			var surfaces:Array=[]
			for part in meshes:
				var points:Array=[]
				for p in posed_vertices([part],rig):points.append([p.x,p.y,p.z])
				surfaces.append(points)
			poses.append({"phase":phase,"launch":launch,"surfaces":surfaces})
	var file=FileAccess.open("res://../cache/silkwing-flight-clearance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"topology":topology,"poses":poses}))
	print("Exported 16 actual SilkWing flight poses for intersection checks")
	quit()
