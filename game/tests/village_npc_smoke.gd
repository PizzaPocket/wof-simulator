extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	var village = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	root.add_child(village)
	await ticks(15)
	var player = village.get_node("Clay")
	var chat = village.get_node("Conversations")
	check(chat.villagers.size() == 7, "Four original villagers plus Moon, Blue and Wren must spawn")
	var umber = village.get_node("Umber")
	check(umber.visual.model_loaded, "Umber must load the existing dragon model")
	check(umber.visual.model_scale < player.visual.model_scale, "Umber must be smaller than Clay")
	check(not umber.visual.motion.player_controlled, "NPC pose must ignore player inputs")
	check(village.get_node("Kai").age == 9 and village.get_node("Camille").age == 9 and village.get_node("Corinne").age == 6, "Child ages")
	for id in chat.dialogue:
		var seen: Array[String] = []
		var previous := ""
		for i in chat.dialogue[id].size():
			var exchange: Array = chat.draw_exchange(id)
			var key: String = exchange[0].text
			check(not seen.has(key), "Dialogue repeated before exhaustion: " + id)
			seen.append(key)
			previous = key
		check(chat.draw_exchange(id)[0].text != previous, "Dialogue repeated across bag boundary: " + id)
	var start: Vector3 = umber.position
	var human_start: Vector3 = village.get_node("Camille").position
	var actions := {}
	for i in 1200:
		await physics_frame
		for npc in chat.villagers:
			actions[npc.activity] = true
	check(umber.position.distance_to(start) > 0.5, "Umber must wander")
	check(village.get_node("Camille").position.distance_to(human_start) > 0.3, "Children must wander")
	check(actions.has("wandering") and actions.has("looking around"), "Idle and roaming states must both run")
	# Park beside the child and exercise real input rather than only calling UI methods.
	var kai = village.get_node("Kai")
	player.position = kai.position + Vector3(2.5, 0.1, 0)
	player.velocity = Vector3.ZERO
	await ticks(12)
	check(chat.find_nearest() != null, "Nearby villagers must be discoverable")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	check(chat.active != null and player.conversation_locked, "J must open dialogue and lock movement")
	var talking_npc = chat.active
	var frozen: Vector3 = talking_npc.position
	var player_before: Vector3 = player.position
	var player_fold: float = player.visual.motion.fold_target
	Input.action_press("move_forward")
	Input.action_press("jump")
	Input.action_press("fire_breath")
	Input.action_press("toggle_wings")
	await ticks(30)
	check(player.position.distance_to(player_before) < 0.2, "Conversation must suppress movement and jumping")
	check(talking_npc.position.distance_to(frozen) < 0.15, "Speaker must stop wandering")
	check(player.visual.motion.fold_target == player_fold, "Conversation must suppress player wing input")
	check(umber.visual.motion.fold_target == 1.0, "NPC must ignore player's wing button")
	for action in ["move_forward", "jump", "fire_breath", "toggle_wings"]:
		Input.action_release(action)
	chat.next_line()
	check(chat.line_index == 2 or chat.active == null, "Selecting a Clay response must consume it and advance to the NPC")
	Input.action_press("release_mouse")
	await process_frame
	Input.action_release("release_mouse")
	await process_frame
	check(chat.active == null and not player.conversation_locked and not talking_npc.talking, "Escape must close and resume both actors")
	# Finishing an exchange and walking/resetting out both restore control.
	chat.start_conversation(kai)
	for i in chat.lines.size():
		chat.next_line()
	check(chat.active == null and not player.conversation_locked, "Final line must release conversation")
	chat.start_conversation(kai)
	player.reset_to_spawn()
	await process_frame
	check(chat.active == null, "Respawn must close an out-of-range conversation")
	player.locomotion_state = &"flying"
	check(chat.find_nearest() == null, "Cannot begin a conversation while flying")
	print("Village NPC smoke: ", "PASS" if failures.is_empty() else "FAIL", " (54 exchanges, four actors, roaming, input isolation, conversation lifecycle)")
	village.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
