extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _run() -> void:
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	var visual: Node3D = scene.get_node("Clay/Visual")
	var motion: Node = visual.motion
	motion.enabled = false
	var vertices := 0
	var maximum_rest_error := 0.0
	var categories: Dictionary = {}
	for mesh in motion.meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			_check(material is ShaderMaterial, "Packed Clay did not receive its procedural shader")
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			_check(arrays[Mesh.ARRAY_CUSTOM0] != null and arrays[Mesh.ARRAY_CUSTOM1] != null, "Importer dropped design/rest coordinates")
			if arrays[Mesh.ARRAY_CUSTOM0] == null: continue
			var design: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
			var rest: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			_check(design.size() == points.size() * 4 and rest.size() == points.size() * 4, "Custom channels lost float precision or dimensions")
			vertices += points.size()
			for i in range(points.size()):
				categories[roundi(floor(design[i*4]))] = true
				var stable := Vector3(rest[i*4], rest[i*4+1], rest[i*4+2])
				maximum_rest_error = maxf(maximum_rest_error, stable.distance_to(points[i]))
			_check(material.get_shader_parameter("limbStart").size() == 6, "Anatomical limb pattern frames missing")
			var original_hash := hash(design)
			for fold in [0.0,0.5,1.0]:
				motion.fold_amount = fold
				motion.apply_wings()
				motion.blink.apply_amount(0.5)
			_check(hash(mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_CUSTOM0]) == original_hash, "Animation changed the material coordinates")
			preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, true)
			_check(mesh.get_active_material(surface).get_shader_parameter("clay_mode"), "Plain-clay inspection failed")
			preload("res://scripts/clay_materials.gd").set_plain_clay(mesh, false)
			_check(not mesh.get_active_material(surface).get_shader_parameter("clay_mode"), "Paint restoration failed")
	_check(vertices > 500000, "Clay mesh did not load fully")
	_check(maximum_rest_error < 0.001, "Source position data disagrees with imported geometry")
	for category in [1,2,6,13,20,23,24,25]:
		_check(categories.has(category), "Material region missing: %d" % category)
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: %d imported vertices retain full-float material/rest channels; max rest error %.7f; anatomical frames, animation coexistence and clay toggle" % [vertices, maximum_rest_error])
	quit(0 if failures.is_empty() else 1)
