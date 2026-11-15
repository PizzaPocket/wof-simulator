extends "res://scripts/rock_site.gd"
## Jade Mountain and its academy: a tall mountain with an arrival ledge, a cave mouth and an
## authored cave complex carved from one rock mass. The plan lives in
## data/jade_mountain_design.json and is an interpretation (see docs/jade-mountain.md).
## Coordinates: the mountain axis is the world Y axis; the ledge faces +Z.
var residents: Array[Node] = []


func _design_path() -> String:
	return "res://data/jade_mountain_design.json"


func _prepare_site() -> void:
	_prepare_cone_site()


func _make_solid() -> void:
	_make_cone_mountain()


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
