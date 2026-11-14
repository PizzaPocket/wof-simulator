extends RefCounted
## Shared organic meshes: layered mud nests, tapered branches and hanging leaf sprays.
static func vertex(st: SurfaceTool, p: Vector3, color: Color) -> void:
 st.set_color(color);st.add_vertex(p)
static func tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,col: Color) -> void:
 for p in [a,b,c]:vertex(st,p,col)
static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,col: Color) -> void:
 tri(st,a,b,c,col);tri(st,a,c,d,col)
static func tube(st: SurfaceTool,points: Array,radii: Array,color: Color,sides: int=7) -> void:
 var rings: Array=[]
 for i in points.size():
  var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
  var right:=tangent.cross(Vector3.FORWARD).normalized()
  if right.length_squared()<.1:right=tangent.cross(Vector3.RIGHT).normalized()
  var front:=right.cross(tangent).normalized()
  var ring: Array[Vector3]=[]
  for j in sides:
   var a:=TAU*j/sides
   ring.append(points[i]+(right*cos(a)+front*sin(a))*radii[i])
  rings.append(ring)
 for i in range(points.size()-1):
  for j in sides:quad(st,rings[i][j],rings[i][(j+1)%sides],rings[i+1][(j+1)%sides],rings[i+1][j],color)
static func nest(radius: float,height: float,seed_value: int,facing: float,entrance: Dictionary={}) -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var half_width:float=entrance.get("azimuth_half_width",.52)
 var center:float=entrance.get("elevation_center",.78)
 var half_height:float=entrance.get("elevation_half_height",.34)
 var n:=96;var m:=48;var points: Array=[];var kept: Array=[]
 for inner in 2:
  var grid: Array=[]
  for j in range(m+1):
   var row: Array[Vector3]=[]
   var base_phi:=j*PI*.5/m
   for i in n:
    var a:=TAU*i/n
    var phi:=base_phi
    var beside_hole:=false;var beside_wall:=false
    for dj in [-1,0]:
     for di in [-1,0]:
      var qa: float=TAU*(i+di+.5)/n
      var qp: float=(j+dj+.5)*PI*.5/m
      var hole:=pow(wrapf(qa-facing,-PI,PI)/half_width,2)+pow((qp-center)/half_height,2)<1
      beside_hole=beside_hole or hole;beside_wall=beside_wall or not hole
    if beside_hole and beside_wall:
     var da:=wrapf(a-facing,-PI,PI)/half_width;var dp:=(phi-center)/half_height
     var length:=sqrt(da*da+dp*dp)
     a=facing+da/length*half_width;phi=center+dp/length*half_height
    var y:=height*sin(phi)
    var uneven:=1+.045*sin(a*3+seed_value)+.025*cos(a*7-phi*3)
    var coil:=.10*sin(y*7+1.2*sin(a*3))
    var r: float=maxf(0,(radius-inner*.85)*pow(maxf(0,cos(phi)),.78)*uneven+coil*cos(phi))
    var offset:=Vector3(sin(seed_value*.7)*radius*.16,0,cos(seed_value*.9)*radius*.12)*pow(sin(phi),2)
    row.append(Vector3(cos(a)*r,(height-inner*.85)*sin(phi),sin(a)*r)+offset)
   grid.append(row)
  points.append(grid)
 for j in m:
  var row: Array[bool]=[]
  for i in n:
   var a:=TAU*(i+.5)/n
   var phi:=(j+.5)*PI*.5/m
   var da:=wrapf(a-facing,-PI,PI)
   # Offset high side entrance, not a ground doorway or central roof hatch.
   row.append(pow(da/half_width,2)+pow((phi-center)/half_height,2)>1)
  kept.append(row)
 for j in m:
  for i in n:
   if not kept[j][i]:continue
   var k: int=(i+1)%n
   var c:=Color("967f5d").lerp(Color("7f754f"),.22+.12*sin(j*.9+i*.4+seed_value))
   quad(st,points[0][j][i],points[0][j][k],points[0][j+1][k],points[0][j+1][i],c)
   quad(st,points[1][j+1][i],points[1][j+1][k],points[1][j][k],points[1][j][i],c.darkened(.22))
   for edge in 4:
    var neighbor: bool=true
    if edge==0 and j>0:neighbor=kept[j-1][i]
    if edge==1:neighbor=kept[j][k]
    if edge==2 and j<m-1:neighbor=kept[j+1][i]
    if edge==3:neighbor=kept[j][posmod(i-1,n)]
    if neighbor:continue
    var coords: Array=[[j,i],[j,k],[j+1,k],[j+1,i]]
    var a: Array=coords[edge];var b: Array=coords[(edge+1)%4]
    quad(st,points[0][a[0]][a[1]],points[1][a[0]][a[1]],points[1][b[0]][b[1]],points[0][b[0]][b[1]],c.lightened(.06))
 st.generate_normals();st.index();return st.commit()
