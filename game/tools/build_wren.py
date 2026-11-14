"""Build Wren from CC0 MakeHuman teen anatomy, with the book-cover travel outfit.

Blender --background --python-exit-code 1 --python game/tools/build_wren.py -- wren
Uses the pinned female child/young macro targets; does not alter the three children.
"""
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'game/tools'))
import build_scavengers as S
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

profile = S.json.loads((ROOT/'game/data/protagonists.json').read_text())['wren']
S.DESIGN['characters']['wren'] = profile
S.NAME = 'wren'
S.HEIGHT = profile['height_m']
S.MATERIALS = {}
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
S.ORIGINAL_RAW = S.BASE.copy()
# MakeHuman's age slider is linear between the 10-year and 25-year macro targets.
for stage, amount in [('child', 2/3), ('young', 1/3)]:
    S.ORIGINAL_RAW += amount * S.Anatomy.target(S.SRC/f'caucasian-female-{stage}.target', len(S.BASE))
S.CURRENT, S.BOTTOM, S.SCALE = S.Anatomy.normalize(S.ORIGINAL_RAW, S.BODY_IDS, S.HEIGHT)
S.RAW = S.CURRENT / S.SCALE
S.RAW[:, 1] += S.BOTTOM
S.ACCEPTED_BOTTOM, S.ACCEPTED_SCALE = S.BOTTOM, S.SCALE
S.CURRENT_W = [[] for _ in range(len(S.CURRENT))]
for bone, weights in S.WEIGHTS.items():
    for i, weight in weights:
        S.CURRENT_W[int(i)].append((bone, weight))
for i, weights in enumerate(S.CURRENT_W):
    weights = sorted(weights, key=lambda x: -x[1])[:4]
    total = sum(w for _, w in weights)
    S.CURRENT_W[i] = [(bone,w/total) for bone,w in weights] if total else []
S.BODY_TREE = S.cKDTree(S.CURRENT[S.BODY_IDS])
S.build_armature()
skin, ids, *_ = S.source_subset('Continuous anatomical skin',
    [fi for fi in S.GROUPS['body'] if S.CURRENT[S.FACES[fi],1].mean() > .080*S.HEIGHT/1.35],
    S.material('Skin', profile['skin'], .66))
S.subdiv(skin, 1)
S.build_eyes()
S.build_blink(skin, ids)
settings = dict(profile, hair_asset='punkduck_alpha7_curly2', sex_target='female')
S.build_outfit(settings)
for material in bpy.data.materials:
    if 'trouser' in material.name.lower():
        material.diffuse_color = S.rgb(profile['pants'])
        material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = S.rgb(profile['pants'])
    if 'shoes' in material.name.lower():
        material.diffuse_color = S.rgb(profile['boots'])
        material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = S.rgb(profile['boots'])
S.build_hair(settings)
S.Garments.omit_covered_skin(skin,S.HEIGHT,S.joint('joint-neck')[1],S.joint('joint-pelvis')[1]+.012*S.HEIGHT/1.35,
    S.joint('joint-l-shoulder'),S.joint('joint-l-elbow'),S.DESIGN['clothing']['covered_skin'])

# Extend the tunic hem into a loose overlapping travel shirt, rather than a tee.
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH' or not obj.name.startswith('Loose woven shirt'):
        continue
    for v in obj.data.vertices:
        p = np.array(S.Garments.yup(v.co))
        weight = float(np.clip((.95 - p[1])/.09, 0, 1))
        p[1] -= weight*.08
        p[0] *= 1+weight*.25
        p[2] *= 1+weight*.40
        v.co = S.B(p)

leather = S.material('Leather sword baldric', '754333', .84)
steel = S.material('Sword pommel and guard', '9a9e9c', .34, .7)
thread = S.material('Sewn tunic seam', 'b8a77a', .9)
chest = S.joint('joint-neck')[1] - .12
waist = S.joint('joint-pelvis')[1]
# A closed shoulder-to-hip baldric, fitted over the torso instead of floating.
tree = BVHTree.FromPolygons([Vector(S.Garments.yup(v.co)) for v in skin.data.vertices],
    [list(f.vertices) for f in skin.data.polygons])
