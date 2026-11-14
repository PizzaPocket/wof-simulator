"""Check exact nonconvex cheek clipping, expression interpolation and rig weights."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'cache/clay-python'),str(ROOT/'prototypes/clay/body'),str(ROOT/'prototypes/clay/head')]
sys.argv=['check_cheek_clip']
import bpy
import numpy as np
import build_head as H
import build_body as B
bpy.ops.wm.read_factory_settings(use_empty=True)
ys=np.linspace(1.60,1.81,8);zs=np.linspace(1.38,1.53,8)
v=np.array([[.23,y,z] for y in ys for z in zs]);faces=[]
for i in range(7):
 for j in range(7):
  k=i*8+j;faces.append([k,k+1,k+9,k+8])
o=H.add_part('Face',v,faces,{'_PART':[1.]*len(v),'_A':v[:,2],'_B':v[:,1],'_ZONE':[0.]*len(v)},[[('head',.7),('jaw',.3)]]*len(v))
a=o.data.attributes.new('head_join_source','FLOAT_VECTOR','POINT');a.data.foreach_set('vector',v.astype(np.float32).ravel())
o.shape_key_add(name='Basis');key=o.shape_key_add(name='testExpression');target=H.to_blender(v);target[:,0]+=.01;key.data.foreach_set('co',target.astype(np.float32).ravel())
B.trim_head([o])
n=len(o.data.vertices)
source=np.empty(n*3,np.float32);o.data.attributes['head_join_source'].data.foreach_get('vector',source);source=source.reshape(-1,3)
line=np.array(B.B['anatomy']['head_weld']['cheek_line']['zy']);distance=source[:,2]-np.interp(source[:,1],line[:,1],line[:,0])
assert distance.min()>-2e-6
assert np.count_nonzero(abs(distance)<2e-6)>10
abz=np.empty(n*3,np.float32);o.data.attributes['_ABZ'].data.foreach_get('vector',abz);abz=abz.reshape(-1,3)
assert np.max(abs(abz[:,0]-source[:,2]))<1e-6
assert np.max(abs(abz[:,1]-source[:,1]))<1e-6
basis=np.array([p.co[:] for p in o.data.shape_keys.key_blocks['Basis'].data]);expression=np.array([p.co[:] for p in o.data.shape_keys.key_blocks['testExpression'].data])
assert np.max(abs((expression-basis)-[.01,0,0]))<2e-6
for vertex in o.data.vertices:
 weights={o.vertex_groups[g.group].name:g.weight for g in vertex.groups}
 assert abs(weights['head']-.7)<1e-6 and abs(weights['jaw']-.3)<1e-6,weights
print('PASS: exact S-curve cut, continuous boundary, preserved attributes, expression displacement and normalized head/jaw weights; %d vertices' % n)
