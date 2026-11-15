extends Control
## One continuous, draggable, zoomable map of every playable landmass.
## All geometry lives in a shared metre space: each continent keeps the placement
## that tools/map/build_terrain.py writes to game/data/terrain/world.json.
## Pins, labels and navigation controls belong to overworld.gd; this node owns the
## camera (centre in metres, zoom in pixels per metre) and the vector drawing.
## Styled after the standard Google Maps look: one water blue, one land colour, thin dashed
## political borders and grey labels with white halos, with an optional shaded-relief layer.
signal view_changed

const WORLD_SIZE := Vector2(1200000, 700000)
const PLACEMENT_ORIGIN := Vector2(960000, 260000)
const CONTINENTS := ["pyrrhia", "pantala", "forgotten_isles", "nightwing_island"]
const MAX_ZOOM := 1.0 / 80.0 # 80 m per pixel; the traced coastlines are about 150 m per sample.
const WATER := Color("aadaff") ## Google Maps' standard water blue.
const LAND := Color("f2efe9") ## Google Maps' standard land colour.
const BORDER := Color("9aa0a6")
## Broad climate tints over the land, blended into soft swaths like Google Maps' green parks,
## desert and arctic areas. Each region's authored ground colour picks its class.
const CLIMATE := {
	"arctic": Color("dceaf4"), "arid": Color("f4dfae"), "dry": Color("e6e8b8"),
	"green": Color("cde8b8"), "deep": Color("a9d6a0"), "rock": Color("d8d0c8"),
}
const CLIMATE_BLEND_M := 14000.0 ## Rough width of the blend between neighbouring climates.
const CONTINENT_INK := Color("3c4043")
const REGION_INK := Color("3c4043") ## Keeps 6:1 or better on every climate tint.
const START_CONTINENT := "pyrrhia" ## The map opens zoomed in here rather than on the whole world.
const START_FILL := 0.72 ## Fraction of the view width the starting continent fills.
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
var fill_layer: Layer
var relief_layer: Layer
var outline_layer: Layer
var relief_available := false
var relief_on := false
var region_labels: Array[Dictionary] = []
var continent_labels: Array[Dictionary] = []

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_load_continents()
	fill_layer = _layer(_paint_fills)
	relief_layer = _layer(_paint_relief)
	relief_layer.visible = false
	relief_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # smooth the coarse overview
	fill_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # smooth the climate blend
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
		var continent := {"id": id, "definition": definition, "scale": scale_m, "origin": origin, "extent": extent, "coasts": [], "borders": [], "relief": null, "climate": null}
		for coast in definition.coastlines:
			continent.coasts.append(_to_world(continent, _points(coast)))
		# Political borders: the kingdoms' boundaries, kept to the part that runs across land so
		# no border is drawn along the shore (Google Maps draws land borders only).
		if id == START_CONTINENT:
			for region in definition.get("regions", []):
				var ring := _to_world(continent, _points(region.polygon))
				ring.append(ring[0])
				for coast in continent.coasts:
					for piece in Geometry2D.intersect_polyline_with_polygon(ring, coast):
						continent.borders.append(piece)
		continent.climate = _climate_texture(continent)
		continent.relief = _relief_texture(continent)
		relief_available = relief_available or continent.relief != null
		continents.append(continent)

func _climate_of(rgb: Array) -> Color:
	var c := Color(rgb[0], rgb[1], rgb[2])
	if c.s < 0.12 and c.v > 0.85:
		return CLIMATE.arctic
	if c.s < 0.2 and c.v < 0.5:
		return CLIMATE.rock
	if c.h < 0.14 and c.s > 0.35:
		return CLIMATE.arid
	if c.h < 0.2:
		return CLIMATE.dry
	if c.v < 0.55 or c.h > 0.30:
		return CLIMATE.deep
	return CLIMATE.green

## A small image of each region's climate colour, blurred so neighbouring climates blend. It is
## sampled with linear filtering while filling the coast polygons, which also clips it to land.
func _climate_texture(item: Dictionary) -> ImageTexture:
	var regions: Array = item.definition.get("regions", [])
	if regions.is_empty():
		return null
	var map_size := Vector2(item.definition.map_size[0], item.definition.map_size[1])
	var width := 160
	var height := maxi(8, int(round(width * map_size.y / map_size.x)))
	var polygons: Array[PackedVector2Array] = []
	var tints: Array[Color] = []
	for region in regions:
		polygons.append(_points(region.polygon))
		tints.append(_climate_of(region.color))
	var grid := PackedColorArray()
	grid.resize(width * height)
	for y in height:
		for x in width:
			var at := Vector2((x + 0.5) / width, (y + 0.5) / height) * map_size
			var tint := LAND
			for i in polygons.size():
				if Geometry2D.is_point_in_polygon(at, polygons[i]):
					tint = tints[i]
					break
			grid[y * width + x] = tint
	var metres_per_pixel := float(item.definition.width_m) / width
	var radius := clampi(int(CLIMATE_BLEND_M / metres_per_pixel), 2, 10)
	for pass_index in 3:
		grid = _box_blur(grid, width, height, radius, true)
		grid = _box_blur(grid, width, height, radius, false)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			image.set_pixel(x, y, grid[y * width + x])
	return ImageTexture.create_from_image(image)

func _box_blur(grid: PackedColorArray, width: int, height: int, radius: int, horizontal: bool) -> PackedColorArray:
	var result := PackedColorArray()
	result.resize(grid.size())
	for y in height:
		for x in width:
			var sum := Color(0, 0, 0, 0)
			var count := 0
			for k in range(-radius, radius + 1):
				var sx := x + k if horizontal else x
				var sy := y if horizontal else y + k
				if sx < 0 or sy < 0 or sx >= width or sy >= height:
					continue
				var c := grid[sy * width + sx]
				sum += c
				count += 1
			result[y * width + x] = Color(sum.r / count, sum.g / count, sum.b / count, 1.0)
	return result

