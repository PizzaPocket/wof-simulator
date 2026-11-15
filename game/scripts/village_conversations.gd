extends CanvasLayer
## Nearby conversation, shuffled per character without repeats until the pool is spent.
var player: CharacterBody3D
var villagers: Array[CharacterBody3D] = []
var nearest: CharacterBody3D
var active: CharacterBody3D
var dialogue: Dictionary
var umber_dialogue: Dictionary
var bags: Dictionary = {}
var last_ids: Dictionary = {}
var lines: Array = []
var line_index := 0
var prompt: Button
var panel: HBoxContainer
var speech_box: PanelContainer
var choices: VBoxContainer
var speaker: Label
var words: Label
var advance: Button
var response: Button
var input_hint: Label
var column: VBoxContainer
var screen: Control
var goodbye: Button
var mouse_before := Input.MOUSE_MODE_VISIBLE
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	player.respawned.connect(close_conversation)
	layer = 3
	process_priority = 30
	rng.randomize()
	dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/village_dialogue.json"))
	umber_dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/village_umber_dialogue.json"))
	_build_ui()

func follow_player(current: CharacterBody3D) -> void:
	close_conversation()
	player.respawned.disconnect(close_conversation)
	player = current
	player.respawned.connect(close_conversation)
	nearest = null
	prompt.hide()

func _dialogue_pool() -> Dictionary:
	match player.character_id:
		"clay": return dialogue
		"umber": return umber_dialogue
		_: return {}

func _process(_delta: float) -> void:
	if active:
		if not is_instance_valid(active) or player.global_position.distance_to(active.global_position) > 12 or player.position.y < -10:
			close_conversation()
		elif Input.is_action_just_pressed("release_mouse") or Input.is_action_just_pressed("cancel_flight"):
			close_conversation()
		elif Input.is_action_just_pressed("interact"):
			next_line()
		return
	nearest = find_nearest()
	prompt.visible = nearest != null
	if nearest:
		prompt.text = "Talk to %s   ·   J / D-pad right" % nearest.display_name
		if Input.is_action_just_pressed("interact"):
			start_conversation(nearest)

func find_nearest() -> CharacterBody3D:
	if player.locomotion_state != &"grounded" or not player.is_on_floor():
		return null
	var best: CharacterBody3D
	var distance := 8.0
	var pool := _dialogue_pool()
	for npc in villagers:
		if npc == player or not pool.has(npc.character_id):
			continue
		var separation := player.global_position.distance_to(npc.global_position)
		if separation < distance and absf(player.position.y - npc.position.y) < 2.5:
			var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.3, npc.global_position + Vector3.UP, 1, [player.get_rid(), npc.get_rid()])
			if player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				best = npc
				distance = separation
	return best

func draw_exchange(id: String) -> Array:
	var pool: Array = _dialogue_pool().get(id, [])
	if pool.is_empty():
		return []
	id = "%s/%s" % [player.character_id, id]
	if not bags.has(id) or bags[id].is_empty():
		var bag: Array = range(pool.size())
		# A local RNG avoids global shuffle state coupling NPC movement to dialogue.
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var value: int = bag[i]
			bag[i] = bag[j]
			bag[j] = value
		if bag.size() > 1 and bag.back() == last_ids.get(id, -1):
			var value: int = bag[0]
			bag[0] = bag[-1]
			bag[-1] = value
		bags[id] = bag
	var index: int = bags[id].pop_back()
	last_ids[id] = index
	return pool[index].lines.duplicate(true)

func start_conversation(npc: CharacterBody3D) -> void:
	if active or not is_instance_valid(npc):
		return
	lines = draw_exchange(npc.character_id)
	if lines.is_empty():
		return
	active = npc
	active.talking = true
	player.conversation_locked = true
	mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prompt.hide()
	panel.show()
	line_index = 0
	_show_line()


func next_line() -> void:
	if not active:
		return
	# Clay's words are a deliberate player action, never another speaker card.
	if response.visible:
		choose_response()
	elif line_index + 1 < lines.size():
		line_index += 1
		_show_line()
	else:
		close_conversation()

func choose_response() -> void:
	if not active or not response.visible:
		return
	line_index += 2 # Consume the displayed NPC line and the chosen Clay reply.
	if line_index >= lines.size():
		close_conversation()
	else:
		_show_line()

func _show_line() -> void:
	speaker.text = lines[line_index].speaker
	words.text = lines[line_index].text
	var has_reply: bool = line_index + 1 < lines.size() and lines[line_index + 1].speaker == player.display_name
	response.visible = has_reply
	advance.visible = not has_reply and line_index + 1 < lines.size()
	if has_reply:
		response.text = lines[line_index + 1].text
		input_hint.text = "J / D-pad right · Enter / A"
		response.grab_focus()
	elif advance.visible:
		input_hint.text = "J / D-pad right to continue"
		advance.grab_focus()
	else:
		input_hint.text = "Esc / B to leave"
		goodbye.grab_focus()

