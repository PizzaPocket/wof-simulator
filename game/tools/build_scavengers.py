"""Build fitted, skinned child characters and sewn bags from anatomical source data.

Blender --background --python-exit-code 1 --python game/tools/build_scavengers.py
Sources: python3 game/tools/fetch_human_source.py (pinned CC0 MakeHuman hm08).
Source coordinates and design data are Y up, +Z forward, in metres. Blender
coordinates are (x, -z, y); glTF restores the game convention at export.
"""
from pathlib import Path
import sys, json, math, random, struct
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'cache/clay-python'))
sys.path.insert(0, str(ROOT/'game/tools'))
import child_anatomy as Anatomy
import child_garments as Garments
import bpy
import numpy as np
from mathutils import Vector
from scipy.spatial import cKDTree, ConvexHull
SRC=ROOT/'cache/human-source'
OUT=ROOT/'game/assets/scavengers'
DESIGN=json.loads((ROOT/'game/data/scavenger_design.json').read_text())
RIG=json.loads((SRC/'default.mhskel').read_text())
WEIGHTS=json.loads((SRC/'default_weights.mhw').read_text())['weights']
# Prepubescent children have one plain trunk surface. Include all source chest
# vertices in its fitting domain and skin them to the parent trunk, eliminating
# separate breast controls and the islands that previously escaped flattening.
for chest_bone in ['breast.L','breast.R']:
    combined=dict(WEIGHTS['spine02'])
    for i,w in WEIGHTS.pop(chest_bone,[]):combined[i]=combined.get(i,0)+w
    WEIGHTS['spine02']=list(combined.items())

TAU=math.tau

def read_obj(path):
    vs=[];uvs=[];fs=[];groups={};face_uv=[];group=''
    for line in path.read_text().splitlines():
        t=line.split()
        if not t:continue
        if t[0]=='v':vs.append(list(map(float,t[1:4])))
        elif t[0]=='vt':uvs.append(list(map(float,t[1:3])))
        elif t[0]=='g':group=t[1]
        elif t[0]=='f':
            f=[i.split('/') for i in t[1:]]
            groups.setdefault(group,[]).append(len(fs))
            fs.append([int(i[0])-1 for i in f])
            face_uv.append([int(i[1])-1 if len(i)>1 and i[1] else -1 for i in f])
    return np.array(vs),fs,groups,uvs,face_uv
BASE,FACES,GROUPS,UVS,FUV=read_obj(SRC/'base.obj')
BODY_IDS=sorted(set(i for f in GROUPS['body'] for i in FACES[f]))
BODY_TREE=None
CURRENT=None
CURRENT_W=None
ARM=None
MATERIALS={}

def B(v):return (float(v[0]),float(-v[2]),float(v[1]))
def rgb(hex):return tuple((int(hex[i:i+2],16)/255)**2.2 for i in (0,2,4))+(1,)
def material(name,color,rough=.65,metal=0):
    if name in MATERIALS:return MATERIALS[name]
    m=bpy.data.materials.new(name);m.diffuse_color=rgb(color);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=rgb(color)
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    if 'Skin' in name:bs.inputs['Subsurface Weight'].default_value=.045
    MATERIALS[name]=m;return m

