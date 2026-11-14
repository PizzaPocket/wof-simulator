"""Fitted Moon nasal cap, shared bite construction and Clay-derived dentition."""
import importlib.util
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from scipy.spatial import cKDTree


def outward(ob):
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()


def build(A,D,H):
    fit_bite_and_tip(A,D,H)
    surface=H['surface'];faces=H['faces'];mouth=D['mouth']
    tree=BVHTree.FromPolygons([Vector(p) for p in surface],faces)
    zmax=float(surface[:,2].max());start=1.36;end=zmax-.065
    def width(z):
        q=surface[np.abs(surface[:,2]-z)<.018]
        return float(np.max(np.abs(q[:,0]))) if len(q) else .13
    def upper_seat(x,z):
        # Smooth load-bearing arcade, independent of the visible lip drape.
        return np.array([x,H['bite_plane'][0]*z+H['bite_plane'][1]+.008*(1-min(1,abs(x)/width(z))**2),z])
    # One closure surface supplies both alveolar beds. The lower jaw is not a
    # separately rotated open-pose outline, and its anterior arc stays recessed.
    zs=np.linspace(start,end,100);ws=[];tops=[]
    for z in zs:
        w=width(z)*.88
        if z>end-.075:w*=math.sqrt(max(.002,1-((z-(end-.075))/.075)**2))
        ws.append(max(.003,w));tops.append(upper_seat(w*.80,z)[1]-mouth['bite_gap'])
    def jaw_width(z):return float(np.interp(z,zs,ws))
    def top(z):return float(np.interp(z,zs,tops))
    def anterior_fraction(z):
        t=np.clip((z-mouth.get('jaw_taper_start',1.72))/max(.05,end-mouth.get('jaw_taper_start',1.72)),0,1)
        return t*t*(3-2*t)
    def floor_depth(z):return mouth['floor_depth']*(1-mouth.get('anterior_floor_reduction',0)*anterior_fraction(z))
    def floor(z,x=0):
        w=jaw_width(z);return top(z)-floor_depth(z)*(1-min(1,abs(x)/w)**2)
    points=[];polygons=[];around=128
    for i,z in enumerate(zs):
        w=ws[i];depth=mouth['jaw_depth']*(.86 if A.ID=='blue' else .8+.2*math.sin(math.pi*i/(len(zs)-1)))
        anterior=anterior_fraction(z)
        depth*=1-(1-mouth.get('anterior_jaw_depth_scale',1))*anterior
        if A.ID=='blue':
            u=np.clip((z-(end-.09))/.09,0,1)
            depth*=math.sqrt(max(0,1-u*u))
        elif z>end-.06:depth*=.55+.45*(end-z)/.06
        # Rounded lip transitions into a trough and a continuous chin shell.
        for j in range(around):
            a=math.tau*j/around;x=w*math.sin(a);c=math.cos(a)
            y=floor(z,x) if c>=0 else top(z)-floor_depth(z)-depth*(-c)**.75
            # Keep one smooth rounded rim at the side rather than a lip shelf.
            if c>=0:y-=.004*(abs(math.sin(a))**16)
            else:y+=floor_depth(z)*abs(math.sin(a))**12
            points.append([x,y,z])
            if i:
                b=(i-1)*around+j;k=(i-1)*around+(j+1)%around;polygons.append([b,k,k+around,b+around])
    polygons.extend([list(range(around-1,-1,-1)),list(range((len(zs)-1)*around,len(points)))])
    jaw=np.array(points);H['jaw']=jaw;H['jaw_faces']=polygons
    skin=A.material('Moon lower facial scales',A.PROFILE['scales'])
    flank=A.linear(A.PROFILE['scales']);belly=A.linear(A.PROFILE['belly'])
    colors=[]
    for index,(x,y,z) in enumerate(jaw):
        if A.ID=='blue':
            # Pigment follows the ventral sector, independent of jaw thickness.
            # A thinner chin must not silently lose its pale underside.
            down=max(0,-math.cos(math.tau*(index%around)/around))
            ventral=np.clip(down/.55,0,1);ventral=ventral*ventral*(3-2*ventral)
        else:ventral=np.clip((floor(z)-y-.035)/.065,0,1)*(.7+.3*(1-min(1,abs(x)/jaw_width(z))**2))*.96
        colors.append(flank*(1-ventral)+belly*ventral)
    jaw_object=A.mesh('MoonSkin continuous lower jaw',jaw,polygons,skin,'jaw',colors=colors);outward(jaw_object)
    jawtree=BVHTree.FromPolygons([Vector(p) for p in jaw],polygons)
    def lower_seat(x,z):
        p,_,_,_=jawtree.ray_cast(Vector((x,2.6,z)),Vector((0,-1,0)),2.)
        if p is None:raise ValueError('Lower bite seat missed: '+str((x,z)))
        return np.array(p)
    # Use the accepted Clay crown primitive: embedded root, oval section and
    # slight throatward recurve, in the same bite frame as both hosts.
    spec=importlib.util.spec_from_file_location('moon_clay_crowns',A.ROOT/'prototypes/clay/head/build_head.py')
    clay=importlib.util.module_from_spec(spec);spec.loader.exec_module(clay);H['clay']=clay
    ivory=A.material('Moon enamel','b7b6a6',.40);gum=A.material('Moon attached gums','45323d',.63)
    archfront=end-.025;join=archfront-.065;back=1.48
    for lower,bone,seat in [(False,'head',upper_seat),(True,'jaw',lower_seat)]:
        sy=1 if lower else -1;inset=.79 if lower else .85
        def w(z):return jaw_width(z)*inset
        # The U-shaped front is explicitly present on both arcades.
        arc=[]
        for z in np.linspace(back,join,48):arc.append(seat(w(z),z))
        fw=w(join)
        for a in np.linspace(math.pi/2,-math.pi/2,49)[1:]:
            arc.append(seat(fw*math.sin(a),join+.065*math.cos(a)))
        for z in np.linspace(join,back,48)[1:]:arc.append(seat(-w(z),z))
        roots=[p-np.array([0,sy*.003,0]) for p in arc]
        A.tube('Moon lower gum arch' if lower else 'Moon upper gum arch',roots,.0055,gum,bone,sides=16)
        verts=[];crowns=[]
        centers=[]
        # Offset the lower stations half a spacing for interdigitation.
        for side in [-1,1]:
            steps=np.linspace(back+(.012 if lower else 0),join-(.008 if lower else 0),mouth['side_teeth'])
            for i,z in enumerate(steps):
                p=seat(side*w(z),z);length=mouth['crown_length']*(.75+.25*math.sin(math.pi*i/(len(steps)-1)))
                direction=np.array([0,sy,0]);tangent=np.array([0,0,1.])
                clay.tooth(verts,crowns,p,direction,tangent,length,.0063,.0042,sink=.004,recurve=.10,NA=20,NL=14)
                centers.append(p.tolist())
        for a in np.linspace(-.9 if lower else -1.08,.9 if lower else 1.08,mouth['front_teeth']-1 if lower else mouth['front_teeth']):
            z=join+.065*math.cos(a);p=seat(fw*math.sin(a),z)
            clay.tooth(verts,crowns,p,np.array([0,sy,0]),np.array([0,0,1.]),mouth['front_crown_length'],.0048,.0038,sink=.004,recurve=.08,NA=20,NL=14)
            centers.append(p.tolist())
        obj=A.mesh('Moon lower dental arcade' if lower else 'Moon upper dental arcade',verts,crowns,ivory,bone);outward(obj)
        H['lower_tooth_roots' if lower else 'upper_tooth_roots']=centers
    lining=A.material('Moon oral mucosa','352630',.68)
    # The tongue's lower surface follows the actual jaw trough with a clearance,
    # so it stays inside when the entire dentary rotates during fire.
    tongue=[];tf=[];clearance=.006;tz=np.linspace(1.45,end-.075,52);rings=32
    for i,z in enumerate(tz):
        u=i/(len(tz)-1);w=min(jaw_width(z)*.48,.063)*math.sqrt(max(.006,1-u**8))
        for j in range(rings):
            a=math.tau*j/rings;x=w*math.sin(a)
            y=floor(z,x)+clearance+.009*(1+math.cos(a))
            y-=.002*math.exp(-(x/.009)**2)*max(0,math.cos(a))
            tongue.append([x,y,z])
            if i:
                b=(i-1)*rings+j;k=(i-1)*rings+(j+1)%rings;tf.append([b,k,k+rings,b+rings])
    tf.extend([list(range(rings-1,-1,-1)),list(range((len(tz)-1)*rings,len(tongue)))])
    obj=A.mesh('Moon floor-fitted muscular tongue',tongue,tf,A.material('Moon tongue','704954',.64),'jaw');outward(obj)
    H['tongue_floor_clearance']=min(p[1]-floor(p[2],p[0]) for p in tongue)
    # Thin inner floor lining remains inside the enclosing jaw, not below it.
    lining_points=[];lf=[]
    for i,z in enumerate(np.linspace(start+.015,end-.012,64)):
        for j,x in enumerate(np.linspace(-jaw_width(z)*.90,jaw_width(z)*.90,32)):
            lining_points.append([x,floor(z,x)+.0015,z])
            if i and j:
                b=(i-1)*32+j-1;k=i*32+j-1;lf.append([b,b+1,k+1,k])
    A.mesh('Moon fitted oral floor',lining_points,lf,lining,'jaw')
    cheek_and_lips(A,D,H,tree,jawtree,jaw_width,top,floor,end)
    nasal_cap(A,D,H)
    print('MOON FITTED BITE',len(H['upper_tooth_roots']),len(H['lower_tooth_roots']),'tongue clearance',H['tongue_floor_clearance'],flush=True)


