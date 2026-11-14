"""Build the measured NightWing craniofacial study; never touches game assets.

Blender --background --python prototypes/moon/head/build_study.py
The intentionally undecorated study exposes the silhouette and uncertain widths.
"""
import json
import math
import sys
import importlib.util
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
import numpy as np
from scipy.ndimage import gaussian_filter1d
DATA = json.loads(Path(__file__).with_name('head_design.json').read_text())
GAME_HEAD=globals().get('GAME_HEAD',False)
OUT = ROOT / 'cache/moon-head-study'
OUT.mkdir(parents=True, exist_ok=True)
if not GAME_HEAD:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def interp(points, x):
    for a, b in zip(points, points[1:]):
        if a[0] <= x <= b[0]:
            t = (x-a[0]) / max(b[0]-a[0], 1e-8)
            return a[1]*(1-t)+b[1]*t
    return points[0][1] if x < points[0][0] else points[-1][1]

def uv(u, v, y=0):
    return ((u-380)/500, y, (550-v)/500)

def frame(kind):
    f=DATA['local_frames'][kind]
    o=Vector(f['origin_uv']);forward=Vector(f['forward_uv'])
    axis=(o-forward).normalized()
    normal=Vector((axis.y,-axis.x))
    return o,axis,normal

def local_point(p,kind):
    o,a,n=frame(kind);d=Vector(p)-o
    return (d.dot(a)/500,d.dot(n)/500)

def image_point(s,h,kind):
    o,a,n=frame(kind)
    return o+a*(s*500)+n*(h*500)

def reference_matrix(kind):
    o,a,n=frame(kind)
    # Columns are local longitudinal, transverse and dorsal axes in Blender.
    return Matrix(((a.x,0,n.x,(o.x-380)/500),
                   (0,1,0,0),
                   (-a.y,0,-n.y,(550-o.y)/500),
                   (0,0,0,1)))

def section_bounds(polygon,s):
    hits=[]
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if min(a[0],b[0]) <= s < max(a[0],b[0]):
            t=(s-a[0])/(b[0]-a[0]);hits.append(a[1]+t*(b[1]-a[1]))
    if len(hits)<2:return None
    return min(hits),max(hits)

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color,1)
    bs.inputs['Roughness'].default_value = .72
    return m

clay = material('Unpainted clay', (.47,.49,.50))
eye_mat = material('Socket contents - clay', (.25,.27,.28))

