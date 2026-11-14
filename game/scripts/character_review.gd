extends "res://scripts/playground.gd"
## The real game characters, shown at a common inspection stage and playable with one click.
const IDS := ["clay", "umber", "moon", "blue", "darkstalker", "wren"]
var actors: Dictionary = {}
var profiles: Dictionary
var selected_id := ""
var inspecting := true
var pose := 0
var dragging := false
var camera: Camera3D
var heading: Label
var details_label: Label
var mode_button: Button
var selector: OptionButton
var pose_selector: OptionButton
var reference: TextureRect
var instructions: Label
var entered_at := 0
var prior_scale_mode: int
var prior_scale_size: Vector2i

func _ready() -> void:
	prior_scale_mode = get_window().content_scale_mode
	prior_scale_size = get_window().content_scale_size
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_fit_review_scale()
	get_window().size_changed.connect(_fit_review_scale)
	entered_at = Time.get_ticks_msec()
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonists.json"))
	_make_environment()
	_box("ReviewFloor", Vector3(220, 1, 220), Vector3(0, -0.5, 0), Color("778579"))
	for i in range(-15, 16):
		_stripe(Vector3(i * 2, 0.008, 0), Vector3(0.015, 0.01, 60))
		_stripe(Vector3(0, 0.008, i * 2), Vector3(60, 0.01, 0.015))
	camera = player.arm.get_child(0)
	actors["clay"] = player
	for id in IDS.slice(1):
		var actor := preload("res://scripts/protagonist_factory.gd").make_actor(id)
		add_child(actor)
		actors[id] = actor
	for actor in actors.values():
		actor.set_physics_process(false)
		actor.hide()
		actor.collision_layer = 0
		if actor.visual.motion:
			actor.visual.motion.enabled = false
	_make_review_ui()
	select_character("umber")

func select_character(id: String) -> void:
	if not selected_id.is_empty():
		player.set_player_controlled(false)
		player.set_physics_process(false)
		player.hide()
		player.collision_layer = 0
		if player.visual.motion:
			player.visual.motion.enabled = false
	selected_id = id
	player = actors[id]
	player.show()
	player.set_player_controlled(true)
	player.collision_layer = 2 if id != "clay" else 1
	player.collision_mask = 1
	player.position = Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	player.visual.rotation = Vector3.ZERO
	if player.visual.motion:
		player.visual.motion.enabled = true
		player.visual.motion.reset_motion()
	camera.reparent(player.arm, false)
	camera.make_current()
	selector.select(IDS.find(id))
	heading.text = player.display_name
	mode_button.disabled = id == "darkstalker"
	details_label.text = {
		"clay": "MudWing\nThe Dragonet Prophecy",
		"umber": "MudWing\nThe Hybrid Prince\n\nCopper-brown scales, amber eyes, nose scar, fitted pouch and throat buckle.",
		"moon": "NightWing\nMoon Rising\n\nGreen eyes, two silver teardrop scales and starry underwings.",
		"blue": "SilkWing\nThe Lost Continent\n\nFour supported wings, a rearward resting fold, antennae and blue-violet scales.",
		"darkstalker": "NightWing–IceWing\nAncient Darkstalker\n\nNow in the village clearing. His giant world scale is inferred; he is not collectible.",
		"wren": "Human · age 15\nDragonslayer\n\nDark curls, freckles, brown eyes, travel clothes and a back-carried sword."
	}[id]
	pose_selector.visible = not player.is_human
	pose_selector.select(0)
	pose = 0
	inspecting = true
	_set_mode()
	frame_body()
	_load_reference()

func _set_mode() -> void:
	player.conversation_locked = inspecting
	player.set_physics_process(not inspecting)
	mode_button.text = "Play as " + player.display_name if inspecting else "Inspect " + player.display_name
	instructions.text = "Drag to rotate · scroll to zoom\nQ / E or right stick also rotates\nTab or 1–6 changes character" if inspecting else "WASD / left stick · Shift to run\nSpace / A to jump · click to aim\nF: wings · V: fire (dragons)\nHumans walk, run and jump"
	if inspecting:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_apply_pose()
	else:
		pose = 0
		player.position = Vector3(0, 0.08, 0)
		player.velocity = Vector3.ZERO
		player._set_state(&"grounded")
		player.visual.rotation = Vector3.ZERO
		if player.visual.motion:
			player.visual.motion.reset_motion()
		frame_body()

func _exit_tree() -> void:
	get_window().size_changed.disconnect(_fit_review_scale)
	get_window().content_scale_mode = prior_scale_mode
	get_window().content_scale_size = prior_scale_size

func _fit_review_scale() -> void:
	var window_size := get_window().size
	get_window().content_scale_size = Vector2i(mini(1280, window_size.x), mini(800, window_size.y))

func _apply_pose() -> void:
	if player.is_human:
		player._set_state(&"grounded")
		return
	var motion = player.visual.motion
	motion.fold_target = 1.0 if pose == 0 else 0.0
	player.position.y = float(player.visual.model_scale) * 1.6 if pose == 2 else 0.05
	player.velocity = Vector3(0, 0, -10) if pose == 2 else Vector3.ZERO
	player.ground_distance = 10.0 if pose == 2 else 0.0
	player._set_state(&"flying" if pose == 2 else &"grounded")
	for mesh in motion.meshes:
		for i in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(i)
			if material is ShaderMaterial:
				material.set_shader_parameter("clay_mode", pose == 3)

