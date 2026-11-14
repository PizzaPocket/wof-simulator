extends SceneTree
## Render the current in-game Clay, never a separate illustration or stale head asset.
func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 1024)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var model := (load("res://assets/clay.glb") as PackedScene).instantiate()
	viewport.add_child(model)
	# The source is one skinned mesh. Retain only head/upper-neck triangles,
	# using skin weights so wings cannot appear behind the portrait.
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var portrait := ArrayMesh.new()
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			var stride: int = bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for triangle in range(0, indices.size(), 3):
				var include := true
				for corner in 3:
					var vertex := indices[triangle + corner]
					var head_weight := 0.0
					for influence in stride:
						var bind := bones[vertex * stride + influence]
						var name := mesh.skin.get_bind_name(bind)
						if name == &"":
							name = skeleton.get_bone_name(mesh.skin.get_bind_bone(bind))
						if name == &"head" or String(name).begins_with("jaw") or String(name).begins_with("oral"):
							head_weight += weights[vertex * stride + influence]
					if head_weight < 0.6:
						include = false
				if include:
					kept.append_array(indices.slice(triangle, triangle + 3))
			if not kept.is_empty():
				arrays[Mesh.ARRAY_INDEX] = kept
				portrait.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mesh.mesh.surface_get_format(surface))
				portrait.surface_set_material(portrait.get_surface_count() - 1, mesh.mesh.surface_get_material(surface))
		mesh.mesh = portrait
	var visual := preload("res://scripts/clay_visual.gd").new()
	visual._prepare_materials(model)
	visual.free()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("fff0d6")
	world.environment.ambient_light_energy = 0.75
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.3
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.32
	viewport.add_child(camera)
	var rig: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var center := rig.to_global(Vector3(0, 1.67, 1.65))
	camera.position = center + rig.global_basis * Vector3(1.5, 0.25, 1.5)
	camera.look_at(center)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	# A launcher portrait should emphasize the face, not reserve space for horn
	# tips. Fill the square edge to edge; allow a small crop at the horn/chin tips.
	var image := viewport.get_texture().get_image()
	var bounds := image.get_used_rect()
	if not bounds.has_area():
		printerr("Clay icon render is empty")
		quit(1)
		return
	var offset := Vector2(bounds.get_center()) - Vector2(viewport.size) * 0.5
	camera.position += camera.global_basis.x * offset.x * camera.size / viewport.size.x
	camera.position -= camera.global_basis.y * offset.y * camera.size / viewport.size.y
	camera.size *= float(maxi(bounds.size.x, bounds.size.y)) / (viewport.size.y * 1.10)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://assets/branding/clay-icon.png")
	var error := viewport.get_texture().get_image().save_png(path)
	print("Icon rendered: ", path)
	quit(0 if error == OK else 1)
