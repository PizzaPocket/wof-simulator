extends "res://scripts/playground.gd"
## The Scorpion Den (Kingdom of Sand): a rough blockout of a walled desert town with a central
## oasis, a market plaza ringed with stalls, and hundreds of alley-forming buildings. Built from
## boxes from data/scorpion_den_design.json. Eras: the Outclaws' camp beside the oasis (Arc 1)
## or Vulture's fortified compound (Arc 2). Coordinates: town centre at the origin, main gate +Z.
var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scorpion_den_design.json"))
var era := "arc1"
var location_label: Label
var building_count := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if not has_meta("startup_loader"):
		initialize_world()


func _loading(callback: Callable, fraction: float, description: String) -> void:
	if callback.is_valid():
		await callback.call(fraction, description)
	else:
		await get_tree().process_frame


func initialize_world(progress_callback: Callable = Callable()) -> void:
	era = str(Engine.get_meta("map_era")) if Engine.has_meta("map_era") else "arc1"
	if not era in design.label_by_era:
		era = "arc1"
	rng.seed = int(design.seed)
	await _loading(progress_callback, 0.0, "Marking out the Scorpion Den")
	_make_environment_desert()
	_make_ground()
	await _loading(progress_callback, 0.15, "Raising the walls")
	_make_walls()
	await _loading(progress_callback, 0.35, "Digging the oasis")
	_make_oasis()
	_make_stalls()
	await _loading(progress_callback, 0.5, "Building the alleys")
	_make_town()
	await _loading(progress_callback, 0.85, "Setting the era")
	_make_era_features()
	_make_hud()
	location_label = Label.new()
	location_label.position = Vector2(24, 66)
	location_label.text = "\n".join(PackedStringArray(design.label_by_era[era]))
	location_label.add_theme_color_override("font_color", Color("f3e5c4"))
	location_label.add_theme_color_override("font_shadow_color", Color("172c28"))
	location_label.add_theme_constant_override("shadow_offset_x", 1)
	location_label.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(location_label)
	help_toggle.toggled.connect(func(expanded: bool): location_label.visible = not expanded)
	var spawn: Array = design.spawn
	player.spawn_position = Vector3(spawn[0], spawn[1], spawn[2])
	player.reset_to_spawn()
	await _loading(progress_callback, 1.0, "Scorpion Den ready")


func _make_environment_desert() -> void:
	var env: Dictionary = design.env
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(env.sky_top)
	sky_material.sky_horizon_color = Color(env.sky_horizon)
	sky_material.ground_bottom_color = Color(design.ground_color)
	sky_material.ground_horizon_color = Color(env.sky_horizon)
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f3e6cf")
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.85
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(env.fog_color)
	environment.fog_density = float(env.fog_density)
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(env.sun_color)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	add_child(sun)


func _make_ground() -> void:
	var radius := float(design.ground_radius)
	var body := StaticBody3D.new()
	body.name = "Desert"
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 4.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -2.0
	body.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 4.0
	mesh.radial_segments = 64
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = -2.0
	instance.material_override = _material(Color(design.ground_color))
	body.add_child(instance)
	add_child(body)
	# A closed wall of collision keeps the scene bounded; it has no visible mesh.
	var faces := PackedVector3Array()
	var edge := float(design.boundary_radius)
	for i in 64:
		var a := TAU * i / 64
		var b := TAU * (i + 1) / 64
		var p := Vector3(cos(a), 0, sin(a)) * edge
		var q := Vector3(cos(b), 0, sin(b)) * edge
		faces.append_array([Vector3(p.x, -40, p.z), Vector3(p.x, 9000, p.z), Vector3(q.x, 9000, q.z), Vector3(p.x, -40, p.z), Vector3(q.x, 9000, q.z), Vector3(q.x, -40, q.z)])
	var wall_shape := ConcavePolygonShape3D.new()
	wall_shape.backface_collision = true
	wall_shape.set_faces(faces)
	var boundary := StaticBody3D.new()
	boundary.name = "RegionBoundary"
	var wall_collider := CollisionShape3D.new()
	wall_collider.shape = wall_shape
	boundary.add_child(wall_collider)
	add_child(boundary)


