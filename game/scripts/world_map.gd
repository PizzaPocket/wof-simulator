extends Control
## One continuous, draggable, zoomable map of every playable landmass.
## All geometry lives in a shared metre space: each continent keeps the placement
## that tools/map/build_terrain.py writes to game/data/terrain/world.json.
## Pins, labels and navigation controls belong to overworld.gd; this node owns the
## camera (centre in metres, zoom in pixels per metre) and the vector drawing.
signal view_changed

const WORLD_SIZE := Vector2(1200000, 700000)
const PLACEMENT_ORIGIN := Vector2(960000, 260000)
const CONTINENTS := ["pyrrhia", "pantala", "forgotten_isles", "nightwing_island"]
const MAX_ZOOM := 1.0 / 80.0 # 80 m per pixel; the traced coastlines are about 150 m per sample.
const WATER := Color("254a51")
const PAN_GESTURE_SPEED := 8.0
const ZOOM_STEP := 1.2

class Layer extends Node2D:
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

var continents: Array[Dictionary] = []
var center := WORLD_SIZE * 0.5
var zoom := 0.001
var target_center := WORLD_SIZE * 0.5
var target_zoom := 0.001
var min_zoom := 0.001
var initialized := false
var dragging := false
var drag_moved := false
var drag_origin := Vector2.ZERO
var drawn_zoom := 0.0
var shore_layer: Layer
var fill_layer: Layer
var outline_layer: Layer
var region_labels: Array[Dictionary] = []
var continent_labels: Array[Dictionary] = []

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_load_continents()
	shore_layer = _layer(_paint_shore)
	fill_layer = _layer(_paint_fills)
	outline_layer = _layer(_paint_outline)
	for continent in continents:
		continent.detail = _layer(_paint_detail.bind(continent))
	_build_labels()
	resized.connect(_on_resized)
	_on_resized()

func _layer(painter: Callable) -> Layer:
	var layer := Layer.new()
	layer.painter = painter
	add_child(layer)
	return layer

# --- Geometry ---------------------------------------------------------------

func _points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		result.append(Vector2(value[0], value[1]))
	return result

func _load_continents() -> void:
	for id in CONTINENTS:
		var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain/%s.json" % id))
		var map_size := Vector2(definition.map_size[0], definition.map_size[1])
		var scale_m := float(definition.width_m) / map_size.x
		var extent := map_size * scale_m
		var origin := Vector2(definition.world_offset_m[0], definition.world_offset_m[1]) + PLACEMENT_ORIGIN - extent * 0.5
		var continent := {"id": id, "definition": definition, "scale": scale_m, "origin": origin, "extent": extent, "coasts": [], "patches": []}
		for coast in definition.coastlines:
			continent.coasts.append(_to_world(continent, _points(coast)))
		continent.shelf = []
		for coast in continent.coasts:
			for ring in [[6000.0, 0.10], [2200.0, 0.16]]:
				for piece in Geometry2D.offset_polygon(coast, ring[0], Geometry2D.JOIN_ROUND):
					# Offsetting outward returns the same winding for outer edges; skip enclosed holes.
					if Geometry2D.is_polygon_clockwise(piece) == Geometry2D.is_polygon_clockwise(coast):
						continent.shelf.append({"polygon": piece, "alpha": ring[1]})
		for region in definition.get("regions", []):
			var polygon := _to_world(continent, _points(region.polygon))
			for coast in continent.coasts:
				for piece in Geometry2D.intersect_polygons(coast, polygon):
					continent.patches.append({"polygon": piece, "color": Color(region.color[0], region.color[1], region.color[2])})
		continents.append(continent)

func _to_world(continent: Dictionary, points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * continent.scale + continent.origin)
	return result

func continent(id: String) -> Dictionary:
	for item in continents:
		if item.id == id:
			return item
	return {}

