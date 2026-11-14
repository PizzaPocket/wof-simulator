extends Node3D
## Independent assets with distinct skulls, bodies, limb rigs and wings.
var model_scale := 1.0
var model_loaded := false
var motion: Node
var details: Node3D
var profile: Dictionary

func _ready() -> void:
	var id: String = get_parent().character_id
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonists.json"))
	profile = profiles[id]
	# Several characters can share one baked model (Starflight uses the NightWing build).
	var model_id: String = str(profile.get("model", id))
	var path := "res://assets/dragons/" + model_id + ".glb"
	var model := (load(path) as PackedScene).instantiate() as Node3D
	add_child(model)
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = PI
	model.position.y = 0.03
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var has_anatomical_colors: bool = mesh.mesh.get_surface_count() > 0 and (mesh.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
		if has_anatomical_colors and (mesh.name.begins_with("Connected anatomical skin") or mesh.name.begins_with("MoonSkin")):
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/tribe_skin.gdshader")
			if mesh.name.begins_with("MoonSkin"):
				material.set_shader_parameter("surface_specular", 0.15)
			if id=="blue":material.set_shader_parameter("iridescence_strength",0.42)
			mesh.material_override = material
		elif id=="blue" and (mesh.name.begins_with("SilkWingMembrane") or mesh.name.begins_with("Moon continuous axillary membrane")):
			var material:=ShaderMaterial.new()
			material.shader=preload("res://shaders/silkwing_membrane.gdshader")
			mesh.material_override=material
		else:
			for i in mesh.mesh.get_surface_count():
				var source = mesh.get_active_material(i)
				if source is StandardMaterial3D:
					var material: StandardMaterial3D = source.duplicate()
					if mesh.name.begins_with("Moon fitted nasal cap"):
						material.metallic_specular = 0.0
						material.roughness = 0.82
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
					material.vertex_color_use_as_albedo = mesh.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR != 0
					mesh.set_surface_override_material(i, material)
	if profile.get("eyes", "") == "blind":
		# Clouded, pupil-less eyes replace the seated pigmented globes.
		var milky := StandardMaterial3D.new()
		milky.albedo_color = Color("aab4ae")
		milky.roughness = 0.3
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.name.begins_with("Moon seated pigmented globe"):
				mesh.material_override = milky
	motion = preload("res://scripts/tribe_dragon_motion.gd").new()
	add_child(motion)
	var anatomy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dragons/" + model_id + "_anatomy.json"))
	if not anatomy.has("ground_plant_model"):
		var lowest := INF
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var bounds := part.get_aabb()
			for corner in range(8):
				lowest = minf(lowest, model.to_local(part.to_global(bounds.get_endpoint(corner))).y)
		anatomy.ground_plant_model = lowest if is_finite(lowest) else 0.0
	model.position.y = -float(anatomy.ground_plant_model) * model_scale + 0.004
	motion.setup(model, get_parent(), anatomy)
	model_loaded = true
