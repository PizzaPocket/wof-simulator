"""Loose garment construction and collision-aware offline cloth draping.

The game receives the baked fabric geometry and its skin weights, not a live
cloth solver. Coordinates passed in/out are Y-up; Blender uses Z-up internally.
"""
import bpy
import numpy as np
from mathutils import Vector

def yup(vertex):return np.array([vertex[0],vertex[2],-vertex[1]])
def blender(point):return (float(point[0]),float(-point[2]),float(point[1]))

def collider(points,faces,name='Temporary body cloth collider'):
    data=bpy.data.meshes.new('Temporary body collision mesh')
    data.from_pydata([blender(v) for v in points],[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob)
    ob.modifiers.new('Body collision','COLLISION')
    ob.collision.thickness_outer=.004
    ob.collision.thickness_inner=.001
    ob.collision.cloth_friction=8
    return ob

def drape(ob,kind,height,neck_y,waist_y,settings):
    unit=height/1.35;scene=bpy.context.scene;scene.frame_set(1)
    for m in list(ob.modifiers):
        if m.type=='ARMATURE':ob.modifiers.remove(m)
    points=np.array([yup(v.co) for v in ob.data.vertices])
    normals=np.array([yup(v.normal) for v in ob.data.vertices])
    initial=points.copy()
    if kind=='shirt' and ob.get('authored_pattern'):
        pin=np.clip((initial[:,1]-(neck_y-.030*unit))/(.018*unit),0,1)
    elif kind=='trousers' and ob.get('authored_pattern'):
        pin=np.clip((initial[:,1]-(waist_y-.003*unit))/(.018*unit),0,1)
    elif kind=='shirt':
        # Add actual pattern ease, strongest at the hem; keep the neckline fitted.
        free=np.clip((neck_y-points[:,1])/(.065*unit),0,1)
        lower=np.clip((.96*unit-points[:,1])/(.20*unit),0,1)
        allowance=(settings['shirt_ease_m']+lower*.009)*unit*free
        points+=normals*allowance[:,None]
        points[:,1]-=.012*unit*lower*free
        pin=np.clip((initial[:,1]-(neck_y-.022*unit))/(.016*unit),0,1)
    else:
        free=np.clip((waist_y+.02*unit-points[:,1])/(.050*unit),0,1)
        allowance=(settings['trouser_ease_m']*unit)*(.25+.75*free)
        points+=normals*allowance[:,None]
        # Keep the cuffs long enough to overlap the boot shafts after draping.
        cuffs=np.clip((.23*unit-points[:,1])/(.13*unit),0,1)
        points[:,1]-=.032*unit*cuffs
        pin=np.clip((initial[:,1]-(waist_y-.003*unit))/(.018*unit),0,1)
    for v,p in zip(ob.data.vertices,points):v.co=blender(p)
    ob.data.update()
    # Fair the pattern before simulation so body grooves are not sewn into it.
    bpy.context.view_layer.objects.active=ob
    fair=ob.modifiers.new('Fabric pattern fairing','SMOOTH');fair.factor=.5;fair.iterations=2 if ob.get('authored_pattern') else 10
    bpy.ops.object.modifier_apply(modifier=fair.name)
    pin_group=ob.vertex_groups.new(name='Cloth anchors')
    for i,w in enumerate(pin):
        if w>0:pin_group.add([i],float(w),'REPLACE')
    if np.count_nonzero(pin>.8)<8:raise RuntimeError(kind+' has no stable cloth anchors')
    cloth=ob.modifiers.new('Offline linen drape','CLOTH')
    cloth.settings.quality=8
    cloth.settings.mass=.12
    cloth.settings.tension_stiffness=30
    cloth.settings.compression_stiffness=25
    cloth.settings.shear_stiffness=15
    cloth.settings.bending_stiffness=.12 if kind=='shirt' else .22
    cloth.settings.air_damping=4
    cloth.settings.vertex_group_mass=pin_group.name
    cloth.settings.pin_stiffness=1
    cloth.collision_settings.use_collision=True
    cloth.collision_settings.distance_min=.005*unit
    cloth.collision_settings.collision_quality=6
    cloth.collision_settings.use_self_collision=True
    cloth.collision_settings.self_distance_min=.003*unit
    cloth.collision_settings.self_friction=4
    cloth.point_cache.frame_start=1
    cloth.point_cache.frame_end=settings['drape_frames']
    for frame in range(1,settings['drape_frames']+1):
        scene.frame_set(frame)
        evaluated=ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
        _=len(evaluated.data.vertices)
        if frame%12==0:print('CLOTH',ob.name,'frame',frame,flush=True)
    bpy.ops.object.modifier_apply(modifier=cloth.name)
    # Remove solver-scale pinches while retaining broad folds. Collision-project
    # the relaxed result so smoothing cannot push fabric through the body.
    relax=ob.modifiers.new('Fabric fold relaxation','SMOOTH');relax.factor=.55;relax.iterations=8
    bpy.ops.object.modifier_apply(modifier=relax.name)
    from mathutils.bvhtree import BVHTree
    for collider_name in ['Temporary body cloth collider','Temporary trouser cloth collider']:
        body=bpy.data.objects.get(collider_name)
        if body is None:continue
        bvh=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
        for v in ob.data.vertices:
            near,normal,_,distance=bvh.find_nearest(v.co)
            if near is not None:
                signed=(v.co-near).dot(normal)
                if signed<.008*unit and distance<.060*unit:v.co=near+normal*(.008*unit)
    if kind=='shirt' and ob.get('authored_pattern'):
        # A loose suspended front panel cannot follow a navel-sized depression.
        # Preserve the broad baked drape and seams, fair only small pinches on
        # the central abdomen; sleeves/collar/hem retain their cloth solution.
        q=np.array([yup(v.co) for v in ob.data.vertices])
        fit=(initial[:,2]>.10*unit)&(abs(initial[:,0])<.15*unit)&(initial[:,1]<neck_y-.09*unit)
        x=q[:,0]/unit;y=(q[:,1]-waist_y)/unit
        basis=np.column_stack([np.ones(len(q)),x,y,x*x,x*y,y*y])
        coefficient=np.linalg.lstsq(basis[fit],q[fit,2],rcond=None)[0]
        broad=basis@coefficient
        def smooth(t):
            t=np.clip(t,0,1);return t*t*(3-2*t)
        weight=smooth((.15*unit-abs(initial[:,0]))/(.035*unit))
        weight*=smooth((initial[:,1]-waist_y+.065*unit)/(.035*unit))
        weight*=smooth((neck_y-.09*unit-initial[:,1])/(.045*unit))
        weight*=initial[:,2]>.10*unit
        fair=broad+np.clip(q[:,2]-broad,-.0015*unit,.004*unit)
        q[:,2]+=(fair-q[:,2])*weight
        for vertex,point in zip(ob.data.vertices,q):vertex.co=blender(point)
    ob.data.update()
    result=np.array([yup(v.co) for v in ob.data.vertices])
    if not np.isfinite(result).all() or np.max(np.linalg.norm(result-initial,axis=1))>.25*unit:
        raise RuntimeError('Unstable cloth bake: '+kind)
    # Anchors are a simulation constraint, not a deform bone in the GLB.
    anchors=ob.vertex_groups.get('Cloth anchors')
    if anchors:ob.vertex_groups.remove(anchors)
    scene.frame_set(1)
    return result,{'method':'Blender cloth collision bake','frames':settings['drape_frames'],
                   'vertices':len(result),'max_pattern_displacement_m':float(np.linalg.norm(result-initial,axis=1).max())}

def thickness(ob,unit,armature,settings):
    bpy.context.view_layer.objects.active=ob
    wall=ob.modifiers.new('Sewn fabric thickness','SOLIDIFY')
    wall.thickness=settings['fabric_thickness_m']*unit;wall.offset=-.5
    wall.use_even_offset=False
    wall.thickness_clamp=.5
    bpy.ops.object.modifier_apply(modifier=wall.name)
    arm=ob.modifiers.new('Garment skinning','ARMATURE');arm.object=armature
    ob.parent=armature

def omit_covered_skin(ob,height,neck_y,waist_y,shoulder,elbow,settings):
    """Remove hidden tissue only after it has served as the cloth collider.

    Keep a generous skin overlap at every garment opening. Use complete faces
    inside the covered region; no boundary through a visible cuff or collar.
    """
    import bmesh
    h=height/1.35
    points=np.array([yup(v.co) for v in ob.data.vertices])
    x=np.abs(points[:,0]);y=points[:,1]
    covered=(y>waist_y-settings['hem_margin_m']*h)&(y<neck_y-settings['collar_margin_m']*h)&(x<shoulder[0]+.010*h)
    mirrored=points.copy();mirrored[:,0]=x
    axis=elbow-shoulder
    along=((mirrored-shoulder)*axis).sum(axis=1)/np.dot(axis,axis)
    radial=np.linalg.norm(mirrored-shoulder-along[:,None]*axis,axis=1)
    covered|=(along>-.12)&(along<settings['sleeve_fraction'])&(radial<.067*h)&(x>.075*h)&(y<shoulder[1]+.012*h)
    bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table()
    hidden=[face for face in bm.faces if all(covered[v.index] for v in face.verts)]
    count=len(hidden)
    bmesh.ops.delete(bm,geom=hidden,context='FACES')
    bm.to_mesh(ob.data);bm.free();ob.data.update()
    print('Omitted',count,'fully shirt-covered skin faces',flush=True)

def shirt_pattern(height,neck,shoulder,waist):
    """Front/back cotton shirt panels joined along shoulder/side/sleeve seams.

    The panel is cut as a flat T-shaped pattern. It contains no skin vertices
    or anatomical surface relief. Neckline, cuffs and hem remain open.
    """
    from scipy.spatial import Delaunay
    h=height/1.35;sy=shoulder[1];sx=shoulder[0]
    width=max(.137*h,sx+.003*h);hem=waist-.070*h
    # Counterclockwise boundary. Each label describes its outgoing seam.
    outline=np.array([
      [-.048*h,neck-.014*h],[-sx-.012*h,sy+.052*h],
      [-sx-.119*h,sy-.047*h],[-sx-.062*h,sy-.110*h],
      [-width,sy-.078*h],[-width,hem],
      [width,hem],[width,sy-.078*h],
      [sx+.062*h,sy-.110*h],[sx+.119*h,sy-.047*h],
      [sx+.012*h,sy+.052*h],[.048*h,neck-.014*h],
      [.034*h,neck-.033*h],[0,neck-.045*h],[-.034*h,neck-.033*h]])
    tags=['shoulder','sleeve_top','cuff','sleeve_bottom','side','hem','side','sleeve_bottom','cuff','sleeve_top','shoulder','neck','neck','neck','neck']
    def surface(x,y,front):
        sleeve=np.clip((abs(x)-width)/(.11*h),0,1)
        depth=(.137 if front else -.083)*h
        depth+=(.072*h-depth)*sleeve if front else (-.052*h-depth)*sleeve
        collar=np.clip((y-(neck-.075*h))/(.055*h),0,1)*np.clip((.075*h-abs(x))/(.025*h),0,1)
        depth=depth*(1-collar)+(.073 if front else -.025)*h*collar
        yy=y+(.018*h*collar if not front else 0)
        return [x,yy,depth]
    return sewn_panels(outline,tags,h,surface)

def sewn_panels(outline,tags,h,surface):
    from scipy.spatial import Delaunay
    coords=[]
    for a,b in zip(outline,np.roll(outline,-1,axis=0)):
        steps=max(1,int(np.ceil(np.linalg.norm(b-a)/(.011*h))))
        coords.extend(a+(b-a)*t/steps for t in range(steps))
    def inside(q):
        result=np.zeros(len(q),bool)
        for a,b in zip(outline,np.roll(outline,-1,axis=0)):
            crossings=(a[1]>q[:,1])!=(b[1]>q[:,1])
            if abs(b[1]-a[1])>1e-12:
                x=a[0]+(q[:,1]-a[1])*(b[0]-a[0])/(b[1]-a[1])
                result^=crossings&(q[:,0]<x)
        return result
    grid=np.array([(x,y) for y in np.arange(outline[:,1].min()+.006*h,outline[:,1].max(),.012*h) for x in np.arange(outline[:,0].min(),outline[:,0].max(),.012*h)])
    coords.extend(grid[inside(grid)])
    xy=np.array(coords);tri=Delaunay(xy).simplices
    # Keep the concave armhole/neck outline, not the triangulation's convex hull.
    valid=inside(xy[tri].mean(axis=1))
    for i,j in [(0,1),(1,2),(2,0)]:
        midpoint=(xy[tri[:,i]]+xy[tri[:,j]])*.5
        # A boundary midpoint can lie exactly on the outline; retain those.
        distances=[]
        for a,b in zip(outline,np.roll(outline,-1,axis=0)):
            t=np.clip(((midpoint-a)*(b-a)).sum(axis=1)/np.dot(b-a,b-a),0,1)
            distances.append(np.linalg.norm(midpoint-a-t[:,None]*(b-a),axis=1))
        valid&=inside(midpoint)|(np.min(distances,axis=0)<1e-6)
    tri=tri[valid];n=len(xy);points=[]
    for front in [True,False]:
        for x,y in xy:points.append(surface(x,y,front))
    faces=[list(t) for t in tri]+[[int(t[2]+n),int(t[1]+n),int(t[0]+n)] for t in tri]
    counts={}
    for f in tri:
        for a,b in zip(f,np.roll(f,-1)):
            key=tuple(sorted([int(a),int(b)]));counts[key]=counts.get(key,0)+1
    columns={}
    def column(i):
        if i not in columns:
            a=np.array(points[i]);b=np.array(points[i+n]);row=[i]
            for j in range(1,9):row.append(len(points));points.append((a+(b-a)*j/9).tolist())
            row.append(i+n);columns[i]=row
        return columns[i]
    for (a,b),count in counts.items():
        if count!=1:continue
        midpoint=(xy[a]+xy[b])*.5;distances=[]
        for p,q in zip(outline,np.roll(outline,-1,axis=0)):
            t=np.clip(np.dot(midpoint-p,q-p)/np.dot(q-p,q-p),0,1)
            distances.append(np.linalg.norm(midpoint-p-t*(q-p)))
        tag=tags[int(np.argmin(distances))]
        if tag in ['hem','cuff','neck','waist']:continue
        ca,cb=column(a),column(b)
        for j in range(9):faces.append([ca[j],cb[j],cb[j+1],ca[j+1]])
    # Give every panel coherent outward normals before expansion/collision.
    return np.array(points),faces


def trouser_pattern(height,waist,hip,knee,ankle):
    """Continuous front/back trouser panels, sewn at outer and inner leg seams."""
    h=height/1.35;top=waist+.02*h;bottom=ankle[1]+.025*h
    hw=hip[0]+.030*h;oh=hip[0]+.050*h
    ok=knee[0]+.048*h;ik=knee[0]-.044*h
    oa=ankle[0]+.041*h;ia=ankle[0]-.039*h
    crotch=hip[1]-.065*h
    outline=np.array([[-hw,top],[hw,top],[oh,hip[1]+.01*h],[ok,knee[1]],[oa,bottom],[ia,bottom],
                      [ik,knee[1]],[0,crotch],[-ik,knee[1]],[-ia,bottom],[-oa,bottom],[-ok,knee[1]],[-oh,hip[1]+.01*h]])
    tags=['waist','side','side','side','cuff','inseam','inseam','inseam','inseam','cuff','side','side','side']
    def surface(x,y,front):
        axis=np.interp(y,[ankle[1],knee[1],hip[1]],[ankle[2],knee[2],hip[2]])
        depth=np.interp(y,[bottom,knee[1],crotch,top],[.049*h,.059*h,.077*h,.075*h])
        return [x,y,axis+(depth if front else -depth)]
    return sewn_panels(outline,tags,h,surface)

def bind_shirt(ob,pattern_points,armature,shoulder_x,shoulder_y,height):
    """Smooth torso/sleeve weights derived from the cut, not nearest skin.

    A flat panel can be closer to an arm than to the ribs. Transferring that
    nearest vertex made the front of the shirt follow the arm during a wave.
    """
    h=height/1.35
    for group in list(ob.vertex_groups):ob.vertex_groups.remove(group)
    spine=sorted([(armature.data.bones[n].head_local.z,n) for n in ['spine01','spine02','spine03','spine04','spine05']])
    groups={}
    def assign(i,name,w):
        if w<1e-5:return
        if name not in groups:groups[name]=ob.vertex_groups.new(name=name)
        groups[name].add([i],float(w),'REPLACE')
    for i,p in enumerate(pattern_points):
        t=float(np.clip((abs(p[0])-(shoulder_x-.005*h))/(.070*h),0,1))
        sleeve=t*t*(3-2*t)
        # The side hem is not part of the sleeve even when a loose shirt is
        # wider than the shoulder joint. Keep that entire lower panel on spine.
        elev=float(np.clip((p[1]-(shoulder_y-.14*h))/(.08*h),0,1));elev=elev*elev*(3-2*elev)
        outer=float(np.clip((abs(p[0])-(shoulder_x+.018*h))/(.037*h),0,1));outer=outer*outer*(3-2*outer)
        sleeve*=max(elev,outer)
        side='L' if p[0]>0 else 'R'
        assign(i,'upperarm01.'+side,sleeve*.92)
        assign(i,'shoulder01.'+side,sleeve*.08)
        if p[1]<=spine[0][0]:assign(i,spine[0][1],1-sleeve)
        elif p[1]>=spine[-1][0]:assign(i,spine[-1][1],1-sleeve)
        else:
            for (a,an),(b,bn) in zip(spine,spine[1:]):
                if a<=p[1]<=b:
                    f=(p[1]-a)/(b-a);assign(i,an,(1-sleeve)*(1-f));assign(i,bn,(1-sleeve)*f);break