def mesh(name,points,faces,mat,source_ids=None,rigid=None,uv=None):
    data=bpy.data.meshes.new(name);data.from_pydata([B(v) for v in points],[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    for p in data.polygons:p.use_smooth=True
    if uv:
        layer=data.uv_layers.new(name='UVMap')
        for p,face in zip(data.polygons,uv):
            for li,coord in zip(p.loop_indices,face):layer.data[li].uv=coord
    if rigid:
        group=obj.vertex_groups.new(name=rigid);group.add(list(range(len(points))),1,'REPLACE')
    elif source_ids is not None:
        buckets={}
        for local,source in enumerate(source_ids):
            for bone,w in CURRENT_W[source]:buckets.setdefault(bone,[]).append((local,w))
        for bone,items in buckets.items():
            group=obj.vertex_groups.new(name=bone)
            for i,w in items:group.add([i],w,'REPLACE')
    if rigid or source_ids is not None:
        mod=obj.modifiers.new('Anatomical skinning','ARMATURE');mod.object=ARM;obj.parent=ARM
    return obj

def subdiv(obj,levels=1):
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Anatomical surface subdivision','SUBSURF');mod.levels=levels
    # Apply before the armature so the exported skin retains fitted weights.
    bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)

def tube(name,points,radii,mat,rigid=None,source_ids=None,sides=6,flatten=1):
    points=np.array(points);vs=[];fs=[]
    for i,p in enumerate(points):
        tangent=points[min(i+1,len(points)-1)]-points[max(i-1,0)]
        tangent/=max(np.linalg.norm(tangent),1e-9)
        hint=np.array([0.,0.,1.]) if abs(tangent[2])<.8 else np.array([1.,0.,0.])
        side=np.cross(tangent,hint);side/=np.linalg.norm(side);other=np.cross(tangent,side)
        r=radii[i] if hasattr(radii,'__len__') else radii
        for j in range(sides):
            a=TAU*j/sides;vs.append(p+r*(side*math.cos(a)+other*math.sin(a)*flatten))
        if i:
            for j in range(sides):fs.append([(i-1)*sides+j,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j])
    fs.extend([list(range(sides-1,-1,-1)),list(range((len(points)-1)*sides,len(points)*sides))])
    ids=None if source_ids is None else [source_ids[min(i//sides,len(source_ids)-1)] for i in range(len(vs))]
    return mesh(name,vs,fs,mat,ids,rigid)

def source_subset(name,face_indices,mat,offset=0,ease=0):
    ids=sorted(set(i for f in face_indices for i in FACES[f]));lookup={source:i for i,source in enumerate(ids)}
    points=CURRENT[ids].copy();fs=[[lookup[i] for i in FACES[f]] for f in face_indices]
    norms=np.zeros_like(points)
    for f in fs:
        n=np.cross(points[f[1]]-points[f[0]],points[f[2]]-points[f[0]])
        for i in f:norms[i]+=n
    norms/=np.maximum(np.linalg.norm(norms,axis=1)[:,None],1e-10)
    points+=norms*offset
    if ease:
        points[:,0]*=1+ease
        points[:,2]=.025+(points[:,2]-.025)*(1+ease)
        # Fine fabric compression gathers about the waist and sleeve boundaries.
        amp=.0016*np.exp(-((points[:,1]-.73*HEIGHT/1.35)/(.12*HEIGHT/1.35))**2)
        wave=np.sin(points[:,1]*140+np.sin(points[:,0]*85)*1.3)
        points+=norms*(amp*wave)[:,None]
    uv=[[UVS[i] if i>=0 else (0,0) for i in FUV[f]] for f in face_indices]
    # Helper vertices inherit the nearest underlying anatomical skin weights.
    source_ids=[i if i<len(CURRENT_W) and CURRENT_W[i] else BODY_IDS[BODY_TREE.query(CURRENT[i])[1]] for i in ids]
    if 'shirt' in name.lower() or 'trouser' in name.lower():
        edges={}
        for face in fs:
            for a,b in zip(face,face[1:]+face[:1]):
                e=tuple(sorted((a,b)));edges[e]=edges.get(e,0)+1
        neighbors={}
        for (a,b),count in edges.items():
            if count==1:neighbors.setdefault(a,[]).append(b);neighbors.setdefault(b,[]).append(a)
        for step in range(12):
            previous=points.copy()
            for i,adjacent in neighbors.items():
                if len(adjacent)==2:points[i]=previous[i]*.4+previous[adjacent].mean(axis=0)*.6
    obj=mesh(name,points,fs,mat,source_ids,uv=uv)
    return obj,ids,points,fs,source_ids

def boundary_stitches(name,points,faces,mat,source_ids,spacing=.008):
    edges={}
    for f in faces:
        for a,b in zip(f,f[1:]+f[:1]):key=tuple(sorted((a,b)));edges[key]=edges.get(key,0)+1
    # Stitched rolled edges make cuffs and the neckline thickness readable.
    for n,((a,b),count) in enumerate(edges.items()):
        if count!=1:continue
        p,q=points[a],points[b];length=np.linalg.norm(q-p)
        if length<.001:continue
        tube(name+' rolled hem', [p,q],.0011,mat,source_ids=[source_ids[a],source_ids[b]],sides=5)

def build_armature():
    global ARM
    data=bpy.data.armatures.new('Anatomical child skeleton');ARM=bpy.data.objects.new('HumanRig',data)
    bpy.context.collection.objects.link(ARM);bpy.context.view_layer.objects.active=ARM;ARM.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name,definition in RIG['bones'].items():
        b=data.edit_bones.new(name)
        b.head=B(CURRENT[RIG['joints'][definition['head']]].mean(axis=0))
        b.tail=B(CURRENT[RIG['joints'][definition['tail']]].mean(axis=0))
        if (b.tail-b.head).length<1e-5:b.tail=b.head+Vector((0,0,.005))
    for name,definition in RIG['bones'].items():
        if definition['parent']:data.edit_bones[name].parent=data.edit_bones[definition['parent']]
    bpy.ops.object.mode_set(mode='OBJECT');ARM.select_set(False)

def joint(group):
    ids=sorted(set(i for f in GROUPS[group] for i in FACES[f]));return CURRENT[ids].mean(axis=0)

def build_eyes():
    raw,fs,groups,uvs,fuv=read_obj(SRC/'high-poly.obj');mapping=[];factor=np.ones(3);reading=False
    for line in (SRC/'high-poly.mhclo').read_text().splitlines():
        t=line.split()
        if not t or t[0].startswith('#'):continue
        if t[0] in ('x_scale','y_scale','z_scale'):
            axis={'x_scale':0,'y_scale':1,'z_scale':2}[t[0]]
            factor[axis]=abs(RAW[int(t[1]),axis]-RAW[int(t[2]),axis])/float(t[3])
        elif t[0]=='verts':reading=True
        elif reading and t[0][0].isdigit():
            if len(t)==1:mapping.append(RAW[int(t[0])])
            elif len(t)==9:
                ix=list(map(int,t[:3]));w=np.array(list(map(float,t[3:6])));off=np.array(list(map(float,t[6:9])))
                mapping.append((RAW[ix]*w[:,None]).sum(axis=0)+off*factor)
        elif reading:break
    global EYE_POINTS
    p=np.array(mapping);p[:,1]-=BOTTOM;p*=SCALE
    EYE_POINTS=p.copy()
    obj=mesh('Fixed anatomical eyeballs',p,fs,material('Eye sclera','e3ddd0',.27),rigid='head')
    # Anatomical eye surface is fixed; coloration follows the eye's front normal.
    colors=obj.data.color_attributes.new(name='EyeColor',type='FLOAT_COLOR',domain='POINT')
    for side in [-1,1]:
        ids=np.where(p[:,0]*side>0)[0];center=(p[ids].max(axis=0)+p[ids].min(axis=0))*.5
        radius=(p[ids,0].max()-p[ids,0].min())*.5
        for i in ids:
            rel=p[i]-center;rad=np.linalg.norm(rel[:2])
            c=rgb('e3ddd0')
            if rel[2]>0 and rad<radius*.47:
                f=rad/(radius*.47);c=rgb('675b3f' if NAME=='kai' else '668b85' if NAME=='camille' else '5b3929' if NAME=='wren' else '769065')
                if f>.86:c=rgb('3b4035')
                if f<.42:c=rgb('151b18')
            colors.data[i].color=c
    bs=obj.data.materials[0].node_tree.nodes.get('Principled BSDF');attr=obj.data.materials[0].node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='EyeColor'
    obj.data.materials[0].node_tree.links.new(attr.outputs['Color'],bs.inputs['Base Color'])
    print(NAME,'eyes bounds',p.min(axis=0),p.max(axis=0),flush=True)
    return obj

def build_blink(skin,ids):
    # Add thin orbital shells. Their outer borders remain on the socket while
    # the margins sweep across the fixed globe; forehead and brows never move.
    from mathutils.bvhtree import BVHTree
    skin_points=[(v.co.x,v.co.z,-v.co.y) for v in skin.data.vertices]
    bvh=BVHTree.FromPolygons([Vector(v) for v in skin_points],[list(p.vertices) for p in skin.data.polygons],all_triangles=False)
    h=HEIGHT/1.35
    _,eye_faces,_,_,_=read_obj(SRC/'high-poly.obj')
    eye_bvh=BVHTree.FromPolygons([Vector(v) for v in EYE_POINTS],eye_faces,all_triangles=False)
    for side in [-1,1]:
        eye=EYE_POINTS[EYE_POINTS[:,0]*side>0]
        low=eye.min(axis=0);high=eye.max(axis=0);center=(low+high)*.5
        rx=(high[0]-low[0])*.5;ry=(high[1]-low[1])*.5;rz=(high[2]-low[2])*.5
        for upper in [True,False]:
            sample_sets=[];N=40;M=8
            for amount in [0,1/3,2/3,1]:
                points=[]
                for j in range(M+1):
                    t=j/M
                    for i in range(N+1):
                        u=i/N*2-1
                        x=center[0]+u*rx*.98
                        arch=max(0,1-u*u)**.65
                        opened=(.0057 if upper else -.0049)*h*arch
                        closed=(-.00035 if upper else .00035)*h*arch
                        inner_y=center[1]+opened*(1-amount)+closed*amount
                        outer_y=center[1]+(.0135 if upper else -.012)*h*arch
                        hit=bvh.ray_cast(Vector((x,outer_y,.35*h)),Vector((0,0,-1)),.7*h)[0]
                        outer_z=hit.z if hit else center[2]+rz*.65
                        fraction=max(0,1-((x-center[0])/rx)**2-((inner_y-center[1])/ry)**2)
                        inner_z=center[2]+rz*math.sqrt(fraction)+.00050*h
                        eye_hit=eye_bvh.ray_cast(Vector((x,inner_y,.35*h)),Vector((0,0,-1)),.7*h)[0]
                        if eye_hit:inner_z=max(inner_z,eye_hit.z+.0005*h)
                        y=inner_y*(1-t)+outer_y*t
                        z=inner_z*(1-t)+outer_z*t+.00020*h*math.sin(t*math.pi)
                        cornea=eye_bvh.ray_cast(Vector((x,y,.35*h)),Vector((0,0,-1)),.7*h)[0]
                        if cornea:z=max(z,cornea.z+.0007*h)
                        points.append([x,y,z])
                sample_sets.append(points)
            faces=[]
            for j in range(M):
                for i in range(N):
                    a=j*(N+1)+i;face=[a,a+1,a+N+2,a+N+1]
                    faces.append(face if upper else face[::-1])
            obj=mesh(('Upper' if upper else 'Lower')+' anatomical eyelid '+str(side),sample_sets[0],faces,skin.data.materials[0],rigid='head')
            obj.shape_key_add(name='Basis')
            for n,points in enumerate(sample_sets[1:],1):
                key=obj.shape_key_add(name='blink'+str(n))
                for vertex,point in zip(key.data,points):vertex.co=B(point)
            if upper:
                # The upper lid's physical margin gives the closed eye a fine
                # crease instead of merging the two shells into a blank dome.
                base_color=DESIGN['characters'][NAME]['skin']
                shade=''.join(f'{int(int(base_color[k:k+2],16)*.63):02x}' for k in [0,2,4])
                rim_mat=material('Upper eyelid margin',shade,.80)
                paths=[np.array(sample[:N+1])+np.array([0,0,.00025*h]) for sample in sample_sets]
                rim=tube('Upper lid margin '+str(side),paths[0],.00024*h,rim_mat,rigid='head',sides=6)
                rim.shape_key_add(name='Basis')
                for n,path in enumerate(paths[1:],1):
                    reference=tube('Temporary lid margin',path,.00024*h,rim_mat,rigid='head',sides=6)
                    key=rim.shape_key_add(name='blink'+str(n))
                    for v,source in zip(key.data,reference.data.vertices):v.co=source.co
                    data=reference.data;bpy.data.objects.remove(reference,do_unlink=True);bpy.data.meshes.remove(data)


def fit_proxy(path, original, bottom=None, scale=None):
    vertex_file=None;factor=np.ones(3);mapping=[];reading=False
    lines=path.read_text().splitlines()
    for line in lines:
        t=line.split()
        if not t or t[0].startswith('#'):continue
        if t[0]=='obj_file':vertex_file=path.parent/t[1]
        elif t[0] in ('x_scale','y_scale','z_scale'):
            axis={'x_scale':0,'y_scale':1,'z_scale':2}[t[0]]
            factor[axis]=abs(original[int(t[1]),axis]-original[int(t[2]),axis])/float(t[3])
    raw,faces,groups,uvs,fuv=read_obj(vertex_file)
    for line in lines:
        t=line.split()
        if not t or t[0].startswith('#'):continue
        if t[0]=='verts':reading=True;continue
        if not reading:continue
        if t[0][0].isdigit():
            if len(t)==1:mapping.append(original[int(t[0])])
            elif len(t)==9:
                ids=list(map(int,t[:3]));w=np.array(list(map(float,t[3:6])));off=np.array(list(map(float,t[6:9])))
                mapping.append((original[ids]*w[:,None]).sum(axis=0)+off*factor)
        if len(mapping)==len(raw):break
    if len(mapping)!=len(raw):raise ValueError(f'Incomplete proxy mapping in {path}: {len(mapping)} / {len(raw)}')
    points=np.array(mapping);points[:,1]-=BOTTOM if bottom is None else bottom;points*=SCALE if scale is None else scale
    return points,faces,uvs,fuv

def build_hair(settings):
    from PIL import Image
    asset=settings['hair_asset']
    folder=SRC/'authored-hair/hair'/asset
    proxy=folder/(asset+'.mhclo')
    points,faces,uvs,fuv=fit_proxy(proxy,ORIGINAL_RAW,ACCEPTED_BOTTOM,ACCEPTED_SCALE)
    h=HEIGHT/1.35
    if NAME=='wren':
        low=points[:,1]<1.39
        points[low,1]=1.39-(1.39-points[low,1])*.45
    # The authored card flow and volume remain intact. Camille has only a small
    # low-frequency wave; Corinne uses a separately authored curly hairstyle.
    if NAME=='camille' and asset=='long01':
        t=np.clip((1.12*h-points[:,1])/(.42*h),0,1)
        points[:,0]+=.0045*h*np.sin(t*TAU*.8)*t
        points[:,2]+=.0035*h*np.cos(t*TAU*.8)*t
    mat_path=next(folder.glob('*.mhmat'))
    diffuse=None
    for line in mat_path.read_text().splitlines():
        parts=line.split()
        if parts and parts[0]=='diffuseTexture':diffuse=folder/' '.join(parts[1:])
    if diffuse is None:raise ValueError('Hair asset has no strand texture: '+str(mat_path))
    image=Image.open(diffuse).convert('RGBA');data=np.asarray(image).copy()
    color=data[:,:,:3].astype(float)/255
    lum=color@np.array([.2126,.7152,.0722]);valid=data[:,:,3]>180
    low,high=np.percentile(lum[valid],[5,95])
    value=np.clip((lum-low)/max(high-low,.01),0,1.2)
    tint=np.array([int(settings['hair'][i:i+2],16)/255 for i in [0,2,4]])
    data[:,:,:3]=np.clip(tint[None,None,:]*(.50+.60*value[:,:,None])*255,0,255).astype(np.uint8)
    generated=ROOT/'cache/human-source'/('hair-'+NAME+'.png');Image.fromarray(data).save(generated)
    mat=material('Authored textured hair','ffffff',.65)
    nodes=mat.node_tree.nodes;bs=nodes.get('Principled BSDF');tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(generated),check_existing=False)
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
    mat.surface_render_method='DITHERED'
    obj=mesh('Authored hair '+asset,points,faces,mat,rigid='head',uv=[[uvs[i] if i>=0 else (0,0) for i in face] for face in fuv])
    # Clean redundant polygons in older authored assets before glTF export.
    if obj.data.validate(clean_customdata=False):
        print('Cleaned legacy hair mesh:',asset,flush=True)
    # Long ends follow the torso lightly, while the scalp follows the head.
    if NAME!='kai':
        head=obj.vertex_groups.get('head');spine=obj.vertex_groups.new(name='spine01')
        for i,p in enumerate(points):
            weight=float(np.clip((p[1]-.94*h)/(.19*h),0,1));weight=weight*weight*(3-2*weight)
            head.add([i],weight,'REPLACE');spine.add([i],1-weight,'REPLACE')
    from mathutils.bvhtree import BVHTree
    skin=bpy.data.objects.get('Continuous anatomical skin')
    tree=BVHTree.FromPolygons([tuple(v.co) for v in skin.data.vertices],[list(f.vertices) for f in skin.data.polygons])
    brow=material('Eyebrows',settings.get('brow_color',settings['hair']),.86)
    rng=random.Random(1701)
    def on_face(x,y):
        hit,normal,_,_=tree.ray_cast(Vector(B([x,y,.40*h])),Vector((0,1,0)),.6*h)
        if hit is None:raise ValueError('Brow misses forehead surface')
        return Garments.yup(hit+normal*.0004*h)
    for side in [-1,1]:
        e=joint('joint-l-upperlid' if side>0 else 'joint-r-upperlid')
        for strand in range(100):
            t=(strand+rng.random()*.7)/100
            x=e[0]+side*(t-.5)*.033*h
            thickness=.0042*h*math.sin(math.pi*(.07+.86*t))**.55
            y=e[1]+.0055*h+.0025*h*math.sin(t*math.pi*.9)+(rng.random()-.5)*thickness
            length=(.0020+.0010*rng.random())*h
            dx=side*length*(.25+.6*t);dy=length*(.85-.5*t)
            path=[on_face(x,y),on_face(x+dx*.5,y+dy*.6),on_face(x+dx,y+dy)]
            tube('Soft brow hairs',path,(.00010+.000035*rng.random())*h,brow,rigid='head',sides=4)
    print('HAIR',NAME,asset,len(points),'authored card vertices',flush=True)

def make_soft_bag(name,center,width,depth,height,mat,thread,rigid=None,front_axis='z'):
    # A sewn gusset bag: rounded rectangular sections, irregular shoulders and a soft base.
    center=np.array(center);vs=[];fs=[];N=64;M=20
    for j in range(M+1):
        t=j/M;y=(t-.5)*height
        fullness=.45+.55*math.sin(math.pi*t)**.35
        for i in range(N):
            a=TAU*i/N
            ca=math.cos(a);sa=math.sin(a)
            x=math.copysign(abs(ca)**.55,ca)*width*.5*fullness
            z=math.copysign(abs(sa)**.55,sa)*depth*.5*fullness
            fold=(.0012*math.sin(7*a+t*3)+.0025*math.sin(3*a-t*4))*math.sin(math.pi*t)
            x+=math.cos(a)*fold;z+=math.sin(a)*fold
            yy=y-.01*(1-t)*math.sin(a)**2+.004*math.sin(3*a+.4)*t**4
            vs.append(center+np.array([x,yy,z]))
    for j in range(M):
        for i in range(N):fs.append([j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i])
    fs.append(list(range(N-1,-1,-1)))
    fs.append(list(range(M*N,(M+1)*N)))
    obj=mesh(name,vs,fs,mat,rigid=rigid)
    for a in [math.pi*.22,math.pi*.78,math.pi*1.22,math.pi*1.78]:
        k=round(a/TAU*N)%N
        line=[vs[j*N+k] for j in range(M+1)]
        tube(name+' panel seam',line,.0007,thread,rigid=rigid,sides=4)
    return obj

def ribbon(name,points,width,thickness,mat,rigid=None):
    pts=np.array(points);vs=[];fs=[]
    for i,p in enumerate(pts):
        tangent=pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]
        tangent/=max(np.linalg.norm(tangent),1e-9)
        across=np.array([1.,0,0]) if abs(tangent[0])<.8 else np.array([0.,0,1.])
        across-=np.dot(across,tangent)*tangent;across/=np.linalg.norm(across)
        normal=np.cross(across,tangent)
        for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:vs.append(p+across*width*.5*a+normal*thickness*.5*b)
        if i:
            for k in range(4):fs.append([(i-1)*4+k,(i-1)*4+(k+1)%4,i*4+(k+1)%4,i*4+k])
    fs.extend([[3,2,1,0],list(range(len(vs)-4,len(vs)))])
    ob=mesh(name,vs,fs,mat,rigid=rigid)
    return ob

def build_backpack(h):
    canvas=material('Canvas backpack','97754b',.93);leather=material('Leather pack straps','6d4d32',.84);thread=material('Flax stitching','b7a17e',.9)
    center=np.array([0,.92,-.103])*h
    make_soft_bag('Sewn backpack with gussets',center,.20*h,.105*h,.245*h,canvas,thread,rigid='spine01')
    # A separate curved flap drapes over the top and down the rear panel.
    pts=[];fs=[];NX=20;NY=18
    for j in range(NY+1):
        t=j/NY
        for i in range(NX+1):
            u=(i/NX*2-1)
            x=u*.096*h*(1-.13*t**4)
            y=(1.05-.12*t-.009*u*u)*h
            z=(-.09-.078*math.sin(min(1,t*2)*math.pi/2))*h
            z+=.002*h*math.sin(u*12+t*9)*t
            pts.append([x,y,z])
    for j in range(NY):
        for i in range(NX):a=j*(NX+1)+i;fs.append([a,a+1,a+NX+2,a+NX+1])
    mesh('Soft overhanging pack flap',pts,fs,leather,rigid='spine01')
    tube('Pack flap stitched edge',[pts[NY*(NX+1)+i] for i in range(NX+1)],.0008*h,thread,rigid='spine01')
    # Fit webbing to the generated clothed torso instead of fixed adult-depth
    # coordinates, which left the straps floating after a smaller chest fit.
    from mathutils.bvhtree import BVHTree
    skin_bvh=SHIRT_BVH
    shoulder_y=joint('joint-l-shoulder')[1]
    for side in [-1,1]:
        p=np.array([[side*.064,1.03,-.10],[side*.074,1.075,-.04],[side*.080,1.10,.005],
                    [side*.086,1.04,.064],[side*.088,.96,.101],[side*.074,.86,.093],
                    [side*.07,.81,-.04],[side*.063,.82,-.10]])*h
        for i in [1,3,4,5]:
            front=i!=1
            origin=Vector((p[i,0],p[i,1],(.5 if front else -.5)*h))
            hit=skin_bvh.ray_cast(origin,Vector((0,0,-1 if front else 1)),h)[0]
            if hit:p[i,2]=hit.z+(.004 if front else -.004)*h
        hit=skin_bvh.ray_cast(Vector((p[2,0],1.30*h,p[2,2])),Vector((0,-1,0)),.4*h)[0]
        if hit:p[2,1]=hit.y+.004*h
        ribbon('Fitted shoulder strap',p,.018*h,.002*h,leather,rigid='spine01')
    make_soft_bag('Front pocket on backpack',[0,.858*h,-.168*h],.12*h,.025*h,.075*h,canvas,thread,rigid='spine01')
    ribbon('Pack closure tab',np.array([[0,.969,-.175],[0,.93,-.177],[0,.905,-.176]])*h,.015*h,.002*h,leather,rigid='spine01')
    tube('Pack carrying loop',np.array([[-.027,1.042,-.09],[-.026,1.08,-.10],[0,1.086,-.105],[.026,1.08,-.10],[.027,1.042,-.09]])*h,.002*h,leather,rigid='spine01')

def build_outfit(settings):
    h=HEIGHT/1.35
    shirt=material('Woven linen shirt',settings['shirt'],.94);pants=material('Woven twill trousers','76674f',.92)
    seam=material('Garment edge stitching','c1b08d',.9)
    # Fit garments to actual child skin. The stock helper-tights shell does not
    # reliably track all child macro targets and previously exposed shoulders.
    shirts=[];trousers=[]
    neck_y=joint('joint-neck')[1]
    waist_y=joint('joint-pelvis')[1]+.012*h
    shoulder=joint('joint-l-shoulder')
    elbow=joint('joint-l-elbow')
    axis=elbow-shoulder
    for fi in GROUPS['body']:
        c=CURRENT[FACES[fi]].mean(axis=0);x,y,z=c
        rel=np.array([abs(x),y,z])-shoulder
        along=float(np.dot(rel,axis)/np.dot(axis,axis))
        sleeve=np.linalg.norm(rel-np.clip(along,0,1)*axis)<.066*h and -.3<along<.64
        trunk=waist_y-.04*h<y<neck_y-.004*h and abs(x)<shoulder[0]+.036*h
        if trunk or sleeve:
            shirts.append(fi)
        if .081*h<y<waist_y+.02*h and abs(x)<.24*h:
            trousers.append(fi)
    global SHIRT_BVH
    from mathutils.bvhtree import BVHTree
    collision=Garments.collider(CURRENT,[FACES[i] for i in GROUPS['body']])
    cloth_report={}
    underlayer=None
    for kind,name,faces,mat in [('trousers','Loose woven trousers',trousers,pants),('shirt','Loose woven shirt',shirts,shirt)]:
        if kind=='shirt':
            points,fs=Garments.shirt_pattern(HEIGHT,neck_y,shoulder,waist_y)
            source=[BODY_IDS[BODY_TREE.query(p)[1]] for p in points]
            obj=mesh(name,points,fs,mat,source_ids=source)
            obj['authored_pattern']=True
            # Recalculate coherent normals on the stitched two-panel garment.
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
        else:
            points,fs=Garments.trouser_pattern(HEIGHT,waist_y,joint('joint-l-upper-leg'),joint('joint-l-knee'),joint('joint-l-ankle'))
            source=[BODY_IDS[BODY_TREE.query(p)[1]] for p in points]
            obj=mesh(name,points,fs,mat,source_ids=source)
            obj['authored_pattern']=True
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
        pattern_points=points.copy()
        points,cloth_report[kind]=Garments.drape(obj,kind,HEIGHT,neck_y,waist_y,DESIGN['clothing'])
        if kind=='shirt':Garments.bind_shirt(obj,pattern_points,ARM,shoulder[0],shoulder[1],HEIGHT)
        if kind=='trousers':underlayer=Garments.collider(points,fs,'Temporary trouser cloth collider')
        if kind=='trousers':boundary_stitches(name,points,fs,seam,source)
        Garments.thickness(obj,h,ARM,DESIGN['clothing'])
        subdiv(obj,1)
        if kind=='shirt':
            SHIRT_BVH=BVHTree.FromPolygons([Vector(Garments.yup(v.co)) for v in obj.data.vertices], [list(p.vertices) for p in obj.data.polygons],all_triangles=False)
    bpy.data.objects.remove(collision,do_unlink=True)
    if underlayer:bpy.data.objects.remove(underlayer,do_unlink=True)
    (OUT/(NAME+'_cloth.json')).write_text(json.dumps(cloth_report,indent=2)+'\n')
    # Soft leather shoes retain the source heel, instep and asymmetric toe box.
    leather=material('Closed leather shoes','5e4936',.82)
    for side in [-1,1]:
        foot=joint('joint-l-ankle' if side>0 else 'joint-r-ankle')
        # Size each shoe from its actual foot, including the heel and toes.
        from scipy.ndimage import gaussian_filter1d
        cloud=CURRENT[BODY_IDS]
        cloud=cloud[(cloud[:,0]*side>0)&(cloud[:,1]<.115*h)]
        z0=cloud[:,2].min()-.010*h;z1=cloud[:,2].max()+.014*h
        z_values=np.linspace(z0,z1,19)
        centers=[];widths=[];tops=[]
        bottom=cloud[:,1].min()-.006*h;sole=.006*h
        for z in z_values:
            local=cloud[abs(cloud[:,2]-z)<(z1-z0)/17]
            if len(local)<3:local=cloud[np.argsort(abs(cloud[:,2]-z))[:12]]
            centers.append((local[:,0].min()+local[:,0].max())*.5)
            widths.append((local[:,0].max()-local[:,0].min())*.5+.008*h)
            tops.append(local[:,1].max()+.012*h)
        centers=gaussian_filter1d(centers,1);widths=gaussian_filter1d(widths,1);tops=gaussian_filter1d(tops,1)
        widths[0]=widths[-1]=.002*h
        tops[0]=tops[-1]=bottom+.015*h
        vs=[];fs=[];N=48
        for j,z in enumerate(z_values):
            for k in range(N):
                a=TAU*k/N
                x=centers[j]+widths[j]*math.cos(a)
                # A flat sole spans the full toe box; the old oval cross section
                # rose above the toes at its edges and exposed the skin below it.
                y=bottom if math.sin(a)<0 else bottom+sole+(tops[j]-bottom-sole)*math.sin(a)**.75
                vs.append([x,y,z])
        for j in range(len(z_values)-1):
            for k in range(N):fs.append([j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k])
        fs.extend([list(range(N-1,-1,-1)),list(range((len(z_values)-1)*N,len(z_values)*N))])
        mesh('Closed leather shoe '+str(side),vs,fs,leather,rigid='foot.L' if side>0 else 'foot.R')
        outline=[]
        for sign in [-1,1]:
            order=range(len(z_values)) if sign<0 else range(len(z_values)-1,-1,-1)
            for j in order:outline.append([centers[j]+widths[j]*sign,bottom+.004*h,z_values[j]])
        outline.append(outline[0])
        tube('Stitched shoe welt',outline,.0017*h,seam,rigid='foot.L' if side>0 else 'foot.R')
        for i in range(3):
            j=7+i;z=z_values[j];y=tops[j]+.0015*h;cx=centers[j]
            lace=[]
            for dx in np.linspace(-.021*h,.021*h,9):
                arch=max(0,1-(dx/widths[j])**2)**.375
                ly=bottom+sole+(tops[j]-bottom-sole)*arch+.001*h
                lace.append([cx+dx,ly,z])
            tube('Shoe laces',lace,.0009*h,seam,rigid='foot.L' if side>0 else 'foot.R')
    # A narrow tied cord follows the waist; there is no separate rigid hip disc.
    cord=[]
    for i in range(65):
        a=TAU*i/64;cord.append([.113*h*math.cos(a),.735*h+.002*h*math.cos(a*3),.023*h+.073*h*math.sin(a)])
    tube('Waist drawcord',cord,.0017*h,material('Waist cord','9e8766',.9),rigid='spine04')
    # Backpacks removed at the user's request.

def join_by_material():
    # Batch the many fibre and stitch surfaces into a handful of skinned meshes.
    buckets={}
    for obj in list(bpy.context.scene.objects):
        if obj.type=='MESH' and len(obj.data.materials)==1 and not obj.data.shape_keys:
            parent='rigged' if obj.parent==ARM else 'static'
            buckets.setdefault((obj.data.materials[0].name,parent),[]).append(obj)
    for (name,parent),objects in buckets.items():
        if len(objects)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=name
    bpy.ops.object.select_all(action='DESELECT')

def write_asset_credit(path, name, settings):
    raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);tail=raw[20+size:]
    credit='Human anatomy and eyes: MakeHuman team, CC0 1.0. '
    if name in ['corinne','wren']:
        credit+='Hair punkduck_alpha7_curly2: punkduck, CC-BY per official MakeHuman hair03 catalog, https://www.makehumancommunity.org/node/477. Fitted, recolored and reweighted. Original source headers retained in fetched data.'
    elif name=='camille' and settings['hair_asset']=='elvs_hazel_hair':credit+='Hair elvs_hazel_hair: Elvaerwyn, CC-BY, official MakeHuman hair02 catalog. Fitted and recolored.'
    else:credit+='Hair '+settings['hair_asset']+': MakeHuman team, CC0 1.0, fitted and recolored.'
    doc.setdefault('asset',{})['copyright']=credit
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(encoded)+len(tail))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+tail)

