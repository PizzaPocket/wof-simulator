extends "res://scripts/rock_site.gd"
## An IceWing palace (rough blockout; data/ice_palace_design.json): an ice mountain with a flight
## ledge, carved ice halls, three moons in a pale sky and a sheet of ice for ground. The era only
## changes the label so far (Glacier in Arcs 1 and 2, Snowfall in Arc 3).


func _design_path() -> String:
	return "res://data/ice_palace_design.json"


func _prepare_site() -> void:
	_pick_era()
	_prepare_cone_site()


func _make_solid() -> void:
	_make_cone_mountain()


## Three moons hang in the sky (the wiki says three are visible).
func _carve_extra() -> void:
	for i in 3:
		var moon := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = [340.0, 210.0, 150.0][i]
		mesh.height = mesh.radius * 2.0
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = [Color("f4f7ff"), Color("e6eefc"), Color("d9e4f5")][i]
		mesh.material = glow
		moon.mesh = mesh
		var angle := deg_to_rad([200.0, 235.0, 165.0][i])
		moon.position = Vector3(cos(angle) * 12000.0, [4200.0, 3400.0, 3000.0][i], sin(angle) * 12000.0 - 4000.0)
		add_child(moon)
