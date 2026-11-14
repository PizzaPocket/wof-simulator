extends Control
## The world map: one draggable, zoomable chart of every landmass with a pin on each
## place the player can travel to. Pins come from the terrain definitions' starting
## entries (so the map and the in-game start list can never disagree) plus the
## detailed destinations in data/overworld_locations.json.
const WorldMap = preload("res://scripts/world_map.gd")
const CONTINENT_ORDER := ["pyrrhia", "pantala", "forgotten_isles", "nightwing_island"]
const FLY_ZOOM := 1.0 / 200.0
const PIN_GAP := 26.0
const MARSH := Color("172c28")
const GOLD := Color("edce91")
const HIGHLIGHT := Color("f3e5c4")

var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_locations.json"))
var map: Control
var pins: Array[Dictionary] = []
var hotspots: Array[Button] = []
var pin_labels: Array[Label] = []
var pin_order: Array[int] = []
var pin_on: Array[bool] = []
var markers: Control
var hover_tip: PanelContainer
var tip_copy: Label
var message: Label
var places: MenuButton
var hovered := -1
var focused := -1
var forced := -1
var entering := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	hover_tip = PanelContainer.new()
	hover_tip.z_index = 10
	hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = MARSH
	tip_style.border_color = GOLD
	tip_style.set_border_width_all(1)
	tip_style.set_corner_radius_all(4)
	tip_style.content_margin_left = 16
	tip_style.content_margin_right = 16
	tip_style.content_margin_top = 12
	tip_style.content_margin_bottom = 12
	hover_tip.add_theme_stylebox_override("panel", tip_style)
	tip_copy = _label("", 16)
	hover_tip.add_child(tip_copy)
	add_child(hover_tip)
	hover_tip.hide()
	message = _label("Drag to move · scroll or pinch to zoom · click a pin to travel", 16)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	message.offset_top = -47
	message.offset_bottom = -21
	add_child(message)
	map.view_changed.connect(_update_pins)
	resized.connect(_update_pins)
	_update_pins()

func _label(copy: String, font_size: int, color := Color("e8e4cf")) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.17, 0.16, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

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

func _add_pin_widgets(index: int) -> void:
	var pin := pins[index]
	var label := _label(pin.name, 14, HIGHLIGHT)
	add_child(label)
	pin_labels.append(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(40, 40)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = ""
	# Only the marker is visible; the whole target stays easy to hit.
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
	# Markers yield to higher-priority neighbours so zooming in reveals more pins.
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
	# Names yield to markers and to each other.
	var taken: Array[Rect2] = map.visible_continent_label_rects()
	var screen_rect := Rect2(Vector2.ZERO, size).grow(40)
	for i in order:
		var button := hotspots[i]
		var label := pin_labels[i]
		var shown := pin_on[i] and screen_rect.has_point(screen_points[i])
		button.visible = shown
		button.focus_mode = Control.FOCUS_ALL if shown else Control.FOCUS_NONE
		var show_name := false
		if shown:
			button.size = button.get_combined_minimum_size()
			button.position = screen_points[i] - button.size * 0.5
			var rect := Rect2(screen_points[i] + Vector2(16, -11), label.get_minimum_size() + Vector2(4, 0))
			if rect.end.x > size.x - 8:
				rect.position.x = screen_points[i].x - 20 - rect.size.x
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

func _draw_markers() -> void:
	for i in pins.size():
		if not hotspots[i].visible:
			continue
		var point: Vector2 = map.world_to_screen(pins[i].world)
		if hovered == i or focused == i:
			markers.draw_arc(point, 19, 0, TAU, 48, HIGHLIGHT, 2, true)
		markers.draw_circle(point, 12, MARSH)
		if pins[i].tier == 0:
			# The detailed village is a solid gold pin.
			markers.draw_circle(point, 9, GOLD)
			markers.draw_circle(point, 3.5, MARSH)
		else:
			markers.draw_arc(point, 10, 0, TAU, 32, GOLD, 2, true)
			markers.draw_circle(point, 4, GOLD)

func _refresh_tip() -> void:
	if not is_instance_valid(hover_tip):
		return
	var index := hovered if hovered >= 0 else focused
	hover_tip.visible = index >= 0 and hotspots[index].visible
	if hover_tip.visible:
		var pin := pins[index]
		tip_copy.text = "%s\n%s\nClick / Enter / A to travel" % [pin.name, pin.subtitle]
		hover_tip.size = hover_tip.get_combined_minimum_size()
		var anchor := hotspots[index].position + Vector2(48, -hover_tip.size.y / 2 + 24)
		if anchor.x + hover_tip.size.x > size.x - 16:
			anchor.x = hotspots[index].position.x - hover_tip.size.x - 8
		hover_tip.position = Vector2(clampf(anchor.x, 16, maxf(16, size.x - hover_tip.size.x - 16)), clampf(anchor.y, 16, maxf(16, size.y - hover_tip.size.y - 16)))
	markers.queue_redraw()

# --- Interface --------------------------------------------------------------

func _build_header() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.17, 0.16, 0.9)
	style.border_color = Color(0.93, 0.81, 0.57, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "World map"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", GOLD)
	column.add_child(heading)
	places = MenuButton.new()
	places.text = "Jump to a place"
	places.flat = false
	places.custom_minimum_size = Vector2(0, 34)
	places.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var popup := places.get_popup()
	var group := ""
	for index in pins.size():
		var continent: String = pins[index].continent
		if continent != group:
			group = continent
			popup.add_separator(map.continent(continent).definition.name)
		popup.add_item(pins[index].name, index)
	popup.id_pressed.connect(_fly_to_pin)
	column.add_child(places)
	add_child(panel)

func _build_zoom_controls() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.offset_left = -64
	column.offset_top = -170
	column.offset_right = -20
	column.offset_bottom = -20
	var actions := [["+", "Zoom in (+ or scroll)", func(): map.zoom_at(map.size * 0.5, WorldMap.ZOOM_STEP * WorldMap.ZOOM_STEP)],
		["−", "Zoom out (− or scroll)", func(): map.zoom_at(map.size * 0.5, 1.0 / (WorldMap.ZOOM_STEP * WorldMap.ZOOM_STEP))],
		["⌂", "Show the whole world", func(): map.fit_world()]]
	for action in actions:
		var button := Button.new()
		button.text = action[0]
		button.tooltip_text = action[1]
		button.custom_minimum_size = Vector2(44, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action[2])
		column.add_child(button)
	add_child(column)

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
	if not ResourceLoader.exists(location.scene):
		message.text = "This destination could not be loaded. Check the game files and try again."
		return
	entering = true
	Engine.set_meta("world_map_view", {"center": map.center, "zoom": map.zoom})
	var loader: Control = load("res://scenes/startup.tscn").instantiate()
	loader.configure(location)
	get_tree().root.add_child(loader)
	get_tree().current_scene = loader
	queue_free()
