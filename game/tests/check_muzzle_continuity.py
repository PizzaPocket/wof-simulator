"""Verify the rounded muzzle cap shares its boundary with the side surface."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'cache/clay-python'),str(ROOT/'prototypes/clay/head')]
sys.argv=['check_muzzle_continuity']
import build_head as H
import numpy as np
from collections import Counter
zs=np.linspace(H.UPPER[0,0],1.86,20)
v,f,uv=H.loft(H.upper_contour,zs,front_dent=H.front_setback,n_inner=24,front_round=.010)
edges=Counter(tuple(sorted((a,b))) for p in f for a,b in zip(p,p[1:]+p[:1]))
assert set(edges.values())=={2},Counter(edges.values())
v=np.array(v)
# Rounding must preserve the dorsal attachment to the shield.
top=int(np.argmax(v[:H.N_AROUND+1,1]))
assert abs(v[top,2]-zs[0])<1e-9
assert v[0,2]<zs[0]-.009
assert np.isfinite(v).all()
assert min(np.linalg.norm(np.cross(v[p[1]]-v[p[0]],v[p[-1]]-v[p[0]])) for p in f)>1e-12
profile=dict(H.D['lip_line']['frame_profile_uh'])
assert .018 <= -profile[.125] <= .025
z=np.linspace(1.90,2.017,240)
edge=np.array([[*H.face_pt(q,0),q] for q in z])
edge[:,2]=H.snout_z(H.premaxilla_z(edge[:,2],edge[:,1]))
edge=H.compact_head_points(edge)
assert np.diff(edge[:,0]-edge[:,2]).max()<0, 'Front corner lip doubles back into a tab'
print('PASS: continuous closed muzzle, fixed shield attachment, rounded dip and no front-corner tab')
