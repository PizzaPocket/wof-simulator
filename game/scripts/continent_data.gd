extends RefCounted
## One uniform metres-per-map-pixel transform; north is negative Godot Z.
var definition: Dictionary
var heights := PackedFloat32Array()
var colors: Image
var grid := Vector2i()
var extent := Vector2()
var streaming := false
var far_only := false
var overview_colors := PackedByteArray()
var pages: Dictionary = {}
var page_lru: Array[Vector2i] = []
var page_reads := 0
var page_evictions := 0
var source_grid := Vector2i()
var rivers: Array[Dictionary] = []
var lakes: Array[Dictionary] = []
var read_failed := false

func open(id: String) -> bool:
	var path := "res://data/terrain/" + id + ".json"
	if not FileAccess.file_exists(path): return false
	definition = JSON.parse_string(FileAccess.get_file_as_string(path))
	grid = Vector2i(definition.grid[0], definition.grid[1])
	extent = Vector2(definition.extent_m[0], definition.extent_m[1])
	streaming = definition.has("streaming")
	if streaming:
		source_grid = grid
		grid = Vector2i(definition.streaming.overview_grid[0],definition.streaming.overview_grid[1])
		heights = FileAccess.get_file_as_bytes(definition.streaming.overview_height).to_float32_array()
		overview_colors = FileAccess.get_file_as_bytes(definition.streaming.overview_color)
		_prepare_waterways()
		return heights.size()==grid.x*grid.y and overview_colors.size()==grid.x*grid.y*3
	heights = FileAccess.get_file_as_bytes(definition.height_file).to_float32_array()
	var texture := load(definition.color_file) as Texture2D
	if texture == null or heights.size() != grid.x * grid.y: return false
	colors = texture.get_image()
	if colors.is_compressed(): colors.decompress()
	return true

func map_to_world(point: Array) -> Vector2:
	return (Vector2(point[0], point[1]) / Vector2(definition.map_size[0], definition.map_size[1]) - Vector2(0.5, 0.5)) * extent

func world_to_grid(point: Vector2) -> Vector2:
	return (point / extent + Vector2(0.5, 0.5)) * Vector2(grid - Vector2i.ONE)

func contains(point: Vector2) -> bool:
	return absf(point.x) <= extent.x * 0.5 and absf(point.y) <= extent.y * 0.5

func height_at(point: Vector2) -> float:
	if streaming and not far_only:
		return _detailed_height(point)
	return overview_height_at(point)

func overview_height_at(point: Vector2) -> float:
	var uv := world_to_grid(point).clamp(Vector2.ZERO, Vector2(grid - Vector2i.ONE))
	var x := mini(int(uv.x), grid.x - 2)
	var z := mini(int(uv.y), grid.y - 2)
	var a := lerpf(heights[z * grid.x + x], heights[z * grid.x + x + 1], uv.x - x)
	var b := lerpf(heights[(z + 1) * grid.x + x], heights[(z + 1) * grid.x + x + 1], uv.x - x)
	return lerpf(a, b, uv.y - z)

func color_at(point: Vector2) -> Color:
	if streaming and not far_only:
		var sample := _page_sample(point)
		if sample.is_empty(): return Color("52694c")
		var rgb: PackedByteArray = sample.page.rgb
		var index: int = (sample.z * int(definition.streaming.page_cells+1)+sample.x)*3
		return Color(rgb[index]/255.0,rgb[index+1]/255.0,rgb[index+2]/255.0)
	var uv := world_to_grid(point)
	if streaming:
		var index := (clampi(roundi(uv.y),0,grid.y-1)*grid.x+clampi(roundi(uv.x),0,grid.x-1))*3
		return Color(overview_colors[index]/255.0,overview_colors[index+1]/255.0,overview_colors[index+2]/255.0)
	return colors.get_pixel(clampi(roundi(uv.x), 0, grid.x-1), clampi(roundi(uv.y), 0, grid.y-1))

func normal_at(point: Vector2, step := 8.0) -> Vector3:
	return Vector3(height_at(point - Vector2(step, 0)) - height_at(point + Vector2(step, 0)), 2 * step, height_at(point - Vector2(0, step)) - height_at(point + Vector2(0, step))).normalized()

func water_level_at(point: Vector2) -> float:
	var level := 0.0
	var metres_per_pixel: float = extent.x / definition.map_size[0]
	for lake in definition.get("lakes", []):
		var center := map_to_world(lake.center)
		var radii := Vector2(lake.radius[0],lake.radius[1]) * metres_per_pixel
		if ((point-center)/radii).length() <= 1.0: level = maxf(level,lake.level)
	for river in definition.get("rivers", []):
		for i in range(river.points.size()-1):
			var a := map_to_world(river.points[i])
			var b := map_to_world(river.points[i+1])
			var t := clampf((point-a).dot(b-a)/maxf(0.01,a.distance_squared_to(b)),0,1)
			if point.distance_to(a.lerp(b,t)) < float(river.width_m)*0.65:
				level = maxf(level,lerpf(river.levels[i],river.levels[i+1],t))
	return level

