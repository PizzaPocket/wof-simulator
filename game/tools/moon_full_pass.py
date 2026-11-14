"""Shared complete dragon construction with explicit NightWing and SilkWing profiles.

Called by build_tribe_dragons.py -- moon. Does not write preview artifacts.
"""
import copy
import json
import math
import runpy
import sys
import moon_face_anatomy as FACE
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from scipy.spatial import cKDTree

A=None
DESIGN=None
HEAD={}
WING_RIG={}
TOES=[]
HORN_PATHS=[]
ANTENNA_RIG=[]

def setup(api):
    global A,DESIGN,HEAD,WING_RIG,TOES,HORN_PATHS,ANTENNA_RIG
    A=api;DESIGN=json.loads((A.ROOT/'game/data/moon_design.json').read_text());HEAD={};WING_RIG={};TOES=[];HORN_PATHS=[];ANTENNA_RIG=[]
    if A.ID=='blue':DESIGN=json.loads((A.ROOT/'game/data/blue_model_design.json').read_text())
    if A.ID=='darkstalker':
        override=json.loads((A.ROOT/'game/data/darkstalker_design.json').read_text())
        def merge(base,delta):
            for key,value in delta.items():
                if isinstance(value,dict) and isinstance(base.get(key),dict):merge(base[key],value)
                else:base[key]=copy.deepcopy(value)
        merge(DESIGN,override)
        body=DESIGN['body']
        for i,row in enumerate(body['spine']):
            neck=i<6
            row[2]*=body['neck_width_multiplier'] if neck else body['trunk_width_multiplier']
            for j in [3,4]:row[j]*=body['neck_width_multiplier'] if neck else body['trunk_depth_multiplier']
        for tip in DESIGN['wing']['tips']:tip[0]*=DESIGN['wing']['span_multiplier']
    A.D=copy.deepcopy(A.D)
    A.D['spine']=DESIGN['body']['spine']
    A.D['front'][0]=[.34,1.22,.60]
    A.D['front'][1]=[.34,.64,.18]
    A.D['front'][2]=[.30,.19,.61]
    A.D['hind'][0]=[.36,1.08,-.72]
    if A.ID=='blue':
        A.D['front']=copy.deepcopy(DESIGN['body']['front']);A.D['hind']=copy.deepcopy(DESIGN['body']['hind'])

def trunk_section(radii,i,t):
    # Clay's independent back/belly depths, rounded-square shoulders and keel.
    c,s=math.cos(t),math.sin(t);power=2/DESIGN['body']['section_squareness']
    v=math.copysign(abs(c)**power,c)*(radii[i,1] if c>=0 else radii[i,2])
    keel=1-DESIGN['body']['keel_taper']*max(0,-c)
    w=math.copysign(abs(s)**power,s)*radii[i,0]*keel
    return v,w

def prototype_parts(parts):
    """Retarget Clay's actual named muscle architecture to NightWing joints."""
    source=json.loads((A.ROOT/'prototypes/clay/body/body_design.json').read_text())
    # Deep throat tissue joins the occiput to the hyoid region behind the
    # moving dentary. Union it with the cervical skin rather than covering the
    # join with a disconnected patch or exposing a gap when the jaw opens.
    parts.append(A.SK.Piece({'name':'Occipital throat transition',
        'from':[0,1.87,1.04],'to':[0,1.87,1.41],
        'radii':[.16,.055],'hint':[1,0,0],
        'rig':{'head':.65,'neck4':.35},'k':.045},1,'muscle'))
    fj=source['front_leg']['joints'];hj=source['hind_leg']['joints']
    old={
        'upperarm':(fj['shoulder'],fj['elbow']), 'forearm':(fj['elbow'],fj['wrist']),
        'hand':(fj['wrist'],fj['knuckles']),
        'thigh':(hj['hip'],hj['knee']), 'shin':(hj['knee'],hj['heel']),
        'foot':(hj['heel'],hj.get('ball',hj.get('toes',[.45,.05,-.5])))
    }
    # The original foot labels differ from the runtime's compact chain.
    for key,(a,b) in list(old.items()):
        if not isinstance(b,list):old[key]=(a,[.45,.05,-.5])
    target={name:(A.D[kind][i],A.D[kind][i+1]) for kind,names in [('front',['upperarm','forearm','hand']),('hind',['thigh','shin','foot'])] for i,name in enumerate(names)}
    def resolve(name):
        if name.startswith(('wrist','forearm_twist')):return 'forearm'
        if name in ['shoulder_soft','wing_socketBlend1']:return 'chest'
        if name in ['ankle','heel']:return 'shin'
        return name if name in old or name in ['chest','spine','hips'] else 'hips'
    def move(p,bone):
        p=np.asarray(p,float)
        if bone not in old:return np.array([p[0]*.94,1.10+(p[1]-1)*1.03,p[2]*.88-.05])
        a,b=np.asarray(old[bone][0]),np.asarray(old[bone][1]);x,y=np.asarray(target[bone][0]),np.asarray(target[bone][1])
        d=A.SK.norm(b-a);e=A.SK.norm(y-x)
        side=A.SK.norm(np.array([1.,0,0])-d*d[0]);up=np.cross(d,side)
        new_side=A.SK.norm(np.array([1.,0,0])-e*e[0]);new_up=np.cross(e,new_side)
        q=p-a;t=np.dot(q,d)/max(np.linalg.norm(b-a),.001)
        return x+(y-x)*t+new_side*np.dot(q,side)*DESIGN['body']['transverse_attachment_scale']+new_up*np.dot(q,up)*.88
    for side in [-1,1]:
        suffix='L' if side>0 else 'R'
        for layer,key in [('bone','bones'),('muscle','muscles')]:
            for raw in source['anatomy'][key]:
                if 'from' not in raw or 'to' not in raw:continue
                spec=copy.deepcopy(raw);rig={}
                for bone,w in raw.get('rig',{'chest':1}).items():
                    b=resolve(bone);name=b+'.'+suffix if b in old else b
                    if name in A.BONES:rig[name]=rig.get(name,0)+w
                dominant=resolve(max(raw.get('rig',{'chest':1}),key=raw.get('rig',{'chest':1}).get))
                for endpoint in ['from','to']:
                    p=move(raw[endpoint],dominant);p[0]*=side;spec[endpoint]=p.tolist()
                for field in ['r','radii']:
                    if field in spec:spec[field]=(np.array(spec[field])*DESIGN['body']['muscle_radius_scale']).tolist()
                if 'hint' in spec:spec['hint'][0]*=side
                spec['rig']=rig or {'chest':1};spec.pop('rig_path',None)
                spec['k']=min(.10,spec.get('k',.05)*.78)
                spec['name']='Shared anatomy: '+raw['name']+' '+suffix
                parts.append(A.SK.Piece(spec,1,layer))

