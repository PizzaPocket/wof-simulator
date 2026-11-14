extends "res://scripts/rock_site.gd"
## Queen Scarlet's palace and arena in the Sky Kingdom (a rough blockout; see
## data/sky_palace_design.json). A flat-topped mountain carries a bowl-shaped arena with
## spires for prisoners. A rear peak holds the palace halls, half inside the rock and open to
## the sky at the front. The era changes the gold: Scarlet's reign (Arc 1) veins the stone
## with gold, and Queen Ruby (Arc 2) has had it stripped.
## Coordinates: the plateau centre is `mouth`; the palace sits toward -Z.
var era := "arc1"


func _design_path() -> String:
	return "res://data/sky_palace_design.json"


func _prepare_site() -> void:
	era = current_era()
	if not era in design.gold_by_era:
		era = "arc1"
	mouth = Vector3(0, float(design.mountain.plateau_y), 0)
	design.label = design.label_by_era[era]


func _make_rock() -> void:
	super._make_rock()
	rock_interior.set_shader_parameter("gold_veins", float(design.gold_by_era[era]))


func _make_solid() -> void:
	var settings: Dictionary = design.mountain
	_new_mountain()
	mountain.add_child(_cone(0, 0, float(settings.base_radius), float(settings.height)))
	for satellite in settings.satellites:
		mountain.add_child(_cone(float(satellite.x), float(satellite.z), float(satellite.radius), float(satellite.height)))
	# Slice the summit flat into the palace plateau.
	var cut := CSGCylinder3D.new()
	cut.radius = 3000.0
	cut.height = 1200.0
	cut.sides = 48
	cut.position = Vector3(0, mouth.y + 600.0, 0)
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.material = rock
	mountain.add_child(cut)
	# The rear peak that holds the palace halls rises from the plateau.
	var peak: Dictionary = settings.peak
	mountain.add_child(_cone(float(peak.x), float(peak.z), float(peak.radius), float(peak.height), mouth.y - 4.0))
	add_child(mountain)


## The arena: a stepped bowl (the stands) with prisoner spires on its floor.
func _carve_extra() -> void:
	var arena: Dictionary = design.arena
	var step_height: float = arena.step_height
	var centre := mouth + Vector3(arena.x, 0, arena.z)
	for i in int(arena.steps):
		var bowl := CSGCylinder3D.new()
		bowl.radius = float(arena.radius) - float(arena.step_inset) * i
		bowl.height = step_height * (i + 1) + 2.0
		bowl.sides = 48
		bowl.position = centre + Vector3(0, 1.0 - bowl.height * 0.5 + 1.0, 0)
		bowl.operation = CSGShape3D.OPERATION_SUBTRACTION
		bowl.material = rock_interior
		mountain.add_child(bowl)
	var floor_y := -step_height * int(arena.steps)
	for i in int(arena.spires):
		var angle := TAU * i / int(arena.spires)
		var spire := CSGCylinder3D.new()
		spire.radius = float(arena.spire_radius)
		spire.height = 44.0
		spire.sides = 12
		spire.position = centre + Vector3(cos(angle) * float(arena.spire_ring), floor_y + 22.0 - 1.0, sin(angle) * float(arena.spire_ring))
		spire.material = rock
		mountain.add_child(spire)