def build_child(name,settings):
    global CURRENT,CURRENT_W,ARM,BODY_TREE,MATERIALS,RAW,HEIGHT,SCALE,BOTTOM,NAME,ORIGINAL_RAW,ACCEPTED_BOTTOM,ACCEPTED_SCALE,BODY_REPORT
    from build_skin_tints import generate
    generate()
    NAME=name;HEIGHT=settings['height_m'];MATERIALS={}
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    targets={}
    for sex in ['male','female']:
        raw=BASE.copy()
        for line in (SRC/f'caucasian-{sex}-child.target').read_text().splitlines():
            if line and not line.startswith('#'):
                t=line.split();raw[int(t[0])]+=np.array(list(map(float,t[1:])))
        targets[sex]=raw
    ORIGINAL_RAW=targets[settings['sex_target']].copy()
    accepted,ACCEPTED_BOTTOM,ACCEPTED_SCALE=Anatomy.normalize(ORIGINAL_RAW,BODY_IDS,HEIGHT)
    raw=Anatomy.age_body(BASE,SRC,settings['age'],weight=1-2*DESIGN['developmental_shape']['weight_slider'],muscle=2*DESIGN['developmental_shape']['muscle_slider'])
    current,BOTTOM,SCALE=Anatomy.normalize(raw,BODY_IDS,HEIGHT)
    style=DESIGN['developmental_shape']['art_direction']
    current,silhouette_report=Anatomy.child_silhouette(current,SRC,SCALE,RIG,WEIGHTS,style)
    profiles=json.loads((ROOT/'game/data/child_proportions.json').read_text())
    profile=profiles['profiles'][settings['proportion_profile']]
    length_scales={'biacromial_breadth_m':style['shoulder_breadth_scale'],'upper_arm_external_length_m':style['upper_arm_length_scale'],'forearm_external_length_m':style['forearm_length_scale']}
    length_targets={k:v*HEIGHT/profile['reference_height_m']*length_scales[k] for k,v in profile['length_targets'].items()}
    current,length_report=Anatomy.fit_lengths(current,SRC,SCALE,length_targets)
    # Keep the accepted face/head geometry fixed. The neck is the only blend
    # between the age-correct body and the unchanged accepted head assembly.
    neck=Anatomy.group_center(accepted,FACES,GROUPS,'joint-neck')[1]
    t=np.clip((accepted[:,1]-(neck-.012*HEIGHT/1.35))/(.050*HEIGHT/1.35),0,1)
    t=t*t*(3-2*t)
    current=current*(1-t[:,None])+accepted*t[:,None]
    profiles=json.loads((ROOT/'game/data/child_proportions.json').read_text())
    profile=profiles['profiles'][settings['proportion_profile']]
    target={k:v*HEIGHT/profile['reference_height_m'] for k,v in profile['target'].items()}
    tris=Anatomy.triangles(FACES,GROUPS['body'])
    current,plain_report=Anatomy.plain_torso(current,FACES,GROUPS,WEIGHTS)
    CURRENT,BODY_REPORT=Anatomy.fit_girths(current,tris,FACES,GROUPS,WEIGHTS,target)
    CURRENT,nose_report=Anatomy.nose_shape(CURRENT,settings.get('nose_shape'),HEIGHT)
    if nose_report:BODY_REPORT['nose_shape']=nose_report
    BODY_REPORT['plain_torso']=plain_report
    BODY_REPORT['art_direction']=silhouette_report
    BODY_REPORT.update({'age_years':settings['age'],'age_weights':Anatomy.age_weights(settings['age']),
                        'length_fit':length_report,'source_muscle_slider':DESIGN['developmental_shape']['muscle_slider'],'source_weight_slider':DESIGN['developmental_shape']['weight_slider'],
                        'height_m':HEIGHT,'profile':settings['proportion_profile'],'source':profiles['source']})
    BODY_REPORT['surface_landmarks']={key:CURRENT[i].tolist() for key,i in {'acromion':8274,'olecranon':10037,'elbow':10040,'wrist':10548}.items()}
    sh=joint('joint-l-shoulder');el=joint('joint-l-elbow');wr=joint('joint-l-hand')
    kn=joint('joint-l-knee');an=joint('joint-l-ankle');hp=joint('joint-l-upper-leg')
    unit=CURRENT[:,1].max()/1.35
    waist=min(np.linspace(hp[1]+.12*unit,sh[1]-.16*unit,5),key=lambda y:Anatomy.section(CURRENT,tris,[0,y,.025*unit],[0,1,0],.20*unit)['circumference'])
    BODY_REPORT['section_planes']={}
    for key,center,normal,limit,measure in [
        ('upper_arm_girth_m',(sh+el)*.5,el-sh,.13*unit,'circumference'),
        ('forearm_girth_m',el+(wr-el)*.35,wr-el,.10*unit,'circumference'),
        ('calf_girth_m',kn+(an-kn)*.35,an-kn,.10*unit,'circumference'),
        ('chest_width_m',np.array([0,sh[1]-.10*unit,.025*unit]),np.array([0,1,0]),.20*unit,'width'),
        ('chest_depth_m',np.array([0,sh[1]-.10*unit,.025*unit]),np.array([0,1,0]),.20*unit,'depth'),
        ('waist_girth_m',np.array([0,waist,.025*unit]),np.array([0,1,0]),.20*unit,'circumference'),
        ('hip_girth_m',np.array([0,hp[1]+.02*unit,.025*unit]),np.array([0,1,0]),.22*unit,'circumference')]:
        BODY_REPORT['section_planes'][key]={'center':center.tolist(),'normal':normal.tolist(),'limit':limit,'measure':measure}
    (OUT/(name+'_proportions.json')).write_text(json.dumps(BODY_REPORT,indent=2)+'\n')
    RAW=CURRENT/SCALE;RAW[:,1]+=BOTTOM
    CURRENT_W=[[] for _ in CURRENT]
    for bone,weights in WEIGHTS.items():
        for i,w in weights:CURRENT_W[i].append((bone,w))
    for i,weights in enumerate(CURRENT_W):
        weights=sorted(weights,key=lambda x:-x[1])[:4];total=sum(w for _,w in weights)
        CURRENT_W[i]=[(b,w/total) for b,w in weights] if total else []
    BODY_TREE=cKDTree(CURRENT[BODY_IDS]);build_armature()
    # Skin enclosed by footwear is omitted, as in a clothed game character.
    # Keep the ankle transition above the shoe, not a second visible foot inside.
    visible_skin=[fi for fi in GROUPS['body'] if CURRENT[FACES[fi],1].mean()>.080*HEIGHT/1.35]
    skin,ids,*_=source_subset('Continuous anatomical skin',visible_skin,material('Skin',settings['skin'],.62))
    subdiv(skin,1)
    build_eyes();build_blink(skin,ids);build_outfit(settings);build_hair(settings)
    Garments.omit_covered_skin(skin,HEIGHT,joint('joint-neck')[1],joint('joint-pelvis')[1]+.012*HEIGHT/1.35,
                             joint('joint-l-shoulder'),joint('joint-l-elbow'),DESIGN['clothing']['covered_skin'])
    join_by_material()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,
        export_animations=False,export_morph=True,export_skins=True,export_all_influences=False,
        export_yup=True,export_attributes=True)
    write_asset_credit(OUT/(name+'.glb'),name,settings)
    metrics={'height_m':HEIGHT,'bones':len(ARM.data.bones),'vertices':sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type=='MESH'),
             'source_commit':DESIGN['source']['commit'],'age':settings['age']}
    (OUT/(name+'_metrics.json')).write_text(json.dumps(metrics,indent=2)+'\n')
    print('BUILT',name,metrics,flush=True)

