extends "res://scripts/playground.gd"
## Shared base for rough rock-and-cave locations (Jade Mountain, the Sky Kingdom palace).
## A subclass names its design file and builds the outer rock mass; this class carves the
## chambers and passages from data, lights them, holds the player until the carved collision
## is real and shows the location label. Designs are authored blockouts: every chamber says
## where it came from. Coordinates are metres relative to `mouth`, a point on the arrival floor.
var lantern := Color("ffd9a0")
var design: Dictionary
var rock: ShaderMaterial          ## Exterior stone.
var rock_interior: ShaderMaterial ## Carved surfaces (may carry gold veins).
var mouth := Vector3.ZERO ## World position of the arrival floor reference point.
var mountain: CSGCombiner3D
var location_label: Label
var chamber_floors: Array[Dictionary] = []
var collision_ready := false
var built := false ## Set once initialization has finished; collision polling starts then.


## Virtuals for subclasses.
func _design_path() -> String:
	return ""

func _prepare_site() -> void:
	pass

func _make_solid() -> void:
	pass

func _carve_extra() -> void:
	pass

var residents: Array[Node] = [] ## Every character this site installed.


## Called once when the carved collision is real, so characters can stand on it. Those placed in
## a named room (data/cast.json) stand in it; the rest wait on the arrival floor behind the player.
func _on_site_ready() -> void:
	var chambers := {}
	for chamber in design.get("chambers", []):
		chambers[str(chamber.id)] = mouth + Vector3(float(chamber.x), 0.4, float(chamber.z))
	for actor in preload("res://scripts/cast_manager.gd").install(self, {"scene_id": str(design.get("scene_id", "")), "origin": player.spawn_position, "offset": Vector3(0, 0, 12), "chambers": chambers}):
		residents.append(actor)


var era := "arc1"

## Resolve the era for this site and take its label; unknown eras fall back to the first listed.
func _pick_era() -> void:
	era = current_era()
	if design.has("label_by_era"):
		if not era in design.label_by_era:
			era = str(design.label_by_era.keys()[0])
		design.label = design.label_by_era[era]


## The era chosen on the world map (Arc 1 for direct runs).
func current_era() -> String:
	return str(Engine.get_meta("map_era")) if Engine.has_meta("map_era") else "arc1"


func _ready() -> void:
	# Direct scene runs and tests initialize immediately; the loader drives it otherwise.
	if not has_meta("startup_loader"):
		initialize_world()


func _loading(callback: Callable, fraction: float, description: String) -> void:
	if callback.is_valid():
		await callback.call(fraction, description)
	else:
		await get_tree().process_frame


func initialize_world(progress_callback: Callable = Callable()) -> void:
	design = JSON.parse_string(FileAccess.get_file_as_string(_design_path()))
	_prepare_site()
	_set_view_distance(float(design.get("view_distance", 20000.0)))
	await _loading(progress_callback, 0.0, "Raising " + str(design.title))
	_make_environment()
	_make_rock()
	_make_ground()
	_make_boundary(float(design.boundary_radius))
	await _loading(progress_callback, 0.15, "Shaping the rock")
	_make_solid()
	await _loading(progress_callback, 0.40, "Carving the caves")
	_carve_interior()
	_carve_extra()
	await _loading(progress_callback, 0.60, "Lighting the lanterns")
	_light_interior()
	await _loading(progress_callback, 0.75, "Settling the stone")
	# CSG meshes and collision build on the next frames.
	for i in 3:
		await get_tree().process_frame
	for i in 3:
		await get_tree().physics_frame
	_make_hud()
	_make_location_label()
	var spawn: Array = design.spawn
	player.spawn_position = mouth + Vector3(spawn[0], spawn[1], spawn[2])
	player.reset_to_spawn()
	# The collision appears some frames after the mesh. Hold the player until the floor is
	# solid so spawning never drops them into the rock.
	player.set_physics_process(false)
	built = true
	await _loading(progress_callback, 1.0, str(design.title) + " ready")


func _physics_process(_delta: float) -> void:
	if collision_ready or not built or not is_inside_tree():
		return
	# The mesh can briefly collide as solid rock before the carved caves are built, so wait
	# until every probe point (arrival floor and a floor inside the rock) is solid.
	for probe: Array in design.ready_probes:
		if absf(_floor_below(mouth + Vector3(probe[0], 8, probe[1])) - mouth.y) >= 0.6:
			return
	collision_ready = true
	player.set_physics_process(true)
	_on_site_ready()


func _floor_below(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3(0, -16, 0))
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else -INF


# --- Materials and environment ----------------------------------------------

## The player camera's default far plane is 300 m, which would clip the mountain until the
## player was almost against it. Sites that can be seen from far away raise it.
func _set_view_distance(distance: float) -> void:
	var camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	camera.far = distance


