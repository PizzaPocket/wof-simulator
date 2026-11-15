extends Control
## The world map: one draggable, zoomable chart of every landmass with a pin on each
## place the player can travel to. Pins come from the terrain definitions' starting
## entries (so the map and the in-game start list can never disagree) plus the
## detailed destinations in data/overworld_locations.json.
## The look follows Google Maps: white cards with soft shadows, blue accents, grey text and
## circular pins. Red pins are detailed destinations, small blue pins are bare-terrain starts.
const WorldMap = preload("res://scripts/world_map.gd")
const CONTINENT_ORDER := ["pyrrhia", "pantala", "forgotten_isles", "nightwing_island"]
const FLY_ZOOM := 1.0 / 200.0
const PIN_GAP := 26.0
const UiStyle = preload("res://scripts/ui_style.gd")
const INK := UiStyle.INK
const INK_SECONDARY := UiStyle.INK_SECONDARY
const BLUE := UiStyle.BLUE
const BLUE_TEXT := UiStyle.BLUE_TEXT
const BLUE_TINT := UiStyle.BLUE_TINT
const PIN_RED := UiStyle.PIN_RED
const PIN_BLUE := UiStyle.PIN_BLUE
const PIN_GRAY := UiStyle.PIN_GRAY
const HOVER_GRAY := UiStyle.HOVER_GRAY
const STROKE := UiStyle.STROKE
const PIN_RADIUS := 10.0 ## Radius of a full-size circular pin, in pixels.

var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_locations.json"))
var map: Control
var pins: Array[Dictionary] = []
var hotspots: Array[Button] = []
var pin_labels: Array[Label] = []
var pin_order: Array[int] = []
var pin_on: Array[bool] = []
var markers: Control
var hover_tip: PanelContainer
var tip_title: Label
var tip_subtitle: Label
var tip_action: Label
var message: Label
var toast: PanelContainer
var places: MenuButton
var terrain_toggle: Button
var hovered := -1
var focused := -1
var forced := -1
var entering := false
var eras: Array = []
var era := ""
var era_buttons: Dictionary = {}
var timeline: PanelContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var era_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/eras.json"))
	eras = era_data.eras
	era = str(Engine.get_meta("map_era")) if Engine.has_meta("map_era") else str(era_data.default)
	Engine.set_meta("map_era", era) # destinations read the era the player chose on the map
	map = WorldMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	_build_pins()
	markers = Control.new()
	markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.draw.connect(_draw_markers)
	add_child(markers)
	for index in pins.size():
		_add_pin_widgets(index)
	_build_header()
	_build_zoom_controls()
	_build_timeline()
	_build_toast()
	_build_tip()
	map.view_changed.connect(_update_pins)
	resized.connect(_update_pins)
	_update_pins()

# --- Styling helpers (see ui_style.gd) -------------------------------------

func _card(radius := 12, pad_h := 16, pad_v := 12, shadow := 7, fill_color := Color.WHITE) -> StyleBoxFlat:
	return UiStyle.card(radius, pad_h, pad_v, shadow, fill_color)

