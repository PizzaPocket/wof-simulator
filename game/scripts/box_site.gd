extends "res://scripts/playground.gd"
## Shared base for rough, box-built outdoor locations (Scorpion Den, Burn's Stronghold, Summer
## Palace). A subclass names its design file and implements `_build()`; this class does the era
## lookup, camera range, sky, ground and boundary, labels and spawn. Designs are authored
## blockouts and each design file starts with a `note` saying what was and was not sourced.
var design: Dictionary
var era := "arc1"
var location_label: Label
var rng := RandomNumberGenerator.new()
var residents: Array[Node] = [] ## Every character this site installed.


func _design_path() -> String:
	return ""


## Build the site's geometry. May await frames and report progress.
func _build(_progress: Callable) -> void:
	pass


func _ready() -> void:
	if not has_meta("startup_loader"):
		initialize_world()


func _loading(callback: Callable, fraction: float, description: String) -> void:
	if callback.is_valid():
		await callback.call(fraction, description)
	else:
		await get_tree().process_frame


func initialize_world(progress_callback: Callable = Callable()) -> void:
	design = JSON.parse_string(FileAccess.get_file_as_string(_design_path()))
	era = str(Engine.get_meta("map_era")) if Engine.has_meta("map_era") else "arc1"
	if not era in design.label_by_era:
		era = str(design.label_by_era.keys()[0])
	rng.seed = int(design.get("seed", 1))
	# The default camera far plane is 300 m, which would clip anything beyond it.
	(player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).far = float(design.get("view_distance", 8000.0))
	await _loading(progress_callback, 0.0, "Marking out " + str(design.title))
	_make_environment()
	_make_ground()
	await _build(progress_callback)
	_make_hud()
	location_label = _add_location_label("\n".join(PackedStringArray(design.label_by_era[era])))
	var spawn: Array = design.spawn
	player.spawn_position = Vector3(spawn[0], spawn[1], spawn[2])
	player.reset_to_spawn()
	# The story's characters for this era wait just ahead of the arrival point.
	for actor in preload("res://scripts/cast_manager.gd").install(self, {"scene_id": str(design.get("scene_id", "")), "origin": player.spawn_position, "offset": Vector3(0, 0, -16)}):
		residents.append(actor)
	await _loading(progress_callback, 1.0, str(design.title) + " ready")


func _make_environment() -> void:
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
	environment.ambient_light_color = Color(env.get("ambient_color", "f3e6cf"))
	environment.ambient_light_energy = float(env.get("ambient", 0.55))
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = float(env.get("exposure", 0.85))
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(env.fog_color)
	environment.fog_density = float(env.fog_density)
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(env.sun_color)
	sun.light_energy = float(env.get("sun_energy", 1.3))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1500.0
	add_child(sun)


## A big solid disc to stand on, a collision wall around the playable area, and no visible edge.
func _make_ground() -> void:
	var radius := float(design.ground_radius)
	var body := StaticBody3D.new()
	body.name = "Ground"
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


## A mesh-only box (no collision) for roofs, awnings and decoration.
func _decor_box(size: Vector3, at: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.rotation.y = yaw
	instance.material_override = _material(color)
	add_child(instance)
	return instance


func _decor_cylinder(top_radius: float, bottom_radius: float, height: float, at: Vector3, color: Color, sides := 12) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(color)
	add_child(instance)
	return instance


func _sign(text: String, at: Vector3, ink := Color("fff4dc"), outline := Color(0.25, 0.17, 0.08, 0.9), pixel_size := 0.06) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 64
	sign.pixel_size = pixel_size
	sign.outline_size = 22
	sign.modulate = ink
	sign.outline_modulate = outline
	sign.visibility_range_end = 380.0
	sign.position = at
	add_child(sign)
