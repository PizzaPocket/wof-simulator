extends Control
## Scene destinations and positions share the traced map's cropped pixel space.
const VectorAtlas = preload("res://scripts/vector_atlas.gd")
var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_locations.json"))
var map_rect := Rect2()
var map_image: Control
var hotspots: Array[Button] = []
var message: Label
var entering := false
var markers: Control
var region_labels: Array[Label] = []
var hover_tip: PanelContainer
var tip_copy: Label
var hovered := -1
var continent_id := "pyrrhia"
var continent_tabs: Array[Button] = []
var registry: Dictionary
var heading: Label
var navigation: HBoxContainer
var focused := -1
var label_data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_labels.json"))

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color("172c28")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	registry = atlas.duplicate(true)
	heading = _label("Pyrrhia", 32, Color("edce91"))
	var title := heading
	title.position = Vector2(28, 16)
	add_child(title)
	var subtitle := _label("Choose a place to explore", 16)
	subtitle.position = Vector2(29, 59)
	navigation = HBoxContainer.new()
	navigation.position = Vector2(28, 90)
	navigation.add_theme_constant_override("separation", 8)
	add_child(navigation)
	var ids := ["pyrrhia", "pantala", "forgotten_isles", "nightwing_island", "world"]
	var names := ["Pyrrhia", "Pantala", "Forgotten Isles", "NightWing Island", "World"]
	for i in ids.size():
		var tab := Button.new()
		tab.text = names[i]
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0, 36)
		tab.pressed.connect(_select_continent.bind(ids[i]))
		navigation.add_child(tab)
		continent_tabs.append(tab)
	continent_tabs[0].button_pressed = true
	atlas.locations = registry.locations.filter(func(item): return item.get("continent", "pyrrhia") == "pyrrhia")
	add_child(subtitle)
	map_image = VectorAtlas.new()
	add_child(map_image)
	for region in label_data:
		var label := _label(region.name, 16, Color("0b1b16"))
		if region.name in ["Kingdom of the Sea", "Rainforest Kingdom"]:
			label.add_theme_color_override("font_color", Color("f3e5c4"))
		add_child(label)
		region_labels.append(label)
	markers = Control.new()
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.draw.connect(_draw_markers)
	add_child(markers)
	_build_hotspots()
	hover_tip = PanelContainer.new()
	hover_tip.z_index = 10
	hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color("172c28")
	tip_style.border_color = Color("edce91")
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
	message = _label("Hover a marker · Tab / D-pad to select · Click / Enter / A to explore", 16)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	message.offset_top = -47
	message.offset_bottom = -21
	add_child(message)
	resized.connect(_layout)
	_layout()

func _label(copy: String, font_size: int, color := Color("e8e4cf")) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _layout() -> void:
	var source_size := Vector2(atlas.map_size[0], atlas.map_size[1])
	var available := Vector2(maxf(1, size.x - 56), maxf(1, size.y - 200))
	var scale_factor := minf(available.x / source_size.x, available.y / source_size.y)
	map_rect = Rect2(Vector2((size.x - source_size.x * scale_factor) / 2, 140), source_size * scale_factor)
	map_image.position = map_rect.position
	map_image.size = map_rect.size
	for i in region_labels.size():
		var point := map_rect.position + Vector2(label_data[i].position[0], label_data[i].position[1]) * scale_factor
		region_labels[i].position = point - region_labels[i].get_minimum_size() / 2
	for i in hotspots.size():
		var location: Dictionary = atlas.locations[i]
		var point := map_rect.position + Vector2(location.position[0], location.position[1]) * scale_factor
		hotspots[i].size = hotspots[i].get_combined_minimum_size()
		hotspots[i].position = point - hotspots[i].size / 2
	_refresh_tip()
	markers.queue_redraw()

