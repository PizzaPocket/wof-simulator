extends RefCounted
## One source for playable village actors and the 3D review room.
static func make_actor(id: String) -> CharacterBody3D:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonists.json"))
	var design: Dictionary = profiles.get(id, {})
	var actor := preload("res://scripts/village_npc.gd").new()
	actor.name = str(design.get("name", id.capitalize()))
	actor.character_id = id
	actor.display_name = str(design.get("name", id.capitalize()))
	actor.playable = profiles.has(id) and bool(design.get("gameplay", true))
	actor.age = int(design.get("age", 9))
	actor.is_human = design.get("species", "human") == "human"
	if actor.is_human:
		actor.can_fly = false
		actor.can_climb = false
		actor.can_breathe_fire = false
		actor.walk_speed = 2.6
		actor.sprint_speed = 5.8
		actor.jump_speed = 6.2
		actor.gravity = 20.0
		actor.falling_gravity = 26.0
	else:
		actor.can_breathe_fire = id != "blue"
		actor.can_climb = true
	actor.default_camera_distance = 3.8 if actor.is_human else maxf(10.0, float(design.get("model_scale", 2.0)) * 7.5)
	var visual := Node3D.new()
	visual.name = "Visual"
	if not design.is_empty() and not actor.is_human:
		visual.set_script(preload("res://scripts/clay_visual.gd") if id == "umber" else preload("res://scripts/tribe_dragon_visual.gd"))
		visual.model_scale = float(design.get("model_scale", 1.55))
	elif actor.playable:
		visual.set_script(preload("res://scripts/human_visual.gd"))
	actor.add_child(visual)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position.y = 1.25 if actor.is_human else 1.8
	actor.add_child(pivot)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.margin = 0.3
	arm.spring_length = actor.default_camera_distance
	pivot.add_child(arm)
	return actor