def fit_bones():
    d=json.loads((A.ROOT/'prototypes/moon/head/head_design.json').read_text())
    o=np.array(d['local_frames']['skull']['origin_uv'],float)
    axis=A.SK.norm(o-np.array(d['local_frames']['skull']['forward_uv']))
    normal=np.array([axis[1],-axis[0]])
    joint=np.array(d['dentary']['hinge_uv'])-o
    p=np.array([np.dot(joint,axis)/500,0,np.dot(joint,normal)/500])
    h=map_point(p)
    A.BONES['jaw']=(h,np.array([0,h[1]-.04,2.0]),'head')
    nozzle=2.025
    A.BONES['fire_origin']=(np.array([0,1.91,nozzle]),np.array([0,1.91,nozzle+.06]),'head')
    if A.ID=='blue':
        cfg=DESIGN['antenna']
        for side in [-1,1]:
            suffix='L' if side>0 else 'R';root=np.array(cfg['root'])*[side,1,1]
            path=A.spline([root+np.array(offset)*[side,1,1] for offset in cfg['offsets']],100)
            indices=[0,33,66,99];bones=[]
            for i in range(3):
                name='antenna'+str(i+1)+'.'+suffix
                A.add_bone(name,path[indices[i]],path[indices[i+1]],'head' if i==0 else bones[-1]);bones.append(name)
            ANTENNA_RIG.append({'side':suffix,'bones':bones,'base_fixed_fraction':.14,'tip_flex_degrees':3.5})


def toe_parts(parts,kind,end,side,bone):
    """Reuse the approved segmented Clay digits and their hooked claws."""
    source=json.loads((A.ROOT/'prototypes/clay/body/body_design.json').read_text())
    d=source['front_leg' if kind=='front' else 'hind_leg']['toes'];scale=DESIGN['body']['foot_scale']
    for i in range(d['count']):
        angle=math.radians(d['spread_deg'][i]);direction=np.array([side*math.sin(angle),0,math.cos(angle)])
        p=np.array(end)+[side*d['base_offset_x'][i]*scale,0,0]
        prefix='f' if kind=='front' else 'h';suffix='L' if side>0 else 'R'
        meta=prefix+'meta'+str(i+1)+'.'+suffix;previous=meta
        # Metacarpal ray embeds the digit in the same palm, not a detached tube.
        base=np.array(end)+[side*d['base_offset_x'][i]*scale*.18,.015,-.075]
        A.add_bone(meta,base,p,bone)
        parts.append(A.SK.Piece({'name':'NightWing metacarpal ray','from':base.tolist(),'to':p.tolist(),'r':[.033,.034],
            'rig':{meta:1},'k':.028,'zone':.5},1,'bone'))
        for j,length in enumerate(d['segments']):
            drop=math.radians(d['drop_deg'][j]);length*=scale*d['length_scale'][i]
            q=p+direction*length*math.cos(drop)+np.array([0,-length*math.sin(drop),0])
            joint=prefix+'toe'+str(i+1)+('' if j==0 else '_p'+str(j+1))+'.'+suffix
            A.add_bone(joint,p,q,previous);previous=joint
            r=d['radius'][j]*scale
            parts.append(A.SK.Piece({'name':'Shared toe phalanx','from':p.tolist(),'to':q.tolist(),'r':[r,r*.9],
                'rig':{joint:1},'k':.023,'zone':.5},1,'bone'));p=q
        TOES.append((p,direction,previous,d['claw'],scale))
    # The visible four main rays retain Clay's form; the inboard thumb/dewclaw
    # completes the grasping forefoot / raised hind claw seen in dragon anatomy.
    p=np.array(end)+[-side*.075,.045,-.018]
    direction=A.SK.norm([-side*.65,-.12,.65])
    q=p+direction*.055
    thumb=('fthumb' if kind=='front' else 'hdew')+'.'+('L' if side>0 else 'R')
    A.add_bone(thumb,p,q,bone)
    parts.append(A.SK.Piece({'name':'Inboard thumb' if kind=='front' else 'Hind dewclaw pad','from':p.tolist(),'to':q.tolist(),
        'r':[.028,.020],'rig':{thumb:1},'k':.025,'zone':.5},1,'bone'))
    TOES.append((q,direction,thumb,d['claw'],scale*.65))

def feet():
    keratin=A.material('Moon claw keratin','535e67',.49)
    for p,direction,bone,d,scale in TOES:
        length=d['length']*scale;hook=math.radians(d['hook_deg']);pitch=math.radians(d['pitch_deg']);radius=length/hook
        p=np.array(p)+[0,.013,0];path=[]
        for theta in np.linspace(0,hook,24):
            forward=radius*(math.sin(pitch)-math.sin(pitch-theta))
            up=radius*(math.cos(pitch-theta)-math.cos(pitch))
            path.append(p+direction*forward+np.array([0,up,0]))
        A.tube('Moon hooked talon',path,np.linspace(d['radius']*scale,.0007,len(path)),keratin,bone,sides=12)

def map_point(p,jaw=False):
    d=DESIGN['head'];s=d['scale'];p=np.asarray(p)
    q=np.array([p[1]*s,d['height']+p[2]*s,d['longitudinal_anchor']-p[0]*s])
    t=np.clip((q[2]-1.70)/.36,0,1);t=t*t*(3-2*t)
    q[0]*=1-d.get('muzzle_width_reduction',0)*t
    q[2]+=d.get('muzzle_extension',0)*t*(.65 if jaw else 1)
    # A tapered section alone still leaves a transverse flat nose cap. Round
    # the anterior footprint: the central premaxilla projects beyond its alae.
    # The smooth anterior gate leaves the broad orbital/cranium section intact.
    lateral=np.clip(abs(q[0])/.15,0,1.6)
    q[2]-=d.get('nose_cap_rounding',.12)*lateral*lateral*t
    if not jaw:
        roof=np.clip((q[1]-1.71)/.12,0,1)
        q[1]+=t*(d.get('anterior_lift',0)*(1-roof))
        q[1]-=.025*lateral*lateral*t*roof
        # Preserve the broad braincase but flatten the SilkWing's anterior
        # premaxillary depth along its own bite frame, not the drawing tilt.
        q[1]=1.79+(q[1]-1.79)*(1-d.get('anterior_profile_compression',0)*t)
    return q

def horn_housings(points,faces):
    """Move the crown itself onto the filleted union with each horn root."""
    global HORN_PATHS
    triangles=np.array([tri for f in faces for tri in [[f[0],f[i],f[i+1]] for i in range(1,len(f)-1)]])
    normals=A.SK.normals(points,triangles);tree=cKDTree(points);out=points.copy();d=DESIGN['horn']
    HORN_PATHS=[]
    for side in [-1,1]:
        raw=np.array(d['path'])*np.array([side,1,1]);_,nearest=tree.query(raw[0]);seat=points[nearest]
        direction=A.SK.norm(raw[1]-raw[0]);path=raw-raw[0]+seat-direction*.028
        HORN_PATHS.append(path)
        start=path[0];end=start+direction*d['housing_length'];segment=end-start
        distance=np.linalg.norm(points-start,axis=1)
        indices=np.where(distance<d['housing_length']+d['housing_radius']+d['housing_fillet'])[0]
        for index in indices:
            p=out[index];n=normals[index]
            if n[1]<-.15:continue
            def field(amount):
                q=p+n*amount;t=np.clip(np.dot(q-start,segment)/np.dot(segment,segment),0,1)
                horn_distance=np.linalg.norm(q-start-segment*t)-d['housing_radius']
                return A.SK.smin(amount,horn_distance,d['housing_fillet'])
            if field(0)>=-1e-7:continue
            lo,hi=0.,.24
            if field(hi)<0:continue
            for _ in range(20):
                mid=(lo+hi)/2
                if field(mid)<0:lo=mid
                else:hi=mid
            out[index]=p+n*((lo+hi)/2)
    return out