def fit_bite_and_tip(A,D,H):
    v=H['surface'];faces=H['faces']
    tree=BVHTree.FromPolygons([Vector(p) for p in v],faces)
    zz=np.linspace(1.46,float(v[:,2].max())-.17,32);yy=[]
    for z in zz:
        p,_,_,_=tree.ray_cast(Vector((0,1.,z)),Vector((0,1,0)),2.)
        if p is None:raise ValueError('Cannot reconstruct palatal plane')
        yy.append(p.y)
    slope=float(np.clip(np.polyfit(zz,yy,1)[0],-.20,.10));intercept=float(np.median(np.array(yy)-slope*zz))
    H['bite_plane']=[slope,intercept]
    triangles=np.array([t for f in faces for t in [[f[0],f[i],f[i+1]] for i in range(1,len(f)-1)]])
    normals=A.SK.normals(v,triangles);zmax=float(v[:,2].max())
    original=v.copy()
    for i,p in enumerate(v):
        z=p[2];plane=slope*z+intercept
        if 1.43<z<zmax-.055 and p[1]<plane+.055:
            gate=np.clip((-normals[i,1]-.05)/.55,0,1)
            low=np.clip((plane+.035-p[1])/.035,0,1)
            mix=max(gate,low*.82)
            p[1]+=(plane+.006-p[1])*mix
        t=np.clip((z-(zmax-.11))/.11,0,1);t=t*t*(3-2*t)
        if D['nose_cap'].get('shape')=='rounded':
            p[0]*=1-.10*t
            p[2]-=.014*t*((p[1]-plane-.06)/.15)**2
            continue
        narrow=np.clip((p[1]-plane+.025)/.12,.08,1)
        p[0]*=(1-.28*t)*(1-t+t*narrow)
        if t>0:p[1]=max(p[1],plane-.018*t)
        # Local convex cap converges to a lower central beak point. The whole
        # maxillary body stays supported; only the terminal premaxilla turns.
        p[2]-=.060*t*((p[1]-(plane+.010))/.12)**2
    host=H['host_object']
    for dst,p in zip(host.data.vertices,v):dst.co=A.B(p)
    host.data.update()
    print('MOON SHARED BITE PLANE',H['bite_plane'],flush=True)


