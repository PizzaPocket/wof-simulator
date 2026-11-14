extends Node3D
## A bounded disk/CPU streaming pipeline, pumped once each render frame.
const Job = preload("res://scripts/terrain_job.gd")
const Chunk = preload("res://scripts/terrain_chunk.gd")
var data: RefCounted
var config: Dictionary
var chunks: Dictionary = {}
var desired: Dictionary = {}
var active: Dictionary = {}
var collision_queue: Array[Dictionary] = []
var failed: Dictionary = {}
var coverage_image: Image
var coverage_texture: ImageTexture
var background_material: ShaderMaterial
var surface_material: ShaderMaterial
var count = Vector2i()
var tile_size = 2048.0
var center = Vector2i(-999,-999)
var prediction = Vector2i(-999,-999)
var backgrounds: Array[Node3D] = []
var frame_commits = PackedFloat64Array()
var frame_pumps = PackedFloat64Array()
var page_reads = 0
var page_evictions = 0
var discarded_jobs = 0
var unloaded_tiles = 0
var peak_tiles = 0
var peak_estimated_bytes = 0
var last_error = ""
var closing = false
var generation = 0
var background_bytes = 0
var commit_over_budget = 0
var max_commit_usec = 0
var max_pump_usec = 0

func configure(source: RefCounted) -> void:
	data=source
	config=data.definition.streaming
	tile_size=config.tile_size_m
	count=Vector2i(ceili(data.extent.x/tile_size),ceili(data.extent.y/tile_size))
	coverage_image=Image.create(count.x,count.y,false,Image.FORMAT_L8)
	coverage_image.fill(Color.BLACK)
	coverage_texture=ImageTexture.create_from_image(coverage_image)
	surface_material=ShaderMaterial.new()
	surface_material.shader=preload("res://shaders/streamed_ground.gdshader")
	background_material=ShaderMaterial.new()
	background_material.shader=surface_material.shader
	background_material.set_shader_parameter("background",true)
	background_material.set_shader_parameter("coverage",coverage_texture)

func build_background(progress: Callable=Callable()) -> void:
	var size=tile_size*16
	var total=Vector2i(ceili(data.extent.x/size),ceili(data.extent.y/size))
	for z in total.y:
		for x in total.x:
			var p=Vector2(x,z)*size-data.extent*.5
			var job=Job.new()
			job.data=data.fork_reader(true)
			job.rect=Rect2(p,Vector2(size,size).min(data.extent*.5-p))
			job.detail=32
			job.tile_size=tile_size; job.cover_count=Vector2(count)
			job.run()
			var chunk=Chunk.new()
			chunk.name="Distant_%d_%d" % [x,z]
			chunk.install(job.rect,32,job.result.arrays,background_material)
			add_child(chunk)
			backgrounds.append(chunk)
			background_bytes+=int(job.result.bytes)*2
		if progress.is_valid(): await progress.call(.65*float(z+1)/total.y,"Preparing distant landscape")
		else: await get_tree().process_frame

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(((point+data.extent*.5)/tile_size).floor())

func rect_for(cell: Vector2i) -> Rect2:
	var p=Vector2(cell)*tile_size-data.extent*.5
	return Rect2(p,Vector2(tile_size,tile_size))