func _make_rock() -> void:
	rock = ShaderMaterial.new()
	rock.shader = load("res://shaders/jade_rock.gdshader")
	rock.set_shader_parameter("base_height", mouth.y)
	# Optional palette (ice, volcanic rock) from the design file.
	var colors: Dictionary = design.get("rock", {})
	for key in ["low_color", "high_color", "snow_color"]:
		if colors.has(key):
			rock.set_shader_parameter(key, Color(colors[key]))
	for key in ["snow_line", "bump"]:
		if colors.has(key):
			rock.set_shader_parameter(key, float(colors[key]))
	rock_interior = rock.duplicate()
	lantern = Color(design.get("lantern", "ffd9a0"))


func _make_environment() -> void:
	var env: Dictionary = design.get("env", {})
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(env.get("sky_top", "5f8fb4"))
	sky_material.sky_horizon_color = Color(env.get("sky_horizon", "d9dfd0"))
	sky_material.ground_bottom_color = Color("6f7d62")
	sky_material.ground_horizon_color = Color(env.get("sky_horizon", "d9dfd0"))
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Low ambient keeps the caves dark; lanterns and the sun do the lighting.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dfe6f0")
	environment.ambient_light_energy = float(env.get("ambient", 0.5))
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = float(env.get("exposure", 0.85))
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(env.get("fog_color", "cfd9dc"))
	environment.fog_density = float(env.get("fog_density", 0.00007))
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.2
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 150, 0)
	sun.light_color = Color(env.get("sun_color", "fff1dc"))
	sun.light_energy = float(env.get("sun_energy", 1.25))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3500.0
	add_child(sun)


func _make_ground() -> void:
	var radius := float(design.ground_radius)
	var body := StaticBody3D.new()
	body.name = "Foothills"
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
	instance.material_override = _material(Color(design.get("ground_color", "6f7d5c")))
	body.add_child(instance)
	add_child(body)


func _make_boundary(radius: float) -> void:
	# A closed wall of collision keeps the local scene bounded; it has no visible mesh.
	var faces := PackedVector3Array()
	var segments := 96
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		var p := Vector3(cos(a), 0, sin(a)) * radius
		var q := Vector3(cos(b), 0, sin(b)) * radius
		var low_p := Vector3(p.x, -40, p.z)
		var low_q := Vector3(q.x, -40, q.z)
		var high_p := Vector3(p.x, 9000, p.z)
		var high_q := Vector3(q.x, 9000, q.z)
		faces.append_array([low_p, high_p, high_q, low_p, high_q, low_q])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var boundary := StaticBody3D.new()
	boundary.name = "RegionBoundary"
	var collider := CollisionShape3D.new()
	collider.shape = shape
	boundary.add_child(collider)
	add_child(boundary)


# --- The rock mass ----------------------------------------------------------

func _cone(x: float, z: float, radius: float, height: float, base_y := 0.0) -> CSGCylinder3D:
	var cone := CSGCylinder3D.new()
	cone.cone = true
	cone.radius = radius
	cone.height = height
	cone.sides = 44
	cone.position = Vector3(x, base_y + height * 0.5, z)
	cone.material = rock
	return cone


func _new_mountain() -> CSGCombiner3D:
	mountain = CSGCombiner3D.new()
	mountain.name = "Mountain"
	mountain.use_collision = true
	mountain.collision_layer = 1
	mountain.collision_mask = 0
	return mountain


## Mouth on the face of the main cone at the ledge height, for cone-mountain sites.
func _prepare_cone_site() -> void:
	var settings: Dictionary = design.mountain
	var radius_at_ledge: float = float(settings.base_radius) * (1.0 - float(settings.ledge_y) / float(settings.height))
	mouth = Vector3(0, float(settings.ledge_y), radius_at_ledge)


## A main cone, satellites, seeded foothills and summit spires, and a buttress ledge at the mouth.
func _make_cone_mountain() -> void:
	var settings: Dictionary = design.mountain
	_new_mountain()
	mountain.add_child(_cone(0, 0, float(settings.base_radius), float(settings.height)))
	for satellite in settings.get("satellites", []):
		mountain.add_child(_cone(float(satellite.x), float(satellite.z), float(satellite.radius), float(satellite.height)))
	var foothills: Dictionary = settings.get("foothills", {"count": 22, "distance": [260, 800], "radius": [110, 270], "height": [650, 1800]})
	var spires: Dictionary = settings.get("spires", {"count": 12, "distance": [0, 230], "base": [1150, 1450], "radius": [70, 130], "height": [520, 1050]})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.get("seed", 2600))
	for i in int(foothills.count):
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(foothills.distance[0], foothills.distance[1])
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		var radius := rng.randf_range(foothills.radius[0], foothills.radius[1])
		var height := rng.randf_range(foothills.height[0], foothills.height[1])
		if _crowds_mouth(x, z, radius, height, 0.0):
			continue
		mountain.add_child(_cone(x, z, radius, height))
	for i in int(spires.count):
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(spires.distance[0], spires.distance[1])
		var base_y := rng.randf_range(spires.base[0], spires.base[1])
		var height := rng.randf_range(spires.height[0], spires.height[1])
		mountain.add_child(_cone(cos(angle) * distance, sin(angle) * distance, rng.randf_range(spires.radius[0], spires.radius[1]), height, base_y))
	var ledge := CSGBox3D.new()
	ledge.size = Vector3(design.ledge.width, 110, design.ledge.depth)
	ledge.position = mouth + Vector3(0, -55, 10)
	ledge.material = rock
	mountain.add_child(ledge)
	add_child(mountain)