def cheek_and_lips(A,D,H,upper_tree,lower_tree,width,top,floor,end):
    skin=A.material('Moon cheek and lip scales',A.PROFILE['scales'],.59)
    mucosa=A.material('Moon buccal lining','382b34',.72)
    slope,intercept=H['bite_plane'];plane=lambda z:slope*z+intercept
    # Fleshy lip drapes around a smooth structural bite. It is not the jaw bed.
    back=1.46;join=end-.09;front=end-.025;arch=[]
    for z in np.linspace(back,join,42):arch.append([width(z)*.985,z])
    fw=width(join)*.985
    for a in np.linspace(math.pi/2,-math.pi/2,49)[1:]:arch.append([fw*math.sin(a),join+(front-join)*math.cos(a)])
    for z in np.linspace(join,back,42)[1:]:arch.append([-width(z)*.985,z])
    points=[];faces=[]
    for i,(x,z) in enumerate(arch):
        target=Vector((x,plane(z)+.025,z));hit,_,_,_=upper_tree.find_nearest(target)
        root=np.array(hit);edge=np.array([x,plane(z)-.012,z])
        for j in range(10):
            t=j/9;p=root*(1-t)+edge*t
            p[0]+=math.copysign(.006*math.sin(math.pi*t),x);points.append(p)
            if i and j:
                a=(i-1)*10+j-1;b=i*10+j-1;faces.append([a,a+1,b+1,b])
    ob=A.mesh('MoonSkin fitted upper lip drape',points,faces,skin,'head',colors=[A.linear(A.PROFILE['scales'])]*len(points));outward(ob)
    ob.shape_key_add(name='Basis');opened=ob.shape_key_add(name='jawOpen')
    for i,p in enumerate(points):
        t=(i%10)/9;opened.data[i].co=A.B(np.asarray(p)+[0,.016*t,0])
    for side in [-1,1]:
        for inner in [False,True]:
            points=[];faces=[];weights=[]
            for i,z in enumerate(np.linspace(1.365,1.565,30)):
                target=Vector((side*width(z),plane(z)+.045,z));u,_,_,_=upper_tree.find_nearest(target)
                target=Vector((side*width(z),top(z)-.022,z));l,_,_,_=lower_tree.find_nearest(target)
                u=np.array(u);l=np.array(l)
                for j in range(25):
                    t=j/24;p=u*(1-t)+l*t
                    p[0]+=side*(.015*math.sin(math.pi*t)-(.005 if inner else 0))
                    p[2]-=.032*math.sin(math.pi*t)*(i/29)**2
                    points.append(p);weights.append([('head',1-t),('jaw',t)])
                    if i and j:
                        a=(i-1)*25+j-1;b=i*25+j-1;faces.append([a,a+1,b+1,b])
            ob=A.mesh('Moon buccal lining' if inner else 'MoonSkin soft cheek commissure',points,faces,mucosa if inner else skin,weights,colors=None if inner else [A.linear(A.PROFILE['scales'])]*len(points));outward(ob)
    # Soft rear oral wall occludes cervical scales inside the open mouth.
    points=[];faces=[];weights=[];z=1.445
    for i,x in enumerate(np.linspace(-width(z)*.90,width(z)*.90,40)):
        upper=np.array([x,plane(z)+.008,z]);lower=np.array([x,floor(z,x)+.002,z])
        for j in range(25):
            t=j/24;p=upper*(1-t)+lower*t;p[2]+=.018*math.sin(math.pi*t)
            points.append(p);weights.append([('head',1-t),('jaw',t)])
            if i and j:
                a=(i-1)*25+j-1;b=i*25+j-1;faces.append([a,a+1,b+1,b])
    A.mesh('Moon soft oral root',points,faces,mucosa,weights)


