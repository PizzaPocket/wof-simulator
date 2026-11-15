extends "res://scripts/playground.gd"
## Bare, explorable terrain. All geographic coordinates remain in metres.
const TerrainData = preload("res://scripts/continent_data.gd")
const Chunk = preload("res://scripts/terrain_chunk.gd")
const CHUNK_SIZE := 1024.0
const FAR_DETAIL := 16
const NEAR_DETAIL := 64
@export var continent_id := "pyrrhia"
var terrain_data := TerrainData.new()
var landscape: Node3D
var chunks: Dictionary = {}
var world_origin := Vector2.ZERO
var terrain_material: StandardMaterial3D
var water_material: StandardMaterial3D
var ocean_material: ShaderMaterial
var ready_to_explore := false
var destination_menu: OptionButton
var location_label: Label
var village_button: Button
var last_cell := Vector2i(999999, 999999)
var requested_cells: Array[Vector2i] = []
var shifting := false
var streamer: Node3D
var landing_waits := 0
var waiting_for_ground := false

func _ready() -> void:
	if not has_meta("startup_loader"): initialize_world()

func initialize_world(progress_callback: Callable = Callable()) -> void:
	if not terrain_data.open(continent_id):
		push_error("Missing or invalid terrain data: " + continent_id)
		get_tree().change_scene_to_file("res://scenes/overworld.tscn")
		return
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_make_environment()
	var environment: Environment = get_world_3d().environment
	environment.fog_enabled = true
	environment.fog_light_color = Color("b0cbd0")
	environment.fog_density = 0.000025
	landscape = Node3D.new()
	landscape.name = "Landscape"
	add_child(landscape)
	terrain_material = StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color("347f92")
	water_material.roughness = 0.32
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	camera.far = 50000
	camera.near = 0.5
	if terrain_data.streaming:
		streamer = preload("res://scripts/terrain_streamer.gd").new()
		streamer.name = "TerrainStreamer"
		landscape.add_child(streamer)
		streamer.configure(terrain_data)
		await streamer.build_background(progress_callback)
		chunks = streamer.chunks
		camera.far = 180000
		environment.fog_density = 0.000006
	else:
		var count := _chunk_count()
		var completed := 0
		for z in count.y:
			for x in count.x:
				_build_chunk(Vector2i(x,z), false)
				completed += 1
			if progress_callback.is_valid():
				await progress_callback.call(0.75 * completed / (count.x * count.y), "Shaping " + terrain_data.definition.name)
			else: await get_tree().process_frame
	_make_water()
	_make_hud()
	_make_terrain_hud()
	await travel_to(int(get_meta("terrain_entry", 0)))
	if progress_callback.is_valid(): await progress_callback.call(1.0, "Terrain ready")
	ready_to_explore = true
	player.respawned.connect(_restore_spawn_collision)

func _chunk_count() -> Vector2i:
	if streamer: return streamer.count
	return Vector2i(ceili(terrain_data.extent.x / CHUNK_SIZE), ceili(terrain_data.extent.y / CHUNK_SIZE))

func _cell_at(point: Vector2) -> Vector2i:
	if streamer: return streamer.cell_at(point)
	return Vector2i(((point + terrain_data.extent * 0.5) / CHUNK_SIZE).floor())

func _rect_for(cell: Vector2i) -> Rect2:
	if streamer: return streamer.rect_for(cell)
	var start := Vector2(cell) * CHUNK_SIZE - terrain_data.extent * 0.5
	return Rect2(start, Vector2(CHUNK_SIZE, CHUNK_SIZE).min(terrain_data.extent * 0.5 - start))

func _build_chunk(cell: Vector2i, nearby: bool) -> void:
	var count := _chunk_count()
	if cell.x < 0 or cell.y < 0 or cell.x >= count.x or cell.y >= count.y: return
	var chunk := Chunk.new()
	chunk.name = "Terrain_%d_%d" % [cell.x,cell.y]
	chunk.build(terrain_data, _rect_for(cell), NEAR_DETAIL if nearby else FAR_DETAIL, terrain_material, nearby)
	if chunks.has(cell):
		var old: Node = chunks[cell]
		landscape.remove_child(old)
		old.queue_free()
	landscape.add_child(chunk)
	chunks[cell] = chunk

