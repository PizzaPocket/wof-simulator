extends "res://scripts/rock_site.gd"
## The NightWing island volcano and fortress (rough blockout; data/nightwing_volcano_design.json):
## a jagged volcano with a smashed crater and lava flows over black sand, with the fortress carved
## into its side. Arc 1 is the fortress before the eruption in The Dark Secret; Arc 2 is after, with
## rubble and heavier ash. Coordinates: the mountain axis is the world Y axis; the mouth faces +Z.
var rubble: Array[Node] = []


func _design_path() -> String:
	return "res://data/nightwing_volcano_design.json"


func _prepare_site() -> void:
	_pick_era()
	_prepare_cone_site()
	if era == "arc2":
		design.env.fog_density = float(design.env.fog_density) * 1.8 # the ash after the eruption


func _make_solid() -> void:
	_make_cone_mountain()
	# The smashed-in top: subtract a shaft so a crater rim remains.
	var crater: Dictionary = design.mountain.crater
	var shaft := CSGCylinder3D.new()
	shaft.radius = float(crater.radius)
	shaft.height = 400.0
	shaft.sides = 28
	shaft.position = Vector3(0, float(crater.floor_y) + 200.0, 0)
	shaft.operation = CSGShape3D.OPERATION_SUBTRACTION
	shaft.material = rock
	mountain.add_child(shaft)


func _glow_disc(at: Vector3, radius: float, color: Color) -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.4
	mesh.radial_segments = 24
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.5
	mesh.material = glow
	disc.mesh = mesh
	disc.position = at
	add_child(disc)


func _carve_extra() -> void:
	var settings: Dictionary = design.mountain
	var height: float = settings.height
	var radius: float = settings.base_radius
	_glow_disc(Vector3(0, float(settings.crater.floor_y) + 0.3, 0), float(settings.crater.radius) * 0.85, Color("ff6a1f"))
	# Lava runs from the rim to the base along a few chosen bearings, away from the cave mouth.
	for flow in design.lava_flows:
		var angle := deg_to_rad(float(flow.angle))
		for i in int(flow.spheres):
			var t := float(i) / float(flow.spheres)
			var y := lerpf(float(settings.crater.floor_y) + 10.0, 6.0, t)
			var r := radius * (1.0 - y / height) + 2.0
			var blob := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = lerpf(7.0, 14.0, t)
			mesh.height = mesh.radius * 1.4
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color("ff7a25")
			glow.emission_enabled = true
			glow.emission = Color("ff5a10")
			glow.emission_energy_multiplier = 1.8
			mesh.material = glow
			blob.mesh = mesh
			blob.position = Vector3(cos(angle + sin(t * 9.0) * 0.03) * r, y, sin(angle + sin(t * 9.0) * 0.03) * r)
			add_child(blob)
	# Dead, twisted trees and sulfur vents on the black-sand ring, never across the mouth's approach.
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in int(design.dead_trees) + int(design.vents):
		var angle := rng.randf() * TAU
		if absf(wrapf(angle - PI * 0.5, -PI, PI)) < 0.45:
			continue
		var distance := rng.randf_range(radius + 30.0, radius + 380.0)
		var at := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var vent: bool = i >= int(design.dead_trees)
		if vent:
			var mound := MeshInstance3D.new()
			var mound_mesh := CylinderMesh.new()
			mound_mesh.top_radius = 1.2
			mound_mesh.bottom_radius = 5.0
			mound_mesh.height = 4.0
			mound.mesh = mound_mesh
			mound.position = at + Vector3(0, 2.0, 0)
			var sulfur := StandardMaterial3D.new()
			sulfur.albedo_color = Color("c9b13a")
			sulfur.emission_enabled = true
			sulfur.emission = Color("8a7a1a")
			mound_mesh.material = sulfur
			add_child(mound)
		else:
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.25
			trunk_mesh.bottom_radius = 0.9
			trunk_mesh.height = rng.randf_range(7.0, 15.0)
			var bark := StandardMaterial3D.new()
			bark.albedo_color = Color("3b332f")
			trunk_mesh.material = bark
			trunk.mesh = trunk_mesh
			trunk.position = at + Vector3(0, trunk_mesh.height * 0.5, 0)
			trunk.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			add_child(trunk)
	# Interior set pieces: lava in the council chamber and the throne cauldron, and the dormitory beds.
	var council: Dictionary = design.council_lava
	_glow_disc(mouth + Vector3(float(council.x), 0.2, float(council.z)), float(council.radius), Color("ff6a1f"))
	var cauldron: Dictionary = design.throne_cauldron
	_glow_disc(mouth + Vector3(float(cauldron.x), 3.0, float(cauldron.z)), float(cauldron.radius), Color("ff7a25"))
	var dorm: Dictionary = design.dormitory
	var a := Vector2(dorm["from"][0], dorm["from"][1])
	var b := Vector2(dorm["to"][0], dorm["to"][1])
	for i in int(dorm.beds):
		var t := (i + 0.5) / int(dorm.beds)
		for side in [-1, 1]:
			var spot := a.lerp(b, t) + Vector2(0, side * 6.5)
			var bed := MeshInstance3D.new()
			var bed_mesh := BoxMesh.new()
			bed_mesh.size = Vector3(5.0, 0.6, 2.2)
			var rock_bed := StandardMaterial3D.new()
			rock_bed.albedo_color = Color("4a4745")
			bed_mesh.material = rock_bed
			bed.mesh = bed_mesh
			bed.position = mouth + Vector3(spot.x, 0.3, spot.y)
			add_child(bed)
	if era == "arc2":
		_scatter_rubble()


## After the eruption the fortress is wrecked: loose blocks at the edges of the halls, never in the
## passages (so the carved routes stay open).
func _scatter_rubble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for chamber in design.chambers:
		for i in 7:
			var angle := rng.randf() * TAU
			var reach := float(chamber.radius) * rng.randf_range(0.55, 0.85)
			var offset := Vector2(cos(angle), sin(angle)) * reach
			if absf(offset.x) < 14.0 or absf(offset.y) < 14.0:
				continue # keep the passages through each hall open
			var size := Vector3(rng.randf_range(2.0, 6.0), rng.randf_range(1.5, 4.0), rng.randf_range(2.0, 6.0))
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			body.add_child(shape)
			var mesh := MeshInstance3D.new()
			var box_mesh := BoxMesh.new()
			box_mesh.size = size
			var stone := StandardMaterial3D.new()
			stone.albedo_color = Color("35323a")
			box_mesh.material = stone
			mesh.mesh = box_mesh
			body.add_child(mesh)
			body.position = mouth + Vector3(float(chamber.x) + offset.x, size.y * 0.4, float(chamber.z) + offset.y)
			body.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
			add_child(body)
			rubble.append(body)