def mesh_color(points,kind):
    colors=[];flank=A.linear(A.PROFILE['scales']);roof=A.linear(A.PROFILE['dorsal']);belly=A.linear(A.PROFILE['belly'])
    for x,y,z in points:
        if kind=='jaw':c=flank*.92+belly*.08
        else:
            t=np.clip((y-1.94)/.16,0,1);c=flank*(1-t)+roof*t
            # Cap and throat boundaries follow separate anatomical surfaces.
        if A.ID=='blue':
            muzzle=np.clip((z-1.65)/.46,0,1);c=c*(1-muzzle*.65)+A.linear(DESIGN['surface']['muzzle_color'])*muzzle*.65
        colors.append(c)
    return colors

def fitted_head():
    before=set(bpy.data.objects)
    source=runpy.run_path(str(A.ROOT/'prototypes/moon/head/build_study.py'),init_globals={
        'GAME_HEAD':True,'GAME_MUZZLE_SQUARENESS':DESIGN['head'].get('muzzle_squareness')})
    objects=[o for o in bpy.data.objects if o not in before]
    root=source['head_root'];jawroot=source['jaw_root']
    jawroot.rotation_euler.y+=math.radians(DESIGN['head']['jaw_close_degrees'])
    bpy.context.view_layer.update()
    surface=[];surface_faces=[];jawpoints=[];jaw_faces=[]
    globe_centres=[]
    for o in objects:
        if o.type!='MESH':continue
        name=o.name;is_jaw=name.startswith('Dentary');is_globe=name.startswith('Seated eyeball')
        if is_jaw:continue
        if is_globe:
            globe_centres.append(map_point(o.matrix_world.translation));continue
        bone='jaw' if is_jaw else 'head'
        evaluated=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        raw=evaluated.to_mesh() if not o.data.shape_keys else o.data
        source_vertices=[np.array(o.matrix_world@v.co) for v in raw.vertices]
        source_faces=[list(p.vertices) for p in raw.polygons]
        # Give the nose cap an interior before curving it. A single ngon only
        # bends at its perimeter, leaving a flat triangulated surface inside.
        if name.startswith('Nasal'):
            rebuilt=[]
            for f in source_faces:
                centre=np.mean([source_vertices[i] for i in f],axis=0)
                if len(f)<64 or map_point(centre)[2]<1.8:
                    rebuilt.append(f);continue
                previous=f
                for fraction in np.linspace(.9,.1,9):
                    ring=[]
                    for index in f:
                        ring.append(len(source_vertices));source_vertices.append(centre+(source_vertices[index]-centre)*fraction)
                    for j in range(len(f)):
                        k=(j+1)%len(f);rebuilt.append([previous[j],previous[k],ring[k],ring[j]])
                    previous=ring
                middle=len(source_vertices);source_vertices.append(centre)
                for j in range(len(f)):rebuilt.append([previous[j],previous[(j+1)%len(f)],middle])
            source_faces=rebuilt
        points=np.array([map_point(p,is_jaw) for p in source_vertices])
        # Local head axes -> game axes include a reflection. Reverse winding
        # so the anatomical host and lids retain outward-facing normals.
        faces=[list(reversed(f)) for f in source_faces]
        if name.startswith('Nasal'):
            vault=DESIGN['head']['cranial_vault']
            for p in points:
                posterior=np.clip((1.65-p[2])/.25,0,1)
                roof=np.clip((p[1]-2.105)/.065,0,1);roof=roof*roof*(3-2*roof)
                p[1]+=vault['height']*posterior*roof*(.25+.75*math.exp(-(p[0]/.16)**2))
                rear=np.clip((1.43-p[2])/.20,0,1)
                p[2]-=vault['rear_extension']*rear*roof
            points=horn_housings(points,faces)
            normals=A.SK.normals(points,np.array([tri for f in faces for tri in [[f[0],f[i],f[i+1]] for i in range(1,len(f)-1)]]))
            # Crown joints are carved into the host, not separate MudWing tiles.
            for i,p in enumerate(points):
                crown=np.clip((normals[i,1]-.35)/.5,0,1)*np.clip((p[1]-1.84)/.16,0,1)
                groove=math.exp(-(math.sin((p[2]-1.2)*math.pi/.082)/.09)**2)*.0015
                points[i]-=normals[i]*groove*crown
            surface=points.copy();surface_faces=faces
        elif is_jaw:jawpoints=points.copy();jaw_faces=faces
        material=A.material('Moon facial scales',A.PROFILE['scales'])
        result=A.mesh('MoonSkin '+name,points,faces,material,bone,colors=mesh_color(points,'jaw' if is_jaw else 'head'))
        if name.startswith('Nasal'):host_object=result
        if o.data.shape_keys:
            result.shape_key_add(name='Basis')
            for key in o.data.shape_keys.key_blocks[1:]:
                dst=result.shape_key_add(name=key.name)
                for item,v in zip(dst.data,key.data):item.co=A.B(map_point(o.matrix_world@v.co,is_jaw))
        if not o.data.shape_keys:evaluated.to_mesh_clear()
    global HEAD
    HEAD={'surface':surface,'faces':surface_faces,'jaw':jawpoints,'jaw_faces':jaw_faces,'eyes':globe_centres,
          'eye_radius':source['radius']*DESIGN['head']['scale'],'joint':A.BONES['jaw'][0],'host_object':host_object}
    for o in objects:bpy.data.objects.remove(o,do_unlink=True)
    FACE.build(A,DESIGN,HEAD)
    head_details()
    FACE.validate_eyes(A,DESIGN,HEAD)

def physical_metrics(body,faces):
    def volume(points,polygons):
        triangles=np.array([t for f in polygons for t in [[f[0],f[i],f[i+1]] for i in range(1,len(f)-1)]])
        p=np.asarray(points)[triangles]
        return float(abs(np.einsum('ij,ij->i',p[:,0],np.cross(p[:,1],p[:,2])).sum()/6))
    scale=DESIGN['physical_estimate']['world_scale']
    body_volume=volume(body,faces)
    head_volume=volume(HEAD['surface'],HEAD['faces'])+volume(HEAD['jaw'],HEAD['jaw_faces'])
    effective_volume=(body_volume+head_volume*.9)*scale**3
    allpoints=np.vstack([body,HEAD['surface'],HEAD['jaw']]);lo=allpoints.min(axis=0)*scale;hi=allpoints.max(axis=0)*scale
    span=2*max(abs(d['tip'][0]) for r in WING_RIG.values() for d in r['digits'])*scale
    density=DESIGN['physical_estimate']['effective_density_kg_m3']
    return {'status':'Inferred game dimensions, not canon measurements','age_years':DESIGN['physical_estimate']['age_years'],
        'linear_fraction_of_near_mature_nightwing':DESIGN['physical_estimate']['relative_linear_size'],
        'nose_to_tail_straight_m':round(float(hi[2]-lo[2]),2),'head_height_excluding_horns_m':round(float(hi[1]),2),
        'shoulder_height_m':round(float(np.max(body[(body[:,2]>.30)&(body[:,2]<.65)&(np.abs(body[:,0])>.28)&(np.abs(body[:,0])<.60),1]))*scale,2),'spread_wingspan_m':round(span,2),
        'primary_anatomical_volume_m3':round(effective_volume,3),'mass_estimate_kg':round(effective_volume*density,-1),
        'mass_range_kg':[round(effective_volume*r,-1) for r in DESIGN['physical_estimate']['density_range_kg_m3']],
        'mass_method':DESIGN['physical_estimate']['method'],
        'sources':DESIGN['physical_estimate']['sources']}