def nasal_cap(A,D,H):
    v=H['surface'];faces=H['faces'];cfg=D['nose_cap']
    triangles=np.array([t for f in faces for t in [[f[0],f[i],f[i+1]] for i in range(1,len(f)-1)]])
    normals=A.SK.normals(v,triangles);zmax=float(v[:,2].max());start=zmax-cfg['length']
    selected=[f for f in faces if all(v[k,2]>start+.025*min(1,abs(v[k,0])/.13)-.025*np.clip((v[k,1]-(H['bite_plane'][0]*v[k,2]+H['bite_plane'][1])-.06)/.09,0,1) for k in f) and all(v[k,1]>H['bite_plane'][0]*v[k,2]+H['bite_plane'][1]-.023 for k in f)]
    indices=sorted({k for f in selected for k in f});mapping={k:i for i,k in enumerate(indices)}
    points=[v[k]+normals[k]*.004 for k in indices];capfaces=[[mapping[k] for k in f] for f in selected]
    count=len(points);points += [v[k]-normals[k]*.006 for k in indices]
    capfaces += [[count+mapping[k] for k in reversed(f)] for f in selected]
    edges={}
    for f in selected:
        for a,b in zip(f,f[1:]+f[:1]):
            key=tuple(sorted((a,b)));edges[key]=edges.get(key,0)+1
    for (a,b),n in edges.items():
        if n==1:capfaces.append([mapping[a],mapping[b],mapping[b]+count,mapping[a]+count])
    cap=A.mesh('Moon fitted nasal cap',points,capfaces,A.material('Moon nasal keratin',cfg['color'],cfg['roughness']),'head');outward(cap)
    # Ellipsoidal apertures cut BOTH the shell and its underlying carrier.
    candidates=np.where(v[:,2]>start+.005)[0]
    for side in [-1,1]:
        side_candidates=[k for k in candidates if v[k,0]*side>.045 and normals[k,0]*side>.65 and normals[k,1]>.05]
        if not side_candidates:raise ValueError('No lateral nasal seat')
        target=np.array([side*.085,1.98,zmax-.065]);k=min(side_candidates,key=lambda k:np.linalg.norm(v[k]-target))
        normal=A.SK.norm(normals[k]);up=A.SK.norm(np.array([0,1.,0])-normal*normal[1]);across=A.SK.norm(np.cross(up,normal));p=v[k]+normal*.004
        # Frame columns describe the small oval in the cap's local surface.
        frame=Matrix(np.column_stack([A.B(across),A.B(up),A.B(normal)]).tolist())
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=32,radius=1,location=A.B(p-normal*.008))
        cutter=bpy.context.object;cutter.name='Nostril cutter';cutter.rotation_euler=frame.to_euler();cutter.scale=(cfg['nostril_width'],cfg['nostril_height'],cfg['nostril_depth'])
        bpy.context.view_layer.update()
        for host in [cap,H['host_object']]:
            bpy.context.view_layer.objects.active=host
            mod=host.modifiers.new('Actual nostril aperture','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
            bpy.ops.object.modifier_apply(modifier=mod.name)
            attr=host.data.color_attributes.get('AnatomicalPalette')
            if attr:
                for value in attr.data:
                    if min(value.color[:3])>.95:value.color=tuple(A.linear(A.PROFILE['scales']))+(1,)
            group=host.vertex_groups.get('head') or host.vertex_groups.new(name='head');group.add(list(range(len(host.data.vertices))),1,'REPLACE')
        bpy.data.objects.remove(cutter,do_unlink=True)
        # Recessed blind cavity, not a black decal sitting above the cap.
        points=[p-normal*.034];ff=[]
        for i in range(40):
            a=math.tau*i/40;points.append(p-normal*.029+across*math.cos(a)*.009+up*math.sin(a)*.022)
            ff.append([0,i+1,(i+1)%40+1])
        A.mesh('Moon recessed nostril cavity',points,ff,A.material('Moon nostril interior','0b0e14',.86),'head')


def validate_eyes(A,D,H):
    """Trace through the real host/lids, sampling the iris visible at rest."""
    def model(p):return Vector((p[0],p[2],-p[1]))
    def tree(ob,key=None):
        vertices=key.data if key else ob.data.vertices
        return BVHTree.FromPolygons([model(v.co) for v in vertices],[list(p.vertices) for p in ob.data.polygons])
    host=tree(H['host_object']);result=[]
    for center in H['eyes']:
        side=1 if center[0]>0 else -1
        normal=A.SK.norm(np.array(D['eye']['gaze'])*[side,1,1]);across=A.SK.norm(np.cross([0,1,0],normal));up=np.cross(normal,across)
        lids=[o for o in A.ARM.children if o.type=='MESH' and 'lid' in o.name and 'MoonSkin' in o.name and np.mean([v.co.x for v in o.data.vertices])*side>0]
        rest=[host]+[tree(o) for o in lids];closed=[host]+[tree(o,o.data.shape_keys.key_blocks[-1] if o.data.shape_keys else None) for o in lids]
        visible=0;leaks=0
        for x in np.linspace(-.65,.65,11):
            for y in np.linspace(-.65,.65,11):
                if x*x+y*y>.65**2:continue
                direction=A.SK.norm(normal+across*x+up*y);origin=Vector(center+direction*(H['eye_radius']+.0001));ray=Vector(direction)
                if any(t.ray_cast(origin,ray,.085)[0] is not None for t in rest):continue
                visible+=1
                if not any(t.ray_cast(origin,ray,.085)[0] is not None for t in closed):leaks+=1
        result.append({'side':side,'visible_iris_samples':visible,'closed_blink_uncovered_samples':leaks})
    H['eye_validation']=result
    print('MOON EYE COVERAGE',result,flush=True)
    if any(r['visible_iris_samples']<8 for r in result):raise ValueError('Iris hidden behind its orbital host')
    if any(r['closed_blink_uncovered_samples'] for r in result):raise ValueError('Closed eyelid exposes the globe')
