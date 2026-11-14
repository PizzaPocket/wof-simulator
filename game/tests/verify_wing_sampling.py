"""Compare Godot wing bone matrices with independent sampling of the source GLB.
Run wing_pose_dump.gd first. Requires numpy and scipy from the Clay build environment.
"""
from pathlib import Path
import json,struct,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
import numpy as np
from scipy.spatial.transform import Rotation,Slerp
with open(ROOT/'game/assets/clay.glb','rb') as f:
    h=f.read(20);g=json.loads(f.read(struct.unpack_from('<I',h,12)[0]));f.read(8);data=f.read()
def array(i):
    a=g['accessors'][i];v=g['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    return np.frombuffer(data,dtype={5126:'<f4',5123:'<u2'}[a['componentType']],count=a['count']*n,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(a['count'],n)
animation=g['animations'][0]
godot=json.load(open(ROOT/'cache/wing_poses.json'))
parents={child:i for i,node in enumerate(g['nodes']) for child in node.get('children',[])}
max_error=0; worst=''
for time,bones in godot.items():
    time_error=0; time_worst=''
    time=float(time)
    transforms=[{'translation':np.array(n.get('translation',[0,0,0]),float),'rotation':np.array(n.get('rotation',[0,0,0,1]),float),'scale':np.array(n.get('scale',[1,1,1]),float)} for n in g['nodes']]
    for channel in animation['channels']:
        target=channel['target'];sampler=animation['samplers'][channel['sampler']];times=array(sampler['input']).ravel();values=array(sampler['output']);prop=target['path']
        if prop not in transforms[0]:continue
        if prop=='rotation':
            value=Slerp(times,Rotation.from_quat(values))([np.clip(time,times[0],times[-1])]).as_quat()[0]
        else:value=np.array([np.interp(time,times,values[:,k]) for k in range(values.shape[1])])
        transforms[target['node']][prop]=value
    cache={}
    def world(i):
        if i in cache:return cache[i]
        t=transforms[i];m=np.eye(4);m[:3,:3]=Rotation.from_quat(t['rotation']).as_matrix()@np.diag(t['scale']);m[:3,3]=t['translation']
        if i in parents:m=world(parents[i])@m
        cache[i]=m;return m
    for i,node in enumerate(g['nodes']):
        name=node.get('name','')
        if name not in bones:continue
        error=np.abs(world(i)-np.array(bones[name]).reshape(4,4,order='F')).max()
        if error>max_error:max_error=error;worst=f'{name} at {time}'
        if error>time_error:time_error=error;time_worst=name
    print(time,time_error,time_worst)
print('Godot versus GLB/viewer bone sampler: max matrix error',max_error,'worst',worst)
assert max_error<0.0001