def project(target):
    v=HEAD['surface'];_,index=cKDTree(v).query(target)
    return v[index]

def sphere_cap(name,center,normal,radius,extent,mat,bone='head',slit=False):
    normal=A.SK.norm(normal);up=np.array([0,1.,0]);a=A.SK.norm(np.cross(up,normal));b=np.cross(normal,a)
    points=[center+normal*(radius+.0006)];faces=[]
    rings=7;around=48
    for j in range(1,rings+1):
        r=extent*j/rings
        for k in range(around):
            theta=math.tau*k/around;x=r*math.cos(theta)*( .22 if slit else 1);y=r*math.sin(theta)
            points.append(center+a*x+b*y+normal*(math.sqrt(max(.00001,radius*radius-x*x-y*y))+.0007))
            if j==1:faces.append([0,k+1,(k+1)%around+1])
            else:
                p=1+(j-2)*around+k;q=1+(j-1)*around+k
                faces.append([p,1+(j-2)*around+(k+1)%around,1+(j-1)*around+(k+1)%around,q])
    return A.mesh(name,points,faces,mat,bone)

def head_details():
    skin=A.material('Moon ear scales',A.PROFILE['scales']);horn=A.material('NightWing horn keratin',DESIGN['horn']['color'],DESIGN['horn']['roughness'])
    silver=A.material('Moon silver tear','cedce5',.25,.65)
    eye_radius=HEAD['eye_radius']
    for center in HEAD['eyes']:
        side=1 if center[0]>0 else -1
        normal=A.SK.norm(np.array(DESIGN['eye']['gaze'])*[side,1,1])
        # One seated globe carries sclera, iris and pupil on the same surface,
        # following Clay's eye assembly. No stacked discs can escape the lids.
        theta=math.asin(min(.95,DESIGN['eye']['iris_extent']/eye_radius))
        samples=sorted(set(list(np.linspace(0,1,110))+[theta/math.pi,(theta+.014)/math.pi]))
        points,faces,uv=HEAD['clay'].sphere(center,eye_radius,lon=128,up=normal,latitude_samples=samples)
        across=A.SK.norm(np.cross([0,1,0],normal));up=np.cross(normal,across)
        colors=[]
        dark=A.linear(DESIGN['eye'].get('sclera_color','30392f'));green=A.linear(DESIGN['eye'].get('iris_color','2c6547'));pupil=A.linear('04090a')
        for p,(latitude,longitude) in zip(points,uv):
            q=np.asarray(p)-center;angle=latitude*math.pi
            color=dark.copy()
            if angle<theta:
                ray=.86+.12*math.sin(longitude*math.tau*37)+.04*math.sin(longitude*math.tau*73)
                color=green*ray
                x=np.dot(q,across);y=np.dot(q,up)
                if (x/(eye_radius*.105))**2+(y/(eye_radius*.67))**2<1:color=pupil
            colors.append(color)
        globe=A.mesh('Moon seated pigmented globe',points,faces,A.material('Moon eye pigments','ffffff',.22),'head',colors=colors)
        FACE.outward(globe)
        if A.ID!='blue':
            target=project(center+np.array([side*.05,-.025,-.055]))
            # The scale is fitted to the cheek at the outward eye corner.
            normal=A.SK.norm([side,.05,.25]);across=A.SK.norm(np.cross([0,1,0],normal));up=np.cross(normal,across)
            edge=[target+across*x+up*y+normal*.002 for x,y in [(0,.020),(.010,.006),(.008,-.009),(0,-.025),(-.008,-.009),(-.010,.006)]]
            A.mesh('SilverTearScale'+('L' if side>0 else 'R'),[target+normal*.006]+edge,[[0,j+1,(j+1)%6+1] for j in range(6)],silver,'head')
    for side,raw in zip([-1,1],HORN_PATHS):
        path=A.spline(raw,72)
        radii=np.interp(np.linspace(0,1,len(path)),np.linspace(0,1,len(DESIGN['horn']['radius'])),DESIGN['horn']['radius'])
        radii*=1-.018*(.5+.5*np.cos(np.linspace(0,1,len(path))*math.tau*26))
        if A.ID=='darkstalker':
            # Helical fluting supplements the gently twisted axis, with no
            # detached coils over the horn shaft.
            radii*=1-.025*np.sin(np.linspace(0,math.tau*2,len(path)))**2
        A.tube('Moon swept horn',path,radii,horn,'head',sides=18)
        root=project(np.array([side*.24,2.035,1.32]))
        points=[];faces=[]
        for layer in [0,1]:
            for i in range(25):
                t=i/24;c=root+np.array([side*.085*t,.045*math.sin(t*math.pi)-.012*t,-.26*t])
                width=.055*math.sin(math.pi*t)**.7+.002
                for j in range(9):
                    u=j/8*2-1
                    points.append(c+np.array([side*(.018*(1-u*u)-layer*.003),width*u,.012*(1-u*u)]))
                    if i and j:
                        a=layer*225+(i-1)*9+j-1;b=layer*225+i*9+j-1;faces.append([a,a+1,b+1,b] if layer==0 else [b,b+1,a+1,a])
        A.mesh('Moon cupped swept ear',points,faces,skin,'head')
    for z in [1.30,1.40,1.50]:
        base=project([0,2.14,z]);blade('Moon fitted crown blade',base,[0,1,0],[0,0,-1],DESIGN.get('surface',{}).get('crown_blade_height',.075),.043,horn,'head')

