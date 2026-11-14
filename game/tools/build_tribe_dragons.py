"""Independent NightWing and SilkWing sculpts; no Clay mesh is imported.

Uses the project's continuous skin field toolkit for connected anatomical masses.
Blender --background --python-exit-code 1 --python game/tools/build_tribe_dragons.py
"""
from pathlib import Path
import sys, json, math
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
sys.path.insert(0,str(ROOT/'prototypes/clay/body'))
import bpy
import numpy as np
from mathutils import Vector
from scipy.interpolate import PchipInterpolator, CubicSpline
import skin as SK
sys.path.insert(0,str(Path(__file__).resolve().parent))
import moon_full_pass as MOON

DATA=json.loads((ROOT/'game/data/dragon_anatomy.json').read_text())
PROFILES=json.loads((ROOT/'game/data/protagonists.json').read_text())
OUT=ROOT/'game/assets/dragons'
ARM=None
BONES={}
MATS={}
ID=''
D={}
PROFILE={}
TAU=math.tau
def B(v):return (float(v[0]),float(-v[2]),float(v[1]))
def linear(code):
    c=np.array([int(code[i:i+2],16)/255 for i in (0,2,4)])
    return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
def material(name,color,rough=.55,metal=0):
    if name in MATS:return MATS[name]
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    mat.diffuse_color=tuple(linear(color))+(1,)
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=mat.diffuse_color
    shader.inputs['Roughness'].default_value=rough
    shader.inputs['Metallic'].default_value=metal
    MATS[name]=mat
    return mat