func _sandstone() -> Color:
	return Color("c3a36b").lerp(Color("dfc58f"), rng.randf()).darkened(rng.randf() * 0.18)


func _make_walls() -> void:
	var wall: Dictionary = design.wall
	var radius := float(wall.radius)
	var segments := int(wall.segments)
	var gates: Array = []
	for degrees in wall.gates_deg:
		gates.append(deg_to_rad(float(degrees)))
	var half_gate := float(wall.gate_width) * 0.5 / radius
	var arc := TAU * radius / segments
	for i in segments:
		var angle := TAU * (i + 0.5) / segments
		var blocked := false
		for gate: float in gates:
			if absf(wrapf(angle - gate, -PI, PI)) < half_gate + arc * 0.5 / radius:
				blocked = true
		if blocked:
			continue
		var tangent := Vector2(-sin(angle), cos(angle))
		var piece := _box("Wall", Vector3(arc * 1.04, float(wall.height), float(wall.thickness)), Vector3(cos(angle) * radius, float(wall.height) * 0.5, sin(angle) * radius), Color("c9ab74"))
		piece.rotation.y = atan2(-tangent.y, tangent.x)
	for gate: float in gates:
		for side in [-1, 1]:
			var a: float = gate + side * (half_gate + 7.0 / radius)
			_box("GateTower", Vector3(wall.tower[0], wall.tower[1], wall.tower[0]), Vector3(cos(a) * radius, float(wall.tower[1]) * 0.5, sin(a) * radius), Color("b8985f"))


func _make_oasis() -> void:
	var oasis: Dictionary = design.oasis
	var radius := float(oasis.radius)
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = radius + 4.0
	rim_mesh.bottom_radius = radius + 4.0
	rim_mesh.height = 0.5
	rim.mesh = rim_mesh
	rim.position.y = 0.2
	rim.material_override = _material(Color("a98d58"))
	add_child(rim)
	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = radius
	water_mesh.bottom_radius = radius
	water_mesh.height = 0.5
	water.mesh = water_mesh
	water.position.y = 0.3
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.18, 0.5, 0.58, 0.9)
	water_material.roughness = 0.1
	water_material.metallic = 0.3
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = water_material
	add_child(water)
	for i in int(oasis.palms):
		var angle := TAU * i / int(oasis.palms) + rng.randf() * 0.3
		var at := Vector3(cos(angle), 0, sin(angle)) * (radius + rng.randf_range(0.0, 6.0))
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.7
		trunk_mesh.bottom_radius = 1.0
		trunk_mesh.height = 15.0
		trunk.mesh = trunk_mesh
		trunk.position = at + Vector3(0, 7.5, 0)
		trunk.material_override = _material(Color("7a5c3a"))
		add_child(trunk)
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 5.5
		crown_mesh.height = 6.0
		crown.mesh = crown_mesh
		crown.position = at + Vector3(0, 15.5, 0)
		crown.material_override = _material(Color("4f7a3c"))
		add_child(crown)


func _make_stalls() -> void:
	var count := int(design.stalls)
	var colors := [Color("b0453a"), Color("3a6fb0"), Color("c99a2e"), Color("5a8f5a"), Color("8a4f9a")]
	for i in count:
		var angle := TAU * (i + 0.5) / count
		var at := Vector3(cos(angle), 0, sin(angle)) * (float(design.plaza_radius) - 8.0)
		var table := _box("Stall", Vector3(9, 3, 6), at + Vector3(0, 1.5, 0), Color("8b6b43"))
		table.rotation.y = -angle
		var canopy := MeshInstance3D.new()
		var canopy_mesh := BoxMesh.new()
		canopy_mesh.size = Vector3(11, 0.5, 8)
		canopy.mesh = canopy_mesh
		canopy.position = at + Vector3(0, 6.5, 0)
		canopy.rotation.y = -angle
		canopy.material_override = _material(colors[i % colors.size()])
		add_child(canopy)


func _near_gate_street(point: Vector2) -> bool:
	for degrees in design.wall.gates_deg:
		var a := deg_to_rad(float(degrees))
		# Perpendicular distance to the street running from the plaza out through each gate.
		var along := point.x * cos(a) + point.y * sin(a)
		if along > 0.0 and absf(point.x * sin(a) - point.y * cos(a)) < 12.0:
			return true
	return false