## A point in a continent's own source-map pixels, as a world position in metres.
func map_to_world(id: String, point: Vector2) -> Vector2:
	var item := continent(id)
	return point * float(item.scale) + Vector2(item.origin)

func region_name_at(id: String, point: Vector2) -> String:
	for region in continent(id).definition.get("regions", []):
		if Geometry2D.is_point_in_polygon(point, _points(region.polygon)):
			return region.name
	return ""

func continent_screen_width(id: String) -> float:
	return float(continent(id).definition.width_m) * zoom

# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WATER)

func _paint_shore(layer: Node2D) -> void:
	# A soft shallow-water shelf around every coast, fixed in metres.
	for item in continents:
		for piece in item.shelf:
			layer.draw_colored_polygon(piece.polygon, Color(0.56, 0.80, 0.80, piece.alpha))

func _paint_fills(layer: Node2D) -> void:
	for item in continents:
		var base: Array = item.definition.base_color
		for coast in item.coasts:
			layer.draw_colored_polygon(coast, Color(base[0], base[1], base[2]))
		for patch in item.patches:
			layer.draw_colored_polygon(patch.polygon, patch.color)
		for lake in item.definition.get("lakes", []):
			var radius := Vector2(lake.radius[0], lake.radius[1]) * float(item.scale)
			var at: Vector2 = map_to_world(item.id, Vector2(lake.center[0], lake.center[1]))
			layer.draw_set_transform(at, 0.0, radius)
			layer.draw_circle(Vector2.ZERO, 1.0, WATER)
			layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_outline(layer: Node2D) -> void:
	var k := 1.0 / maxf(drawn_zoom, 0.00001)
	for item in continents:
		for coast in item.coasts:
			var ring: PackedVector2Array = coast.duplicate()
			ring.append(coast[0])
			layer.draw_polyline(ring, Color("d1c896"), 1.5 * k, true)

func _paint_detail(layer: Node2D, item: Dictionary) -> void:
	var k := 1.0 / maxf(drawn_zoom, 0.00001)
	var definition: Dictionary = item.definition
	for river in definition.get("rivers", []):
		layer.draw_polyline(_to_world(item, _points(river.points)), Color("80b1b0"), 2.5 * k, true)
	for ridge in definition.get("ridges", []):
		for peak in ridge.points:
			_mountain(layer, map_to_world(item.id, Vector2(peak[0], peak[1])), 7.0 * k, k)
	for peak in definition.get("peaks", []):
		_mountain(layer, map_to_world(item.id, Vector2(peak.center[0], peak.center[1])), 10.0 * k, k)
	for volcano in definition.get("volcanoes", []):
		var at := map_to_world(item.id, Vector2(volcano.center[0], volcano.center[1]))
		_mountain(layer, at, 14.0 * k, k)
		layer.draw_arc(at - Vector2(0, 12.0 * k), 6.0 * k, 0.0, TAU, 24, Color("e1a365"), 1.5 * k, true)

func _mountain(layer: Node2D, at: Vector2, radius: float, k: float) -> void:
	var outline := PackedVector2Array([at + Vector2(-radius, radius * 0.75), at - Vector2(0, radius), at + Vector2(radius, radius * 0.75)])
	layer.draw_colored_polygon(outline, Color("65776a"))
	outline.append(outline[0])
	layer.draw_polyline(outline, Color("d4d6b8"), 1.2 * k, true)