func _fill(color: Color, radius := 8, border := Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	return UiStyle.fill(color, radius, border, border_width)

func _style_button(button: Button, ink := INK_SECONDARY, selected_ink := BLUE_TEXT, radius := 8, outline := false) -> void:
	UiStyle.style_button(button, ink, selected_ink, radius, outline)

func _text(copy: String, font_size: int, color := INK, bold := false) -> Label:
	return UiStyle.text(copy, font_size, color, bold)

func _halo_label(copy: String, font_size: int, color := INK) -> Label:
	return UiStyle.halo_label(copy, font_size, color)

# --- Pins -------------------------------------------------------------------

func _build_pins() -> void:
	var templates := {}
	var detailed: Array[Dictionary] = []
	for location in registry.locations:
		if location.has("terrain_entry"):
			templates[location.continent] = location
		else:
			detailed.append(location)
	for location in detailed:
		var continent: String = location.get("continent", "pyrrhia")
		var point := Vector2(location.position[0], location.position[1])
		var region: String = map.region_name_at(continent, point)
		var pin := location.duplicate(true)
		pin.continent = continent
		pin.world = map.map_to_world(continent, point)
		pin.subtitle = _subtitle(continent, region, "Detailed village")
		pin.tier = 0
		pins.append(pin)
	for id in CONTINENT_ORDER:
		var template: Dictionary = templates[id]
		var definition: Dictionary = map.continent(id).definition
		var entries: Array = definition.entries
		for index in entries.size():
			var point := Vector2(entries[index].position[0], entries[index].position[1])
			var pin := {
				"id": "%s_%d" % [template.id, index],
				"name": entries[index].name,
				"continent": id,
				"scene": template.scene,
				"assets": template.assets.duplicate(true),
				"terrain_entry": index,
				"world": map.map_to_world(id, point),
				"subtitle": _subtitle(id, map.region_name_at(id, point), "Bare terrain"),
				"tier": 1 if index == 0 else 2,
			}
			pins.append(pin)
	var indices: Array[int] = []
	for i in pins.size():
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		if pins[a].tier != pins[b].tier:
			return pins[a].tier < pins[b].tier
		return a < b)
	pin_order = indices
	pin_on.resize(pins.size())

func _subtitle(continent: String, region: String, kind: String) -> String:
	var land: String = map.continent(continent).definition.name
	if region == "" or region == land:
		return "%s · %s" % [land, kind]
	return "%s · %s · %s" % [region, land, kind]

func _pin_scale(pin: Dictionary) -> float:
	return 1.0 if pin.tier == 0 else 0.7

