extends RefCounted
## Worker-only disk reads and CPU arrays. No rendering/physics/scene-tree calls.
var data: RefCounted
var rect: Rect2
var detail = 16
var collider = false
var tile_size = 2048.0
var cover_count = Vector2.ONE
var result: Dictionary = {}

func run() -> void:
	var started = Time.get_ticks_usec()
	var stride = detail+1
	var v = PackedVector3Array(); var n = PackedVector3Array()
	var c = PackedColorArray(); var uv = PackedVector2Array()
	var indices = PackedInt32Array()
	for z in stride:
		for x in stride:
			var p = rect.position+rect.size*Vector2(x,z)/detail
			v.append(Vector3(p.x-rect.position.x,data.height_at(p),p.y-rect.position.y))
			n.append(data.normal_at(p,16))
			c.append(data.color_at(p).srgb_to_linear())
			uv.append((p+data.extent*.5)/tile_size/cover_count)
	for z in detail:
		for x in detail:
			var a = z*stride+x
			indices.append_array([a,a+1,a+stride,a+1,a+stride+1,a+stride])
	var heights = PackedFloat32Array()
	if collider:
		for vertex in v: heights.append(vertex.y)
	var edges: Array[PackedInt32Array] = []
	var top = PackedInt32Array(); var bottom = PackedInt32Array()
	var left = PackedInt32Array(); var right = PackedInt32Array()
	for i in stride:
		top.append(i); bottom.append(detail*stride+i)
		left.append(i*stride); right.append(i*stride+detail)
	edges.append_array([top,bottom,left,right])
	for edge in edges:
		for i in detail:
			var a: int=edge[i]; var b: int=edge[i+1]; var base=v.size()
			v.append_array([v[a],v[b],v[a]-Vector3.UP*160,v[b]-Vector3.UP*160])
			for j in 4:
				var index: int = b if j%2 else a
				n.append(n[index]); c.append(c[index]); uv.append(uv[index])
			indices.append_array([base,base+1,base+2,base+1,base+3,base+2])
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=v; arrays[Mesh.ARRAY_NORMAL]=n
	arrays[Mesh.ARRAY_COLOR]=c; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
	result={"arrays":arrays,"heights":heights,"failed":data.read_failed,"worker_usec":Time.get_ticks_usec()-started,"page_reads":data.page_reads,"page_evictions":data.page_evictions,"reader_bytes":data.resident_data_bytes(),"bytes":v.size()*12+n.size()*12+c.size()*16+uv.size()*8+indices.size()*4+heights.size()*4}
	# Disk pages belong only to the job; release them before completion.
	data=null
