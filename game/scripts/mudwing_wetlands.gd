extends "res://scripts/playground.gd"
## Raised mud causeways through a flooded, irregular marsh region.
const HALF_SIZE := 250.0
const GRID := 240
const WATER_LEVEL := -0.3
const REGION_ID := &"mudwing_wetlands_01"
const Forms = preload("res://scripts/wetland_forms.gd")
var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wetlands_world.json"))
var homes: Array[Vector2] = []
var causeways: Array[Dictionary] = []
var roster_save_path := "user://protagonists.cfg"
const WALLOWS := [Vector2(-42, 14), Vector2(18, 68)]
const VILLAGE_LEVEL := 1.1
const DARKSTALKER_SITE := Vector2(-42, -65)
const WALLOW_FLOOR := -1.7
const MUD_LEVEL := -0.28
const GroundPaint = preload("res://scripts/ground_paint.gd")


func _ready() -> void:
	# Direct scene runs and existing tests retain immediate initialization.
	if not has_meta("startup_loader"):
		initialize_world()


func _loading(callback: Callable, fraction: float, description: String) -> void:
	if callback.is_valid():
		await callback.call(fraction, description)


func initialize_world(progress_callback: Callable = Callable()) -> void:
	await _loading(progress_callback, 0.0, "Planning village paths")
	for entry in design.homes:homes.append(Vector2(entry[0],entry[1]))
	_build_causeways()
	_make_environment()
	await _loading(progress_callback, 0.04, "Sculpting the marsh terrain")
	await _make_terrain(progress_callback)
	_make_region_boundary()
	await _loading(progress_callback, 0.68, "Building rivers and pools")
	_make_water()
	await _loading(progress_callback, 0.74, "Building nests and causeways")
	_make_village()
	await _loading(progress_callback, 0.80, "Planting reeds and wetland trees")
	_make_vegetation()
	# Broad roots and low obstacles on dry ground, away from the spawn approach.
	for point in [Vector2(-96, 16), Vector2(-112, 20), Vector2(-128, 24)]:
		var log_body := _box("FallenTrunk", Vector3(9, 0.8, 1.3), Vector3(point.x, _height(point.x, point.y) + 0.3, point.y), Color("68533d"))
		log_body.rotation.y = 0.25
	_make_hud()
	player.spawn_position = Vector3(_path_x(10)+1, _height(_path_x(10)+1, 10) + 0.15, 10)
	player.reset_to_spawn()
	await _loading(progress_callback, 0.88, "Preparing villagers and conversations")
	_make_villagers()
	await _loading(progress_callback, 1.0, "Village ready")


func _make_region_boundary() -> void:
	# Closed, two-sided collision ring follows the irregular shoreline. It has
	# no visible mesh and is not climbable. Tall side walls keep this local scene
	# bounded horizontally; there is no overhead flight ceiling.
	var boundary := StaticBody3D.new()
	boundary.name = "RegionBoundary"
	boundary.collision_layer = 1
	add_child(boundary)
	var faces := PackedVector3Array()
	var segments := 256
	var wall_top := 12000.0
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		var p := Vector3(cos(a), 0, sin(a)) * (_region_radius(a) - 5.0)
		var q := Vector3(cos(b), 0, sin(b)) * (_region_radius(b) - 5.0)
		var low_p := Vector3(p.x, -40, p.z)
		var low_q := Vector3(q.x, -40, q.z)
		var high_p := Vector3(p.x, wall_top, p.z)
		var high_q := Vector3(q.x, wall_top, q.z)
		faces.append_array([low_p, high_p, high_q, low_p, high_q, low_q])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	boundary.add_child(collider)


func _region_radius(angle: float) -> float:
	return 236.0+18*sin(angle*3+.4)+19*cos(angle*5-.8)+9*sin(angle*9)

func _map_point(x: float,z: float) -> Vector2:
	var u:=x/HALF_SIZE;var v:=z/HALF_SIZE
	var disc:=Vector2(u*sqrt(maxf(0,1-v*v*.5)),v*sqrt(maxf(0,1-u*u*.5)))
	var shaped:=disc*_region_radius(disc.angle())
	return shaped

func _segment_distance(p: Vector2,a: Vector2,b: Vector2) -> float:
	var t:=clampf((p-a).dot(b-a)/maxf(.01,(b-a).length_squared()),0,1)
	return p.distance_to(a+(b-a)*t)

