extends SceneTree
## Functional response checks and native screenshots at several display sizes.
var failures: Array[String] = []
var output := "res://../cache/dialogue-ui-split"
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func layout_frames() -> void:
	for i in 5:
		await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output).path_join(name + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var village = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	root.add_child(village)
	await physics_frame
	await physics_frame
	var player = village.get_node("Clay")
	var chat = village.get_node("Conversations")
	var umber = village.get_node("Umber")
	for npc in chat.villagers:
		npc.set_physics_process(false)
	player.position = umber.position + Vector3(5, 0, 1)
	player.set_physics_process(false)
	var camera := Camera3D.new()
	village.add_child(camera)
	camera.current = true
	camera.fov = 55
	camera.position = umber.position + Vector3(9, 8, 16)
	camera.look_at(umber.position + Vector3(1, 2, 0))
	chat.start_conversation(umber)
	chat.lines = chat.dialogue.umber[0].lines.duplicate(true)
	chat.line_index = 0
	chat._show_line()
	var logical_width := 0.0
	for config in [["window-1280x800",1280,800], ["retina-2560x1600",2560,1600], ["desktop-2560x1440",2560,1440], ["ultrawide-3440x1440",3440,1440], ["small-800x500",800,500]]:
		root.size = Vector2i(config[1], config[2])
		await layout_frames()
		var screen_rect: Rect2 = chat.screen.get_global_rect()
		var panel_rect: Rect2 = chat.panel.get_global_rect()
		check(screen_rect.encloses(panel_rect), "Dialogue fits " + config[0])
		check(panel_rect.size.x <= 961, "Bounded reading width " + config[0])
		check(chat.response.has_focus(), "Reply has keyboard/controller focus")
		check(chat.choices.get_global_rect().position.x > chat.speech_box.get_global_rect().end.x, "Choices sit separately to the right")
		check(chat.speaker.text == "Umber" and chat.response.text == "Oh. Is it a house?", "NPC words and player response separated")
		if logical_width == 0: logical_width = panel_rect.size.x
		check(absf(panel_rect.size.x - logical_width) < 1, "Consistent logical scale " + config[0])
		print(config[0], ": canvas=", screen_rect.size, " panel=", panel_rect, " scale=", root.get_final_transform().get_scale())
		await capture(config[0])
	# Check the actual longest exchanges for every character, including final replies.
	for id in chat.dialogue:
		for exchange in chat.dialogue[id]:
			chat.lines = exchange.lines.duplicate(true)
			chat.line_index = 0
			while chat.line_index < chat.lines.size():
				chat._show_line()
				await layout_frames()
				check(chat.speaker.text != "Clay", "Clay must never be a speaker card")
				check(chat.screen.get_global_rect().encloses(chat.panel.get_global_rect()), "All dialogue fits: " + exchange.id)
				check(chat.words.size.y + .5 >= chat.words.get_minimum_size().y, "NPC copy is not clipped")
				chat.line_index += 2 if chat.response.visible else 1
	root.size = Vector2i(1280,800)
	chat.lines = chat.dialogue.umber[0].lines.duplicate(true)
	chat.line_index = 0
	chat._show_line()
	chat.response.pressed.emit()
	check(chat.line_index == 2 and chat.speaker.text == "Umber" and not chat.response.visible, "Clicking reply advances directly to NPC answer")
	await layout_frames()
	await capture("npc-answer")
	chat.next_line()
	check(chat.active == null and not player.conversation_locked, "Final NPC answer releases conversation")
	chat.start_conversation(umber)
	chat.lines = chat.dialogue.umber.filter(func(e): return e.lines.size() == 2)[0].lines.duplicate(true)
	chat.line_index = 0
	chat._show_line()
	chat.response.pressed.emit()
	check(chat.active == null and not player.conversation_locked, "Final player response closes without a Clay speaker card")
	# Route real GUI key and controller events through the focused response button.
	for use_controller in [false, true]:
		chat.start_conversation(umber)
		chat.lines = chat.dialogue.umber[0].lines.duplicate(true)
		chat.line_index = 0
		chat._show_line()
		await layout_frames()
		for down in [true, false]:
			var event: InputEvent
			if use_controller:
				var pad := InputEventJoypadButton.new()
				pad.button_index = JOY_BUTTON_A
				pad.pressed = down
				event = pad
			else:
				var key := InputEventKey.new()
				key.keycode = KEY_ENTER
				key.pressed = down
				event = key
			Input.parse_input_event(event)
			await process_frame
		await process_frame
		check(chat.line_index == 2, "Focused response accepts " + ("controller A" if use_controller else "Enter"))
		chat.close_conversation()
	print("Dialogue UI review: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