func _add_pin_widgets(index: int) -> void:
	var pin := pins[index]
	var label := _halo_label(pin.name, 13, INK)
	# The name is part of the pin: hovering or clicking it acts on the pin itself.
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.mouse_entered.connect(func():
		hovered = index
		_refresh_tip())
	label.mouse_exited.connect(func():
		if hovered == index: hovered = -1
		_refresh_tip())
	label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_enter(pins[index]))
	add_child(label)
	pin_labels.append(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(32, 32)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = ""
	# Only the pin is visible; the whole target stays easy to hit.
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.mouse_entered.connect(func():
		hovered = index
		_refresh_tip())
	button.mouse_exited.connect(func():
		if hovered == index: hovered = -1
		_refresh_tip())
	button.focus_entered.connect(func():
		focused = index
		map.reveal(pins[index].world)
		_refresh_tip())
	button.focus_exited.connect(func():
		if focused == index: focused = -1
		_refresh_tip())
	button.pressed.connect(_enter.bind(pin))
	add_child(button)
	hotspots.append(button)

func _update_pins() -> void:
	if map == null or not map.initialized or hotspots.size() != pins.size():
		return
	var order: Array[int] = pin_order.duplicate()
	if forced >= 0:
		order.erase(forced)
		order.push_front(forced)
	var placed: Array[Vector2] = []
	var screen_points: Array[Vector2] = []
	screen_points.resize(pins.size())
	# Pins yield to higher-priority neighbours so zooming in reveals more of them.
	for i in order:
		var point: Vector2 = map.world_to_screen(pins[i].world)
		screen_points[i] = point
		var clear := true
		for other in placed:
			if other.distance_to(point) < PIN_GAP:
				clear = false
				break
		pin_on[i] = clear
		if clear:
			placed.append(point)
	# Names yield to pins and to each other.
	var taken: Array[Rect2] = map.visible_continent_label_rects()
	var screen_rect := Rect2(Vector2.ZERO, size).grow(60)
	for i in order:
		var button := hotspots[i]
		var label := pin_labels[i]
		var shown := pin_on[i] and screen_rect.has_point(screen_points[i])
		button.visible = shown
		button.focus_mode = Control.FOCUS_ALL if shown else Control.FOCUS_NONE
		var show_name := false
		if shown:
			var scale_factor := _pin_scale(pins[i])
			var head := screen_points[i]
			button.size = button.get_combined_minimum_size()
			button.position = head - button.size * 0.5
			var label_size := label.get_minimum_size()
			var rect := Rect2(head + Vector2(PIN_RADIUS * scale_factor + 6.0, -label_size.y * 0.5), label_size)
			if rect.end.x > size.x - 8:
				rect.position.x = head.x - PIN_RADIUS * scale_factor - 6.0 - rect.size.x
			show_name = true
			for other in taken:
				if other.intersects(rect):
					show_name = false
					break
			if show_name:
				for other_point in placed:
					if other_point != screen_points[i] and rect.grow(6).has_point(other_point):
						show_name = false
						break
			if show_name:
				taken.append(rect)
				label.position = rect.position
		label.visible = show_name
	markers.queue_redraw()
	_refresh_tip()

## Pins list the eras they are open in; none listed means every era.
func _open_in_era(pin: Dictionary) -> bool:
	var open_eras: Array = pin.get("eras", [])
	return open_eras.is_empty() or era in open_eras

func _era_name(id: String) -> String:
	for item in eras:
		if item.id == id:
			return item.name
	return id

func _era_hint(pin: Dictionary) -> String:
	var names: Array[String] = []
	for id in pin.get("eras", []):
		names.append(_era_name(id))
	return "Opens in " + " / ".join(names)

## A circular pin like a Google Maps place marker: a coloured disc with a white rim and centre.
func _draw_pin(canvas: Control, center: Vector2, scale_factor: float, color: Color, ringed: bool) -> void:
	var radius := PIN_RADIUS * scale_factor
	canvas.draw_circle(center + Vector2(0, 1.5), radius + 3.0, Color(0, 0, 0, 0.22))
	canvas.draw_circle(center, radius + 2.0, Color.WHITE)
	canvas.draw_circle(center, radius, color)
	canvas.draw_circle(center, radius * 0.38, Color.WHITE)
	if ringed:
		canvas.draw_arc(center, radius + 4.5, 0, TAU, 40, BLUE, 2.0, true)

func _draw_markers() -> void:
	for i in pins.size():
		if not hotspots[i].visible:
			continue
		var center: Vector2 = map.world_to_screen(pins[i].world)
		var detailed: bool = pins[i].tier == 0
		var color := PIN_GRAY
		if _open_in_era(pins[i]):
			color = PIN_RED if detailed else PIN_BLUE
		var lift := 1.2 if (hovered == i or focused == i) else 1.0
		_draw_pin(markers, center, _pin_scale(pins[i]) * lift, color, focused == i)

func _refresh_tip() -> void:
	if not is_instance_valid(hover_tip):
		return
	var index := hovered if hovered >= 0 else focused
	hover_tip.visible = index >= 0 and hotspots[index].visible
	if hover_tip.visible:
		var pin := pins[index]
		var open := _open_in_era(pin)
		tip_title.text = pin.name
		tip_subtitle.text = pin.subtitle
		tip_action.text = "Click / Enter / A to travel" if open else _era_hint(pin) + " (see the timeline)"
		tip_action.add_theme_color_override("font_color", BLUE_TEXT if open else INK_SECONDARY)
		hover_tip.size = hover_tip.get_combined_minimum_size()
		# The card sits above the pin like a Google Maps info window, so it never hides the pin's
		# name; it drops below the pin when there is no room above.
		var tip_point: Vector2 = map.world_to_screen(pin.world)
		var head_top := tip_point.y - (PIN_RADIUS * _pin_scale(pin) + 4.0)
		var anchor := Vector2(tip_point.x - hover_tip.size.x * 0.5, head_top - hover_tip.size.y - 12.0)
		if anchor.y < 16.0:
			anchor.y = tip_point.y + PIN_RADIUS * _pin_scale(pin) + 12.0
		hover_tip.position = Vector2(clampf(anchor.x, 16, maxf(16, size.x - hover_tip.size.x - 16)), clampf(anchor.y, 16, maxf(16, size.y - hover_tip.size.y - 16)))
	markers.queue_redraw()

# --- Interface --------------------------------------------------------------

func _build_tip() -> void:
	hover_tip = PanelContainer.new()
	hover_tip.z_index = 10
	hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tip.add_theme_stylebox_override("panel", _card(10, 14, 11, 9))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_title = _text("", 15, INK, true)
	tip_subtitle = _text("", 13, INK_SECONDARY)
	tip_action = _text("", 13, BLUE_TEXT)
	for label in [tip_title, tip_subtitle, tip_action]:
		column.add_child(label)
	hover_tip.add_child(column)
	add_child(hover_tip)
	hover_tip.hide()

func _build_header() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.add_theme_stylebox_override("panel", _card(14, 16, 12, 8))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := _text("Wings of Fire", 18, INK, true)
	column.add_child(heading)
	var subheading := _text("World map", 13, INK_SECONDARY)
	column.add_child(subheading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	places = MenuButton.new()
	places.text = "Jump to a place  ▾"
	places.custom_minimum_size = Vector2(0, 34)
	places.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_button(places, BLUE_TEXT, BLUE_TEXT, 17, true)
	var popup := places.get_popup()
	popup.add_theme_stylebox_override("panel", _card(10, 6, 8, 10))
	popup.add_theme_stylebox_override("hover", _fill(HOVER_GRAY, 6))
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", INK)
	popup.add_theme_color_override("font_separator_color", INK_SECONDARY)
	popup.add_theme_font_size_override("font_size", 14)
	var group := ""
	for index in pins.size():
		var continent: String = pins[index].continent
		if continent != group:
			group = continent
			popup.add_separator(map.continent(continent).definition.name)
		popup.add_item(_menu_text(pins[index]), index)
	popup.id_pressed.connect(_fly_to_pin)
	row.add_child(places)
	terrain_toggle = Button.new()
	terrain_toggle.text = "Terrain"
	terrain_toggle.toggle_mode = true
	terrain_toggle.custom_minimum_size = Vector2(0, 34)
	terrain_toggle.tooltip_text = "Show shaded relief"
	terrain_toggle.focus_mode = Control.FOCUS_NONE
	_style_button(terrain_toggle, INK_SECONDARY, BLUE_TEXT, 17, true)
	terrain_toggle.add_theme_stylebox_override("pressed", _fill(BLUE_TINT, 17, BLUE, 1))
	terrain_toggle.add_theme_stylebox_override("hover_pressed", _fill(BLUE_TINT, 17, BLUE, 1))
	terrain_toggle.toggled.connect(func(on: bool): map.set_relief(on))
	terrain_toggle.visible = map.relief_available
	row.add_child(terrain_toggle)
	add_child(panel)

func _menu_text(pin: Dictionary) -> String:
	return pin.name if _open_in_era(pin) else "%s  (%s)" % [pin.name, _era_hint(pin).trim_prefix("Opens in ")]

func _build_timeline() -> void:
	timeline = PanelContainer.new()
	timeline.add_theme_stylebox_override("panel", _card(22, 10, 6, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	timeline.add_child(row)
	var caption := _text("Era", 13, INK_SECONDARY)
	caption.add_theme_constant_override("margin_left", 6)
	var caption_holder := MarginContainer.new()
	caption_holder.add_theme_constant_override("margin_left", 8)
	caption_holder.add_theme_constant_override("margin_right", 6)
	caption_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_holder.add_child(caption)
	row.add_child(caption_holder)
	var group := ButtonGroup.new()
	for item in eras:
		var button := Button.new()
		button.text = item.name
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = item.subtitle
		button.custom_minimum_size = Vector2(66, 32)
		button.button_pressed = item.id == era
		_style_button(button, INK_SECONDARY, BLUE_TEXT, 16)
		button.pressed.connect(_set_era.bind(item.id))
		row.add_child(button)
		era_buttons[item.id] = button
	timeline.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	timeline.grow_horizontal = Control.GROW_DIRECTION_BOTH
	timeline.grow_vertical = Control.GROW_DIRECTION_BEGIN
	timeline.offset_top = -64
	timeline.offset_bottom = -20
	add_child(timeline)

## A short-lived note for the rare message the map needs to show (a closed pin or a failed load).
## The map itself explains nothing: its controls are the familiar ones.
func _build_toast() -> void:
	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override("panel", _card(14, 14, 7, 6, Color(0.125, 0.129, 0.141, 0.96)))
	message = _text("", 13, Color.WHITE)
	toast.add_child(message)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_top = -84
	toast.offset_bottom = -84
	toast.visible = false
	add_child(toast)

func _show_message(copy: String) -> void:
	message.text = copy
	toast.visible = true
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(self) and message.text == copy:
			toast.visible = false)

func _set_era(id: String) -> void:
	if era == id:
		return
	era = id
	Engine.set_meta("map_era", id)
	toast.visible = false
	var popup := places.get_popup()
	for index in pins.size():
		popup.set_item_text(popup.get_item_index(index), _menu_text(pins[index]))
	_update_pins()

func _build_zoom_controls() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = -64
	column.offset_right = -16
	column.offset_top = -196
	column.offset_bottom = -20
	var zoom_card := PanelContainer.new()
	zoom_card.add_theme_stylebox_override("panel", _card(10, 0, 0, 7))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	zoom_card.add_child(stack)
	var steps := [["+", "Zoom in (+ or scroll)", func(): map.zoom_at(map.size * 0.5, WorldMap.ZOOM_STEP * WorldMap.ZOOM_STEP)],
		["−", "Zoom out (− or scroll)", func(): map.zoom_at(map.size * 0.5, 1.0 / (WorldMap.ZOOM_STEP * WorldMap.ZOOM_STEP))]]
	for i in steps.size():
		if i > 0:
			var divider := ColorRect.new()
			divider.color = STROKE
			divider.custom_minimum_size = Vector2(0, 1)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(divider)
		stack.add_child(_icon_button(steps[i][0], steps[i][1], steps[i][2], 22))
	column.add_child(zoom_card)
	var home_card := PanelContainer.new()
	home_card.add_theme_stylebox_override("panel", _card(10, 0, 0, 7))
	home_card.add_child(_icon_button("⌂", "Show the whole world", func(): map.fit_world(), 20))
	column.add_child(home_card)
	add_child(column)

func _icon_button(glyph: String, tip: String, action: Callable, glyph_size: int) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(46, 44)
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, INK_SECONDARY, INK_SECONDARY, 10)
	button.add_theme_font_size_override("font_size", glyph_size)
	button.pressed.connect(action)
	return button

func _fly_to_pin(index: int) -> void:
	forced = index
	map.fly_to(pins[index].world, maxf(map.target_zoom, FLY_ZOOM))
	_update_pins()
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(self) and index < hotspots.size() and hotspots[index].visible:
			hotspots[index].grab_focus()
		forced = -1)

func _unhandled_input(event: InputEvent) -> void:
	if focused < 0 and not hotspots.is_empty() and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		for i in pin_order:
			if hotspots[i].visible:
				hotspots[i].grab_focus()
				get_viewport().set_input_as_handled()
				return

func _enter(location: Dictionary) -> void:
	if entering:
		return
	if not _open_in_era(location):
		_show_message("%s: %s. Choose that era on the timeline below." % [location.name, _era_hint(location)])
		return
	if not ResourceLoader.exists(location.scene):
		_show_message("This destination could not be loaded. Check the game files and try again.")
		return
	entering = true
	Engine.set_meta("world_map_view", {"center": map.center, "zoom": map.zoom})
	var loader: Control = load("res://scenes/startup.tscn").instantiate()
	loader.configure(location)
	get_tree().root.add_child(loader)
	get_tree().current_scene = loader
	queue_free()
