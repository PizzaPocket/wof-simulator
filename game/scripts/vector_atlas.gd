extends Control
## Original native geometry shared with the playable terrain's geographic rules.
var coastlines: Array[PackedVector2Array] = []
var terrain: Array[Dictionary] = []
var map_size := Vector2(2165,1606)
var definition: Dictionary

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if definition.is_empty():
		configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain/pyrrhia.json")))
	resized.connect(queue_redraw)

func configure(data: Dictionary) -> void:
	definition = data
	map_size = Vector2(data.map_size[0],data.map_size[1])
	coastlines.clear()
	terrain.clear()
	for coast in data.coastlines: coastlines.append(_points(coast))
	for region in data.get("regions", []):
		for coast in coastlines:
			for polygon in Geometry2D.intersect_polygons(coast,_points(region.polygon)):
				terrain.append({"polygon":polygon,"color":_color(region.color)})
	queue_redraw()

func _color(rgb: Array) -> Color:
	return Color(rgb[0],rgb[1],rgb[2])

func _points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values: result.append(Vector2(value[0],value[1]))
	return result

func _draw() -> void:
	if definition.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/map_size)
	draw_rect(Rect2(Vector2.ZERO,map_size),Color("254a51"))
	for coast in coastlines: draw_colored_polygon(coast,_color(definition.base_color))
	for patch in terrain: draw_colored_polygon(patch.polygon,patch.color)
	for coast in coastlines:
		var outline := coast.duplicate()
		outline.append(coast[0])
		draw_polyline(outline,Color("d1c896"),2,true)
	var symbol_size: float = map_size.x * 0.012
	for ridge in definition.get("ridges",[]):
		for peak in ridge.points: _mountain(Vector2(peak[0],peak[1]),symbol_size)
	for peak in definition.get("peaks",[]): _mountain(Vector2(peak.center[0],peak.center[1]),symbol_size*1.5)
	for volcano in definition.get("volcanoes",[]):
		var p := Vector2(volcano.center[0],volcano.center[1])
		_mountain(p,symbol_size*2)
		draw_arc(p-Vector2(0,symbol_size*1.8),symbol_size*.45,0,TAU,24,Color("e1a365"),2,true)
	for river in definition.get("rivers",[]): draw_polyline(_points(river.points),Color("80b1b0"),4,true)
	for lake in definition.get("lakes",[]):
		draw_set_transform(Vector2(lake.center[0],lake.center[1])*size/map_size,0,Vector2(lake.radius[0],lake.radius[1])*size/map_size)
		draw_circle(Vector2.ZERO,1,Color("254a51"))
		draw_set_transform(Vector2.ZERO,0,size/map_size)

func _mountain(p: Vector2, radius: float) -> void:
	var outline := PackedVector2Array([p+Vector2(-radius,radius*.75),p-Vector2(0,radius),p+Vector2(radius,radius*.75)])
	draw_colored_polygon(outline,Color("65776a"))
	draw_polyline(outline,Color("d4d6b8"),2,true)