func _draw_markers() -> void:
	if map_rect.size == Vector2.ZERO:
		return
	markers.draw_rect(map_rect, Color("a4b89a"), false, 1)
	for i in atlas.locations.size():
		var location: Dictionary = atlas.locations[i]
		var point := map_rect.position + Vector2(location.position[0], location.position[1]) / Vector2(atlas.map_size[0], atlas.map_size[1]) * map_rect.size
		if hovered == i or focused == i:
			markers.draw_arc(point, 19, 0, TAU, 48, Color("f3e5c4"), 2, true)
		markers.draw_circle(point, 12, Color("172c28"))
		markers.draw_arc(point, 10, 0, TAU, 32, Color("edce91"), 2, true)
		markers.draw_circle(point, 4, Color("edce91"))

func _refresh_tip() -> void:
	if not is_instance_valid(hover_tip):
		return
	var index := hovered if hovered >= 0 else focused
	hover_tip.visible = index >= 0
	if index >= 0:
		var location: Dictionary = atlas.locations[index]
		tip_copy.text = "%s\n%s\nClick / Enter / A to explore" % [location.name, location.kingdom]
		hover_tip.size = hover_tip.get_combined_minimum_size()
		var anchor := hotspots[index].position + Vector2(48, -hover_tip.size.y / 2 + 24)
		if anchor.x + hover_tip.size.x > size.x - 16:
			anchor.x = hotspots[index].position.x - hover_tip.size.x - 8
		hover_tip.position = Vector2(clampf(anchor.x, 16, maxf(16, size.x-hover_tip.size.x-16)), clampf(anchor.y, 16, maxf(16, size.y-hover_tip.size.y-16)))
	markers.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if focused < 0 and not hotspots.is_empty() and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		hotspots[0].grab_focus()
		get_viewport().set_input_as_handled()

func _enter(location: Dictionary) -> void:
	if entering:
		return
	if not ResourceLoader.exists(location.scene):
		message.text = "This destination could not be loaded. Check the game files and try again."
		return
	entering = true
	var loader: Control = load("res://scenes/startup.tscn").instantiate()
	loader.configure(location)
	get_tree().root.add_child(loader)
	get_tree().current_scene = loader
	queue_free()

func _build_hotspots() -> void:
	for index in atlas.locations.size():
		var location: Dictionary = atlas.locations[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 48)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Only the marker is visible; the full target remains easy to hit.
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
			_refresh_tip())
		button.focus_exited.connect(func():
			if focused == index: focused = -1
			_refresh_tip())
		button.pressed.connect(_enter.bind(location))
		add_child(button)
		hotspots.append(button)

func _select_continent(id: String) -> void:
	if entering: return
	continent_id = id
	hovered = -1
	focused = -1
	hover_tip.hide()
	for button in hotspots:
		remove_child(button)
		button.queue_free()
	hotspots.clear()
	for label in region_labels:
		remove_child(label)
		label.queue_free()
	region_labels.clear()
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain/" + id + ".json"))
	heading.text = definition.name
	atlas.map_size = definition.map_size
	atlas.locations = definition.locations if id == "world" else registry.locations.filter(func(item): return item.get("continent", "pyrrhia") == id)
	map_image.configure(definition)
	label_data = []
	if id == "world": label_data = definition.labels
	elif id == "pyrrhia": label_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_labels.json"))
	else:
		for region in definition.get("regions", []):
			var center := Vector2.ZERO
			for point in region.polygon: center += Vector2(point[0],point[1])
			center /= region.polygon.size()
			var rgb := Color(region.color[0],region.color[1],region.color[2]).srgb_to_linear()
			var luminance := rgb.r*0.2126+rgb.g*0.7152+rgb.b*0.0722
			label_data.append({"name":region.name,"position":[center.x,center.y],"ink":Color.WHITE if luminance<0.18 else Color.BLACK})
	for region in label_data:
		var label := _label(region.name, 16, region.get("ink", Color("f3e5c4") if id in ["nightwing_island", "world"] else Color("0b1b16")))
		if region.name in ["Kingdom of the Sea", "Rainforest Kingdom"]: label.add_theme_color_override("font_color",Color("f3e5c4"))
		add_child(label)
		region_labels.append(label)
	_build_hotspots()
	var ids := ["pyrrhia", "pantala", "forgotten_isles", "nightwing_island", "world"]
	for i in continent_tabs.size(): continent_tabs[i].set_pressed_no_signal(ids[i] == id)
	_layout()