func _build_causeways() -> void:
	for i in homes.size():
		var home:=homes[i];var toward:=1.0 if home.x<-13 else -1.0
		var radius: float=design.homes[i][2]
		var a:=Vector2(_path_x(home.y-5),home.y-5)
		var d:=home+Vector2(toward*radius*.85,0)
		var b:=a+Vector2((d.x-a.x)*.18,8+sin(i)*2)
		var c:=d+Vector2(toward*5,-3)
		var points: Array[Vector2]=[];var widths: Array[float]=[]
		var lo:=a.min(d)-Vector2(7,12);var hi:=a.max(d)+Vector2(7,12)
		for j in 9:
			var t:=j/8.0
			points.append(a*pow(1-t,3)+b*3*pow(1-t,2)*t+c*3*(1-t)*t*t+d*t*t*t)
			widths.append(2.5+.45*sin(t*7+i*1.7)+.25*cos(t*11-i))
		causeways.append({"points":points,"widths":widths,"lo":lo,"hi":hi})

func _main_width(z: float) -> float:
	var tip:=smoothstep(-92,-66,z)*(1-smoothstep(89,122,z))
	return (9+.9*sin(z/18)+.5*cos(z/8))*sqrt(tip)

func _height(x: float, z: float) -> float:
	var point:=Vector2(x,z)
	var center:=62.0+19*sin(z/56.0)+8*sin(z/23.0+.6)
	var width:=18.0+7*sin(z/37.0)+3*cos(z/17.0)
	var channel:=absf(x-center)/width
	var rolling:=.22*sin(x/21.0)*cos(z/29.0)+.09*sin(x/7.3+z/11.0)
	var y: float=-.38+rolling
	y=minf(y,lerpf(-5.8+.7*sin(z/33.0),y,smoothstep(.30,1.38,channel)))
	for channel_id in 3:
		var d: float
		var w: float
		if channel_id==0:d=absf(z-20-9*sin(x/24.0));w=4.6+1.8*sin(x/17.0)
		elif channel_id==1:d=absf(z+97+13*sin(x/31.0));w=6+2*cos(x/25.0)
		else:d=absf(x+38-8*sin(z/19.0));w=2.6+.8*cos(z/15.0)
		y=minf(y,lerpf(-2.0,y,smoothstep(.25,1.6,d/w)))
	for pool in design.pools:
		var delta:=Vector2((x-pool[0])/pool[2],(z-pool[1])/pool[3])
		if delta.length_squared()>3.3:continue
		var shape:=delta.length()+.09*sin(delta.angle()*3+pool[0])+.05*cos(delta.angle()*5)
		y=minf(y,lerpf(-float(pool[4]),y,smoothstep(.35,1.25,shape)))
	# Raised, walkable mud above the marsh; original village spine is preserved.
	if z>-92 and z<122:
		var tip:=smoothstep(-92,-66,z)*(1-smoothstep(89,122,z))
		var path_width:=_main_width(z)
		y=lerpf(y,VILLAGE_LEVEL,(1-smoothstep(path_width,path_width+3.5,absf(x-_path_x(z))))*tip)
	for i in homes.size():
		var home:=homes[i];var radius: float=design.homes[i][2]
		var distance:=point.distance_to(home)
		if distance<radius+5:y=lerpf(y,VILLAGE_LEVEL,1-smoothstep(radius*.9,radius+5,distance))
	for branch in causeways:
		if x<branch.lo.x or x>branch.hi.x or z<branch.lo.y or z>branch.hi.y:continue
		for j in range(branch.points.size()-1):
			var d:=_segment_distance(point,branch.points[j],branch.points[j+1])
			var branch_width: float=branch.widths[j]
			if d<branch_width+2:y=lerpf(y,VILLAGE_LEVEL,1-smoothstep(branch_width,branch_width+2,d))
	for wallow in WALLOWS:
		var distance: Vector2=(point-wallow)/Vector2(12,9)
		y=lerpf(y,WALLOW_FLOOR,1-smoothstep(.5,1.35,distance.length()))
	# A broad dry clearing supports the ancient dragon's full stance.
	y=lerpf(y,VILLAGE_LEVEL,1-smoothstep(14,21,point.distance_to(DARKSTALKER_SITE)))
	var edge:=_region_radius(point.angle())-point.length()
	y=lerpf(-9.0,y,smoothstep(0,16,edge))
	return y

