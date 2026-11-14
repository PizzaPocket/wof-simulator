extends Node
## Shared keyboard/gamepad actions. Device -1 accepts any connected controller,
## including controllers paired after the game starts. Physical keys preserve WASD.

func _ready() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_bind("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_bind("move_forward", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_bind("move_back", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_bind("look_left", [KEY_Q], JOY_AXIS_RIGHT_X, -1.0)
	_bind("look_right", [KEY_E], JOY_AXIS_RIGHT_X, 1.0)
	_bind("look_up", [], JOY_AXIS_RIGHT_Y, -1.0)
	_bind("look_down", [], JOY_AXIS_RIGHT_Y, 1.0)
	_bind("jump", [KEY_SPACE], -1, 0.0, JOY_BUTTON_A)
	_bind("fire_breath", [KEY_V], -1, 0.0, JOY_BUTTON_RIGHT_SHOULDER)
	_bind("sprint", [KEY_SHIFT], -1, 0.0, JOY_BUTTON_LEFT_SHOULDER)
	_bind("possess_protagonist", [KEY_X], -1, 0.0, JOY_BUTTON_X)
	_bind("cycle_protagonist", [KEY_TAB], -1, 0.0, JOY_BUTTON_DPAD_LEFT)
	_bind("character_review", [KEY_F8], -1, 0.0, JOY_BUTTON_Y)
	_bind("release_mouse", [KEY_ESCAPE], -1, 0.0, JOY_BUTTON_START)
	_bind("world_map", [KEY_M], -1, 0.0, JOY_BUTTON_START)
	_bind("recenter", [KEY_C], -1, 0.0, JOY_BUTTON_RIGHT_STICK)
	_bind("toggle_wings", [KEY_F])
	_bind("spread_wings", [KEY_BRACKETLEFT], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind("fold_wings", [KEY_BRACKETRIGHT], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind("cancel_flight", [KEY_CTRL], -1, 0.0, JOY_BUTTON_B)
	_bind("toggle_hud", [KEY_H], -1, 0.0, JOY_BUTTON_BACK)
	_bind("tail_preview", [KEY_T], -1, 0.0, JOY_BUTTON_DPAD_DOWN)
	_bind("interact", [KEY_J], -1, 0.0, JOY_BUTTON_DPAD_RIGHT)
	_bind("arm_preview", [KEY_G], -1, 0.0, JOY_BUTTON_DPAD_UP)
	# Built-in GUI actions may only contain keyboard defaults in exported/custom
	# main loops. Give focused dialogue controls explicit any-device pad bindings.
	_bind_ui_button("ui_accept", JOY_BUTTON_A)
	_bind_ui_button("ui_up", JOY_BUTTON_DPAD_UP)
	_bind_ui_button("ui_down", JOY_BUTTON_DPAD_DOWN)


func _bind_ui_button(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _bind(action: StringName, keys: Array, axis: int = -1, direction: float = 0.0, button: int = -1) -> void:
	# Explicit Input Map overrides in project.godot take priority over these defaults.
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = axis
		event.axis_value = direction
		InputMap.action_add_event(action, event)
	if button >= 0:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = button
		InputMap.action_add_event(action, event)
