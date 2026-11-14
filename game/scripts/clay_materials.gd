extends RefCounted
## The source procedural material, using packed float design/rest channels.
const SURFACE = preload("res://shaders/clay.gdshader")

static func supported(mesh: MeshInstance3D, surface: int) -> bool:
	var format: int = mesh.mesh.surface_get_format(surface)
	return (format & Mesh.ARRAY_FORMAT_CUSTOM0) != 0 and (format & Mesh.ARRAY_FORMAT_CUSTOM1) != 0

static func make_material(rig: Skeleton3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	var anatomy: Dictionary = {}
	if FileAccess.file_exists("res://assets/clay_rig.json"):
		anatomy = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clay_rig.json"))
	var pattern: Dictionary = anatomy.get("skin_pattern", {})
	material.set_shader_parameter("neckScale", float(pattern.get("neck_scale", 2.0)))
	for entry in [["neckBlend", "neck_blend_s", [0.48, 0.75]], ["bodySpacing", "body_spacing", [0.065, 0.06]], ["limbSpacing", "limb_spacing", [0.07, 0.075]]]:
		var values: Array = pattern.get(entry[1], entry[2])
		material.set_shader_parameter(entry[0], Vector2(values[0], values[1]))
	var starts := PackedVector3Array()
	var ends := PackedVector3Array()
	var offsets := PackedFloat32Array()
	for names in [["upperarm.L", "forearm.L", "hand.L", "ftoe2.L"], ["thigh.L", "shin.L", "foot.L", "htoe2.L"]]:
		var offset := 0.0
		for i in range(3):
			var first: int = rig.find_bone(names[i]) if rig else -1
			var second: int = rig.find_bone(names[i + 1]) if rig else -1
			var start := rig.get_bone_global_rest(first).origin if first >= 0 else Vector3(1000, 0, 0)
			var end := rig.get_bone_global_rest(second).origin if second >= 0 else start + Vector3.UP
			if i == 2:
				end += (end - start) * 0.3
			starts.append(start)
			ends.append(end)
			offsets.append(offset)
			offset += start.distance_to(end)
	material.set_shader_parameter("limbStart", starts)
	material.set_shader_parameter("limbEnd", ends)
	material.set_shader_parameter("limbOffset", offsets)
	return material

static func set_plain_clay(mesh: MeshInstance3D, enabled: bool, tint := Color("beb4aa")) -> void:
	for index in range(mesh.mesh.get_surface_count()):
		var material: Material = mesh.get_active_material(index).duplicate()
		if material is ShaderMaterial:
			material.set_shader_parameter("clay_mode", enabled)
		elif material is StandardMaterial3D:
			material.vertex_color_use_as_albedo = not enabled
			material.albedo_color = tint if enabled else Color.WHITE
		mesh.set_surface_override_material(index, material)
