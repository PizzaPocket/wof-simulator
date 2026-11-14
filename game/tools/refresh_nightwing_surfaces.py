"""Refresh wing and ventral surfaces on an existing full-pass NightWing export.

Uses the same authoring functions as a full build. Preserves the fitted skull,
body and their rig; validates the imported basis before replacing the asset.
Blender --background --python ... -- moon darkstalker
"""
import sys,json,math
from pathlib import Path
import bpy
import numpy as np
from mathutils import Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_tribe_dragons as A
from scipy.interpolate import PchipInterpolator
M=A.MOON
args=sys.argv[sys.argv.index('--')+1:]
allow_wing_rig='--wing-rig' in args
for character in [arg for arg in args if not arg.startswith('--')]:
    assert character in ['moon','blue','darkstalker']
    path=A.OUT/(character+'.glb');meta_path=A.OUT/(character+'_anatomy.json')
    runtime=json.loads(meta_path.read_text());assert 'face_fit' in runtime
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    A.ID=character;A.PROFILE=A.PROFILES[character];A.D=A.DATA['silkwing' if character=='blue' else 'nightwing'];A.MATS={}
    A.BONES={name:(np.array(spec['head']),np.array(spec['tail']),spec['parent']) for name,spec in runtime['bones'].items()}
    A.ARM=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    assert max(abs(A.ARM.matrix_world[i][j]-(1 if i==j else 0)) for i in range(4) for j in range(4))<1e-5,'Unexpected imported rig frame'
    previous_bones={name:(value[0].copy(),value[1].copy()) for name,value in A.BONES.items()}
    M.setup(A);M.register_wings()
    changed=[]
    for name,(head,tail,_) in A.BONES.items():
        assert name in previous_bones,'New bones require a full build: '+name
        if np.linalg.norm(head-previous_bones[name][0])>1e-5 or np.linalg.norm(tail-previous_bones[name][1])>1e-5:changed.append(name)
    assert not changed or (allow_wing_rig and character=='blue' and all(name.startswith('wing_') for name in changed)),'Changed bone geometry requires a full build or the explicit Blue wing-rig refresh: '+str(changed)
    body=next(o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Connected anatomical skin'))
    V=np.array([[v.co.x,v.co.z,-v.co.y] for v in body.data.vertices]);F=np.array([list(p.vertices) for p in body.data.polygons]);assert F.shape[1]==3
    W=[[(body.vertex_groups[g.group].name,g.weight) for g in v.groups] for v in body.data.vertices]
    host=next(o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('MoonSkin Nasal'))
    M.HEAD={'surface':np.array([[v.co.x,v.co.z,-v.co.y] for v in host.data.vertices])}
    if character=='blue':
        attr=host.data.color_attributes.active_color
        colors=M.mesh_color(M.HEAD['surface'],'head')
        if attr.domain=='POINT':
            for item,color in zip(attr.data,colors):item.color=tuple(color)+(1,)
        else:
            for item,loop in zip(attr.data,host.data.loops):item.color=tuple(colors[loop.vertex_index])+(1,)
    prefixes=('NightWingMembrane','SilkWingMembrane','Moon continuous axillary membrane','Moon arm patagium','MoonSkin muscular wing arm','Moon articulated wing finger','Moon wrist claw','Moon underwing silver scales','SilkWing graceful distal arch','SilkWing basal hooked support','SilkWing arm bend hook')
    if character=='darkstalker':prefixes+=('Moon fitted ventral scute','Moon seated dorsal blade','Darkstalker left bone half hoop','Darkstalker fitted icy wing root scute')
    for ob in list(bpy.data.objects):
        if ob.type=='MESH' and ob.name.startswith(prefixes):bpy.data.objects.remove(ob,do_unlink=True)
    if changed:
        for ob in bpy.data.objects:
            if ob.type!='MESH':continue
            for group in ob.vertex_groups:
                if group.name not in changed:continue
                assert not any(any(g.group==group.index and g.weight>1e-6 for g in v.groups) for v in ob.data.vertices),'Retained body mesh uses a changed wing bone: '+ob.name
        bpy.context.view_layer.objects.active=A.ARM;A.ARM.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
        for name in changed:
            h,t,parent=A.BONES[name];bone=A.ARM.data.edit_bones[name];bone.head=A.B(h);bone.tail=A.B(t)
            bone.parent=A.ARM.data.edit_bones[parent] if parent else None
        bpy.ops.object.mode_set(mode='OBJECT');A.ARM.select_set(False)
    print('REFRESH WINGS',character,flush=True);M.wings()
    rows=np.array(A.D['spine']);raw=rows[:,[0,1]];s=np.r_[0,np.cumsum(np.linalg.norm(np.diff(raw,axis=0),axis=1))]
    axis=np.linspace(0,s[-1],round(s[-1]/.018));centers=PchipInterpolator(s,raw,axis=0)(axis);P=np.column_stack([np.zeros(len(axis)),centers[:,1],centers[:,0]])
    if character=='darkstalker':
        print('REFRESH BODY SURFACES',character,flush=True);M.body_details(V,F,W,axis,P,[]);M.character_details()
    else:M.HEAD['ventral_fit']=runtime.get('ventral_fit',{'method':'previous body surface preserved; wing attachment refresh only'})
    for ob in bpy.data.objects:
        if ob.type=='MESH' and ob.data.shape_keys:
            for key in ob.data.shape_keys.key_blocks[1:]:key.value=0
    bpy.ops.object.select_all(action='SELECT')
    temp=path.with_name(character+'.refresh.glb')
    bpy.ops.export_scene.gltf(filepath=str(temp),export_format='GLB',use_selection=True,export_animations=False,export_morph=True,export_skins=True,export_yup=True)
    runtime['bones']={name:{'head':h.tolist(),'tail':t.tolist(),'parent':parent} for name,(h,t,parent) in A.BONES.items()}
    runtime['wing_rest_style']=M.DESIGN['wing']['rest_style']
    runtime['wing_rig']=M.WING_RIG;runtime['ventral_fit']=M.HEAD['ventral_fit'];runtime['character_design']='game/data/'+('blue_model_design.json' if character=='blue' else character+'_design.json');runtime['character_id']=character
    temp.replace(path);meta_path.write_text(json.dumps(runtime,indent=2)+'\n')
    print('REFRESHED',character,M.HEAD['ventral_fit'],flush=True)
