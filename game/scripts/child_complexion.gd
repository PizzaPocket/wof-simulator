extends RefCounted
## Small skin variation and iris color; lip contours use UV-aligned albedo.
static func paint(mesh: Mesh,profile: Dictionary,eyes: bool=false) -> ArrayMesh:
 var result:=ArrayMesh.new()
 for surface in mesh.get_surface_count():
  var arrays:=mesh.surface_get_arrays(surface)
  var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var colors:=PackedColorArray();colors.resize(points.size())
  for i in points.size():
   if eyes:
    var old: Color=arrays[Mesh.ARRAY_COLOR][i]
    var brightness:=maxf(old.r,maxf(old.g,old.b))
    colors[i]=Color("493025").srgb_to_linear()*(.85+brightness*.9) if brightness>.018 and brightness<.45 else old
   else:
    var p: Vector3=points[i]
    var variation:=sin(p.x*17+p.y*11)*cos(p.z*23-p.y*8)*float(profile.skin_variation)
    # Anatomical lip contour is in the albedo texture; vertex color only
    # contributes very small spatial skin variation, without a second lip mask.
    var c:=Color.WHITE*(1+variation)
    colors[i]=Color(c.r,c.g,c.b,1)
  arrays[Mesh.ARRAY_COLOR]=colors
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  result.surface_set_material(surface,mesh.surface_get_material(surface))
 return result
