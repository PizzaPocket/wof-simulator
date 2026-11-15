extends "res://scripts/box_site.gd"
## The SeaWing Summer Palace (rough blockout; data/summer_palace_design.json): a twelve-story
## pavilion of blue-tinted stone on a small island in a shallow sea. Arc 1: intact and hidden
## under a plant canopy, with the electric eel cell. Arc 2: ruins and rubble, no canopy.
## Coordinates: island centre at the origin, approach from +Z.
var story_walls := 0
var rubble_count := 0


func _design_path() -> String:
	return "res://data/summer_palace_design.json"


func _build(progress_callback: Callable) -> void:
	await _loading(progress_callback, 0.2, "Raising the island")
	_make_island()
	await _loading(progress_callback, 0.4, "Building the pavilion")
	_make_pavilion()
	await _loading(progress_callback, 0.75, "Setting the era")
	_make_palms()
	if era == "arc1":
		_make_canopy()
		_make_eel_cell()
	else:
		_make_rubble()


func _make_island() -> void:
	var island: Dictionary = design.island
	var body := StaticBody3D.new()
	body.name = "Island"
	var shape := CylinderShape3D.new()
	shape.radius = float(island.radius)
	shape.height = float(island.height)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = float(island.height) * 0.5
	body.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = float(island.radius)
	mesh.bottom_radius = float(island.radius) + 6.0
	mesh.height = float(island.height)
	mesh.radial_segments = 40
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = float(island.height) * 0.5
	instance.material_override = _material(Color(island.color))
	body.add_child(instance)
	add_child(body)


func _make_pavilion() -> void:
	var p: Dictionary = design.pavilion
	var base_y: float = design.island.height
	var stories: int = p.stories
	var story_h: float = p.story_height
	var wall_t: float = p.wall
	var stone := Color(p.color)
	for s in stories:
		var t := float(s) / float(stories - 1)
		var width := lerpf(float(p.base_width), float(p.top_width), t)
		var y := base_y + s * story_h
		# The ruins keep the lower stories only, and break their walls.
		if era == "arc2" and s >= 4:
			continue
		var wall_h := story_h - 1.5
		var cx: float = p.x
		var cz: float = p.z
		var sides := [
			[Vector3(width, wall_h, wall_t), Vector3(cx, 0, cz - width * 0.5)],
			[Vector3(wall_t, wall_h, width), Vector3(cx - width * 0.5, 0, cz)],
			[Vector3(wall_t, wall_h, width), Vector3(cx + width * 0.5, 0, cz)],
		]
		for side in sides:
			if era == "arc2" and rng.randf() < 0.4:
				continue
			_box("PavilionWall", side[0], side[1] + Vector3(0, y + wall_h * 0.5, 0), stone.lightened(t * 0.12))
			story_walls += 1
		# Front wall: story 0 has a door.
		var door: float = p.door if s == 0 else 0.0
		var half := (width - door) * 0.5
		for sign in [-1, 1]:
			if half > 0.5 and not (era == "arc2" and rng.randf() < 0.4):
				_box("PavilionWall", Vector3(half, wall_h, wall_t), Vector3(cx + sign * (door * 0.5 + half * 0.5), y + wall_h * 0.5, cz + width * 0.5), stone.lightened(t * 0.12))
				story_walls += 1
		if not (era == "arc2" and s >= 3):
			_box("PavilionFloor", Vector3(width + wall_t, 1.5, width + wall_t), Vector3(cx, y + story_h - 0.75, cz), stone.darkened(0.1))
	_sign("Summer Palace" if era == "arc1" else "Summer Palace (ruins)", Vector3(float(p.x), base_y + stories * story_h + 14.0, float(p.z)), Color("f2fbff"), Color(0.05, 0.2, 0.3, 0.9), 0.08)


func _make_palms() -> void:
	var island: Dictionary = design.island
	for i in int(design.palms) if era == "arc1" else int(design.palms) / 2:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(float(island.radius) * 0.55, float(island.radius) * 0.95)
		var at := Vector3(cos(angle) * distance, float(island.height), sin(angle) * distance)
		_decor_cylinder(0.7, 1.0, 15.0, at + Vector3(0, 7.5, 0), Color("7a5c3a"))
		var crown := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 5.5
		mesh.height = 6.0
		mesh.material = _material(Color("4f8a46") if era == "arc1" else Color("5a5a3a"))
		crown.mesh = mesh
		crown.position = at + Vector3(0, 15.5, 0)
		add_child(crown)


## Arc 1: a canopy of foliage hides the palace from above.
func _make_canopy() -> void:
	var island: Dictionary = design.island
	for i in int(design.canopy.blobs):
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(20.0, float(island.radius) * 0.95)
		var blob := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(12.0, 26.0)
		mesh.height = mesh.radius * 1.3
		mesh.material = _material(Color("3f7f3c").lerp(Color("5fa24a"), rng.randf()))
		blob.mesh = mesh
		blob.position = Vector3(cos(angle) * distance, rng.randf_range(float(design.pavilion.stories) * 13.0 + 6.0, float(design.pavilion.stories) * 13.0 + 26.0), sin(angle) * distance)
		add_child(blob)


func _make_eel_cell() -> void:
	var p: Dictionary = design.pavilion
	var base_y: float = design.island.height
	var pool := _decor_box(Vector3(14, 0.3, 10), Vector3(float(p.x) - 14.0, base_y + 0.2, float(p.z) - 8.0), Color("2a5f78"))
	pool.material_override.emission_enabled = true
	pool.material_override.emission = Color("4aa8ff")
	pool.material_override.emission_energy_multiplier = 0.8
	_sign("Electric eel cell", Vector3(float(p.x) - 14.0, base_y + 9.0, float(p.z) - 8.0))


## Arc 2: blocks from the destroyed upper stories lie around the base.
func _make_rubble() -> void:
	var p: Dictionary = design.pavilion
	var base_y: float = design.island.height
	for i in 46:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(float(p.base_width) * 0.7, float(design.island.radius) * 0.9)
		var size := Vector3(rng.randf_range(2.0, 8.0), rng.randf_range(1.5, 5.0), rng.randf_range(2.0, 8.0))
		var at := Vector3(float(p.x) + cos(angle) * distance, base_y + size.y * 0.4, float(p.z) + sin(angle) * distance)
		# Keep the approach from the spawn to the door clear.
		if absf(at.x) < 14.0 and at.z > float(p.z):
			continue
		var block := _box("Rubble", size, at, Color(p.color).darkened(rng.randf() * 0.25))
		block.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		rubble_count += 1