func _path_x(z: float) -> float:
	return -13.0 + 3.0*sin(z/38.0)+.7*sin(z/13.0)


func _make_terrain(progress_callback: Callable = Callable()) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision_points:=PackedVector3Array()
	for z in range(GRID):
		if progress_callback.is_valid() and z % 8 == 0:
			await _loading(progress_callback, 0.04 + 0.59 * z / GRID, "Sculpting marsh terrain · row %d / %d" % [z, GRID])
		for x in range(GRID):
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var px: float = -HALF_SIZE + (x + corner.x) * (HALF_SIZE * 2.0 / GRID)
				var pz: float = -HALF_SIZE + (z + corner.y) * (HALF_SIZE * 2.0 / GRID)
				var mapped:=_map_point(px,pz)
				px=mapped.x;pz=mapped.y
				var y := _height(px, pz)
				var damp:=.5+.5*sin(px*.17+sin(pz*.13))*cos(pz*.11)
				var color := Color("998565").lerp(Color("4f6b3e"),damp*.85)
				color=color.lerp(Color("a28b66"),smoothstep(.2,.85,y)*.65)
				surface.set_color(color)
				surface.add_vertex(Vector3(px, y, pz))
				collision_points.append(Vector3(px,_mud_bed(px,pz,y),pz))
	await _loading(progress_callback, 0.64, "Baking terrain mesh and collision")
	surface.generate_normals()
	surface.index()
	var terrain := MeshInstance3D.new()
	terrain.name = "WetlandTerrain"
	terrain.mesh = surface.commit()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/wetland_ground.gdshader")
	terrain.material_override=material
	GroundPaint.mark_terrain(terrain)
	add_child(terrain)
	var body:=StaticBody3D.new();body.name="WetlandSupportBed"
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(collision_points)
	var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);add_child(body)


func _make_water() -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n:=100
	for z in n:
		for x in n:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p:=_map_point(-HALF_SIZE+(x+corner.x)*500/n,-HALF_SIZE+(z+corner.y)*500/n)
				var depth:=clampf((WATER_LEVEL-_height(p.x,p.y))/7.0,0,1)
				st.set_color(Color(depth,0,0));st.add_vertex(Vector3(p.x,WATER_LEVEL,p.y))
	st.generate_normals();st.index()
	var water:=MeshInstance3D.new();water.name="MarshWater";water.mesh=st.commit()
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/river_water.gdshader")
	var marsh:Dictionary=design.marsh_water
	material.set_shader_parameter("marsh_enabled",1.0)
	material.set_shader_parameter("marsh_color",Color(marsh.color))
	material.set_shader_parameter("algae_color",Color(marsh.algae_color))
	material.set_shader_parameter("silt_color",Color(marsh.silt_color))
	material.set_shader_parameter("shallow_depth_m",marsh.shallow_depth_m)
	material.set_shader_parameter("open_depth_m",marsh.open_depth_m)
	water.material_override=material;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _batch(title: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = title
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
	instance.multimesh = batch
	instance.material_override = material
	add_child(instance)


func _make_vegetation() -> void:
	var random:=RandomNumberGenerator.new();random.seed=27031
	var leaf_material:=ShaderMaterial.new()
	leaf_material.shader=preload("res://shaders/marsh_foliage.gdshader")
	var groups: Array=[[],[],[]]
	var points: Array[Vector2]=[Vector2(-101,90),Vector2(93,22),Vector2(-88,-30),Vector2(37,99)]
	for i in 155:
		var p:=Vector2(random.randf_range(-216,216),random.randf_range(-216,216))
		if p.length()>_region_radius(p.angle())-20:continue
		if absf(p.x-_path_x(p.y))<22 and p.y>-95 and p.y<115:continue
		var clear:=true
		for home in homes:
			if p.distance_to(home)<20:clear=false
		if clear:points.append(p)
	for i in points.size():
		var p:=points[i];var y:=_height(p.x,p.y)
		if y<-1.4:continue
		var scale_factor:=1.65 if i==0 else random.randf_range(.7,1.3)
		var transform:=Transform3D(Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3.ONE*scale_factor),Vector3(p.x,y,p.y))
		groups[i%3].append(transform)
	for kind in 3:
		var transforms: Array[Transform3D]=[]
		for t in groups[kind]:transforms.append(t)
		_batch(["WeepingWillows","ButtressedCypress","MarshAlders"][kind],Forms.tree(kind),leaf_material,transforms)
	var reeds: Array[Transform3D]=[]
	for i in int(design.grass_clumps):
		var p:=Vector2(random.randf_range(-100,55),random.randf_range(-95,115)) if i%3==0 else Vector2(random.randf_range(-230,230),random.randf_range(-230,230))
		if p.length()>_region_radius(p.angle())-10:continue
		var y:=_height(p.x,p.y)
		if y<-.65 or y>.45:continue
		if p.y>-80 and p.y<110 and absf(p.x-_path_x(p.y))<10:continue
		var size:=random.randf_range(.75,1.6)
		var basis:=Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3(size,random.randf_range(.8,1.65),size))
		reeds.append(Transform3D(basis,Vector3(p.x,y,p.y)))
	# Overlapping clumps form continuous high-grass beds, not scattered tufts.
	for field in design.grass_fields:
		var rx: float=field[2];var rz: float=field[3]
		for ix in range(int(-rx/.75),int(rx/.75)+1):
			for iz in range(int(-rz/.75),int(rz/.75)+1):
				var p:=Vector2(field[0]+ix*.75+random.randf_range(-.22,.22),field[1]+iz*.75+random.randf_range(-.22,.22))
				var shape:=Vector2((p.x-field[0])/rx,(p.y-field[1])/rz)
				if shape.length()>1+.08*sin(p.x*.8+p.y*.35):continue
				var y:=_height(p.x,p.y)
				if y<-.72 or y>.40:continue
				var basis:=Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3(random.randf_range(1.1,1.5),random.randf_range(1.5,2.1),random.randf_range(1.1,1.5)))
				reeds.append(Transform3D(basis,Vector3(p.x,y,p.y)))
	_batch("TallMarshSedges",Forms.grass(),leaf_material,reeds)

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)


