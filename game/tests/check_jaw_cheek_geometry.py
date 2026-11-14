"""Verify actual cheek corrective attachments and tangents in the built head."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'cache/clay-python'),str(ROOT/'prototypes/clay/head')]
sys.argv=['check_jaw_cheeks']
import bpy
import numpy as np
from scipy.spatial.transform import Rotation
import build_head as H
metadata=json.loads((ROOT/'cache/head-untrimmed.json').read_text())
hinge=np.array(next(a for name,a,_,_ in metadata['bones'] if name=='jaw'))
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'cache/head-untrimmed.blend'))
def model(data):
 q=np.array([v.co for v in data]);return np.column_stack([q[:,0],q[:,2],-q[:,1]])
maximum_error=0.;minimum_tangent=1.
for obj in bpy.data.objects:
 if not obj.name.startswith('CheekWeb'):continue
 rest=model(obj.data.vertices);nu,nv=22,12;rows=(nu+1)*(nv+1)
 for sample,angle in enumerate(H.D['mouth']['opening_arc']['cheek_sample_angles'],1):
  corrected=model(obj.data.shape_keys.key_blocks['cheekOpen'+str(sample)].data)
  rotations=[Rotation.from_rotvec([angle*i/3,0,0]).as_matrix() for i in range(4)]
  posed=[]
  for v,attr in zip(corrected,obj.data.attributes['_ABZ'].data):
   weights=H.oral_weights(float(attr.vector.y));blend=sum(rotations[int(n[-1]) if n.startswith('oral') else (3 if n=='jaw' else 0)]*w for n,w in weights)
   posed.append(hinge+blend@(v-hinge))
  posed=np.array(posed)
  for layer in (0,1):
   for i in range(nu+1):
    base=layer*rows+i*(nv+1)
    maximum_error=max(maximum_error,np.linalg.norm(posed[base]-rest[base]),np.linalg.norm(posed[base+nv]-(hinge+rotations[3]@(rest[base+nv]-hinge))))
   b=layer*rows+nu*(nv+1);prev=b-(nv+1)
   upper=H.norm(rest[b]-rest[prev]);lower=rotations[3]@H.norm(rest[b+nv]-rest[prev+nv])
   d0=H.norm(-3*posed[b]+4*posed[b+1]-posed[b+2]);d1=H.norm(3*posed[b+nv]-4*posed[b+nv-1]+posed[b+nv-2])
   minimum_tangent=min(minimum_tangent,float(d0@(-upper)),float(d1@lower))
assert maximum_error<2e-6,maximum_error
assert minimum_tangent>.98,minimum_tangent
print('PASS: cheek attachments error',maximum_error,'minimum jaw-tangent alignment',minimum_tangent,flush=True)