## Soft hillshade from the coarse overview heightfield: shadow on the side facing away from a
## north-west light and a pale highlight facing it. Transparent over water. Null when the
## overview file is not present (it is baked locally by tools/map/build_terrain.py).
func _relief_texture(item: Dictionary) -> ImageTexture:
	var streaming: Dictionary = item.definition.get("streaming", {})
	if streaming.is_empty() or not streaming.has("overview_height"):
		return null
	var path := str(streaming.overview_height)
	if not FileAccess.file_exists(path):
		return null
	var nx := int(streaming.overview_grid[0])
	var nz := int(streaming.overview_grid[1])
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < nx * nz * 4:
		return null
	var heights := bytes.to_float32_array()
	var spacing := Vector2(item.extent) / Vector2(nx - 1, nz - 1)
	var light := Vector3(-1.0, 1.25, -1.0).normalized()
	var flat := light.y
	var data := PackedByteArray()
	data.resize(nx * nz * 4)
	for z in nz:
		for x in nx:
			var h: float = heights[z * nx + x]
			var left: float = heights[z * nx + maxi(x - 1, 0)]
			var right: float = heights[z * nx + mini(x + 1, nx - 1)]
			var up: float = heights[maxi(z - 1, 0) * nx + x]
			var down: float = heights[mini(z + 1, nz - 1) * nx + x]
			var gx := (right - left) / (spacing.x * 2.0) * 3.0
			var gz := (down - up) / (spacing.y * 2.0) * 3.0
			var shade := Vector3(-gx, 1.0, -gz).normalized().dot(light)
			var delta := shade - flat
			var land := smoothstep(0.0, 40.0, h)
			var index := (z * nx + x) * 4
			if delta < 0.0:
				data[index] = 92
				data[index + 1] = 84
				data[index + 2] = 70
				data[index + 3] = int(clampf(-delta * 1.5, 0.0, 0.42) * land * 255.0)
			else:
				data[index] = 255
				data[index + 1] = 255
				data[index + 2] = 255
				data[index + 3] = int(clampf(delta * 1.2, 0.0, 0.4) * land * 255.0)
	return ImageTexture.create_from_image(Image.create_from_data(nx, nz, false, Image.FORMAT_RGBA8, data))

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

func _paint_fills(layer: Node2D) -> void:
	# Land is tinted by climate (blended swaths); lakes are water blue.
	for item in continents:
		for coast in item.coasts:
			if item.climate != null:
				var uvs := PackedVector2Array()
				var tint := PackedColorArray()
				for point in coast:
					uvs.append((point - item.origin) / item.extent)
					tint.append(Color.WHITE)
				layer.draw_polygon(coast, tint, uvs, item.climate)
			else:
				layer.draw_colored_polygon(coast, LAND)
		for lake in item.definition.get("lakes", []):
			var radius := Vector2(lake.radius[0], lake.radius[1]) * float(item.scale)
			var at: Vector2 = map_to_world(item.id, Vector2(lake.center[0], lake.center[1]))
			layer.draw_set_transform(at, 0.0, radius)
			layer.draw_circle(Vector2.ZERO, 1.0, WATER)
			layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_relief(layer: Node2D) -> void:
	for item in continents:
		if item.relief != null:
			layer.draw_texture_rect(item.relief, Rect2(item.origin, item.extent), false)

## Thin dashed political borders, constant in pixels.
func _paint_outline(layer: Node2D) -> void:
	var k := 1.0 / maxf(drawn_zoom, 0.00001)
	for item in continents:
		for piece in item.borders:
			for i in range(piece.size() - 1):
				layer.draw_dashed_line(piece[i], piece[i + 1], BORDER, 1.4 * k, 7.0 * k, true, true)

## Rivers, in the same blue as the sea.
func _paint_detail(layer: Node2D, item: Dictionary) -> void:
	var k := 1.0 / maxf(drawn_zoom, 0.00001)
	for river in item.definition.get("rivers", []):
		layer.draw_polyline(_to_world(item, _points(river.points)), WATER, 2.2 * k, true)

func set_relief(on: bool) -> void:
	relief_on = on and relief_available
	relief_layer.visible = relief_on

func _label_settings(font_size: int, ink: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = ink
	# A thin halo: a thick one eats the strokes of small text and makes it look faint.
	settings.outline_size = 5 if font_size >= 18 else 3
	settings.outline_color = Color(1, 1, 1, 0.92)
	return settings

func _build_labels() -> void:
	for item in continents:
		var label := Label.new()
		label.text = str(item.definition.name).to_upper()
		label.label_settings = _label_settings(20, CONTINENT_INK)
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
			text.text = str(region.name).to_upper()
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text.label_settings = _label_settings(13, REGION_INK)
			add_child(text)
			region_labels.append({"label": text, "id": item.id, "world": map_to_world(item.id, map_point)})

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
			show_continent(START_CONTINENT, true)
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

## Centre on a landmass at a zoom where it fills most of the view.
func show_continent(id: String, instant := false) -> void:
	var item := continent(id)
	var fit := minf(size.x * START_FILL / float(item.extent.x), size.y * START_FILL / float(item.extent.y))
	set_view(Vector2(item.origin) + Vector2(item.extent) * 0.5, maxf(fit, min_zoom), instant)

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
	for layer in [fill_layer, relief_layer, outline_layer]:
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
		label.modulate.a = clampf((continent_screen_width(entry.id) - 500.0) / 120.0, 0.0, 1.0)
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
