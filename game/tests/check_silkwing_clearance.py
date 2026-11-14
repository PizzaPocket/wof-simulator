"""Blender Python: test actual Godot-skinned fore/hind membranes for crossings.

Run silkwing_flight_clearance.gd first. Tests launch and cruise strokes, not just
the neutral spread pose. Root tissue hidden inside the trunk is excluded.
"""
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
data=json.loads((ROOT/'cache/silkwing-flight-clearance.json').read_text())
failures=[]
for index,topology in enumerate(data['topology']):
    if topology['bank']!='fore' or 'axillary' not in topology['name']:continue
    arcs=[]
    for pose in data['poses']:
        edge=pose['surfaces'][index][-23:-7]
        arcs.append(sum(math.dist(a,b) for a,b in zip(edge,edge[1:])))
    ratio=max(arcs)/min(arcs)
    assert ratio<1.01,'Main lobe stretches/bulges through the power stroke: '+str(ratio)
    print('FORE LOBE OUTER ARC maximum/minimum length:',ratio,flush=True)
for pose in data['poses']:
    banks={name:{'vertices':[],'faces':[]} for name in ['fore','hind']}
    for topology,points in zip(data['topology'],pose['surfaces']):
        bank=banks[topology['bank']];offset=len(bank['vertices'])
        bank['vertices'].extend(Vector(p) for p in points)
        indices=topology['indices']
        for i in range(0,len(indices),3):
            face=[offset+k for k in indices[i:i+3]]
            if max(bank['vertices'][k].x for k in face)>.55:bank['faces'].append(face)
    for bank in banks.values():
        bank['tree']=BVHTree.FromPolygons(bank['vertices'],bank['faces'],all_triangles=True)
    crossings=[]
    for source,target in [('fore','hind'),('hind','fore')]:
        bank=banks[source];other=banks[target]['tree'];edges=set()
        for face in bank['faces']:
            for a,b in zip(face,face[1:]+face[:1]):edges.add(tuple(sorted((a,b))))
        for a,b in edges:
            start=bank['vertices'][a];end=bank['vertices'][b];delta=end-start;length=delta.length
            if length<.00003:continue
            direction=delta/length
            point,_,_,distance=other.ray_cast(start+direction*.00001,direction,length-.00002)
            if point is not None and point.x>.55:crossings.append(tuple(point))
    print('FLIGHT CLEARANCE',pose['launch'],pose['phase'],'crossings',len(crossings),flush=True)
    if crossings:failures.append({'phase':pose['phase'],'launch':pose['launch'],'count':len(crossings),'sample':crossings[:4]})
assert not failures,'Fore/hind wing intersections: '+str(failures)
print('SilkWing fore/hind membrane clearance: PASS (16 actual flight poses)')
