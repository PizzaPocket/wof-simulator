extends "res://scripts/box_site.gd"
## The SandWing stronghold (rough blockout; data/burn_stronghold_design.json): a squat, defensive
## walled fortress in open desert. Arc 1 (Burn) has enemy heads on spikes and the weirdling tower;
## Arc 2 (Thorn) has neither. Coordinates: courtyard centre at the origin, main gate +Z.
var piece_count := 0


func _design_path() -> String:
	return "res://data/burn_stronghold_design.json"


func _build(progress_callback: Callable) -> void:
	await _loading(progress_callback, 0.2, "Raising the walls")
	_make_walls()
	await _loading(progress_callback, 0.5, "Building the keep")
	_make_keep()
	_make_outbuildings()
	await _loading(progress_callback, 0.8, "Setting the era")
	_make_dunes()
	if era == "arc1":
		_make_burn_features()


func _wall(title: String, size: Vector3, at: Vector3) -> void:
	_box(title, size, at + Vector3(0, size.y * 0.5, 0), Color("c4a46a").darkened(rng.randf() * 0.12))
	piece_count += 1


func _make_walls() -> void:
	var w: Dictionary = design.wall
	var hw: float = w.half_w
	var hd: float = w.half_d
	var height: float = w.height
	var thick: float = w.thickness
	var gate: float = w.gate_width
	# Back and side walls run full length; the front wall leaves a gate.
	_wall("Wall", Vector3(hw * 2.0, height, thick), Vector3(0, 0, -hd))
	_wall("Wall", Vector3(thick, height, hd * 2.0), Vector3(-hw, 0, 0))
	_wall("Wall", Vector3(thick, height, hd * 2.0), Vector3(hw, 0, 0))
	var side := hw - gate * 0.5
	for sign in [-1, 1]:
		_wall("Wall", Vector3(side, height, thick), Vector3(sign * (gate * 0.5 + side * 0.5), 0, hd))
		_box("GateTower", Vector3(w.tower[0], w.tower[1], w.tower[0]), Vector3(sign * (gate * 0.5 + 7.0), float(w.tower[1]) * 0.5, hd), Color("b39455"))
	for corner in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(-hw, hd), Vector2(hw, hd)]:
		_box("CornerTower", Vector3(w.tower[0] * 1.25, w.tower[1], w.tower[0] * 1.25), Vector3(corner.x, float(w.tower[1]) * 0.5, corner.y), Color("b39455"))


## A hollow keep: four walls with a door in the front one, and a walkable roof.
func _make_keep() -> void:
	var k: Dictionary = design.keep
	var cx: float = k.x
	var cz: float = k.z
	var kw: float = k.w
	var kd: float = k.d
	var kh: float = k.height
	var t: float = k.thickness
	var door: float = k.door
	var color := Color("b8985c")
	_box("KeepWall", Vector3(kw, kh, t), Vector3(cx, kh * 0.5, cz - kd * 0.5), color)
	_box("KeepWall", Vector3(t, kh, kd), Vector3(cx - kw * 0.5, kh * 0.5, cz), color)
	_box("KeepWall", Vector3(t, kh, kd), Vector3(cx + kw * 0.5, kh * 0.5, cz), color)
	var side := (kw - door) * 0.5
	for sign in [-1, 1]:
		_box("KeepWall", Vector3(side, kh, t), Vector3(cx + sign * (door * 0.5 + side * 0.5), kh * 0.5, cz + kd * 0.5), color)
	_box("KeepLintel", Vector3(door, 12.0, t), Vector3(cx, kh - 6.0, cz + kd * 0.5), color)
	_box("KeepRoof", Vector3(kw, 2.0, kd), Vector3(cx, kh + 1.0, cz), Color("a8884f"))
	# A dais for the throne.
	_box("Dais", Vector3(26, 2.5, 14), Vector3(cx, 1.25, cz - kd * 0.5 + 12.0), Color("8a6c3e"))
	_sign("Throne hall", Vector3(cx, kh * 0.7, cz))


func _make_outbuildings() -> void:
	var cells: Dictionary = design.cells
	var size := Vector3(cells.size[0], cells.size[1], cells.size[2])
	_box("Cells", size, Vector3(float(cells.x), size.y * 0.5, float(cells.z)), Color("9a7d4a"))
	_sign("Prison cells", Vector3(float(cells.x), size.y + 7.0, float(cells.z)))
	var hatch: Dictionary = design.hatch
	_decor_box(Vector3(9, 0.3, 9), Vector3(float(hatch.x), 0.16, float(hatch.z)), Color("a68a55"))
	_sign("Sand-hidden tunnel to the Rainforest", Vector3(float(hatch.x), 9.0, float(hatch.z)))


## Low sand ridges for the "pale ocean" of the desert (visual only, never above 3 m).
func _make_dunes() -> void:
	for i in 26:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(230.0, 1100.0)
		var ridge := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(60.0, 150.0)
		mesh.height = mesh.radius * 2.0
		mesh.material = _material(Color("d6b87c").darkened(rng.randf() * 0.1))
		ridge.mesh = mesh
		ridge.scale = Vector3(1, 0.02, 0.6)
		ridge.position = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		ridge.rotation.y = rng.randf() * PI
		add_child(ridge)


## Burn's reign: enemy heads on spikes along the walls and the weirdling tower.
func _make_burn_features() -> void:
	var w: Dictionary = design.wall
	var hw: float = w.half_w
	var hd: float = w.half_d
	var height: float = w.height
	var spacing: float = design.spike_spacing
	for edge in [[Vector2(-hw, hd), Vector2(hw, hd)], [Vector2(-hw, -hd), Vector2(hw, -hd)], [Vector2(-hw, -hd), Vector2(-hw, hd)], [Vector2(hw, -hd), Vector2(hw, hd)]]:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var count := int(a.distance_to(b) / spacing)
		for i in count:
			var at := a.lerp(b, (i + 0.5) / count)
			if absf(at.x) < float(w.gate_width) * 0.5 + 12.0 and at.y > 0.0:
				continue
			_decor_cylinder(0.5, 0.7, 9.0, Vector3(at.x, height + 4.5, at.y), Color("3d2f26"), 6)
			var head := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 1.7
			mesh.height = 3.4
			mesh.material = _material(Color("7a2a24"))
			head.mesh = mesh
			head.position = Vector3(at.x, height + 10.2, at.y)
			add_child(head)
	var tower: Dictionary = design.weirdling_tower
	for i in int(tower.segments):
		var size := Vector3(11.0 - i * 0.45, 6.0, 11.0 - i * 0.45)
		var piece := _box("WeirdlingTower", size, Vector3(float(tower.x), 3.0 + 6.0 * i, float(tower.z)), Color("574a63").lightened(i * 0.012))
		piece.rotation.y = 0.33 * i
	_sign("Burn's weirdling tower", Vector3(float(tower.x), 96.0, float(tower.z)))