def register_wings():
    global WING_RIG
    for d in DESIGN['wing'].get('sets',[DESIGN['wing']]):
        d=copy.deepcopy(d)
        sweep=math.radians(d.get('flight_sweep_degrees',0))
        if sweep:
            # Sweep only the deployed anatomy. Arm lengths and the authored
            # standing directions stay identical, so the approved fold remains.
            c,s=math.cos(sweep),math.sin(sweep)
            rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
            pivot=np.array(d['root'])
            def swept(points):return ((np.asarray(points)-pivot)@rotation.T+pivot).tolist()
            for key in ['elbow','wrist','tips','digit_controls','main_lobe_controls','trailing_lobe_controls']:
                if key in d:d[key]=swept(d[key])
        bank=d.get('bank','fore')
        for side in [-1,1]:
            suffix='L' if side>0 else 'R';mirror=np.array([side,1,1]);prefix='' if bank=='fore' else 'hind_'
            root=np.array(d['root'])*mirror;elbow=np.array(d['elbow'])*mirror;wrist=np.array(d['wrist'])*mirror
            base='wing_'+bank+'.'+suffix;fore='wing_'+prefix+'elbow.'+suffix
            A.add_bone(base,root,elbow,'chest');A.add_bone(fore,elbow,wrist,base)
            digits=[]
            for i,p in enumerate(d['tips']):
                tip=wrist+(np.array(p)*mirror-wrist)*d.get('digit_length_multiplier',1.0)
                middle=wrist+(tip-wrist)*.53;middle[1]-=.035
                first='wing_'+prefix+'digit%da.'%i+suffix;second='wing_'+prefix+'digit%db.'%i+suffix
                A.add_bone(first,wrist,middle,fore);A.add_bone(second,middle,tip,first)
                fold=np.array(d['fold_finger_directions'][i])*mirror;distal=fold.copy();distal[0]*=d.get('fold_distal_lateral_fraction',1.0);distal[1]-=.08
                digits.append({'first':first,'second':second,'middle':middle.tolist(),'tip':tip.tolist(),'fold':fold.tolist(),'fold_distal':distal.tolist()})
            key=suffix if A.ID!='blue' else bank+'.'+suffix
            rig={'root_bone':base,'elbow_bone':fore,'side':suffix,'bank':bank,'root':root.tolist(),'elbow':elbow.tolist(),'wrist':wrist.tolist(),
                'flight_sweep_degrees':d.get('flight_sweep_degrees',0),
                'fold_upper':(np.array(d['fold_upper_direction'])*mirror).tolist(),'fold_fore':(np.array(d['fold_fore_direction'])*mirror).tolist(),'digits':digits,
                'arm_muscle_scale':d.get('arm_muscle_scale',DESIGN['wing'].get('arm_muscle_scale',.9)),
                'web_end_offset':d.get('web_end_offset',[0,-.30,-1.02]),'web_end_bone':d.get('web_end_bone','hips')}
            backward=np.array([0.,0.,-1.]);dh=A.SK.norm(elbow-root);df=A.SK.norm(wrist-elbow)
            trailing=A.SK.norm((backward-dh*np.dot(backward,dh))+(backward-df*np.dot(backward,df)));inset=elbow+(trailing*.035 if A.ID!='blue' else np.zeros(3));attachment=[]
            for j in range(23):
                u=j/22;point=wrist+(inset-wrist)*(2*u) if u<=.5 else inset+(root-inset)*(2*u-1)
                axis_point=wrist+(elbow-wrist)*(2*u) if u<=.5 else elbow+(root-elbow)*(2*u-1)
                blend=np.clip((u-.44)/.12,0,1);blend=blend*blend*(3-2*blend)
                attachment.append({'point':point.tolist(),'axis_point':axis_point.tolist(),'weights':[(fore,float(1-blend)),(base,float(blend))]})
            rig['arm_attachment']=attachment;rig['membrane_attachment_side']='trailing shoulder-elbow-wrist chain; no leading triangle';WING_RIG[key]=rig
            if 'rest_fan_leading' in d:
                rig['rest_fan_leading']=(np.array(d['rest_fan_leading'])*mirror).tolist();rig['rest_fan_normal']=[-side,0,0];rig['rest_fan_mode']='preserve_open_lobe'
            if A.ID=='blue':
                for field in ['trailing_lobe_controls','main_lobe_controls']:
                    if field in d:rig[field]=(np.array(d[field])*mirror).tolist()
                for field in ['rest_trailing_lobe_yz','rest_main_lobe_yz']:
                    if field in d:rig[field]=d[field]
                from scipy.interpolate import CubicSpline
                boundary=np.array([wrist]+[np.array(digit['tip']) for digit in digits]+[root+np.array(rig['web_end_offset'])])
                parameters=np.r_[0,np.cumsum(np.linalg.norm(np.diff(boundary,axis=0),axis=1))]
                edge=CubicSpline(parameters,boundary,bc_type='natural')
                rig['outer_boundary']=boundary.tolist();rig['outer_parameters']=parameters.tolist();rig['edge_style']='continuous_spline_lobes'
                for i,digit in enumerate(digits):
                    tip=np.array(digit['tip']);attachment=d.get('digit_attachments',['wrist']*len(digits))[i]
                    origin=elbow if attachment=='proximal' else wrist
                    digit['origin']=origin.tolist();digit['attachment']=attachment
                    delta=tip-origin
                    c1=origin+delta*.30+np.array([side*.035,0,.12])
                    c2=origin+delta*.73+np.array([side*.035,0,.08])
                    if i==0:
                        tangent=edge(parameters[1],1);tangent=A.SK.norm(tangent)
                        c2=tip-tangent*np.linalg.norm(delta)*.28
                    if 'digit_controls' in d:c1,c2=np.array(d['digit_controls'][i])*mirror
                    if d.get('reference_curve_yz',[] ) and d['reference_curve_yz'][i] is not None:
                        import silkwing_wings
                        c1,c2=silkwing_wings.reference_controls(A,rig,digit,d['reference_curve_yz'][i])
                    digit['control1']=c1.tolist();digit['control2']=c2.tolist();digit['smooth_arc']=True
                    t=.53;middle=(1-t)**3*origin+3*(1-t)**2*t*c1+3*(1-t)*t*t*c2+t**3*tip
                    digit['middle']=middle.tolist()
                    A.BONES[digit['first']]=(origin,middle,base if attachment=='proximal' else fore);A.BONES[digit['second']]=(middle,tip,digit['first'])


def finger_weights(digit,t):
    blend=np.clip((t-.30)/.48,0,1) if digit.get('smooth_arc') else np.clip((t-.45)/.16,0,1)
    if digit.get('smooth_arc'):blend=blend*blend*(3-2*blend)
    return [(digit['first'],float(1-blend)),(digit['second'],float(blend))]

def wing_ray(wrist,digit,t):
    middle=np.array(digit['middle']);tip=np.array(digit['tip']);origin=np.array(digit.get('origin',wrist))
    if 'control1' in digit:
        return (1-t)**3*origin+3*(1-t)**2*t*np.array(digit['control1'])+3*(1-t)*t*t*np.array(digit['control2'])+t**3*tip
    return wrist+(middle-wrist)*t/.53 if t<=.53 else middle+(tip-middle)*(t-.53)/.47

def blend_weights(a,b,u):
    result={}
    for name,w in a:result[name]=result.get(name,0)+w*(1-u)
    for name,w in b:result[name]=result.get(name,0)+w*u
    return list(result.items())