func _make_village() -> void:
	_make_ground_paint()
	var mud:=ShaderMaterial.new()
	mud.shader=preload("res://shaders/wetland_ground.gdshader")
	for i in homes.size():
		_make_sleep_house(i, homes[i], mud)
	# Only the submerged bed collides: Clay can walk into and out of the mud.
	var wet_mud := _material(Color("938263"))
	wet_mud.roughness = 0.65
	for i in WALLOWS.size():
		var center: Vector2 = WALLOWS[i]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in 32:
			surface.add_vertex(Vector3(center.x, MUD_LEVEL, center.y))
			for angle in [TAU * segment / 32.0, TAU * (segment + 1) / 32.0]:
				# Extend underneath the banks so terrain hides the perimeter cleanly.
				surface.add_vertex(Vector3(center.x + 19.0 * (1+.08*sin(angle*5)+.06*cos(angle*3)) * cos(angle), MUD_LEVEL, center.y + 14.0 * (1+.08*sin(angle*5)+.06*cos(angle*3)) * sin(angle)))
		var puddle := MeshInstance3D.new()
		puddle.name = "MudWallow%d" % i
		surface.generate_normals()
		puddle.mesh = surface.commit()
		puddle.material_override = wet_mud
		add_child(puddle)


func _make_ground_paint() -> void:
	var strokes: Array=[];var patches: Array=[]
	for z in range(-88,121,5):
		var width:=maxf(.3,_main_width(z)*1.05)
		var points: Array[Vector2]=[Vector2(_path_x(z),z),Vector2(_path_x(z+5),z+5)]
		strokes.append({"points":points,"width":width})
	for branch in causeways:
		for j in range(branch.points.size()-1):
			var points: Array[Vector2]=[branch.points[j],branch.points[j+1]]
			strokes.append({"points":points,"width":branch.widths[j]*1.65})
	GroundPaint.paint(self,strokes,patches,VILLAGE_LEVEL,"VillageWornEarth",Color("8d805a"),Color("a08d68"),.93,4207,_dry_ground_paint_weight)

func _dry_ground_paint_weight(point: Vector2) -> float:
	# Worn dry earth fades before the mud line; water, houses and props are excluded
	# by the terrain-only render layer, not by extra collision or per-frame work.
	return smoothstep(MUD_LEVEL + 0.1, VILLAGE_LEVEL, _height(point.x, point.y))