func _make_water() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = terrain_data.extent + (Vector2(400000,400000) if terrain_data.streaming else Vector2(16000,16000))
	sea.mesh = plane
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = preload("res://shaders/terrain_ocean.gdshader")
	ocean_material.set_shader_parameter("ocean_mask", load(terrain_data.definition.ocean_mask_file))
	ocean_material.set_shader_parameter("terrain_size", terrain_data.extent)
	sea.material_override = ocean_material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landscape.add_child(sea)
	for lake in terrain_data.definition.get("lakes", []):
		var mesh := MeshInstance3D.new()
		mesh.name = "Lake"
		var disc := CylinderMesh.new()
		disc.top_radius = 1; disc.bottom_radius = 1; disc.height = 0.2
		disc.radial_segments = 64
		mesh.mesh = disc
		var p := terrain_data.map_to_world(lake.center)
		mesh.position = Vector3(p.x, lake.level, p.y)
		var scale_m: float = terrain_data.extent.x / terrain_data.definition.map_size[0]
		mesh.scale = Vector3(lake.radius[0] * scale_m, 1, lake.radius[1] * scale_m)
		mesh.material_override = water_material
		landscape.add_child(mesh)
	for river in terrain_data.definition.get("rivers", []):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(river.points.size()-1):
			var a := terrain_data.map_to_world(river.points[i])
			var b := terrain_data.map_to_world(river.points[i+1])
			var ha: float = river.levels[i]; var hb: float = river.levels[i+1]
			var before := terrain_data.map_to_world(river.points[maxi(0,i-1)])
			var after := terrain_data.map_to_world(river.points[mini(river.points.size()-1,i+2)])
			var side_a := (b-before).normalized().orthogonal() * float(river.width_m) * 0.6
			var side_b := (after-a).normalized().orthogonal() * float(river.width_m) * 0.6
			var v := [Vector3(a.x-side_a.x,ha,a.y-side_a.y),Vector3(a.x+side_a.x,ha,a.y+side_a.y),Vector3(b.x-side_b.x,hb,b.y-side_b.y),Vector3(b.x+side_b.x,hb,b.y+side_b.y)]
			for index in [0,1,2,1,3,2]: surface.add_vertex(v[index])
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		mesh.material_override = water_material
		landscape.add_child(mesh)

func _make_terrain_hud() -> void:
	var panel := HBoxContainer.new()
	panel.position = Vector2(24, 68)
	panel.add_theme_constant_override("separation", 8)
	hud.add_child(panel)
	destination_menu = OptionButton.new()
	destination_menu.custom_minimum_size = Vector2(210, 36)
	for entry in terrain_data.definition.entries: destination_menu.add_item(entry.name)
	destination_menu.item_selected.connect(travel_to)
	var popup := destination_menu.get_popup()
	popup.add_theme_stylebox_override("panel", UiStyle.card(10, 6, 8, 10))
	popup.add_theme_stylebox_override("hover", UiStyle.fill(UiStyle.HOVER_GRAY, 6))
	popup.add_theme_color_override("font_color", UiStyle.INK)
	popup.add_theme_color_override("font_hover_color", UiStyle.INK)
	popup.add_theme_font_size_override("font_size", 14)
	panel.add_child(UiStyle.frost_button(destination_menu, 18))
	village_button = Button.new()
	village_button.text = "Enter MudWing village"
	village_button.visible = continent_id == "pyrrhia"
	UiStyle.primary_button(village_button, 18)
	village_button.custom_minimum_size.y = 36
	village_button.pressed.connect(_enter_village)
	panel.add_child(village_button)
	location_label = _add_location_label("", Vector2(24, 116))
	help_toggle.toggled.connect(func(expanded: bool):
		panel.visible = not expanded)

