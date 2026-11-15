extends CanvasLayer
## Each unlocked protagonist stays in the world when someone else takes over.
signal switched(previous: CharacterBody3D, current: CharacterBody3D)

const SWITCH_RANGE := 7.0
var save_path := "user://protagonists.cfg"
var player: CharacterBody3D
var protagonists: Dictionary = {}
## Base ids (a character's model variants share one id, so the blind Starflight is "starflight").
## The collection is saved and shared by every scene, and may include characters who are not in
## the current scene.
var unlocked := PackedStringArray()
var camera: Camera3D
var status: Label
var hint: Label


func register(body: CharacterBody3D) -> void:
	protagonists[body.character_id] = body


static func _base(id: String) -> String:
	return id.trim_suffix("_blind")


## The body in this scene for a base id, or null when that character is not here.
func _body_for(base: String) -> CharacterBody3D:
	for id in protagonists:
		if _base(str(id)) == base:
			return protagonists[id]
	return null


func _display_name_for(base: String) -> String:
	var body := _body_for(base)
	if body:
		return body.display_name
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonists.json"))
	return str(profiles.get(base, {}).get("name", base.capitalize()))


## An unlocked character who is not in this scene joins the player's side when cycled to.
func _summon(base: String) -> CharacterBody3D:
	var cast := preload("res://scripts/cast_manager.gd")
	var id: String = cast.variant_for(base, cast.current_era())
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonists.json"))
	if not profiles.has(id):
		return null
	var side := Basis(Vector3.UP, player.pivot.rotation.y) * Vector3(5.0, 0.4, 0.0)
	return cast.make_actor(get_parent(), id, player.global_position + side, self)


func _ready() -> void:
	camera = player.arm.get_child(0)
	var saved := ConfigFile.new()
	if not save_path.is_empty() and saved.load(save_path) == OK:
		for id in saved.get_value("roster", "unlocked", PackedStringArray()):
			if not unlocked.has(_base(str(id))):
				unlocked.append(_base(str(id)))
	if not unlocked.has(_base(player.character_id)):
		unlocked.insert(0, _base(player.character_id))
	_make_status()


func _physics_process(_delta: float) -> void:
	var target := nearest_protagonist() if not player.conversation_locked else null
	if not player.conversation_locked:
		if target and Input.is_action_just_pressed("possess_protagonist"):
			_switch(target)
			target = nearest_protagonist()
		elif unlocked.size() > 1 and Input.is_action_just_pressed("cycle_protagonist"):
			var next := (unlocked.find(_base(player.character_id)) + 1) % unlocked.size()
			var body := _body_for(unlocked[next])
			if body == null:
				body = _summon(unlocked[next])
			if body:
				_switch(body)
			target = nearest_protagonist()
	var names := PackedStringArray()
	for id in unlocked:
		names.append(_display_name_for(id))
	status.text = "Playing as %s  ·  %s: %s" % [player.display_name, "Collected", ", ".join(names)]
	hint.visible = not player.conversation_locked and (target != null or unlocked.size() > 1)
	var cycle_hint := "Tab / D-pad left · Switch collected character" if unlocked.size() > 1 else ""
	if target:
		hint.text = "X / Square · %s %s" % ["Play as" if unlocked.has(_base(target.character_id)) else "Unlock", target.display_name]
		if not cycle_hint.is_empty():
			hint.text += "\n" + cycle_hint
	else:
		hint.text = cycle_hint


func nearest_protagonist() -> CharacterBody3D:
	var nearest: CharacterBody3D
	var best := SWITCH_RANGE
	for body in protagonists.values():
		if body == player or absf(player.global_position.y - body.global_position.y) > 2.5:
			continue
		var distance: float = player.global_position.distance_to(body.global_position)
		if distance >= best:
			continue
		var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP,
			body.global_position + Vector3.UP, 1, [player.get_rid(), body.get_rid()])
		if player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			nearest = body
			best = distance
	return nearest


func _switch(target: CharacterBody3D) -> void:
	if not unlocked.has(_base(target.character_id)):
		unlocked.append(_base(target.character_id))
		if not save_path.is_empty():
			var saved := ConfigFile.new()
			saved.set_value("roster", "unlocked", unlocked)
			var error := saved.save(save_path)
			if error != OK:
				push_warning("Could not save the protagonist collection: %s" % error_string(error))
	var previous := player
	previous.set_player_controlled(false)
	player = target
	player.set_player_controlled(true)
	player.pivot.rotation = previous.pivot.rotation
	player.arm.spring_length = player.default_camera_distance * previous.arm.spring_length / previous.default_camera_distance
	camera.reparent(player.arm, false)
	camera.position = Vector3.BACK * player.arm.get_hit_length()
	camera.make_current()
	camera.reset_physics_interpolation()
	switched.emit(previous, player)


func _make_status() -> void:
	var UiStyle := preload("res://scripts/ui_style.gd")
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# One light card keeps the status and the prompt readable over the scene.
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.frost_panel(card, 12, 14, 9)
	margin.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	status = Label.new()
	hint = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", UiStyle.INK)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiStyle.BLUE_TEXT)
	for label in [status, hint]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack.add_child(label)