def wings():
    if A.ID=='blue':
        import silkwing_wings
        return silkwing_wings.build(A,sys.modules[__name__])
    membrane=A.material('Moon wing membrane',A.PROFILE['wing'],.6);finger=A.material('Moon wing fingers',A.PROFILE['dorsal'],.48)
    silver=A.material('Moon underwing stars','b6c9d5',.3,.45)
    for suffix,rig in WING_RIG.items():
        root=np.array(rig['root']);elbow=np.array(rig['elbow']);wrist=np.array(rig['wrist']);digits=rig['digits']
        wing_arm_skin(rig)
        outer=None
        if A.ID=='blue':
            from scipy.interpolate import CubicSpline
            outer=CubicSpline(rig['outer_parameters'],np.array(rig['outer_boundary']),bc_type='natural')
        def panel_point(panel,t,u):
            p=wing_ray(wrist,digits[panel],t)*(1-u)+wing_ray(wrist,digits[panel+1],t)*u
            # Scalloping has its domain along the actual two articulated rays.
            if outer is not None:
                parameters=rig['outer_parameters'];q=parameters[panel+1]*(1-u)+parameters[panel+2]*u
                chord=np.array(digits[panel]['tip'])*(1-u)+np.array(digits[panel+1]['tip'])*u
                p+=(outer(q)-chord)*t**3
            else:
                gather=.10*math.sin(math.pi*u)*t**8;p=p*(1-gather)+wrist*gather
            p[1]-=.035*math.sin(math.pi*u)*math.sin(math.pi*t)
            w=blend_weights(finger_weights(digits[panel],t),finger_weights(digits[panel+1],t),u)
            return p,w
        pts=[];faces=[];weights=[]
        for panel in range(len(digits)-1):
            start=len(pts)
            for i in range(46):
                for j in range(19):
                    p,w=panel_point(panel,i/45,j/18);pts.append(p);weights.append(w)
                    if i and j:
                        a=start+(i-1)*19+j-1;b=start+i*19+j-1;faces.append([a,a+1,b+1,b])
        colors=wing_colors(pts,wrist,rig) if A.ID=='blue' else None
        A.mesh('SilkWingMembrane '+rig['bank'] if A.ID=='blue' else 'NightWingMembrane',pts,faces,membrane,weights,colors=colors)
        # The proximal boundary follows the trailing arm chain, not a
        # shoulder-to-wrist chord. Filling the chord's elbow triangle made a
        # leading-side sail during folding. There is no independent arm triangle.
        pts=[];faces=[];weights=[]
        body_end=root+np.array(rig.get('web_end_offset',[0,-.30,-1.02]))
        for i,t in enumerate(np.linspace(0,1,46)):
            ray=wing_ray(wrist,digits[-1],t);body=root*(1-t)+body_end*t
            release=np.clip(t/.25,0,1);release=release*release*(3-2*release)
            for j,u in enumerate(np.linspace(0,1,23)):
                attachment=rig['arm_attachment'][j]
                chord=wrist*(1-u)+root*u
                p=ray*(1-u)+body*u+(np.array(attachment['point'])-chord)*(1-t)
                if outer is not None:
                    parameters=rig['outer_parameters'];q=parameters[-2]*(1-u)+parameters[-1]*u
                    p+=(outer(q)-(np.array(digits[-1]['tip'])*(1-u)+body_end*u))*t**3
                pts.append(p)
                base_weights=blend_weights(finger_weights(digits[-1],t),[('chest',1-t),(rig.get('web_end_bone','hips'),t)],u)
                weights.append(base_weights if j in [0,22] else blend_weights(attachment['weights'],base_weights,release))
                if i and j:
                    a=(i-1)*23+j-1;b=i*23+j-1;faces.append([a,a+1,b+1,b])
        A.mesh('Moon continuous axillary membrane',pts,faces,membrane,weights,colors=wing_colors(pts,wrist,rig) if A.ID=='blue' else None)
        for digit in digits:
            points=[wing_ray(wrist,digit,t) for t in np.linspace(0,1,48)]
            radii=np.interp(np.linspace(0,1,48),[0,.12,.43,.50,.56,.64,1],[.030,.024,.021,.031,.030,.018,.004])
            if A.ID=='blue':radii=np.interp(np.linspace(0,1,48),[0,.25,.65,1],[.023,.020,.012,.003])
            # Each segment has its own rigid support; the joint tissue blends.
            ob=A.tube('Moon articulated wing finger',points,radii,finger,digit['first'],sides=10)
            ob.vertex_groups.clear()
            for i,t in enumerate(np.linspace(0,1,48)):
                for bone,w in finger_weights(digit,t):
                    if w>0:
                        group=ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone);group.add(list(range(i*10,i*10+10)),w,'REPLACE')
        claw_path=A.spline([wrist,wrist+[0,.045,.01],wrist+[0,.065,.05],wrist+[0,.04,.07]],32)
        A.tube('Moon wrist claw',claw_path,np.interp(np.linspace(0,1,32),[0,1/3,2/3,1],[.021,.017,.009,.001]),finger,rig['elbow_bone'],sides=16)
        if A.ID=='blue':continue
        rng=np.random.default_rng(8106);stars=[];star_faces=[];star_weights=[]
        for panel in range(len(digits)-1):
            for _ in range(38):
                t=rng.uniform(.12,.96);u=rng.uniform(.05,.95);p,w=panel_point(panel,t,u);p[1]-=.002
                radius=rng.uniform(.002,.006);start=len(stars);stars.append(p-[0,.0008,0]);star_weights.append(w)
                for theta in np.linspace(0,math.tau,6,endpoint=False):stars.append(p+[radius*math.cos(theta),0,radius*.7*math.sin(theta)]);star_weights.append(w)
                for j in range(6):star_faces.append([start,start+j+1,start+(j+1)%6+1])
        A.mesh('Moon underwing silver scales',stars,star_faces,silver,star_weights)