func close_conversation() -> void:
	var was_active := active != null
	if is_instance_valid(active):
		active.talking = false
		active.idle_time = maxf(active.idle_time, 2.0)
	active = null
	player.conversation_locked = false
	panel.hide()
	for button in [advance, response, goodbye]:
		button.release_focus()
	if was_active:
		Input.mouse_mode = mouse_before

func _fit_width() -> void:
	# Logical canvas units, independent of the Retina framebuffer's pixel density.
	column.custom_minimum_size.x = minf(960, maxf(240, screen.size.x - 64))

const UiStyle = preload("res://scripts/ui_style.gd")

func _button_style(color: Color, shadow := 6) -> StyleBoxFlat:
	var style := UiStyle.card(24, 22, 12, shadow, color)
	return style

## Light, rounded buttons in the shared style, readable over the 3D scene.
func _style_button(button: Button, is_reply := false) -> void:
	button.add_theme_font_size_override("font_size", 20 if is_reply else 18)
	for key in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(key, UiStyle.INK)
	button.add_theme_color_override("font_pressed_color", UiStyle.BLUE_TEXT)
	button.add_theme_stylebox_override("normal", _button_style(Color(1, 1, 1, 0.95)))
	button.add_theme_stylebox_override("hover", _button_style(UiStyle.HOVER_GRAY))
	button.add_theme_stylebox_override("pressed", _button_style(UiStyle.BLUE_TINT))
	button.add_theme_stylebox_override("focus", UiStyle.fill(Color(0, 0, 0, 0), 24, UiStyle.BLUE, 2))

## Dialogue buttons are frosted cards; the holder (the card) is what goes into the layout.
var holders: Dictionary = {}

func _frost(button: Button, is_reply := false) -> void:
	button.add_theme_font_size_override("font_size", 20 if is_reply else 18)
	holders[button] = UiStyle.frost_button(button, 24)

func _holder(button: Button) -> Control:
	return holders[button]

func _build_ui() -> void:
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.add_theme_constant_override("margin_left", 32)
	bottom.add_theme_constant_override("margin_right", 32)
	bottom.add_theme_constant_override("margin_bottom", 56)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bottom)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(stack)
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(center)
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	screen.resized.connect(_fit_width)
	_fit_width()
	prompt = Button.new()
	prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt.custom_minimum_size.y = 48
	_frost(prompt)
	prompt.pressed.connect(func():
		if nearest:
			start_conversation(nearest))
	column.add_child(_holder(prompt))
	# Separate the person speaking from the player's actions, as in the reference.
	panel = HBoxContainer.new()
	panel.add_theme_constant_override("separation", 32)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(panel)
	var speech := VBoxContainer.new()
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.size_flags_vertical = Control.SIZE_SHRINK_END
	speech.add_theme_constant_override("separation", 8)
	speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(speech)
	speaker = Label.new()
	speaker.add_theme_font_size_override("font_size", 15)
	speaker.add_theme_color_override("font_color", UiStyle.INK_SECONDARY)
	speaker.add_theme_font_override("font", UiStyle.bold_font())
	speech_box = PanelContainer.new()
	UiStyle.frost_panel(speech_box, 28, 30, 22)
	speech_box.custom_minimum_size.y = 112
	speech.add_child(speech_box)
	var speech_content := VBoxContainer.new()
	speech_content.add_theme_constant_override("separation", 8)
	speech_box.add_child(speech_content)
	speech_content.add_child(speaker)
	words = Label.new()
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_size_override("font_size", 22)
	words.add_theme_color_override("font_color", UiStyle.INK)
	speech_content.add_child(words)
	choices = VBoxContainer.new()
	choices.custom_minimum_size.x = 300
	choices.size_flags_vertical = Control.SIZE_SHRINK_END
	choices.add_theme_constant_override("separation", 10)
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(choices)
	response = Button.new()
	response.alignment = HORIZONTAL_ALIGNMENT_LEFT
	response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	response.custom_minimum_size.y = 48
	_frost(response, true)
	response.pressed.connect(choose_response)
	choices.add_child(_holder(response))
	advance = Button.new()
	advance.text = "Continue"
	advance.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_frost(advance)
	advance.pressed.connect(next_line)
	choices.add_child(_holder(advance))
	goodbye = Button.new()
	goodbye.text = "Goodbye"
	goodbye.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_frost(goodbye)
	goodbye.pressed.connect(close_conversation)
	choices.add_child(_holder(goodbye))
	input_hint = Label.new()
	input_hint.add_theme_font_size_override("font_size", 13)
	input_hint.add_theme_color_override("font_color", UiStyle.INK)
	input_hint.add_theme_constant_override("outline_size", 5)
	input_hint.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
	input_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	choices.add_child(input_hint)
	panel.hide()
	prompt.hide()