def clay_foundation():
    spec=importlib.util.spec_from_file_location('clay_head_foundation',ROOT/'prototypes/clay/head/build_head.py')
    H=importlib.util.module_from_spec(spec);spec.loader.exec_module(H)
    zs=np.linspace(H.UPPER[0,0],H.UPPER[-1,0],180)
    MO=H.D['mouth']
    inside=lambda z:H.smoothstep(MO['inside_from'][0],MO['inside_from'][1],z)*H.smoothstep(MO['hinge_z'],MO['hinge_z']+.06,z)
    verts,faces,_=H.loft(H.upper_contour,zs,front_dent=H.front_setback,inner_dip=lambda z:MO['palate_arch']*inside(z),n_inner=24,inner_power=MO['palate_shape_power'],front_round=.010)
    p=np.asarray(verts,float)
    p[:,2]=H.snout_z(H.premaxilla_z(p[:,2],p[:,1]))
    p=H.compact_head_points(p)
    f=H.D['head_compact_frame'];axis=np.asarray(f['axis_yz']);axis/=np.linalg.norm(axis)
    normal=np.array([axis[1],-axis[0]])
    delta=p[:,1:]-np.asarray(f['anchor_yz'])
    # Same local convention as NightWing: forward is negative longitudinal.
    q=np.stack([-delta@axis,p[:,0],delta@normal],axis=1)
    length=float(np.ptp(q[:,0]));width=float(np.ptp(q[:,1]))
    normalized=(q[:,0]-q[:,0].min())/length
    envelope=[]
    for t in np.linspace(0,1,51):
        mask=np.abs(normalized-t)<.025
        envelope.append([float(t),float(np.max(np.abs(q[mask,1]))/length)])
    mesh=bpy.data.meshes.new('Clay accepted facial volume');mesh.from_pydata(q.tolist(),[],faces);mesh.update()
    ob=bpy.data.objects.new('Clay accepted facial volume',mesh);bpy.context.collection.objects.link(ob);ob.data.materials.append(clay)
    comparison_polygon=[local_point(p,'skull') for p in DATA['cranial_roof']['trace']+list(reversed(DATA['maxilla_lip']['trace']))]
    mn,mx=min(p[0] for p in comparison_polygon),max(p[0] for p in comparison_polygon)
    ob['comparison_length']=mx-mn;ob['comparison_centre']=(mx+mn)/2
    for poly in mesh.polygons:poly.use_smooth=True
    # Keep the accepted volume's own proportions in this separate export.
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True)
    if not GAME_HEAD:
        bpy.ops.export_scene.gltf(filepath=str(OUT/'clay-foundation.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True)
    bpy.data.objects.remove(ob,do_unlink=True)
    return envelope,{'anatomical_length':length,'maximum_width':width,'width_length_ratio':width/length,'source':'Actual accepted Clay face generator, with existing transforms'}

CLAY_ENVELOPE,CLAY_METRICS=clay_foundation()
SKULL_POLYGON=[local_point(p,'skull') for p in DATA['cranial_roof']['trace']+list(reversed(DATA['maxilla_lip']['trace']))]
SKULL_MIN=min(p[0] for p in SKULL_POLYGON)
SKULL_LENGTH=max(p[0] for p in SKULL_POLYGON)-SKULL_MIN

def anatomical_width(source,kind):
    longitudinal,_=local_point(source,'skull')
    t=max(0,min(1,(longitudinal-SKULL_MIN)/SKULL_LENGTH))
    d=DATA['foundation'];a,b=d['muzzle_transition_fraction']
    f=max(0,min(1,(t-a)/(b-a)));f=f*f*(3-2*f)
    multiplier=d['muzzle_width_multiplier']*(1-f)+d['skull_width_multiplier']*f
    if kind=='jaw':multiplier*=d['dentary_width_multiplier']
    return interp(CLAY_ENVELOPE,t)*SKULL_LENGTH*multiplier

def curve_distance(u, v, points):
    p = Vector((u,v))
    best = 1e9
    for a,b in zip(points, points[1:]):
        a,b = Vector(a),Vector(b)
        d = b-a
        t = max(0,min(1,(p-a).dot(d)/max(d.length_squared,1e-8)))
        best = min(best,(p-a-d*t).length)
    return best/500

PROFILES={}
centre=None
radius=None
orbital_bevel=None

def inside_orbit(u,v):
    upper,lower=DATA['orbit']['upper'],DATA['orbit']['lower']
    return upper[0][0]<=u<=upper[-1][0] and interp(upper,u)<=v<=interp(lower,u)

def globe_surface(s,h):
    d2=(s-centre.x)**2+(h-centre.z)**2
    return centre.y+math.sqrt(max(0,radius*radius-d2))

def make_profile(top,bottom,kind):
    polygon=[local_point(p,kind) for p in top+list(reversed(bottom))]
    samples=np.linspace(min(p[0] for p in polygon)+.00002,max(p[0] for p in polygon)-.00002,360)
    bounds=np.array([section_bounds(polygon,float(s)) for s in samples])
    # Smooth the tracing's few-pixel corner jitter without turning the profile
    # into a new guessed silhouette. Keep its endpoints and record deviation.
    smoothed=gaussian_filter1d(bounds,1.6,axis=0,mode='nearest')
    smoothed=np.clip(smoothed,bounds-2/500,bounds+2/500)
    smoothed[0]=bounds[0];smoothed[-1]=bounds[-1]
    widths=np.array([anatomical_width(image_point(float(s),float((b+t)/2),kind),kind) for s,(b,t) in zip(samples,smoothed)])
    widths=gaussian_filter1d(widths,3,mode='nearest')
    PROFILES[kind]=(samples,smoothed,widths,float(np.max(np.abs(smoothed-bounds)))*500)

def section(kind,s):
    samples,bounds,widths,_=PROFILES[kind]
    return (float(np.interp(s,samples,bounds[:,0])),float(np.interp(s,samples,bounds[:,1])),float(np.interp(s,samples,widths)))

def section_squareness(kind,s):
    value=DATA['dentary']['section_squareness'] if kind=='jaw' else DATA['foundation']['section_squareness']
    rounded=globals().get('GAME_MUZZLE_SQUARENESS')
    if kind=='skull' and GAME_HEAD and rounded is not None:
        anterior=max(0,min(1,(-s-.50)/.60))
        anterior=anterior*anterior*(3-2*anterior)
        value=value*(1-anterior)+rounded*anterior
    return value

def host_surface(s,h,kind='skull'):
    bottom,top,width=section(kind,s)
    vertical=max(-1,min(1,2*(h-bottom)/max(top-bottom,1e-8)-1))
    squareness=section_squareness(kind,s)
    c=math.copysign(abs(vertical)**(squareness/2),vertical)
    sn=math.sqrt(max(0,1-c*c))
    skin=width*sn**(2/squareness)*(.89+.11*vertical)
    if kind=='skull' and orbital_bevel is not None:
        anchor,height,intercept,slope,band=orbital_bevel
        if s<anchor:
            plane=max(.02,intercept-slope*(anchor-s))
            blend=math.exp(-((h-height)/band)**4)
            settings=DATA['orbit']['preorbital_plane']
            outer,inner=settings['anterior_fade_fractions']
            fade=max(0,min(1,(s-(anchor-outer*SKULL_LENGTH))/((outer-inner)*SKULL_LENGTH)))
            fade=fade*fade*(3-2*fade)
            maximum=settings['maximum_reduction_fraction']*SKULL_LENGTH
            reduction=maximum*math.tanh(max(0,skin-plane)/maximum)
            skin-=reduction*blend*fade
    if kind=='skull' and centre is not None:
        p=image_point(s,h,kind)
        if (s-centre.x)**2+(h-centre.z)**2<radius*radius and not inside_orbit(p.x,p.y):
            skin=max(skin,globe_surface(s,h)+.006)
    return skin

def make_mass(name, top, bottom, kind, socket=False):
    verts, faces = [], []
    make_profile(top,bottom,kind)
    start,end=PROFILES[kind][0][[0,-1]]
    # Cross-sections are NORMAL TO THE ANATOMICAL AXIS, not image columns.
    rings, sides = (420,512) if socket else (280,112)
    for j in range(rings):
        longitudinal=start+(end-start)*j/(rings-1)
        zbottom,ztop,w=section(kind,longitudinal)
        middle=image_point(longitudinal,(ztop+zbottom)/2,kind)
        u=middle.x
        for k in range(sides):
            t = 2*math.pi*k/sides
            c,s = math.cos(t),math.sin(t)
            squareness=section_squareness(kind,longitudinal)
            exponent=2/squareness
            vertical=math.copysign(abs(c)**exponent,c)
            # A bevelled wedge, with a narrower palate than cranial roof.
            z = zbottom+(ztop-zbottom)*(vertical*.5+.5)
            y = math.copysign(host_surface(longitudinal,z,kind),s)
            source=image_point(longitudinal,z,kind);u,v=source.x,source.y
            if socket:
                upper = DATA['orbit']['upper']; lower=DATA['orbit']['lower']
                if upper[0][0] <= u <= upper[-1][0]:
                    a,b = interp(upper,u),interp(lower,u)
                    inside = a <= v <= b
                    edge = min(curve_distance(u,v,upper),curve_distance(u,v,lower))
                    side = abs(s)**6
                    displacement = DATA['orbit']['rim_height']*math.exp(-(edge/.014)**2)
                    if inside:
                        displacement -= DATA['orbit']['socket_depth']*(1-math.exp(-(edge/.0035)**2))
                    y += (1 if y>=0 else -1)*displacement*side
                d = curve_distance(u,v,DATA['nasal_opening']['trace'])
                if not globals().get('GAME_HEAD',False):
                    y -= math.copysign(DATA['nasal_opening']['depth']*math.exp(-(d/.009)**2)*abs(s)**4,y)
                if centre is not None and (longitudinal-centre.x)**2+(z-centre.z)**2<radius*radius:
                    cap=globe_surface(longitudinal,z)
                    if inside_orbit(u,v):
                        # The hidden socket floor follows the globe rather
                        # than plunging far behind it. Deep discontinuous
                        # walls made intervening triangles expose the globe
                        # beyond the lower lid at the aperture boundary.
                        y=math.copysign(cap-.006,y)
                    else:
                        y=math.copysign(max(abs(y),cap+.006),y)
            verts.append((longitudinal,y,z))
    for j in range(rings-1):
        for k in range(sides):
            a=j*sides+k;b=j*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((rings-1)*sides+k for k in range(sides)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(clay)
    for p in mesh.polygons:p.use_smooth=True
    if not socket:
        smooth=obj.modifiers.new('Surface continuity between measured sections','SUBSURF')
        smooth.levels=1;smooth.render_levels=1
    # Recalculate generated loft orientation rather than trusting winding.
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
    return obj

# Seat the globe against the uncarved host normal before constructing its
# surrounding skin, so the orbital host and fitted lids use the same surface.
make_profile(DATA['cranial_roof']['trace'],DATA['maxilla_lip']['trace'],'skull')
GLOBE=DATA['orbit']['globe']
cx,cz=local_point(GLOBE['centre_uv'],'skull')
bevel=DATA['orbit']['preorbital_plane']
anchor=cx+bevel['posterior_anchor_fraction']*SKULL_LENGTH
orbital_bevel=(anchor,cz,host_surface(anchor,cz),bevel['forward_slope'],bevel['height_band_fraction']*SKULL_LENGTH)
cy=host_surface(cx,cz)
epsilon=.001
dx=(host_surface(cx+epsilon,cz)-host_surface(cx-epsilon,cz))/(2*epsilon)
dz=(host_surface(cx,cz+epsilon)-host_surface(cx,cz-epsilon))/(2*epsilon)
normal=Vector((-dx,1,-dz)).normalized()
centre=Vector((cx,cy,cz))-normal*GLOBE['setback']
radius=GLOBE['radius']

head_root=bpy.data.objects.new('SkullFrame',None);bpy.context.collection.objects.link(head_root)
head_reference=reference_matrix('skull')
upper=make_mass('Nasal bridge and maxilla',DATA['cranial_roof']['trace'],DATA['maxilla_lip']['trace'],'skull',True)
upper.parent=head_root
jaw_root=bpy.data.objects.new('JawFrame',None);bpy.context.collection.objects.link(jaw_root)
jaw_root.parent=head_root
jaw_root.matrix_local=head_reference.inverted() @ reference_matrix('jaw')
jaw=make_mass('Dentary - open reference pose',DATA['dentary']['upper'],DATA['dentary']['lower'],'jaw')
jaw.parent=jaw_root

# A full globe sits behind the facial host; the lids fit to the globe and host.
for sign in [-1,1]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=40,radius=radius,location=(centre.x,sign*centre.y,centre.z))
    eye=bpy.context.object;eye.name='Seated eyeball '+str(sign);eye.parent=head_root;eye.data.materials.append(eye_mat)
    for p in eye.data.polygons:p.use_smooth=True
    up,lo=DATA['orbit']['upper'],DATA['orbit']['lower']
    n=DATA['orbit']['lids']['samples'];bands=12
    for upper_lid in [True,False]:
        def lid_vertices(blink):
            points=[]
            for layer in [0,1]:
                for j in range(n):
                    f=j/(n-1);u=291+(368-291)*f
                    a,b=interp(up,u),interp(lo,u)
                    margin=a+(b-a)*blink if upper_lid else b
                    if upper_lid:
                        margin+=max(0,(blink-2/3)*3)*DATA['orbit']['lids']['closure_overlap_pixels']*math.sin(math.pi*f)
                    outer=(a if upper_lid else b)+( -1 if upper_lid else 1)*DATA['orbit']['lids']['width_pixels']*math.sin(math.pi*f)
                    os,oh=local_point((u,outer),'skull')
                    outer_y=host_surface(os,oh)+.001
                    for k in range(bands+1):
                        t=k/bands;v=outer*(1-t)+margin*t
                        s,h=local_point((u,v),'skull')
                        inner_y=globe_surface(s,h)+.0025
                        y=max(outer_y*(1-t)+inner_y*t,globe_surface(s,h)+.0025)
                        points.append((s,sign*(y-layer*.002),h))
            return points
        points=lid_vertices(0);faces=[];rows=n*(bands+1)
        for layer in [0,1]:
            for j in range(n-1):
                for k in range(bands):
                    a=layer*rows+j*(bands+1)+k
                    face=(a,a+1,a+bands+2,a+bands+1)
                    faces.append(face if layer==0 else tuple(reversed(face)))
        for j in range(n-1):
            for k in [0,bands]:
                a=j*(bands+1)+k;b=a+bands+1;faces.append((a,b,b+rows,a+rows))
        mesh=bpy.data.meshes.new('Fitted lid');mesh.from_pydata(points,[],faces);mesh.update()
        obj=bpy.data.objects.new(('Upper lid ' if upper_lid else 'Lower lid ')+str(sign),mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(clay);obj.parent=head_root
        for p in mesh.polygons:p.use_smooth=True
        if upper_lid:
            obj.shape_key_add(name='Basis')
            for i,amount in enumerate(DATA['orbit']['lids']['blink_steps']):
                key=obj.shape_key_add(name='Blink'+str(i+1))
                for point,co in zip(key.data,lid_vertices(amount)):point.co=co

# Save the canonical level head. Reference tilt is supplied separately to viewers.
head_root.matrix_world=Matrix.Identity(4)
metadata={'skull_reference_matrix': [list(r) for r in head_reference],
          'clay_foundation':CLAY_METRICS,
          'nightwing_anatomical_length':SKULL_LENGTH,
          'nightwing_anatomical_min':SKULL_MIN,
          'width_source':'Clay transverse envelope with local NightWing deltas; obsolete thin station widths are not used',
          'skull_tilt_degrees': math.degrees(math.atan2(-frame('skull')[1].y,frame('skull')[1].x)),
          'jaw_tilt_degrees': math.degrees(math.atan2(-frame('jaw')[1].y,frame('jaw')[1].x)),
          'section_axis': 'local longitudinal; never image horizontal',
          'profile_smoothing_maximum_pixels': {kind:profile[3] for kind,profile in PROFILES.items()},
          'eye_globe_centre': list(centre),
          'status': DATA['status']}
joint_s,joint_h=local_point(DATA['dentary']['hinge_uv'],'skull')
joint_bottom,joint_top,_=section('skull',joint_s)
metadata['joint_vertical_clearance_inside_skull']=min(joint_h-joint_bottom,joint_top-joint_h)
assert metadata['joint_vertical_clearance_inside_skull']>0,'Jaw joint is outside the cranial host'
assert all(profile[3]<=2.001 for profile in PROFILES.values()),'Profile smoothing exceeded its reference-pixel limit'
errors=[]
for kind,points in [('skull',DATA['cranial_roof']['trace']+DATA['maxilla_lip']['trace']),('jaw',DATA['dentary']['upper']+DATA['dentary']['lower'])]:
    for p in points:
        s,h=local_point(p,kind)
        errors.append((image_point(s,h,kind)-Vector(p)).length)
metadata['maximum_frame_roundtrip_error_pixels']=max(errors)
assert max(errors)<.001,metadata
if not GAME_HEAD:
    (OUT/'frame-metadata.json').write_text(json.dumps(metadata,indent=2))
head_root['reference_tilt_degrees']=metadata['skull_tilt_degrees']
if not GAME_HEAD:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'nightwing-head-study.glb'),export_format='GLB',export_yup=True,export_extras=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'nightwing-head-study.blend'))
    print('Saved isolated craniofacial study', OUT)