func frame_body() -> void:
	var scale_value: float = 1.0 if player.is_human else float(player.visual.model_scale)
	player.pivot.position = Vector3(0, 0.85, 0) if player.is_human else Vector3(0, scale_value * 1.0, -scale_value * 0.20)
	player.pivot.rotation = Vector3(-0.18, PI + 0.60, 0)
	player.arm.spring_length = 2.8 if player.is_human else scale_value * (7.0 if pose > 0 else 5.7)
	camera.h_offset = -player.arm.spring_length * 0.13
	camera.position = Vector3.BACK * player.arm.spring_length

func frame_face() -> void:
	var model: Node3D = player.visual.human.model if player.is_human else player.visual.motion.model
	var point := Vector3(0, 1.43, 0.10) if player.is_human else Vector3(0, 1.78, 1.70)
	if selected_id == "umber": point.y = 1.59
	player.pivot.position = player.to_local(model.to_global(point))
	player.pivot.rotation = Vector3(-0.02, PI + 0.90, 0)
	player.arm.spring_length = 0.8 if player.is_human else float(player.visual.model_scale) * 1.25
	camera.h_offset = -player.arm.spring_length * 0.18
	camera.position = Vector3.BACK * player.arm.spring_length

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - entered_at > 500 and Input.is_action_just_pressed("character_review"):
		get_tree().change_scene_to_file("res://scenes/mudwing_wetlands.tscn")
		return
	if inspecting:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		player.pivot.rotation.y -= look.x * delta * 1.8
		player.pivot.rotation.x = clampf(player.pivot.rotation.x - look.y * delta * 1.4, -1.25, 1.15)
	if Input.is_action_just_pressed("cycle_protagonist"):
		select_character(IDS[(IDS.find(selected_id) + 1) % IDS.size()])
	if player.position.y < -10:
		player.position = Vector3(0, 0.1, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
		select_character(IDS[event.physical_keycode - KEY_1])
	if not inspecting:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			player.arm.spring_length = clampf(player.arm.spring_length * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), 0.35, 38.0)
	if event is InputEventMouseMotion and dragging:
		player.pivot.rotation.y -= event.relative.x * 0.007
		player.pivot.rotation.x = clampf(player.pivot.rotation.x - event.relative.y * 0.007, -1.25, 1.15)

func _load_reference() -> void:
	var file: String = {"clay": "", "umber": "umber-cover.jpg", "moon": "moon-cover.jpg", "blue": "blue-cover.jpg", "darkstalker": "darkstalker-cover.jpg", "wren": "wren-flames-of-hope.png"}[selected_id]
	reference.texture = null
	reference.hide()
	var path := ProjectSettings.globalize_path("res://../cache/protagonist-references/" + file)
	if not file.is_empty() and FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			reference.texture = ImageTexture.create_from_image(image)

func _button(text_value: String, parent: Control, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _make_review_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size.x = 230
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.085, 0.065, 0.96)
	style.set_corner_radius_all(8)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 18)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 10)
	scroll.add_child(stack)
	selector = OptionButton.new()
	for id in IDS:
		selector.add_item("Clay" if id == "clay" else profiles[id].name)
	selector.item_selected.connect(func(index): select_character(IDS[index]))
	stack.add_child(selector)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 27)
	stack.add_child(heading)
	details_label = Label.new()
	details_label.custom_minimum_size.x = 210
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.add_theme_font_size_override("font_size", 16)
	details_label.add_theme_color_override("font_color", Color("e1e5d5"))
	stack.add_child(details_label)
	mode_button = _button("", stack, func(): inspecting = not inspecting; _set_mode())
	pose_selector = OptionButton.new()
	for value in ["Rest / folded wings", "Wings spread", "Flight pose", "Plain clay · shape review"]:
		pose_selector.add_item(value)
	pose_selector.item_selected.connect(func(index): pose = index; inspecting = true; _set_mode(); frame_body())
	stack.add_child(pose_selector)
	var row := HBoxContainer.new()
	stack.add_child(row)
	_button("Whole body", row, frame_body)
	_button("Face", row, frame_face)
	_button("Show / hide reference", stack, func(): reference.visible = not reference.visible and reference.texture != null)
	instructions = Label.new()
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color("d5dfc9"))
	stack.add_child(instructions)
	_button("Return to village · F8", stack, func(): get_tree().change_scene_to_file("res://scenes/mudwing_wetlands.tscn"))
	reference = TextureRect.new()
	canvas.add_child(reference)
	reference.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	reference.position = Vector2(-310, 20)
	reference.size = Vector2(290, 440)
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference.hide()
	var fit := func():
		scroll.custom_minimum_size.y = minf(640, get_viewport().get_visible_rect().size.y - 76)
	get_viewport().size_changed.connect(fit)
	fit.call()