func _make_sleep_house(index: int,center: Vector2,mud: Material) -> void:
	var toward:=Vector2(_path_x(center.y),center.y)-center
	var facing:=toward.angle()+.18*sin(index*2.1)
	var entry: Array=design.homes[index]
	var house:=MeshInstance3D.new();house.name="SharedSleepHouse%d"%index
	house.mesh=Forms.nest(entry[2],entry[3],index+7,facing,design.entrance)
	house.material_override=mud;house.position=Vector3(center.x,VILLAGE_LEVEL-.1,center.y)
	add_child(house);house.create_trimesh_collision()
	for body in house.get_children():
		if body is StaticBody3D: body.add_to_group("climbable")

func _make_villagers() -> void:
	player.collision_mask |= 2
	var roster := preload("res://scripts/protagonist_roster.gd").new()
	roster.name = "Protagonists"
	roster.save_path = roster_save_path
	roster.player = player
	roster.register(player)
	var conversations := preload("res://scripts/village_conversations.gd").new()
	conversations.name = "Conversations"
	conversations.player = player
	var cast := [
		{"id": "umber", "age": 0, "playable": true, "start": Vector2(-10, -10), "route": [Vector2(-10, -16), Vector2(-17, -17), Vector2(-16, -7), Vector2(-9, -5)]},
		{"id": "moon", "start": Vector2(-18, -30), "route": [Vector2(-18, -30), Vector2(-12, -27)]},
		{"id": "blue", "start": Vector2(_path_x(2)-3, 2), "route": [Vector2(_path_x(2)-3, 2), Vector2(_path_x(-3)-3, -3)]},
		{"id": "darkstalker", "start": DARKSTALKER_SITE, "route": [], "facing": -2.75},
		{"id": "wren", "start": Vector2(-8, 16), "route": [Vector2(-8, 16), Vector2(-11, 18)]},
		{"id": "kai", "age": 9, "start": Vector2(-5, 4), "route": [Vector2(-8, 0), Vector2(-10, -3), Vector2(-7, 5)]},
		{"id": "camille", "age": 9, "start": Vector2(-12, 2), "route": [Vector2(-14, 1), Vector2(-14, -3), Vector2(-11, 3)]},
		{"id": "corinne", "age": 6, "start": Vector2(-14, 4), "route": [Vector2(-15, 3), Vector2(-16, 0), Vector2(-14, 2)]},
	]
	for entry in cast:
		var npc := preload("res://scripts/protagonist_factory.gd").make_actor(entry.id)
		npc.age = entry.get("age", npc.age)
		npc.listener = player
		npc.position = Vector3(entry.start.x, _height(entry.start.x, entry.start.y) + 0.08, entry.start.y)
		for point in entry.route:
			npc.route.append(Vector3(point.x, _height(point.x, point.y) + 0.08, point.y))
		add_child(npc)
		if entry.has("facing"):npc.visual.rotation.y=entry.facing
		if entry.id=="darkstalker":
			var shape: CapsuleShape3D=npc.get_node("CollisionShape3D").shape
			shape.radius=4.0;shape.height=16.0
			npc.get_node("CollisionShape3D").position.y=8.0
			npc.activity="watching the village"
			npc.visual.motion.player_controlled=false
		conversations.villagers.append(npc)
		if npc.playable:
			roster.register(npc)
	add_child(conversations)
	roster.switched.connect(func(_previous, current):
		player = current
		conversations.follow_player(current)
		for villager in conversations.villagers:
			villager.listener = current if villager != current else null)
	add_child(roster)


func _mud_bed(_x: float,_z: float,visible_y: float) -> float:
	if visible_y<-1.3:return visible_y
	var softness: float=(1-smoothstep(-.70,.65,visible_y))*smoothstep(-1.3,-.7,visible_y)
	return visible_y-.65*softness

func sample_soft_mud(point: Vector3) -> Dictionary:
	for wallow in WALLOWS:
		if ((Vector2(point.x,point.z)-wallow)/Vector2(14,10)).length()<1:
			return {"surface_y":MUD_LEVEL,"softness":1.0,"max_depth":.90,"wallow":true}
	var h:=_height(point.x,point.z)
	if h>.65 or h<-.95:return {}
	return {"surface_y":h,"softness":1-smoothstep(-.70,.65,h),"max_depth":.65,"wallow":false}

func is_dry_ground(point: Vector3) -> bool:
	return _height(point.x,point.z)>.65

func dry_refuge(point: Vector3) -> Vector3:
	var z:=clampf(point.z,-64,84)
	var x:=_path_x(z)
	return Vector3(x,_height(x,z)+.08,z)