def body_details(V,F,W,axis,P,segments):
    tree=cKDTree(V);N=A.SK.normals(V,F)
    host=BVHTree.FromPolygons([Vector(p) for p in V],F.tolist())
    scute=A.material('Moon belly scutes',A.PROFILE['belly'],.61);dorsal=A.material('Moon dorsal ridge',A.PROFILE['dorsal'],.52)
    # Plate patches are clipped from the actual host triangles. A coarse
    # ray-fitted grid connected fitted corners by chords through the belly,
    # especially where a ray hit an adjoining shoulder/leg mass.
    axis_tree=cKDTree(P);_,nearest=axis_tree.query(V)
    best=np.full(len(V),np.inf);coordinate=np.zeros(len(V));centers=np.zeros_like(V);tangents=np.zeros_like(V)
    for offset in [-1,0]:
        idx=np.clip(nearest+offset,0,len(P)-2);a=P[idx];delta=P[idx+1]-a
        fraction=np.clip(np.einsum('ij,ij->i',V-a,delta)/np.einsum('ij,ij->i',delta,delta),0,1)
        c=a+delta*fraction[:,None];distance=np.linalg.norm(V-c,axis=1);take=distance<best
        best[take]=distance[take];coordinate[take]=axis[idx[take]]+(axis[idx[take]+1]-axis[idx[take]])*fraction[take]
        centers[take]=c[take];tangents[take]=delta[take]/np.linalg.norm(delta[take],axis=1)[:,None]
    normal=np.cross(np.tile([1.,0,0],(len(V),1)),tangents)
    radial=V-centers;angle=np.arctan2(radial[:,0],-np.einsum('ij,ij->i',radial,normal))
    rows=np.asarray(DESIGN['body']['spine']);station=np.r_[0,np.cumsum(np.linalg.norm(np.diff(rows[:,[0,1]],axis=0),axis=1))]
    depth=np.interp(coordinate,station,rows[:,4]);width=np.interp(coordinate,station,rows[:,2])
    radius=np.sqrt((radial[:,0]/width)**2+(np.einsum('ij,ij->i',radial,normal)/depth)**2)
    stats={'faces':0,'min_signed_clearance_model':1.,'trimmed_occluded_faces':0,'emitted_area_model2':0.,'trimmed_area_model2':0.}
    def mix(a,b,t):return [a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t,a[2]*(1-t)+b[2]*t]
    def clip(poly,dimension,bound,above):
        result=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            da=a[2][dimension]-bound;db=b[2][dimension]-bound;ina=da>=0 if above else da<=0;inb=db>=0 if above else db<=0
            if ina:result.append(a)
            if ina!=inb:result.append(mix(a,b,da/(da-db)))
        return result
    for s in np.arange(.18,min(axis[-1],4.6),.105):
        points=[];faces=[];weights=[];surface_normals=[]
        candidates=np.where((coordinate[F].max(axis=1)>=s-.047)&(coordinate[F].min(axis=1)<=s+.047)&(np.abs(angle[F]).min(axis=1)<.82)&(radius[F].max(axis=1)<1.35))[0]
        for face_index in candidates:
            tri=F[face_index]
            poly=[[V[index],np.eye(3)[j],np.array([coordinate[index],angle[index]])] for j,index in enumerate(tri)]
            for dimension,bound,above in [(0,s-.047,True),(0,s+.047,False),(1,-.82,True),(1,.82,False)]:
                poly=clip(poly,dimension,bound,above)
                if not poly:break
            if len(poly)<3:continue
            first=len(points)
            for p,bary,uv in poly:
                n=A.SK.norm(np.sum(N[tri]*bary[:,None],axis=0));points.append(p+n*.002);surface_normals.append(n)
                blended={}
                for index,fraction in zip(tri,bary):
                    for bone,weight in W[index]:blended[bone]=blended.get(bone,0)+fraction*weight
                blend=sorted(blended.items(),key=lambda x:-x[1])[:4];total=sum(value for _,value in blend)
                weights.append([(bone,value/total) for bone,value in blend])
            def emit(face,depth=0):
                sample=np.mean([points[k] for k in face],axis=0);p,n,host_index,_=host.find_nearest(Vector(sample));clearance=float(np.dot(sample-np.array(p),np.array(n)))
                if clearance<.001 and depth<5:
                    # Sharp concave transitions can still cut a tiny chord
                    # after offsetting host vertices. Refine only that face,
                    # fitting its new center and weights to the actual host.
                    q=np.array(p);host_tri=F[host_index];a,b,c=V[host_tri];u=b-a;v=c-a;d=q-a
                    aa=np.dot(u,u);ab=np.dot(u,v);bb=np.dot(v,v);ad=np.dot(u,d);bd=np.dot(v,d);den=max(1e-15,aa*bb-ab*ab)
                    y=(bb*ad-ab*bd)/den;z=(aa*bd-ab*ad)/den;bary=np.clip([1-y-z,y,z],0,1);bary/=sum(bary)
                    blend={}
                    for index,fraction in zip(host_tri,bary):
                        for bone,weight in W[index]:blend[bone]=blend.get(bone,0)+fraction*weight
                    blend=sorted(blend.items(),key=lambda x:-x[1])[:4];total=sum(w for _,w in blend)
                    k=len(points);points.append(q+np.array(n)*.002);surface_normals.append(A.SK.norm(np.sum(N[host_tri]*bary[:,None],axis=0)));weights.append([(bone,w/total) for bone,w in blend])
                    for j in range(3):emit([face[j],face[(j+1)%3],k],depth+1)
                    return
                va,vb,vc=[points[k] for k in face];area=float(np.linalg.norm(np.cross(vb-va,vc-va))*.5)
                if clearance<.0005:
                    stats['trimmed_occluded_faces']+=1;stats['trimmed_area_model2']+=area
                    return
                stats['emitted_area_model2']+=area
                faces.append(face);stats['min_signed_clearance_model']=min(stats['min_signed_clearance_model'],clearance);stats['faces']+=1
            for j in range(1,len(poly)-1):emit([first,first+j,first+j+1])
        if faces:
            ob=A.mesh('Moon fitted ventral scute',points,faces,scute,weights)
            # Clipped triangle islands retain the host's smooth shading frame,
            # rather than appearing as faceted flat triangles over smooth skin.
            ob.data.normals_split_custom_set_from_vertices([A.B(n) for n in surface_normals])
    stats['trimmed_area_fraction']=stats['trimmed_area_model2']/max(1e-12,stats['emitted_area_model2']+stats['trimmed_area_model2'])
    if stats['trimmed_area_fraction']>.01:raise ValueError('Excessive ventral overlap trimming: '+str(stats))
    HEAD['ventral_fit']=stats
    if stats['min_signed_clearance_model']<-.0005:raise ValueError('Ventral scute intersects the host: '+str(stats))
    for s in np.arange(.13,axis[-1]-.15,.125):
        c=np.array([np.interp(s,axis,P[:,j]) for j in range(3)])
        _,k=tree.query(c+[0,.55,0]);root=V[k]
        index=min(len(P)-2,max(1,np.searchsorted(axis,s)))
        tangent=A.SK.norm(P[index+1]-P[index-1])
        height=DESIGN.get('surface',{}).get('dorsal_blade_height',.115)*(1-.72*s/axis[-1])
        blade('Moon seated dorsal blade',root,N[k],tangent,height,.062*(1-.65*s/axis[-1]),dorsal,W[k])

def blade(name,root,normal,tangent,height,width,material,weights):
    normal=A.SK.norm(normal);tangent=A.SK.norm(tangent-normal*np.dot(tangent,normal))
    across=A.SK.norm(np.cross(normal,tangent));points=[];faces=[]
    for i,t in enumerate(np.linspace(0,1,25)):
        c=np.asarray(root)-normal*.013+normal*height*t+tangent*height*.55*t*t
        breadth=width*(1-t)**.95+.0003;thickness=.014*(1-t)**.7+.0002
        for j in range(20):
            theta=math.tau*j/20;points.append(c+tangent*breadth*math.cos(theta)+across*thickness*math.sin(theta))
            if i:
                a=(i-1)*20+j;b=(i-1)*20+(j+1)%20;faces.append([a,b,b+20,a+20])
    faces.extend([list(range(19,-1,-1)),list(range(480,500))])
    return A.mesh(name,points,faces,material,weights if isinstance(weights,str) else [weights]*len(points))