func fork_reader(coarse := false):
	# Arrays/definitions are immutable after open. Each worker owns its page cache.
	var reader = get_script().new()
	reader.definition = definition
	reader.heights = heights
	reader.grid = grid
	reader.source_grid = source_grid
	reader.extent = extent
	reader.streaming = streaming
	reader.far_only = coarse
	reader.overview_colors = overview_colors
	reader.rivers = rivers
	reader.lakes = lakes
	return reader

func _page_sample(point: Vector2) -> Dictionary:
	var uv := ((point/extent+Vector2(.5,.5))*Vector2(source_grid-Vector2i.ONE)).clamp(Vector2.ZERO,Vector2(source_grid-Vector2i.ONE))
	var cell_count: int = definition.streaming.page_cells
	var cell := Vector2i(mini(int(uv.x),source_grid.x-2),mini(int(uv.y),source_grid.y-2))
	var key := Vector2i(cell.x/cell_count,cell.y/cell_count)
	if not pages.has(key):
		var path: String = definition.streaming.page_dir+"/%d_%d.page" % [key.x,key.y]
		var raw := FileAccess.get_file_as_bytes(path)
		var samples := (cell_count+1)*(cell_count+1)
		if raw.size()!=samples*7:
			read_failed = true
			return {}
		while pages.size()>=int(definition.streaming.page_cache_limit):
			pages.erase(page_lru.pop_front())
			page_evictions += 1
		pages[key] = {"h":raw.slice(0,samples*4).to_float32_array(),"rgb":raw.slice(samples*4)}
		page_reads += 1
	page_lru.erase(key)
	page_lru.append(key)
	return {"page":pages[key],"x":cell.x-key.x*cell_count,"z":cell.y-key.y*cell_count,"fx":uv.x-cell.x,"fz":uv.y-cell.y}

func _detailed_height(point: Vector2) -> float:
	var sample := _page_sample(point)
	if sample.is_empty(): return overview_height_at(point)
	var stride: int = definition.streaming.page_cells+1
	var index: int = sample.z*stride+sample.x
	var h: PackedFloat32Array = sample.page.h
	var value := lerpf(lerpf(h[index],h[index+1],sample.fx),lerpf(h[index+stride],h[index+stride+1],sample.fx),sample.fz)
	# Shared world coordinates make this local relief continuous across page/mesh edges.
	var relief := sin(point.x/137.0+sin(point.y/293.0))*cos(point.y/183.0)+.35*sin(point.x/53.0+point.y/97.0)
	value += relief*float(definition.streaming.local_relief_m)*smoothstep(4,30,value)
	for lake in lakes:
		if not lake.bounds.has_point(point): continue
		var radius: float = ((point-lake.center)/lake.radii).length()
		var bank := 1.0-smoothstep(1,1.5,radius)
		value = maxf(value,lerpf(value,lake.level+3,bank))
		value = lerpf(value,lake.level-lake.depth,1.0-smoothstep(.85,1.18,radius))
	for river in rivers:
		if not river.bounds.has_point(point): continue
		var distance := INF
		var level := 0.0
		for i in range(river.points.size()-1):
			var a: Vector2 = river.points[i]; var b: Vector2 = river.points[i+1]
			var t := clampf((point-a).dot(b-a)/maxf(.01,a.distance_squared_to(b)),0,1)
			var d := point.distance_to(a.lerp(b,t))
			if d<distance:
				distance=d
				level=lerpf(river.levels[i],river.levels[i+1],t)
		var bank := 1.0-smoothstep(river.width*1.1,river.width*3.5,distance)
		value=maxf(value,lerpf(value,level+4,bank))
		value=lerpf(value,level-river.depth,1.0-smoothstep(river.width*.35,river.width*1.35,distance))
	return value

func _prepare_waterways() -> void:
	for river in definition.get("rivers",[]):
		var points := PackedVector2Array()
		var bounds := Rect2(map_to_world(river.points[0]),Vector2.ZERO)
		for point in river.points:
			var p := map_to_world(point)
			points.append(p)
			bounds=bounds.expand(p)
		rivers.append({"points":points,"bounds":bounds.grow(river.width_m*3.5),"levels":river.levels,"width":float(river.width_m),"depth":float(river.get("depth_m",6))})
	for lake in definition.get("lakes",[]):
		var radii: Vector2 = Vector2(lake.radius[0],lake.radius[1])*extent.x/definition.map_size[0]
		var center := map_to_world(lake.center)
		lakes.append({"center":center,"radii":radii,"level":float(lake.level),"depth":float(lake.get("depth_m",12)),"bounds":Rect2(center-radii*1.5,radii*3)})

func resident_data_bytes() -> int:
	var total := heights.size()*4+overview_colors.size()
	for page in pages.values(): total += page.h.size()*4+page.rgb.size()
	return total