path = []
for front in [True, False]:
    controls = [[-.13,chest+.10,0],[0,chest-.10,0],[.16,waist+.04,0]]
    if not front: controls = list(reversed(controls))
    for a,b in zip(controls,controls[1:]):
        for t in np.linspace(0,1,20,endpoint=False):
            p=np.array(a)*(1-t)+np.array(b)*t
            hit=tree.ray_cast(Vector((p[0],p[1],.65 if front else -.65)),Vector((0,0,-1 if front else 1)),1.3)[0]
            p[2]=(hit.z if hit else 0)+(.026 if front else -.026)
            path.append(p)
path.append(path[0])
S.ribbon('Fitted sword baldric',path,.029,.003,leather,rigid='spine02')
# Back-carried sword: shaped scabbard, small curved crossguard and wrapped grip.
lower=np.array([.13,waist-.16,-.13]);upper=np.array([-.13,chest+.08,-.13])
S.tube('Leather sword scabbard',[lower,lower*.2+upper*.8,upper],
    [.010,.021,.022],leather,rigid='spine02',sides=8,flatten=.45)
axis=(upper-lower);axis/=np.linalg.norm(axis)
guard=upper+axis*.015
S.tube('Sword crossguard',[guard+[-.085,.012,0],guard,guard+[.085,.012,0]],
    [.006,.010,.006],steel,rigid='spine02',sides=8)
S.tube('Wrapped sword grip',[guard+axis*.015,guard+axis*.135],.013,leather,rigid='spine02',sides=10)
for t in np.linspace(.022,.125,9):
    center=guard+axis*t
    S.tube('Grip wrap ridge',[center+np.array([.014*np.cos(a),0,.014*np.sin(a)]) for a in np.linspace(0,S.TAU,20)],
        .0018,thread,rigid='spine02',sides=4)
pommel=guard+axis*.15
S.tube('Oval sword pommel',[pommel-axis*.009,pommel,pommel+axis*.009],
    [.009,.023,.009],steel,rigid='spine02',sides=14,flatten=.7)

# Freckles are shallow surface pigmentation, positioned on the actual face/arms.
freckle = S.material('Freckles', '76452f', .9)
rng = S.random.Random(1705)
for i in range(130):
    face = i < 65
    x = rng.uniform(-.075,.075) if face else rng.choice([-1,1])*rng.uniform(.20,.34)
    y = rng.uniform(1.412,1.433) if face else rng.uniform(.87,1.12)
    hit,normal,_,_=tree.ray_cast(Vector((x,y,.5)),Vector((0,0,-1)),1.0)
    if hit is None: continue
    r = rng.uniform(.0007,.0014)
    across=normal.cross(Vector((0,1,0))).normalized()
    other=normal.cross(across).normalized()
    center=np.array(hit+normal*.00025)
    points=[center]+[center+r*np.array(across*np.cos(a)+other*np.sin(a)) for a in np.linspace(0,S.TAU,7,endpoint=False)]
    S.mesh('Freckle',points,[[0,j+1,(j+1)%7+1] for j in range(7)],freckle,
        rigid='head' if face else ('upperarm01.L' if x>0 else 'upperarm01.R'))

S.join_by_material()
bpy.ops.object.select_all(action='SELECT')
S.OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(S.OUT/'wren.glb'),export_format='GLB',use_selection=True,
    export_animations=False,export_morph=True,export_skins=True,export_yup=True)
S.write_asset_credit(S.OUT/'wren.glb','wren',settings)
(S.OUT/'wren_metrics.json').write_text(S.json.dumps({'height_m':S.HEIGHT,'age':15,
    'bones':len(S.ARM.data.bones),'source':'CC0 MakeHuman, female child/young age interpolation'},indent=2)+'\n')
print('BUILT Wren: teen anatomy, curls, freckles, travel outfit and back-carried sword',flush=True)