func travel_to(index: int) -> void:
	if shifting: return
	shifting = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var entry: Dictionary = terrain_data.definition.entries[index]
	var point := terrain_data.map_to_world(entry.position)
	world_origin = (point / CHUNK_SIZE).floor() * CHUNK_SIZE
	landscape.position = Vector3(-world_origin.x,0,-world_origin.y)
	player.spawn_position = Vector3(point.x-world_origin.x, terrain_data.height_at(point)+4, point.y-world_origin.y)
	player.reset_to_spawn()
	last_cell = _cell_at(point)
	requested_cells.clear()
	if streamer:
		if not await streamer.prepare(point):
			location_label.text = "Could not prepare this area. Choose World map to return."
			shifting = false
			return
	else:
		for z in range(last_cell.y-1,last_cell.y+2):
			for x in range(last_cell.x-1,last_cell.x+2):
				_build_chunk(Vector2i(x,z),true)
			await get_tree().process_frame
		# Complete physics registration before resuming movement.
		await get_tree().physics_frame
		await get_tree().physics_frame
		for cell in chunks:
			if chunks[cell].detail == NEAR_DETAIL and (absi(cell.x-last_cell.x)>2 or absi(cell.y-last_cell.y)>2): _build_chunk(cell,false)
	waiting_for_ground = false
	player.set_physics_process(true)
	destination_menu.select(index)
	location_label.text = terrain_data.definition.name + " · " + entry.name + "\nBare terrain"
	player.process_mode = Node.PROCESS_MODE_INHERIT
	shifting = false

func _process(delta: float) -> void:
	if not ready_to_explore: return
	super._process(delta)
	if not is_inside_tree(): return
	if shifting: return
	var point := Vector2(player.position.x,player.position.z) + world_origin
	var cell := _cell_at(point)
	if streamer:
		streamer.update_interest(point,Vector2(player.velocity.x,player.velocity.z))
		streamer.pump()
		# Use a conservative global bound: the distant overview can undershoot
		# a narrow peak, so it must not decide whether a dive needs collision.
		var needs_ground := player.position.y<float(terrain_data.definition.elevation_range_m[1])+maxf(300,-player.velocity.y*4+100)
		var must_wait: bool = needs_ground and not streamer.collision_ready(point)
		if must_wait and not waiting_for_ground: landing_waits += 1
		waiting_for_ground = must_wait
		player.set_physics_process(not must_wait)
		if must_wait and not streamer.last_error.is_empty():
			location_label.text="This area could not load. Choose another starting point or World map."
	else:
		if cell != last_cell:
			last_cell = cell
			requested_cells.clear()
			for z in range(cell.y-1,cell.y+2):
				for x in range(cell.x-1,cell.x+2):
					var key := Vector2i(x,z)
					if chunks.has(key) and chunks[key].detail != NEAR_DETAIL: requested_cells.append(key)
		if not requested_cells.is_empty(): _build_chunk(requested_cells.pop_front(),true)
		else:
			for key in chunks:
				if chunks[key].detail == NEAR_DETAIL and (absi(key.x-cell.x)>2 or absi(key.y-cell.y)>2):
					_build_chunk(key,false)
					break
	if Vector2(player.position.x,player.position.z).length() > 2048:
		var shift := (Vector2(player.position.x,player.position.z) / CHUNK_SIZE).floor() * CHUNK_SIZE
		world_origin += shift
		var shift3 := Vector3(shift.x,0,shift.y)
		landscape.position -= shift3
		player.position -= shift3
		player.spawn_position -= shift3
		if player.visual.motion: player.visual.motion.reset_motion()
	if not terrain_data.contains(point) or player.position.y < terrain_data.water_level_at(point)-2:
		# Water is a simple surface in this pass; return safely instead of falling forever.
		travel_to(destination_menu.selected)
	if is_instance_valid(village_button) and village_button.visible:
		var village := terrain_data.map_to_world([1480,1080])
		village_button.disabled = point.distance_to(village) > 600

func _enter_village() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_locations.json"))
	var loader: Control = load("res://scenes/startup.tscn").instantiate()
	loader.configure(registry.locations[0])
	get_tree().root.add_child(loader)
	get_tree().current_scene = loader
	queue_free()

func _restore_spawn_collision() -> void:
	if ready_to_explore and not shifting:
		travel_to(destination_menu.selected)