## Jittered grid blocks leave winding alleys between them; streets from each gate stay clear.
func _make_town() -> void:
	var cell := float(design.cell)
	var limit := float(design.wall.radius) - 26.0
	var plaza := float(design.plaza_radius) + 14.0
	var reach := int(ceil(limit / cell))
	var compound: Dictionary = design.compound
	var named: Dictionary = design.named
	for i in range(-reach, reach + 1):
		for j in range(-reach, reach + 1):
			var centre := Vector2(i * cell + rng.randf_range(-5, 5), j * cell + rng.randf_range(-5, 5))
			var size := Vector3(rng.randf_range(22, 40), rng.randf_range(10, 26), rng.randf_range(22, 40))
			var yaw := rng.randf_range(-0.25, 0.25)
			var color := _sandstone()
			if centre.length() < plaza or centre.length() > limit or _near_gate_street(centre):
				continue
			if rng.randf() < 0.07:
				continue
			if era in compound.eras and absf(centre.x - float(compound.x)) < float(compound.size[0]) * 0.5 + 25 and absf(centre.y - float(compound.z)) < float(compound.size[1]) * 0.5 + 25:
				continue
			var skip := false
			for key in named:
				var spot: Dictionary = named[key]
				if Vector2(float(spot.x), float(spot.z)).distance_to(centre) < 34:
					skip = true
			if skip:
				continue
			var block := _box("Building", size, Vector3(centre.x, size.y * 0.5, centre.y), color)
			block.rotation.y = yaw
			building_count += 1
	for key in named:
		var spot: Dictionary = named[key]
		if spot.has("eras") and not era in spot.eras:
			continue
		var size := Vector3(spot.size[0], spot.size[1], spot.size[2])
		_box(str(spot.name), size, Vector3(float(spot.x), size.y * 0.5, float(spot.z)), Color(spot.color))
		_sign(str(spot.name), Vector3(float(spot.x), size.y + 7.0, float(spot.z)))
		building_count += 1
	_sign("Oasis", Vector3(0, 24, 0))
	_sign("Market", Vector3(0, 30, float(design.plaza_radius) + 4.0))


func _make_era_features() -> void:
	var outclaws: Dictionary = design.outclaws
	if era in outclaws.eras:
		var centre := Vector3(float(outclaws.x), 0, float(outclaws.z))
		for i in int(outclaws.tents):
			var angle := TAU * i / int(outclaws.tents)
			var tent := MeshInstance3D.new()
			var tent_mesh := CylinderMesh.new()
			tent_mesh.top_radius = 0.0
			tent_mesh.bottom_radius = 7.5
			tent_mesh.height = 9.0
			tent_mesh.radial_segments = 6
			tent.mesh = tent_mesh
			tent.position = centre + Vector3(cos(angle) * 14.0, 4.5, sin(angle) * 14.0)
			tent.material_override = _material(Color("7a3a34"))
			add_child(tent)
		_sign(str(outclaws.name), centre + Vector3(0, 16, 0))
	var compound: Dictionary = design.compound
	if era in compound.eras:
		var cx := float(compound.x)
		var cz := float(compound.z)
		var w := float(compound.size[0])
		var d := float(compound.size[1])
		var h := float(compound.wall_height)
		for side in [-1, 1]:
			_box("CompoundWall", Vector3(w, h, 6), Vector3(cx, h * 0.5, cz + side * d * 0.5), Color("9a8a6a"))
			_box("CompoundWall", Vector3(6, h, d), Vector3(cx + side * w * 0.5, h * 0.5, cz), Color("9a8a6a"))
		_box("Observatory", Vector3(compound.tower[0] * 2, compound.tower[1], compound.tower[0] * 2), Vector3(cx - w * 0.25, float(compound.tower[1]) * 0.5, cz), Color("b0a083"))
		_sign(str(compound.name), Vector3(cx, h + 12.0, cz))


func _sign(text: String, at: Vector3) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 64
	sign.pixel_size = 0.06
	sign.outline_size = 22
	sign.modulate = Color("fff4dc")
	sign.outline_modulate = Color(0.25, 0.17, 0.08, 0.9)
	sign.visibility_range_end = 380.0
	sign.position = at
	add_child(sign)