static func leaf(st: SurfaceTool,base: Vector3,tip: Vector3,width: float,col: Color) -> void:
 var axis:=(tip-base).normalized();var side:=axis.cross(Vector3(.3,.8,.2)).normalized()*width
 var middle:=base.lerp(tip,.45)+Vector3.UP*width*.4
 quad(st,base,middle-side,tip,middle+side,col)
static func tree(kind: int) -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rng:=RandomNumberGenerator.new();rng.seed=9821+kind*77
 var bark:=Color("696b4c") if kind==0 else Color("716653")
 tube(st,[Vector3.ZERO,Vector3(.2,1.5,.1),Vector3(-.35,5,.2),Vector3(.45,9,-.1),Vector3(.2,13,0)],[1.05,.62,.43,.25,.045],bark,10)
 for root in 7:
  var a:=root*TAU/7
  tube(st,[Vector3(cos(a)*2.4,-.1,sin(a)*2.4),Vector3(cos(a)*.9,.6,sin(a)*.9),Vector3(0,1.8,0)],[.12,.36,.45],bark,6)
 if kind==1:
  for k in 6:
   var a:=rng.randf_range(0,TAU);var p:=Vector3(cos(a)*rng.randf_range(2,4),0,sin(a)*rng.randf_range(2,4))
   tube(st,[p,p+Vector3(.08,.6,0),p+Vector3(0,rng.randf_range(.8,1.3),.1)],[.22,.12,.015],bark,6)
 for branch in 14:
  var a:=branch*2.399+kind*.7
  var y:=5.6+branch*.43
  var reach:=rng.randf_range(4.2,7.2) if kind!=1 else 5.7-branch*.23
  var base:=Vector3(.15,y,0);var out:=Vector3(cos(a),0,sin(a))
  var elbow:=base+out*reach*.5+Vector3.UP*1.6
  var tip:=base+out*reach+Vector3.UP*(.5 if kind==0 else 1.3)
  var curve: Array=[];var radii: Array=[]
  for k in 8:
   var q:=k/7.0
   curve.append(base*(1-q)*(1-q)+elbow*2*q*(1-q)+tip*q*q)
   radii.append(lerpf(.20,.025,q))
  tube(st,curve,radii,bark,7)
  for twig in 13:
   var t: float=.22+twig*.06
   var start:=base.lerp(tip,t)+Vector3.UP*sin(t*PI)*1.3
   var bend:=Vector3(cos(a+1.2),0,sin(a+1.2))*rng.randf_range(.5,1.9)
   var drop:=rng.randf_range(2.8,5.4) if kind==0 else rng.randf_range(.9,2.3)
   var end:=start+bend-Vector3.UP*drop
   tube(st,[start,start+bend*.7-Vector3.UP*drop*.25,end],[.022,.012,.003],bark,4)
   for j in range(1,16):
    var q: float=j/15.0
    var p:=start.lerp(end,q)+bend*sin(q*PI)*.22
    for sign_side in [-1,1]:
     var direction:=Vector3(cos(a+sign_side*.8),-.65,sin(a+sign_side*.8))
     var tint:=Color("667d42").lerp(Color("8d9958"),rng.randf()*.65)
     if kind==1:tint=tint.darkened(.14)
     leaf(st,p,p+direction*rng.randf_range(.65,1.15),rng.randf_range(.075,.14),tint)
 st.generate_normals();st.index();return st.commit()
static func grass() -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 8:
  var a:=i*2.399;var length:=.8+.18*(i%5)
  var base:=Vector3(cos(a)*.18,0,sin(a)*.18)
  var tip:=base+Vector3(cos(a)*.45,length,sin(a)*.45)
  var side:=Vector3(-sin(a),0,cos(a))*.055
  var middle:=base.lerp(tip,.62)+Vector3.UP*.13
  quad(st,base-side,middle-side*.7,tip,middle+side*.7,Color("7d9050").lerp(Color("a09d65"),float(i%3)/5))
 st.generate_normals();return st.commit()
