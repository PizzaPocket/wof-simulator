extends "res://scripts/rock_site.gd"
## Jade Mountain and its academy: a tall mountain with an arrival ledge, a cave mouth and an
## authored cave complex carved from one rock mass. The plan lives in
## data/jade_mountain_design.json and is an interpretation (see docs/jade-mountain.md).
## Coordinates: the mountain axis is the world Y axis; the ledge faces +Z.

var residents: Array[Node] = []


func _design_path() -> String:
	return "res://data/jade_mountain_design.json"


func _prepare_site() -> void:
	var settings: Dictionary = design.mountain
	var radius_at_ledge: float = float(settings.base_radius) * (1.0 - float(settings.ledge_y) / float(settings.height))
	mouth = Vector3(0, float(settings.ledge_y), radius_at_ledge)


func _make_solid() -> void:
	_new_mountain()
	var settings: Dictionary = design.mountain
	mountain.add_child(_cone(0, 0, float(settings.base_radius), float(settings.height)))
	for satellite in settings.satellites:
		mountain.add_child(_cone(float(satellite.x), float(satellite.z), float(satellite.radius), float(satellite.height)))
	# Seeded foothills, ridges and summit spires break up the silhouette. None may
	# crowd the approach to the cave mouth.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2600
	for i in 22:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(260.0, 800.0)
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		var radius := rng.randf_range(110.0, 270.0)
		var height := rng.randf_range(650.0, 1800.0)
		if _crowds_mouth(x, z, radius, height, 0.0):
			continue
		mountain.add_child(_cone(x, z, radius, height))
	for i in 12:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(0.0, 230.0)
		var base_y := rng.randf_range(1150.0, 1450.0)
		var height := rng.randf_range(520.0, 1050.0)
		mountain.add_child(_cone(cos(angle) * distance, sin(angle) * distance, rng.randf_range(70.0, 130.0), height, base_y))
	# The ledge: a buttress of rock rising from the slope to the cave mouth.
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


## Starflight, blind and head librarian in Arc 2, stands in the library.
func _on_site_ready() -> void:
	for chamber in design.chambers:
		if chamber.id != "library":
			continue
		var npc := preload("res://scripts/protagonist_factory.gd").make_actor("starflight_blind")
		npc.listener = player
		npc.position = mouth + Vector3(float(chamber.x) + 6.0, 0.4, float(chamber.z))
		npc.activity = "at the librarian's desk"
		add_child(npc)
		residents.append(npc)