def build_pouch():
    global ARM,MATERIALS
    ARM=None;MATERIALS={}
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    d=DESIGN['pouch'];center=np.array(d['center']);N=96;M=36;vs=[];fs=[]
    leather=material('Leather soft pouch','735037',.86);lining=material('Leather lining','473426',.98)
    thread=material('Pouch saddle stitches','b69c6d',.95);cordmat=material('Pouch drawstring','8b704b',.9)
    # Horizontal sections collapse and pucker toward the gathered throat.
    for j in range(M+1):
        t=j/M
        profile=np.interp(t,[0,.08,.25,.55,.75,.88,1],[.12,.65,1,1,.86,.48,.60])
        gather=max(0,(t-.68)/.32)
        for i in range(N):
            a=TAU*i/N
            fold=(.009*math.sin(a*13+t*1.4)+.003*math.sin(a*23-t*2))*gather**1.4
            rr=profile+fold/.12
            x=math.cos(a)*d['depth']*.5*rr
            z=math.sin(a)*d['width']*.5*rr
            y=(t-.5)*d['height']+.006*math.sin(5*a+.4)*t**6-.008*math.sin(a*2)**2*(1-t)**3
            x+=.015*(1-t)**2
            vs.append(center+np.array([x,y,z]))
    for j in range(M):
        for i in range(N):fs.append([j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i])
    fs.append(list(range(N-1,-1,-1)))
    ob=mesh('Gathered leather pouch',vs,fs,leather)
    mod=ob.modifiers.new('Leather wall thickness','SOLIDIFY');mod.thickness=.002;mod.offset=-1
    ob.data.materials.append(lining);mod.material_offset=1
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
    rim=[vs[M*N+i] for i in range(N)]+[vs[M*N]]
    tube('Soft rolled leather mouth',rim,.0025,leather,sides=6)
    # Seams run down the two joined side panels with discrete saddle stitches.
    for index in [N//4,3*N//4]:
        for j in range(3,M-2,2):
            p=vs[j*N+index];q=vs[(j+1)*N+index]
            outward=(p-center)*np.array([1,0,1]);outward/=max(np.linalg.norm(outward),1e-9)
            tube('Individual saddle stitch',[p+outward*.0018,q+outward*.0018],.0007,thread,sides=4)
    string=[]
    for i in range(97):
        a=TAU*i/96;string.append(center+np.array([math.cos(a)*.052,.138,math.sin(a)*.078]))
    tube('Gathered drawstring channel',string,.002,cordmat,sides=6)
    for side in [-1,1]:
        points=[center+np.array([.055,.138,side*.018]),center+np.array([.076,.129,side*.022]),center+np.array([.081,.087,side*.032]),center+np.array([.079,.031,side*.049])]
        tube('Hanging leather tie',points,.0021,cordmat,sides=6)
    # Subdivided curved ribbon, with narrow rolled edges instead of squared bars.
    # Fit the closed strap to a convex cross-section of the exported neck.
    # Both underside closure and upper contact are derived from the same skin.
    raw=(ROOT/'game/assets/clay.glb').read_bytes()
    size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);binary=raw[28+size:]
    body_mesh=doc['meshes'][0]
    attrs=body_mesh['primitives'][0]['attributes']
    def read_attribute(key,width):
        a=doc['accessors'][attrs[key]];v=doc['bufferViews'][a['bufferView']]
        return np.ndarray((a['count'],width),dtype='<f4',buffer=binary,
            offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*4),4)).copy()
    points=read_attribute('POSITION',3)
    part=read_attribute('_PART',1)[:,0] if '_PART' in attrs else np.full(len(points),20.0)
    z=d['strap_z']
    selected=points[(abs(points[:,2]-z)<.018)&(part>=19.5)&(part<21)&(points[:,1]>.60)&(abs(points[:,0])<.4)]
    hull=ConvexHull(selected[:,:2]);cross=selected[hull.vertices,:2]
    center2=np.array([0.,(cross[:,1].min()+cross[:,1].max())*.5])
    path=[]
    for angle in np.linspace(0,TAU,161):
        direction=np.array([math.cos(angle),math.sin(angle)])
        radius=min(-(np.dot(e[:2],center2)+e[2])/np.dot(e[:2],direction)
                   for e in hull.equations if np.dot(e[:2],direction)>1e-7)
        p=center2+direction*(radius+d['strap_clearance_m'])
        path.append([p[0],p[1],z])
    path=np.array(path)
    ribbon('Closed fitted neck strap',path,d['strap_width_m'],.003,leather)
    for side in [-1,1]:
        seam=path.copy();seam[:,2]+=side*.014
        tube('Neck strap stitching',seam,.0006,thread,sides=4)
    # A visible buckle lies under the throat; its pin closes through the tongue.
    metal=material('Aged brass buckle','b39a62',.42,.65)
    throat=float(path[:,1].min())-.004
    buckle=np.array([[-.026,throat,z-.024],[.026,throat,z-.024],
                     [.026,throat,z+.024],[-.026,throat,z+.024],[-.026,throat,z-.024]])
    tube('Under-throat buckle frame',buckle,.0035,metal,sides=8)
    tube('Buckle tongue',[[0,throat-.003,z-.023],[0,throat-.003,z+.023]],.002,metal,sides=6)
    ribbon('Leather buckle closure',[[0,throat,z-.045],[0,throat-.006,z],[0,throat-.008,z+.068]],.024,.0025,leather)
    for zz in [z+.025,z+.042,z+.059]:
        tube('Strap punched hole',[[0,throat-.010,zz-.001],[0,throat-.010,zz+.001]],.0012,lining,sides=6)
    # Two short loops transfer the load from the neck band into the bag's rim.
    for zz in [center[2]-.07,center[2]+.07]:
        ribbon('Bag suspension tab',[[.30,1.22,zz],[.36,1.19,zz],[.39,1.145,zz]],.025,.003,leather)
    join_by_material();bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'umber_pouch.glb'),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
    print('BUILT supple leather pouch',flush=True)

OUT.mkdir(parents=True,exist_ok=True)
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for name,settings in DESIGN['characters'].items():
    if not selected or name in selected:build_child(name,settings)
if not selected or 'umber_pouch' in selected:build_pouch()
