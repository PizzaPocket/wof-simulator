extends Node3D
## Only this node knows about the model. Movement/collision never depend on its rig.
## Clay's builder exports +Z forward; the player faces -Z. Correct that here.

@export var use_procedural_materials: bool = true
@export var model_path: String = "res://assets/clay.glb"
@export var model_scale: float = 2.0
@export var model_y_offset: float = 0.09
@export var model_yaw_degrees: float = 180.0
var model_loaded: bool = false
var model_status: String = ""
var motion: Node


func _ready() -> void:
	var instance: Node3D
	if ResourceLoader.exists(model_path):
		var scene := load(model_path) as PackedScene
		if scene:
			instance = scene.instantiate() as Node3D
	if instance:
		add_child(instance)
		instance.scale = Vector3.ONE * model_scale
		instance.position.y = model_y_offset
		instance.rotation_degrees.y = model_yaw_degrees
		_prepare_materials(instance)
		motion = preload("res://scripts/creature_motion.gd").new()
		add_child(motion)
		motion.setup(instance, get_parent())
		model_loaded = true
		model_status = "Clay model loaded"
		if motion.anatomy.is_empty():
			model_status = "Clay loaded · rebuild asset to export locomotion anatomy"
	else:
		_make_placeholder()
		model_status = "Placeholder · build or copy Clay to game/assets/clay.glb"


func _prepare_materials(node: Node, rig: Skeleton3D = null) -> void:
	if not rig:
		for candidate in node.find_children("*", "Skeleton3D", true, false):
			rig = candidate
			break
	# Explicitly enable standard glTF COLOR_0: some Godot imports leave the
	# material's vertex-colour switch off, even when the mesh has colour data.
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			if use_procedural_materials and preload("res://scripts/clay_materials.gd").supported(node, surface):
				node.set_surface_override_material(surface, preload("res://scripts/clay_materials.gd").make_material(rig))
				continue
			if node.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
				var source := node.get_active_material(surface) as StandardMaterial3D
				var material := source.duplicate() as StandardMaterial3D if source else StandardMaterial3D.new()
				material.vertex_color_use_as_albedo = true
				node.set_surface_override_material(surface, material)
	for child in node.get_children():
		_prepare_materials(child, rig)


func _make_placeholder() -> void:
	# A deliberately simple marker so a fresh clone is playable before a model build.
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.7
	mesh.height = 2.2
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = 1.1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("be703e")
	body.material_override = material
	add_child(body)
	var nose := MeshInstance3D.new()
	var marker := PrismMesh.new()
	marker.size = Vector3(0.7, 0.4, 1.0)
	nose.mesh = marker
	nose.position = Vector3(0, 1.7, -0.8)
	nose.material_override = material
	add_child(nose)