func valid(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<count.x and cell.y<count.y

func update_interest(point: Vector2, velocity: Vector2) -> void:
	var here=cell_at(point)
	var ahead=cell_at(point+velocity.limit_length(250)*float(config.lookahead_seconds))
	if here==center and ahead==prediction: return
	center=here; prediction=ahead
	desired.clear()
	for focus in [here,ahead]:
		for z in range(focus.y-int(config.medium_radius),focus.y+int(config.medium_radius)+1):
			for x in range(focus.x-int(config.medium_radius),focus.x+int(config.medium_radius)+1):
				var key=Vector2i(x,z)
				if not valid(key): continue
				var near: bool = maxi(absi(x-focus.x),absi(z-focus.y))<=int(config.near_radius)
				desired[key]=maxi(int(desired.get(key,0)),int(config.near_subdivisions) if near else int(config.medium_subdivisions))
	# Evict before scheduling. In-flight results are checked against the new interest.
	for key in chunks.keys():
		if not desired.has(key): _unload(key)
	for item in collision_queue.duplicate():
		if not is_instance_valid(item.chunk) or not item.chunk.is_inside_tree(): collision_queue.erase(item)
	_upload_coverage()

func _unload(key: Vector2i) -> void:
	var old: Node3D=chunks[key]
	remove_child(old)
	old.queue_free()
	chunks.erase(key)
	coverage_image.set_pixel(key.x,key.y,Color.BLACK)
	unloaded_tiles+=1

func _upload_coverage() -> void:
	coverage_texture.update(coverage_image)

func collision_ready(point: Vector2) -> bool:
	var key=cell_at(point)
	return chunks.has(key) and chunks[key].collision!=null

func neighborhood_ready(point: Vector2) -> bool:
	var cell=cell_at(point)
	for z in range(cell.y-1,cell.y+2):
		for x in range(cell.x-1,cell.x+2):
			var key=Vector2i(x,z)
			if valid(key) and (not chunks.has(key) or chunks[key].collision==null): return false
	return true

func prepare(point: Vector2) -> bool:
	generation+=1
	last_error=""
	failed.clear()
	center=Vector2i(-999,-999)
	update_interest(point,Vector2.ZERO)
	var deadline=Time.get_ticks_msec()+30000
	while not neighborhood_ready(point):
		pump()
		if not last_error.is_empty() or Time.get_ticks_msec()>deadline: return false
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	return true

func pump() -> void:
	if closing: return
	var started=Time.get_ticks_usec()
	# Only one GPU upload OR physics installation per frame. Workers never touch either.
	var committed=false
	while not collision_queue.is_empty():
		var item: Dictionary=collision_queue.pop_front()
		if not is_instance_valid(item.chunk) or not item.chunk.is_inside_tree(): continue
		if not desired.has(item.key) or desired[item.key]!=int(config.near_subdivisions): continue
		var before=Time.get_ticks_usec()
		item.chunk.install_heightmap(item.heights)
		frame_commits.append(Time.get_ticks_usec()-before)
		committed=true
		break
	for key in active.keys():
		var work: Dictionary=active[key]
		if not WorkerThreadPool.is_task_completed(work.task): continue
		# Always release the pool task, even when a teleport made its result stale.
		if committed: break
		WorkerThreadPool.wait_for_task_completion(work.task)
		var result: Dictionary=work.job.result
		active.erase(key)
		page_reads+=result.page_reads
		page_evictions+=result.page_evictions
		if work.generation!=generation or not desired.has(key) or desired[key]!=work.detail:
			discarded_jobs+=1
			continue
		if result.failed:
			failed[key]=true
			last_error="Terrain page missing or invalid at %s" % key
			continue
		var before=Time.get_ticks_usec()
		var chunk=Chunk.new()
		chunk.name="Streamed_%d_%d" % [key.x,key.y]
		chunk.install(rect_for(key),work.detail,result.arrays,surface_material)
		chunk.set_meta("resident_bytes",result.bytes)
		# Replace the existing representation only once its successor is prepared.
		if chunks.has(key): _unload(key)
		add_child(chunk)
		chunks[key]=chunk
		coverage_image.set_pixel(key.x,key.y,Color.WHITE)
		_upload_coverage()
		if work.detail==int(config.near_subdivisions): collision_queue.append({"key":key,"chunk":chunk,"heights":result.heights})
		frame_commits.append(Time.get_ticks_usec()-before)
		committed=true
		break
	if Time.get_ticks_usec()-started<int(config.commit_budget_usec): _schedule()
	peak_tiles=maxi(peak_tiles,chunks.size())
	peak_estimated_bytes=maxi(peak_estimated_bytes,estimated_bytes())
	var elapsed=Time.get_ticks_usec()-started
	frame_pumps.append(elapsed)
	max_pump_usec=maxi(max_pump_usec,elapsed)
	if committed:
		max_commit_usec=maxi(max_commit_usec,int(frame_commits[-1]))
		if frame_commits[-1]>int(config.commit_budget_usec): commit_over_budget+=1
	# Keep diagnostic storage bounded for arbitrarily long sessions.
	if frame_pumps.size()>4096: frame_pumps=frame_pumps.slice(2048)
	if frame_commits.size()>4096: frame_commits=frame_commits.slice(2048)

func _schedule() -> void:
	if active.size()>=int(config.max_jobs): return
	var candidates: Array[Vector2i]=[]
	for key in desired:
		if active.has(key) or failed.has(key): continue
		if chunks.has(key) and chunks[key].detail==desired[key]: continue
		candidates.append(key)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i):
		var pa=a.distance_squared_to(center)+(0 if desired[a]==int(config.near_subdivisions) else 10000)
		var pb=b.distance_squared_to(center)+(0 if desired[b]==int(config.near_subdivisions) else 10000)
		return pa<pb)
	for key in candidates:
		if active.size()>=int(config.max_jobs): break
		if not chunks.has(key) and chunks.size()+active.size()>=int(config.max_resident_tiles): break
		# Conservative estimate includes native mesh/collider copies and pending jobs.
		if estimated_bytes()+1500000>int(config.terrain_budget_bytes): break
		var job=Job.new()
		job.data=data.fork_reader()
		job.rect=rect_for(key)
		job.detail=desired[key]
		job.collider=job.detail==int(config.near_subdivisions)
		job.tile_size=tile_size; job.cover_count=Vector2(count)
		var task=WorkerThreadPool.add_task(job.run,false,"Terrain %s" % key)
		active[key]={"task":task,"job":job,"detail":job.detail,"generation":generation}

func estimated_bytes() -> int:
	# Payload accounting, not process RSS: driver/BVH allocator overhead is estimated.
	var bytes: int=data.resident_data_bytes()+background_bytes+active.size()*1500000+16*1024*1024
	for chunk in chunks.values(): bytes+=int(chunk.get_meta("resident_bytes",0))*2
	return bytes

func stats() -> Dictionary:
	var commits=frame_commits.duplicate(); commits.sort()
	var pumps=frame_pumps.duplicate(); pumps.sort()
	return {"resident_tiles":chunks.size(),"max_tiles":peak_tiles,"estimated_bytes":estimated_bytes(),"peak_estimated_bytes":peak_estimated_bytes,
		"page_reads":page_reads,"page_evictions":page_evictions,"unloaded_tiles":unloaded_tiles,"discarded_jobs":discarded_jobs,"active_jobs":active.size(),
		"commit_p95_usec":commits[int((commits.size()-1)*.95)] if not commits.is_empty() else 0,
		"commit_max_usec":max_commit_usec,"pump_max_usec":max_pump_usec,"commit_over_budget":commit_over_budget,"pump_p95_usec":pumps[int((pumps.size()-1)*.95)] if not pumps.is_empty() else 0}

func _exit_tree() -> void:
	closing=true
	for work in active.values(): WorkerThreadPool.wait_for_task_completion(work.task)
	active.clear()