def wing_arm_skin(rig):
    """Clay's bone/muscle/carpal organization, fitted to this wing's lengths."""
    root=np.array(rig['root']);elbow=np.array(rig['elbow']);wrist=np.array(rig['wrist']);scale=rig.get('arm_muscle_scale',DESIGN['wing']['arm_muscle_scale'])
    upper=rig['root_bone'];fore=rig['elbow_bone'];dh=A.SK.norm(elbow-root);df=A.SK.norm(wrist-elbow);parts=[]
    def bone(name,a,b,r,weights,k=.035):
        parts.append(A.SK.Piece({'name':name,'from':list(a),'to':list(b),'r':list(np.array(r)*scale),'rig':weights,'k':k},1,'bone'))
    def muscle(name,a,b,r,weights):
        parts.append(A.SK.Piece({'name':name,'from':list(a),'to':list(b),'radii':list(np.array(r)*scale),'hint':[0,1,0],
            'rig':weights,'k':.045,'profile':[[0,.3,.3],[.25,.90,.90],[.48,1,1],[.78,.7,.65],[1,.22,.22]]},1,'muscle'))
    bone('Wing humerus',root,elbow,[.060,.052],{upper:1})
    bone('Wing radius and ulna',elbow,wrist,[.055,.035],{fore:1})
    bone('Wing olecranon',elbow-dh*.045,elbow+df*.055,[.070,.056],{upper:.45,fore:.55})
    muscle('Wing deltoid',root-dh*.065,root+dh*.20,[.115,.102],{upper:.75,'chest':.25})
    muscle('Wing upper-arm belly',root+dh*.08,elbow-dh*.055,[.115,.105],{upper:1})
    muscle('Wing forearm extensors',elbow+df*.035,elbow+(wrist-elbow)*.73,[.082,.075],{fore:1})
    bone('Wing terminal tendon',elbow+(wrist-elbow)*.42,wrist,[.043,.032],{fore:1})
    avg=A.SK.norm(np.mean([np.array(d['middle'])-wrist for d in rig['digits'] if d.get('attachment','wrist')=='wrist'],axis=0))
    bone('Wing carpal saddle',wrist-df*.055,wrist+avg*.075,[.073,.058],{fore:1})
    for digit in rig['digits']:
        origin=np.array(digit.get('origin',wrist));direction=A.SK.norm(np.array(digit['middle'])-origin)
        bone('Wing metacarpal knuckle',origin,origin+direction*.13,[.045,.030],{digit['first']:.7,fore:.3},.025)
    V,F=A.SK.mesh(None,parts,.009,pad=.025);weights=A.SK.piece_weights(V,parts,.020);normals=A.SK.normals(V,F)
    flank=A.linear(A.PROFILE['scales']);dorsal=A.linear(A.PROFILE['dorsal']);colors=[]
    for n in normals:
        top=np.clip((n[1]-.1)/.8,0,1);colors.append(flank*(1-top)+dorsal*top)
    A.mesh('MoonSkin muscular wing arm',V,F,A.material('Moon wing arm scales',A.PROFILE['scales']),weights,colors=colors)


def character_details():
    """Darkstalker-only features seated on the shared final NightWing surfaces."""
    if A.ID!='darkstalker':return
    bone=A.material('Darkstalker bone earring','bfc3ba',.72)
    # Model +X is the animal's left, matching the .L rig convention.
    ear_root=project(np.array([.24,2.035,1.32]))
    ear_point=ear_root+np.array([.085*.60,.045*math.sin(.60*math.pi)-.012*.60,-.26*.60])
    width=.055*math.sin(.60*math.pi)**.7+.002
    center=ear_point+np.array([.018,-width*.90,0])
    angles=np.linspace(0,math.pi,64)
    path=[center+np.array([0,-.045*math.sin(a),.028*math.cos(a)]) for a in angles]
    A.tube('Darkstalker left bone half hoop',path,.008,bone,'head',sides=12)
    icy=A.material('Darkstalker IceWing heritage','b4c2ce',.59,.12)
    # Fit each pale scute to the actual torso under the wing root and inherit
    # the host weights; a chest-bound decoration must not follow a wing bone.
    hosts=[o for o in A.ARM.children if o.type=='MESH' and o.name.startswith('Connected anatomical skin')]
    host=hosts[0];vertices=np.array([(v.co.x,v.co.z,-v.co.y) for v in host.data.vertices]);tree=cKDTree(vertices)
    for side in [-1,1]:
        for z in np.linspace(.43,-.54,12):
            _,index=tree.query([side*.43,1.30,z]);p=vertices[index]
            normal=A.SK.norm([side,.35,0]);across=A.SK.norm(np.cross([0,0,1],normal));along=np.cross(normal,across)
            pts=[p+normal*.010]
            for a in np.linspace(0,math.tau,12,endpoint=False):pts.append(p+normal*.002+across*.023*math.cos(a)+along*.035*math.sin(a))
            weights=[(host.vertex_groups[g.group].name,g.weight) for g in host.data.vertices[index].groups]
            A.mesh('Darkstalker fitted icy wing root scute',pts,[[0,j+1,(j+1)%12+1] for j in range(12)],icy,[weights]*len(pts))


def wing_colors(points,wrist,rig):
    blue=A.linear('50bce4');violet=A.linear('6655a3');light=A.linear('82d7eb');colors=[]
    reach=max(np.linalg.norm(np.array(d['tip'])-wrist) for d in rig['digits'])
    for p in points:
        t=np.clip(np.linalg.norm(np.asarray(p)-wrist)/reach,0,1.3)
        edge=np.clip((t-.70)/.30,0,1);c=blue*(1-edge)+violet*edge
        shine=.15*math.sin(t*math.pi);colors.append(c*(1-shine)+light*shine)
    return colors

def silkwing_details():
    if A.ID!='blue':return
    mat=A.material('Blue flexible antenna keratin','62507f',.58)
    for side in [-1,1]:
        cfg=DESIGN['antenna'];root=project(np.array(cfg['root'])*[side,1,1])
        path=A.spline([root+np.array(offset)*[side,1,1] for offset in cfg['offsets']],80)
        ob=A.tube('SilkWing brow antenna',path,np.linspace(.010,.0008,len(path)),mat,'head',sides=12)
        ob.vertex_groups.clear();suffix='L' if side>0 else 'R'
        for i,t in enumerate(np.linspace(0,1,len(path))):
            if t<.14:weights=[('head',1.)]
            elif t<.36:
                amount=(t-.14)/.22;amount=amount*amount*(3-2*amount);weights=[('head',1-amount),('antenna1.'+suffix,amount)]
            elif t<.66:
                amount=(t-.36)/.30;amount=amount*amount*(3-2*amount);weights=[('antenna1.'+suffix,1-amount),('antenna2.'+suffix,amount)]
            else:
                amount=(t-.66)/.34;amount=amount*amount*(3-2*amount);weights=[('antenna2.'+suffix,1-amount),('antenna3.'+suffix,amount)]
            for bone,weight in weights:
                if weight>1e-6:
                    group=ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone);group.add(list(range(i*12,i*12+12)),float(weight),'REPLACE')
        c=np.array(A.D['front'][2])*[side,1,1]+[0,-.015,.015]
        points,faces,_=HEAD['clay'].sphere(c,.020,lon=24)
        A.mesh('Blue flamesilk wrist gland',points,faces,A.material('Warm flamesilk gland','d7a85a',.55),'forearm.'+('L' if side>0 else 'R'))