func _crowds_mouth(x: float, z: float, radius: float, height: float, base_y: float) -> bool:
	for y: float in [mouth.y - 80.0, mouth.y, mouth.y + 80.0, mouth.y + 180.0]:
		if y < base_y or y > base_y + height:
			continue
		var reach: float = radius * (1.0 - (y - base_y) / height)
		if Vector2(x, z).distance_to(Vector2(0.0, mouth.z)) < reach + 110.0:
			return true
	return false


# --- Caves ------------------------------------------------------------------

func _carve(node: CSGShape3D) -> void:
	node.operation = CSGShape3D.OPERATION_SUBTRACTION
	mountain.add_child(node)


func _volume(shape: CSGShape3D) -> CSGShape3D:
	shape.material = rock_interior
	return shape


func _carve_interior() -> void:
	for chamber in design.get("chambers", []):
		_carve_chamber(chamber)
	for tunnel in design.get("tunnels", []):
		_carve_tunnel(tunnel)


## A flat-floored room with a domed roof. The floor sits at the arrival height.
func _carve_chamber(chamber: Dictionary) -> void:
	var radius: float = chamber.radius
	var height: float = chamber.height
	var group := CSGCombiner3D.new()
	group.name = "Chamber_" + str(chamber.id)
	group.position = mouth + Vector3(chamber.x, 0, chamber.z)
	var drum := CSGCylinder3D.new()
	drum.radius = radius
	drum.height = height
	drum.sides = 40
	drum.position.y = height * 0.5
	group.add_child(_volume(drum))
	var dome := CSGSphere3D.new()
	dome.radius = radius
	dome.radial_segments = 40
	dome.rings = 20
	dome.scale.y = minf(float(chamber.dome), height / radius)
	dome.position.y = height
	group.add_child(_volume(dome))
	_carve(group)
	chamber_floors.append({"id": chamber.id, "position": group.position, "height": height + radius * minf(float(chamber.dome), height / radius)})


## A flat-floored passage with an arched roof between two plan points.
func _carve_tunnel(tunnel: Dictionary) -> void:
	var a := Vector2(tunnel.from[0], tunnel.from[1])
	var b := Vector2(tunnel.to[0], tunnel.to[1])
	var width: float = tunnel.width
	var height: float = tunnel.height
	var length := a.distance_to(b) + 4.0
	# The arch is a half circle on a straight-walled base, so a passage is never lower than it is wide.
	var spring := maxf(height - width * 0.5, width * 0.5)
	var group := CSGCombiner3D.new()
	group.name = "Tunnel"
	var middle := (a + b) * 0.5
	group.position = mouth + Vector3(middle.x, 0, middle.y)
	group.rotation.y = atan2(b.x - a.x, b.y - a.y)
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(width, spring, length)
	floor_box.position.y = spring * 0.5
	group.add_child(_volume(floor_box))
	var arch := CSGCylinder3D.new()
	arch.radius = width * 0.5
	arch.height = length
	arch.sides = 24
	arch.rotation.x = PI * 0.5
	arch.position.y = spring
	group.add_child(_volume(arch))
	_carve(group)


func _light(position: Vector3, range_m: float, energy: float, shadows: bool) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = lantern
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows
	add_child(light)
	var bulb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.1
	var glow := StandardMaterial3D.new()
	glow.albedo_color = lantern
	glow.emission_enabled = true
	glow.emission = lantern
	glow.emission_energy_multiplier = 3.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = glow
	bulb.mesh = mesh
	bulb.position = position
	add_child(bulb)


func _light_interior() -> void:
	for chamber in design.get("chambers", []):
		var radius: float = chamber.radius
		var height: float = chamber.height
		var large: bool = radius >= 30
		var top := mouth + Vector3(chamber.x, height * 0.82, chamber.z)
		_light(top, radius * 3.2, 7.0 if large else 4.0, radius >= 50)
		var sign := Label3D.new()
		sign.text = chamber.name
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.font_size = 64
		sign.pixel_size = 0.035 if large else 0.02
		sign.outline_size = 20
		sign.modulate = Color("f3e5c4")
		sign.outline_modulate = Color(0.09, 0.17, 0.16, 0.9)
		sign.visibility_range_end = radius * 3.0
		sign.position = mouth + Vector3(chamber.x, height * 0.6, chamber.z)
		add_child(sign)
	for tunnel in design.get("tunnels", []):
		var a := Vector2(tunnel.from[0], tunnel.from[1])
		var b := Vector2(tunnel.to[0], tunnel.to[1])
		var steps := maxi(1, int(a.distance_to(b) / 60.0))
		for i in steps:
			var point := a.lerp(b, (i + 0.5) / steps)
			_light(mouth + Vector3(point.x, float(tunnel.height) * 0.78, point.y), 46.0, 3.5, false)


func _make_location_label() -> void:
	location_label = _add_location_label("\n".join(PackedStringArray(design.label)))