func _label_settings(font_size: int, ink: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = ink
	settings.outline_size = 4
	settings.outline_color = Color(0.09, 0.17, 0.16, 0.85) if ink.get_luminance() > 0.5 else Color(1, 1, 1, 0.55)
	return settings

func _build_labels() -> void:
	for item in continents:
		var label := Label.new()
		label.text = item.definition.name
		label.label_settings = _label_settings(30, Color("edce91"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		continent_labels.append({"label": label, "id": item.id, "world": item.origin + Vector2(item.extent.x * 0.5, -22000.0)})
		var names: Array = []
		if item.id == "pyrrhia":
			names = JSON.parse_string(FileAccess.get_file_as_string("res://data/overworld_labels.json"))
		else:
			for region in item.definition.get("regions", []):
				var sum := Vector2.ZERO
				for point in region.polygon:
					sum += Vector2(point[0], point[1])
				names.append({"name": region.name, "position": [sum.x / region.polygon.size(), sum.y / region.polygon.size()]})
		for region in names:
			var map_point := Vector2(region.position[0], region.position[1])
			var text := Label.new()
			text.text = region.name
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text.label_settings = _label_settings(15, _ink_at(item, map_point))
			add_child(text)
			region_labels.append({"label": text, "id": item.id, "world": map_to_world(item.id, map_point)})

## Dark ink over light ground, light ink over dark ground and open water.
func _ink_at(item: Dictionary, map_point: Vector2) -> Color:
	for region in item.definition.get("regions", []):
		if Geometry2D.is_point_in_polygon(map_point, _points(region.polygon)):
			var linear := Color(region.color[0], region.color[1], region.color[2]).srgb_to_linear()
			var luminance := linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722
			return Color.WHITE if luminance < 0.18 else Color("0b1b16")
	return Color("f3e5c4")

# --- Camera -----------------------------------------------------------------

func world_to_screen(point: Vector2) -> Vector2:
	return (point - center) * zoom + size * 0.5

func screen_to_world(point: Vector2) -> Vector2:
	return center + (point - size * 0.5) / zoom

func _clamp_center(value: Vector2, z: float) -> Vector2:
	var half := size * 0.5 / z
	var margin := WORLD_SIZE * 0.04
	var result := value
	for axis in 2:
		if half[axis] * 2.0 >= WORLD_SIZE[axis]:
			result[axis] = WORLD_SIZE[axis] * 0.5
		else:
			result[axis] = clampf(value[axis], half[axis] - margin[axis], WORLD_SIZE[axis] - half[axis] + margin[axis])
	return result

func _on_resized() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	min_zoom = minf(size.x / WORLD_SIZE.x, size.y / WORLD_SIZE.y)
	if not initialized:
		initialized = true
		if Engine.has_meta("world_map_view"):
			var saved: Dictionary = Engine.get_meta("world_map_view")
			set_view(saved.center, saved.zoom, true)
		else:
			set_view(WORLD_SIZE * 0.5, min_zoom, true)
	else:
		target_zoom = clampf(target_zoom, min_zoom, MAX_ZOOM)
		zoom = clampf(zoom, min_zoom, MAX_ZOOM)
		target_center = _clamp_center(target_center, target_zoom)
		center = _clamp_center(center, zoom)
	queue_redraw()
	_apply_view()

func set_view(new_center: Vector2, new_zoom: float, instant := false) -> void:
	target_zoom = clampf(new_zoom, min_zoom, MAX_ZOOM)
	target_center = _clamp_center(new_center, target_zoom)
	if instant:
		zoom = target_zoom
		center = target_center
		_apply_view()

func fit_world(instant := false) -> void:
	set_view(WORLD_SIZE * 0.5, min_zoom, instant)

func fly_to(world: Vector2, new_zoom: float) -> void:
	set_view(world, new_zoom)

## Pan only as far as needed to bring a world point inside a comfortable margin.
func reveal(world: Vector2, margin := 96.0) -> void:
	var screen := (world - target_center) * target_zoom + size * 0.5
	if Rect2(Vector2.ONE * margin, size - Vector2.ONE * margin * 2.0).has_point(screen):
		return
	target_center = _clamp_center(world, target_zoom)

func zoom_at(screen: Vector2, factor: float) -> void:
	var new_zoom := clampf(target_zoom * factor, min_zoom, MAX_ZOOM)
	var anchor := target_center + (screen - size * 0.5) / target_zoom
	target_zoom = new_zoom
	target_center = _clamp_center(anchor - (screen - size * 0.5) / new_zoom, new_zoom)

func pan_by(screen_delta: Vector2) -> void:
	target_center = _clamp_center(target_center - screen_delta / target_zoom, target_zoom)

func _apply_view() -> void:
	if not initialized:
		return
	var origin := size * 0.5 - center * zoom
	var scaling := Vector2(zoom, zoom)
	for layer in [shore_layer, fill_layer, outline_layer]:
		layer.position = origin
		layer.scale = scaling
	for item in continents:
		item.detail.position = origin
		item.detail.scale = scaling
		item.detail.modulate.a = clampf((continent_screen_width(item.id) - 450.0) / 300.0, 0.0, 1.0)
	# Strokes and symbols hold a constant pixel size; repaint them when zoom changes materially.
	if drawn_zoom <= 0.0 or absf(log(zoom / drawn_zoom)) > 0.18:
		drawn_zoom = zoom
		outline_layer.queue_redraw()
		for item in continents:
			item.detail.queue_redraw()
	for entry in continent_labels:
		var width := continent_screen_width(entry.id)
		var label: Label = entry.label
		label.modulate.a = clampf((1250.0 - width) / 350.0, 0.0, 1.0)
		var wanted := world_to_screen(entry.world) - Vector2(label.get_minimum_size().x * 0.5, label.get_minimum_size().y)
		label.position = Vector2(clampf(wanted.x, 8.0, maxf(8.0, size.x - label.get_minimum_size().x - 8.0)), wanted.y)
	for entry in region_labels:
		var label: Label = entry.label
		label.modulate.a = clampf((continent_screen_width(entry.id) - 700.0) / 250.0, 0.0, 1.0)
		label.position = world_to_screen(entry.world) - label.get_minimum_size() * 0.5
	view_changed.emit()

## Screen rectangles of continent names that are currently readable, so pin names can avoid them.
func visible_continent_label_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for entry in continent_labels:
		var label: Label = entry.label
		if label.modulate.a > 0.3:
			rects.append(Rect2(label.position, label.get_minimum_size()).grow(4))
	return rects

func _process(delta: float) -> void:
	if not initialized:
		return
	_joystick(delta)
	if zoom == target_zoom and center == target_center:
		return
	var blend := 1.0 - exp(-16.0 * delta)
	zoom = exp(lerpf(log(zoom), log(target_zoom), blend))
	center = center.lerp(target_center, blend)
	if absf(log(zoom / target_zoom)) < 0.0004 and center.distance_to(target_center) * zoom < 0.25:
		zoom = target_zoom
		center = target_center
	_apply_view()

func _joystick(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.25:
		pan_by(-stick * 900.0 * delta)
	var trigger := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(trigger) > 0.2:
		zoom_at(size * 0.5, exp(trigger * 1.6 * delta))

# --- Input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			zoom_at(click.position, ZOOM_STEP)
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			zoom_at(click.position, 1.0 / ZOOM_STEP)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			dragging = click.pressed
			if click.pressed:
				drag_moved = false
				drag_origin = click.position
				if click.double_click:
					zoom_at(click.position, ZOOM_STEP * ZOOM_STEP)
			mouse_default_cursor_shape = Control.CURSOR_DRAG if click.pressed else Control.CURSOR_ARROW
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		if not drag_moved and motion.position.distance_to(drag_origin) > 3.0:
			drag_moved = true
		if drag_moved:
			center = _clamp_center(center - motion.relative / zoom, zoom)
			target_center = center
			_apply_view()
	elif event is InputEventMagnifyGesture:
		zoom_at((event as InputEventMagnifyGesture).position, (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		pan_by(-(event as InputEventPanGesture).delta * PAN_GESTURE_SPEED)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_at(size * 0.5, ZOOM_STEP)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_at(size * 0.5, 1.0 / ZOOM_STEP)
		_:
			return
	get_viewport().set_input_as_handled()
