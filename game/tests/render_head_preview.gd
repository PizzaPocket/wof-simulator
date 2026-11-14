extends SceneTree
var rig: Skeleton3D
var surfaces: Array[MeshInstance3D] = []
var camera: Camera3D
var output: String

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String, offset: Vector3, center: Vector3, size: float) -> void:
	camera.size = size
	camera.position = center + offset
	camera.look_at(center)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _mouth(angle: float) -> void:
	rig.reset_bone_pose(rig.find_bone("head"))
	var fire = preload("res://scripts/fire_breath.gd").new()
	fire.setup(rig, surfaces)
	fire.jaw_angle = angle
	fire._apply_mouth()
	fire.stream.queue_free()

func _run() -> void:
	output = ProjectSettings.globalize_path("res://../cache/head-lip-preview")
	DirAccess.make_dir_recursive_absolute(output)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error := doc.append_from_file(ProjectSettings.globalize_path("res://../cache/head-lip-preview.glb"),state)
	if error != OK:
		printerr("Cannot load head preview: ",error)
		quit(1)
		return
	var head := doc.generate_scene(state)
	root.add_child(head)
	for bone_rig in head.find_children("*","Skeleton3D",true,false): rig = bone_rig
	for mesh in head.find_children("*","MeshInstance3D",true,false):
		surfaces.append(mesh)
		for i in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(i,preload("res://scripts/clay_materials.gd").make_material(rig))
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("343b38")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.7
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_energy = 1.1
	root.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	root.add_child(camera)
	for angle in [0.0,0.45,0.9]:
		_mouth(angle)
		for clay in [false,true]:
			for mesh in surfaces: preload("res://scripts/clay_materials.gd").set_plain_clay(mesh,clay)
			var label := "%02d-%s" % [roundi(angle*100),"clay" if clay else "painted"]
			await _capture("side-"+label,Vector3(2,0,0),Vector3(0,1.62,1.66),0.9)
			await _capture("three-quarter-"+label,Vector3(1.5,0.1,1.5),Vector3(0,1.62,1.66),0.9)
			await _capture("front-"+label,Vector3(0,0,2),Vector3(0,1.62,1.66),0.9)
	quit()
