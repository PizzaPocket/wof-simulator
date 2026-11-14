extends Node3D
## Grid edges sample the same world coordinates. Skirts seal mixed-detail edges.
const Data = preload("res://scripts/continent_data.gd")
var mesh_instance: MeshInstance3D
var collision: StaticBody3D
var detail := 0
var bounds := Rect2()

func build(data: Data, rect: Rect2, subdivisions: int, material: Material, with_collision: bool) -> void:
	bounds = rect
	detail = subdivisions
	position = Vector3(rect.position.x, 0, rect.position.y)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var stride := subdivisions + 1
	for z in stride:
		for x in stride:
			var p := rect.position + rect.size * Vector2(x, z) / subdivisions
			vertices.append(Vector3(p.x - rect.position.x, data.height_at(p), p.y - rect.position.y))
			normals.append(data.normal_at(p))
			colors.append(data.color_at(p).srgb_to_linear())
	for z in subdivisions:
		for x in subdivisions:
			var a := z * stride + x
			indices.append_array([a, a+1, a+stride, a+1, a+stride+1, a+stride])
	# Physics contains only the actual ground, never the vertical skirts.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var ground := ArrayMesh.new()
	ground.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if with_collision:
		collision = StaticBody3D.new()
		collision.name = "TerrainCollision"
		var shape := CollisionShape3D.new()
		shape.shape = ground.create_trimesh_shape()
		collision.add_child(shape)
		add_child(collision)
	var edges: Array[PackedInt32Array] = []
	var top := PackedInt32Array(); var bottom := PackedInt32Array()
	var left := PackedInt32Array(); var right := PackedInt32Array()
	for i in stride:
		top.append(i); bottom.append(subdivisions * stride + i)
		left.append(i * stride); right.append(i * stride + subdivisions)
	edges.append_array([top, bottom, left, right])
	for edge in edges:
		for i in subdivisions:
			var a: int = edge[i]; var b: int = edge[i+1]
			var base := vertices.size()
			vertices.append_array([vertices[a], vertices[b], vertices[a] - Vector3.UP * 90, vertices[b] - Vector3.UP * 90])
			for j in 4:
				normals.append(normals[a]); colors.append(colors[a])
			indices.append_array([base,base+1,base+2,base+1,base+3,base+2])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = surface
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

func install(rect: Rect2, subdivisions: int, arrays: Array, material: Material) -> void:
	bounds=rect
	detail=subdivisions
	position=Vector3(rect.position.x,0,rect.position.y)
	var surface:=ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh_instance=MeshInstance3D.new()
	mesh_instance.mesh=surface
	mesh_instance.material_override=material
	mesh_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

func install_heightmap(heights: PackedFloat32Array) -> void:
	collision=StaticBody3D.new()
	collision.name="TerrainCollision"
	var shape:=CollisionShape3D.new()
	var terrain:=HeightMapShape3D.new()
	terrain.map_width=detail+1
	terrain.map_depth=detail+1
	var spacing := bounds.size.x/detail
	var scaled := heights.duplicate()
	for i in scaled.size(): scaled[i] /= spacing
	terrain.map_data=scaled
	shape.shape=terrain
	shape.position=Vector3(bounds.size.x*.5,0,bounds.size.y*.5)
	shape.scale=Vector3.ONE*spacing
	collision.add_child(shape)
	add_child(collision)
