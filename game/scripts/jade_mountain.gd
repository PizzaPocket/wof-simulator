extends "res://scripts/rock_site.gd"
## Jade Mountain and its academy: a tall mountain with an arrival ledge, a cave mouth and an
## authored cave complex carved from one rock mass. The plan lives in
## data/jade_mountain_design.json and is an interpretation (see docs/jade-mountain.md).
## Coordinates: the mountain axis is the world Y axis; the ledge faces +Z.


func _design_path() -> String:
	return "res://data/jade_mountain_design.json"


func _prepare_site() -> void:
	_prepare_cone_site()


func _make_solid() -> void:
	_make_cone_mountain()