def mesh(name,points,faces,mat,weights,colors=None,fold=None,blink=None):
    points=np.asarray(points,float)
    data=bpy.data.meshes.new(name);data.from_pydata([B(p) for p in points],[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);data.materials.append(mat)
    for f in data.polygons:f.use_smooth=True
    if colors is not None:
        attr=data.color_attributes.new(name='AnatomicalPalette',type='FLOAT_COLOR',domain='POINT')
        for i,c in enumerate(colors):attr.data[i].color=tuple(c)+(1,)
        shader=mat.node_tree.nodes.get('Principled BSDF')
        vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name=attr.name
        mat.node_tree.links.new(vc.outputs['Color'],shader.inputs['Base Color'])
    buckets={}
    if isinstance(weights,str):weights=[[(weights,1.)] for _ in points]
    for i,items in enumerate(weights):
        for bone,weight in items:
            if weight>.0001:buckets.setdefault(bone,[]).append((i,weight))
    for bone,items in buckets.items():
        group=ob.vertex_groups.new(name=bone)
        for i,w in items:group.add([i],float(w),'REPLACE')
    mod=ob.modifiers.new('Anatomical skeleton','ARMATURE');mod.object=ARM;ob.parent=ARM
    if fold or blink is not None:
        ob.shape_key_add(name='Basis')
    if fold:
        for k in range(1,4):
            key=ob.shape_key_add(name='fold'+str(k))
            for dst,p in zip(key.data,fold(points,k/3)):dst.co=B(p)
    if blink is not None:
        key=ob.shape_key_add(name='blink')
        for dst,p in zip(key.data,blink):dst.co=B(p)
    return ob
def tube(name,path,radii,mat,bone,sides=10,fold=None,flatten=1):
    path=np.array(path,float);points=[];faces=[]
    for i,p in enumerate(path):
        tangent=SK.norm(path[min(i+1,len(path)-1)]-path[max(0,i-1)])
        hint=np.array([0,1.,0]) if abs(tangent[1])<.9 else np.array([0,0,1.])
        a=SK.norm(np.cross(tangent,hint));b=np.cross(tangent,a)
        radius=radii[i] if hasattr(radii,'__len__') else radii
        for j in range(sides):
            theta=TAU*j/sides
            points.append(p+radius*(a*math.cos(theta)+b*math.sin(theta)*flatten))
            if i:
                faces.append([(i-1)*sides+j,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j])
    faces.extend([list(range(sides-1,-1,-1)),list(range((len(path)-1)*sides,len(path)*sides))])
    return mesh(name,points,faces,mat,bone,fold=fold)
def add_bone(name,head,tail,parent=None):
    BONES[name]=(np.array(head,float),np.array(tail,float),parent)
def armature():
    global ARM
    data=bpy.data.armatures.new(ID+' anatomical rig');ARM=bpy.data.objects.new(ID+'Rig',data)
    bpy.context.collection.objects.link(ARM);bpy.context.view_layer.objects.active=ARM;ARM.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name,(h,t,_) in BONES.items():
        bone=data.edit_bones.new(name);bone.head=B(h);bone.tail=B(t)
        if (bone.tail-bone.head).length<.001:bone.tail=bone.head+Vector((0,0,.01))
    for name,(_,_,parent) in BONES.items():
        if parent:data.edit_bones[name].parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');ARM.select_set(False)
def spline(points,count):
    points=np.array(points,float);steps=np.r_[0,np.cumsum(np.linalg.norm(np.diff(points,axis=0),axis=1))]
    return CubicSpline(steps,points)(np.linspace(0,steps[-1],count))
def head_sections(rows):
    sections=[]
    for z,cy,rx,ry in rows:
        polygon=[]
        for j in range(48):
            a=TAU*j/48
            # A low nasal wedge, with rounded lateral jaw edges; no gabled cap.
            polygon.append([rx*math.sin(a),cy+ry*math.cos(a)])
        sections.append((z,polygon))
    return sections
def loft(name,rows,mat,bone):
    rows=np.array(rows,float);curve=PchipInterpolator(rows[:,0],rows[:,1:],axis=0)
    points=[];faces=[];samples=80;around=48
    for i,z in enumerate(np.linspace(rows[0,0],rows[-1,0],samples)):
        cy,rx,ry=curve(z)
        for j in range(around):
            a=TAU*j/around;points.append([rx*math.sin(a),cy+ry*math.cos(a),z])
            if i:faces.append([(i-1)*around+j,(i-1)*around+(j+1)%around,i*around+(j+1)%around,i*around+j])
    faces.extend([list(range(around-1,-1,-1)),list(range((samples-1)*around,samples*around))])
    return mesh(name,points,faces,mat,bone)

def build_body():
    rows=np.array(D['spine']);raw=rows[:,[0,1]]
    s=np.r_[0,np.cumsum(np.linalg.norm(np.diff(raw,axis=0),axis=1))]
    axis=np.linspace(0,s[-1],round(s[-1]/.018))
    centers=PchipInterpolator(s,raw,axis=0)(axis)
    radii=PchipInterpolator(s,rows[:,2:],axis=0)(axis)
    P=np.column_stack([np.zeros(len(axis)),centers[:,1],centers[:,0]])
    tangent=np.gradient(P,axis=0);tangent/=np.linalg.norm(tangent,axis=1)[:,None]
    lateral=np.tile([1.,0,0],(len(P),1));normal=np.cross(lateral,tangent)
    section=(lambda i,t:MOON.trunk_section(radii,i,t)) if ID in ['moon','blue','darkstalker'] else (lambda i,t:(radii[i,1]*math.cos(t),radii[i,0]*math.sin(t)))
    trunk=SK.Trunk(axis,P,normal,lateral,section,nphi=96 if ID in ['moon','blue','darkstalker'] else 72)
    # Ordered rig segments along the curved spine. Each is blended at the join.
    locations=[0,.12,.25,.40,.57,.77,1.05,1.52,1.94,2.35,2.8,3.25,3.75,4.25,4.75,5.25,5.8]
    if ID in ['moon','blue','darkstalker']:locations=[0,s[1],s[2],s[3],s[4],s[6],s[7],s[9]]+list(np.linspace(s[10],s[-1],8))
    locations=np.unique(np.clip(locations,0,s[-1]))
    names=['head','neck4','neck3','neck2','neck1','chest','spine','hips']+['tail'+str(i) for i in range(1,len(locations)-7)]
    segments=[]
    for i in range(len(locations)-1):
        a,b=locations[i:i+2];name=names[i]
        h=np.array([0,np.interp(a,axis,P[:,1]),np.interp(a,axis,P[:,2])])
        t=np.array([0,np.interp(b,axis,P[:,1]),np.interp(b,axis,P[:,2])])
        parent=names[i+1] if i<7 else ('hips' if i==7 else names[i-1])
        if name=='hips':parent=None
        add_bone(name,h,t,parent);segments.append((name,a,b))
    # The head faces forward rather than along the spine.
    BONES['head']=(P[0],np.array([0,D['skull'][2][1],1.70]),'neck4')
    add_bone('jaw',[0,D['jaw'][0][1],D['jaw'][0][0]],[0,D['jaw'][-2][1],D['jaw'][-2][0]],'head')
    add_bone('fire_origin',[0,D['jaw'][-2][1]+.055,D['jaw'][-2][0]+.01],
             [0,D['jaw'][-2][1]+.055,D['jaw'][-2][0]+.07],'head')
    parts=[]
    radii_leg=D['limb_radii']
    for side in [-1,1]:
        suffix='L' if side>0 else 'R'
        for kind,labels,parent in [('front',['upperarm','forearm','hand'],'chest'),('hind',['thigh','shin','foot'],'hips')]:
            joints=np.array(D[kind])*np.array([side,1,1])
            for i,name in enumerate(labels):
                full=name+'.'+suffix
                add_bone(full,joints[i],joints[i+1],parent if i==0 else labels[i-1]+'.'+suffix)
                spec={'name':full,'from':joints[i].tolist(),'to':joints[i+1].tolist(),
                      'r':[radii_leg[i],radii_leg[i+1]],'rig':{full:1},'k':.06 if i==0 else .035,'zone':.5}
                parts.append(SK.Piece(spec,1,'bone'))
                # Shoulder and haunch muscular bellies blend into the same skin.
                if i==0 and ID not in ['moon','blue','darkstalker']:
                    spec={'name':kind+' muscle '+suffix,'from':joints[0].tolist(),
                          'to':(joints[0]*.3+joints[1]*.7).tolist(),'radii':[radii_leg[0]*1.45,radii_leg[0]*1.1],
                          'rig':{full:.7,parent:.3},'k':.10,'hint':[side,0,0],'zone':.5}
                    parts.append(SK.Piece(spec,1,'muscle'))
            end=joints[-1]
            if ID in ['moon','blue','darkstalker']:
                MOON.toe_parts(parts,kind,end,side,labels[-1]+'.'+suffix)
                continue
            for toe in range(4):
                spread=(toe-1.5)*(.034 if ID!='umber' else .045)
                base=end+np.array([spread,0,0])
                tip=base+np.array([spread*.25,-.047,.12+(1-abs(toe-1.5)/2)*.045])
                parts.append(SK.Piece({'name':'toe','from':base.tolist(),'to':tip.tolist(),'r':[.026,.012],
                    'rig':{labels[-1]+'.'+suffix:1},'k':.025,'zone':.5},1,'bone'))
    # The skull's load-bearing wedge merges into the cervical skin.
    if ID in ['moon','blue','darkstalker']:MOON.prototype_parts(parts)
    else:parts.append(SK.SectionPiece('Cranium',head_sections(D['skull']),{'head':1},.5,.055,0,D['skull'][-1][0],margin=.15))
    eye=np.array(D['eye'])
    def clip(X,dist,allD,pieces):
        result=dist
        for side in [-1,1]:
            center=eye*np.array([side,1,1])
            delta=(X-center)/np.array([.035,.053,.071])
            socket=(np.linalg.norm(delta,axis=1)-1)*.035
            result=np.maximum(result,-socket)
        return result
    SK.CLIP=clip if ID not in ['moon','blue','darkstalker'] else None;SK.CAVITY=None
    V,F=SK.mesh(trunk,parts,.014,pad=.045);SK.CLIP=None
    def weights(sc):
        i=max(0,min(len(segments)-1,np.searchsorted([b for _,_,b in segments],sc)))
        name,a,b=segments[i]
        if i+1<len(segments) and sc>b-.065:
            t=np.clip((sc-(b-.065))/.13,0,1);return [(name,1-t),(segments[i+1][0],t)]
        if i>0 and sc<a+.065:
            t=np.clip((sc-(a-.065))/.13,0,1);return [(segments[i-1][0],1-t),(name,t)]
        return [(name,1.)]
    N=SK.normals(V,F)
    W,Z,A,around,T=SK.vertex_data(V,trunk,parts,weights,
        lambda s,f,z,y,x:f,lambda *args:0,100,blend=.030,N=N)
    # Limit the palette to anatomy: dark dorsal surface, colored flanks and belly.
    dorsal=linear(PROFILE['dorsal']);scales=linear(PROFILE['scales']);belly=linear(PROFILE['belly'])
    f=np.array(Z);colors=np.empty((len(V),3))
    if ID in ['moon','blue','darkstalker']:
        for i,weights in enumerate(W):
            limb=sum(w for n,w in weights if n.split('.')[0] in ['upperarm','forearm','hand','thigh','shin','foot'] or n.startswith(('ftoe','htoe','fmeta','hmeta','fthumb','hdew')))
            amount=np.clip((limb-.35)/.45,0,1);f[i]=around[i]*(1-amount)+Z[i]*amount
    for i in range(len(V)):
        colors[i]=scales*(1-min(1,max(0,(f[i]-.48)/.38)))+belly*min(1,max(0,(f[i]-.48)/.38))
        top=np.clip((.35-f[i])/.28,0,1)
        colors[i]=colors[i]*(1-top)+dorsal*top
        colors[i]*=.96+.05*math.sin(V[i,0]*71+V[i,2]*23)
    return V,F,W,colors,segments,axis,P

def make_head_details():
    skin=material('Face scales',PROFILE['scales'])
    jawmat=material('Lower jaw',PROFILE['belly'])
    loft('Independent mandible',D['jaw'],jawmat,'jaw')
    # A recessed oral line is a shallow dark internal surface, not a painted smile.
    lining=material('Oral cavity','33242d',.7)
    rows=np.array(D['jaw'],float);rows[:,1]+=.027;rows[:,2]*=.95;rows[:,3]=.006
    loft('Recessed mouth',rows,lining,'jaw')
    hornmat=material('Horn keratin',PROFILE['dorsal'],.42)
    for side in [-1,1]:
        h=np.array(D['horn'])*np.array([side,1,1])
        if ID in ['moon','blue','darkstalker']:
            h[1:]=h[0]+(h[1:]-h[0])*.78
        if ID=='darkstalker':
            h[1:,0]+=side*np.sin(np.linspace(0,2.7,len(h)-1))*.035
        p=spline(h,44);tube('Swept horn',p,np.linspace(.047,.001,len(p)),hornmat,'head',sides=16)
        # A thin swept ear follows the cranium, not a large MudWing frill.
        e=np.array([.125,1.93,1.34]) if ID!='umber' else np.array([.19,1.69,1.33])
        e*=np.array([side,1,1])
        ear_path=spline([e,e+[side*.045,.010,-.035],e+[side*.085,.020,-.095],e+[side*.11,.028,-.17]],24)
        ear_width=np.interp(np.linspace(0,1,24),[0,.3,.6,1],[.015,.034,.030,.001])
        tube('Sculpted swept ear',ear_path,ear_width,skin,'head',sides=14,flatten=.19)
        eye=np.array(D['eye'])*np.array([side,1,1])
        normal=SK.norm([side*.92,.05,.38]);up=np.array([0,1.,0]);across=SK.norm(np.cross(up,normal))
        eye-=normal*.007
        def plane(x,y,depth=0):return eye+across*x*.76+up*y*.76+normal*depth
        dark=material('Eye outline','17151c',.5)
        iris=material('Iris',PROFILE['iris'],.25)
        pupil=material('Pupil','08090b',.2)
        # Almond opening with a restrained scleral rim; no oversized white sphere.
        def disk(title,rx,ry,mat,depth):
            pts=[plane(0,0,depth)]
            pts += [plane(rx*math.cos(a),ry*math.sin(a),depth-.004*math.sin(a)**2) for a in np.linspace(0,TAU,48,endpoint=False)]
            return mesh(title,pts,[[0,i+1,(i+1)%48+1] for i in range(48)],mat,'head')
        disk('Almond eye socket',.074,.041,dark,.008)
        disk('Iris jewel',.043,.034,iris,.013)
        disk('Vertical pupil',.013,.030,pupil,.015)
        disk('Eye glint',.004,.005,material('Eye highlight','e4eef0',.12),.017).location=Vector(B(across*.011+up*.009))
        # The upper lid closes across the eye and returns to its own rim.
        pts=[];closed=[];faces=[]
        for row in range(2):
            for i,x in enumerate(np.linspace(-.074,.074,41)):
                top=.041*math.sqrt(max(0,1-(x/.074)**2))
                pts.append(plane(x,top+(0.007 if row==0 else -.002),.019))
                closed.append(plane(x,top+.007 if row==0 else -top,.019))
                if row and i:faces.append([i-1,i,41+i,41+i-1])
        mesh('Upper eyelid',pts,faces,skin,'head',blink=closed)
        # Integrated paired nostrils sit on the upper outer nose, without a cat nose pad.
        muzzle=D['skull'][-2];c=np.array([side*muzzle[2]*.82,muzzle[1]+muzzle[3]*.38,muzzle[0]-.045])
        points=[c]
        for a in np.linspace(0,TAU,24,endpoint=False):
            points.append(c+np.array([side*.005*math.cos(a),.013*math.sin(a),.028*math.cos(a)]))
        mesh('Nostril recess',points,[[0,j+1,(j+1)%24+1] for j in range(24)],dark,'head')
        if ID in ['moon','blue','darkstalker']:
            silver=material('Silver mindreader scale','c4d6df',.3,.65)
            c=eye-across*.070-up*.008+normal*.011
            points=[c+normal*.006]+[c+across*x+up*y for x,y in [(0,.023),(.009,.005),(.010,-.012),(0,-.020),(-.009,-.012),(-.007,.004)]]
            mesh('SilverTearScale'+('L' if side>0 else 'R'),points,[[0,j+1,(j+1)%6+1] for j in range(6)],silver,'head')
        if ID=='blue':
            path=spline(np.array([[side*.06,2.035,1.48],[side*.095,2.22,1.35],[side*.13,2.31,1.02],[side*.13,2.29,.79]]),42)
            tube('SilkWing antenna',path,np.linspace(.011,.001,len(path)),hornmat,'head',sides=8)
    # Short dorsal blades, with roots embedded in the cervical and back skin.
    spine=np.array(D['spine'])
    for i in range(2,len(spine)-2):
        z,y,rx,ry=spine[i]
        root=np.array([0,y+ry*.90,z])
        height=.14 if i<5 else .095
        points=[root+[-.012,0,.045],root+[.012,0,.045],root+[0,height,-.095],root+[0,-.018,-.08]]
        mesh('Dorsal blade',points,[[0,1,2],[1,3,2],[3,0,2],[0,3,1]],hornmat,
             'neck2' if i<3 else ('neck1' if i<4 else 'chest' if i<6 else 'hips'))
    if ID=='umber':
        # Short, healed crosswise scar on the actual nose bridge.
        scar=material('Healed nose scar','b88d74',.78)
        p=[]
        for x in np.linspace(-.14,.14,30):
            p.append([x,1.605-.034*(x/.14)**2,1.86+.025*x])
        tube('Nose bridge scar',p,.0022,scar,'head',sides=6)

def make_feet():
    claw=material('Claw keratin','25212a',.4)
    for side in [-1,1]:
        suffix='L' if side>0 else 'R'
        for kind,bone in [('front','hand.'+suffix),('hind','foot.'+suffix)]:
            end=np.array(D[kind][-1])*np.array([side,1,1])
            for toe in range(4):
                spread=(toe-1.5)*(.034 if ID!='umber' else .045)
                base=end+np.array([spread*1.25,-.045,.13+(1-abs(toe-1.5)/2)*.045])
                path=[base,base+[0,-.01,.025],base+[0,-.045,.038]]
                tube('Hooked claw',path,[.015,.010,.001],claw,bone,sides=10)

def make_neck_scutes(V,F,W):
    # Low overlapping scutes follow the real cervical skin and share its weights.
    # They never form Clay's broad forehead shield or bulky shoulder armor.
    from scipy.spatial import cKDTree
    tree=cKDTree(V);normals=SK.normals(V,F)
    rows=np.array(D['spine']);raw=rows[:,[0,1]]
    steps=np.r_[0,np.cumsum(np.linalg.norm(np.diff(raw,axis=0),axis=1))]
    curve=PchipInterpolator(steps,rows[:,[0,1,2,3]],axis=0)
    plate_mat=material('Cervical scutes',PROFILE['dorsal'],.54)
    for row,s in enumerate(np.arange(.25,.96,.115)):
        for theta0 in [-1.50,-.76,0,.76,1.50]:
            points=[];weights=[];faces=[]
            for i in range(5):
                u=i/4
                ss=s+(u-.5)*.12
                z,y,rx,ry=curve(ss)
                tangent=curve.derivative()(ss)[:2]
                forward=SK.norm([0,tangent[1],tangent[0]])
                normal=SK.norm(np.cross([1,0,0],forward))
                for j in range(7):
                    v=j/6
                    theta=theta0+(v-.5)*.66+(row%2)*.09
                    target=np.array([0,y,z])+normal*ry*math.cos(theta)+np.array([rx*math.sin(theta),0,0])
                    _,k=tree.query(target)
                    points.append(V[k]+normals[k]*(.003+.003*math.sin(u*math.pi)*math.sin(v*math.pi)))
                    weights.append(W[k])
                    if i and j:
                        a=(i-1)*7+j-1;b=i*7+j-1;faces.append([a,a+1,b+1,b])
            mesh('Fitted neck scute',points,faces,plate_mat,weights)

def fold_transform(root,side,kind):
    root=np.array(root)
    def transform(points,amount):
        p=np.array(points);d=p-root
        # Shoulder sweeps aft before the distal fan narrows; the lobes stow
        # along the sides/back. This is not the butterfly-style upright close.
        a=amount*side*1.24
        x=d[:,0]*math.cos(a)+d[:,2]*math.sin(a)
        z=-d[:,0]*math.sin(a)+d[:,2]*math.cos(a)
        close=np.clip((amount-.25)/.75,0,1)
        x=x*(1-close*.82)
        y=d[:,1]*(1-close*.72)-close*.035*np.abs(d[:,0])
        z*=1-close*.32
        if kind=='hind':z-=close*.17*np.abs(d[:,0])
        return root+np.column_stack([x,y,z])
    return transform

def make_wings():
    wingmat=material('Wing membranes',PROFILE['wing'],.57)
    veinam=material('Wing fingers',PROFILE['dorsal'],.48)
    for side in [-1,1]:
        suffix='L' if side>0 else 'R'
        for kind in (['fore','hind'] if ID=='blue' else ['fore']):
            root=np.array([side*.22,1.27,.43 if kind=='fore' else .14])
            name='wing_'+kind+'.'+suffix
            fold=fold_transform(root,side,kind)
            if ID=='blue':
                # Skeletal leading arm, long narrow lobes and smaller hindwing:
                # the structure follows the cover rather than an oval fan.
                wrist=np.array([side*(1.15 if kind=='fore' else .73),1.47,.86 if kind=='fore' else -.29])
                tips=np.array([[3.35,1.50,1.54],[3.18,1.42,.56],[2.70,1.31,-.15],[2.05,1.20,-.62],[1.24,1.12,-.63]])
                if kind=='hind':tips=np.array([[2.10,1.32,-.55],[2.06,1.23,-1.13],[1.70,1.14,-1.65],[1.15,1.07,-1.74],[.65,1.03,-1.17]])
            else:
                wrist=np.array([side*1.17,1.56,.80])
                tips=np.array([[3.12,1.43,.85],[3.00,1.31,-.05],[2.63,1.20,-.87],[1.95,1.08,-1.35],[.72,1.02,-1.03]])
            tips[:,0]*=side
            # Generate a connected set of ruled membranes between curved finger rays.
            rays=[]
            for i,tip in enumerate(tips):
                path=[]
                for t in np.linspace(0,1,38):
                    p=wrist*(1-t)+tip*t
                    p[1]-=.08*math.sin(math.pi*t)
                    path.append(p)
                rays.append(np.array(path))
            points=[];faces=[];colors=[]
            for panel in range(len(rays)-1):
                start=len(points)
                for i in range(38):
                    t=i/37
                    for j in range(15):
                        u=j/14
                        p=rays[panel][i]*(1-u)+rays[panel+1][i]*u
                        # The trailing edge scallops inward between the fingertips.
                        p=p*(1-.10*math.sin(math.pi*u)*t**8)+wrist*(.10*math.sin(math.pi*u)*t**8)
                        p[1]-=.045*math.sin(math.pi*u)*math.sin(math.pi*t)
                        points.append(p)
                        c=linear(PROFILE['wing'])
                        if ID=='blue':
                            border=max(t**6,abs(u-.5)*.25)
                            c=c*(1-border*.65)+linear(PROFILE['dorsal'])*border*.65
                        colors.append(c)
                        if i and j:
                            a=start+(i-1)*15+j-1;b=start+i*15+j-1
                            faces.append([a,a+1,b+1,b])
            mesh('SilkWingMembrane'+kind if ID=='blue' else 'NightWingMembrane',points,faces,wingmat,name,colors=colors,fold=fold)
            # A broad proximal panel joins the fingers into the real shoulder.
            mesh('Wing shoulder membrane',[root,wrist,tips[-1],root+[0,-.20,-.70]],[[0,1,2],[0,2,3]],wingmat,name,fold=fold)
            leading=spline([root,root*.4+wrist*.6+np.array([0,.07,-.10]),wrist,tips[0]],48)
            tube('Wing leading arm',leading,np.linspace(.050,.007,len(leading)),veinam,name,sides=12,fold=fold)
            for ray in rays[1:]:
                tube('Articulated wing finger',ray,np.linspace(.024,.004,len(ray)),veinam,name,sides=8,fold=fold)
            if ID!='blue':
                silver=material('Silver star scales','c7d7e5',.35,.45)
                rng=np.random.default_rng(177)
                for panel in range(4):
                    for _ in range(24):
                        t=rng.uniform(.12,.94);u=rng.uniform(.08,.92);i=min(36,int(t*37))
                        p=rays[panel][i]*(1-u)+rays[panel+1][i]*u;p[1]-=.012
                        r=rng.uniform(.0025,.0055)
                        v=[p]+[p+[r*math.cos(a),0,r*.7*math.sin(a)] for a in np.linspace(0,TAU,6,endpoint=False)]
                        mesh('Underwing silver scale',v,[[0,j+1,(j+1)%6+1] for j in range(6)],silver,name,fold=fold)
            if ID=='darkstalker':
                icy=material('IceWing heritage scales','dbe7ef',.35,.35)
                for i in range(9):
                    p=root+np.array([side*.025,-.10,-i*.045])
                    tube('White wing-root scute',[p,p+[side*.012,-.006,-.026]],[.016,.009],icy,'chest',sides=8)

def build(id):
    global ARM,BONES,MATS,ID,D,PROFILE
    assert id in ['moon','blue','darkstalker'], "Umber uses the shared MudWing base; do not generate an independent body."
    ID=id;PROFILE=PROFILES[id];kind='silkwing' if id=='blue' else 'nightwing'
    D=DATA[kind];BONES={};MATS={};ARM=None
    if id in ['moon','blue','darkstalker']:MOON.setup(sys.modules[__name__])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    V,F,W,colors,segments,axis,P=build_body()
    for side in ([] if id in ['moon','blue','darkstalker'] else [-1,1]):
        suffix='L' if side>0 else 'R'
        for wing in (['fore','hind'] if id=='blue' else ['fore']):
            root=[side*.22,1.27,.43 if wing=='fore' else .14]
            add_bone('wing_'+wing+'.'+suffix,root,[root[0]+side*.3,root[1],root[2]],'chest')
    if id in ['moon','blue','darkstalker']:MOON.fit_bones();MOON.register_wings()
    armature()
    mesh('Connected anatomical skin',V,F,material('Scaled skin','ffffff'),W,colors=colors)
    if id not in ['moon','blue','darkstalker']:make_neck_scutes(V,F,W)
    if id in ['moon','blue','darkstalker']:
        MOON.fitted_head();MOON.feet();MOON.wings();MOON.silkwing_details()
        MOON.body_details(V,F,W,axis,P,segments);MOON.character_details()
    else:make_head_details();make_feet();make_wings()
    # Export a neutral rest expression. Game motion also resets these values,
    # but viewers and first-frame consumers must not start with all samples on.
    for ob in bpy.data.objects:
        if ob.type=='MESH' and ob.data.shape_keys:
            for key in ob.data.shape_keys.key_blocks[1:]:key.value=0.0
    bpy.ops.object.select_all(action='SELECT')
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(id+'.glb')),export_format='GLB',use_selection=True,
        export_animations=False,export_morph=True,export_skins=True,export_yup=True)
    runtime={'kind':kind,'front':D['front'],'hind':D['hind'],'eye':D['eye'],'skull':D['skull'],
        'model_source':'Independent continuous skin, skull, mandible, limb and wing construction; no Clay mesh imported.',
        'bones':{name:{'head':h.tolist(),'tail':t.tolist(),'parent':parent} for name,(h,t,parent) in BONES.items()}}
    if id in ['moon','blue','darkstalker']:
        runtime['wing_rig']=MOON.WING_RIG
        runtime['antenna_rig']=MOON.ANTENNA_RIG
        runtime['model_source']='Clay named skeletal/muscular prototype retargeted to NightWing proportions, fitted craniofacial source, fixed-length wing arm/digit chains.'
        runtime['head_source']='prototypes/moon/head/head_design.json'
        runtime['character_design']='game/data/'+('blue_model_design.json' if id=='blue' else id+'_design.json')
        runtime['character_id']=id
        runtime['ventral_fit']=MOON.HEAD['ventral_fit']
        runtime['wing_rest_style']=MOON.DESIGN['wing']['rest_style']
        runtime['physical_estimate']=MOON.physical_metrics(V,F)
        runtime['ground_plant_model']=min(float((ob.matrix_world@v.co).z) for ob in bpy.data.objects if ob.type=='MESH' for v in ob.data.vertices)
        runtime['feet']={kind:{'toes':json.loads((ROOT/'prototypes/clay/body/body_design.json').read_text())[key]['toes']} for kind,key in [('front','front_leg'),('hind','hind_leg')]}
        runtime['face_fit']={'bite_plane_y_from_z':MOON.HEAD['bite_plane'],'tongue_floor_clearance':MOON.HEAD['tongue_floor_clearance'],'upper_teeth':len(MOON.HEAD['upper_tooth_roots']),'lower_teeth':len(MOON.HEAD['lower_tooth_roots']),'eyes':MOON.HEAD['eye_validation']}
    (OUT/(id+'_anatomy.json')).write_text(json.dumps(runtime,indent=2)+'\n')
    print('BUILT independent',id,len(V),'skin vertices',len(BONES),'bones',flush=True)

if __name__=='__main__':
    selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['moon','blue','darkstalker']
    for character in selected:build(character)
