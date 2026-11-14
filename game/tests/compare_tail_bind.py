"""Independent CPU-skinning comparison of curled and extended binds.
Uses the previous local backup when available; always checks the current bind.
Requires numpy/scipy from the Clay build environment.
"""
from pathlib import Path
import json,struct,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
import numpy as np
from scipy.spatial.transform import Rotation

def study(path,meta_path):
    with path.open('rb') as f:
        h=f.read(20);g=json.loads(f.read(struct.unpack_from('<I',h,12)[0]));f.read(8);data=f.read()
    def read(i):
        a=g['accessors'][i];v=g['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        return np.frombuffer(data,dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']],count=a['count']*width,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    parents={c:i for i,n in enumerate(g['nodes'])for c in n.get('children',[])}
    cache={}
    def world(i):
        if i in cache:return cache[i]
        n=g['nodes'][i];m=np.eye(4)
        if 'matrix'in n:m=np.array(n['matrix']).reshape(4,4,order='F')
        else:
            m[:3,:3]=Rotation.from_quat(n.get('rotation',[0,0,0,1])).as_matrix()@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0])
        if i in parents:m=world(parents[i])@m
        cache[i]=m;return m
    def frame(d):
        d=d/np.linalg.norm(d);x=np.cross(d,[0,1,0]);x/=np.linalg.norm(x)
        return np.column_stack([x,d,np.cross(x,d)])
    meta=json.load(open(meta_path));segments=meta['tail_bones'];target={};cursor=np.array(segments[0]['head'],float)
    nodes={n.get('name'):i for i,n in enumerate(g['nodes'])}
    for segment in segments:
        i=nodes[segment['name']];rest=world(i);rotate=frame(np.array([0.,0,-1.]))@frame(rest[:3,1]).T
        m=np.eye(4);m[:3,:3]=rotate@rest[:3,:3];m[:3,3]=cursor;target[i]=m
        cursor=cursor+np.array([0,0,-segment['length']])
    skin=g['skins'][0];ib=read(skin['inverseBindMatrices']);matrices=[]
    for j,i in enumerate(skin['joints']):matrices.append(target.get(i,world(i))@ib[j].reshape(4,4,order='F'))
    matrices=np.array(matrices)
    primitive=g['meshes'][0]['primitives'][0]['attributes']
    part=read(primitive['_PART']).ravel();abz=read(primitive['_ABZ']);joints=read(primitive['JOINTS_0']).astype(int);weights=read(primitive['WEIGHTS_0'])
    tail=np.array([g['nodes'][i].get('name','').startswith('tail') for i in skin['joints']])
    selection=(part>19.5)&(part<20.5)&(abz[:,0]>2.85)&(abz[:,0]<5.3)&((tail[joints]*weights).sum(axis=1)>.9)
    vertices=read(primitive['POSITION'])[selection];joints=joints[selection];weights=weights[selection];s=abz[selection,0]
    points=np.column_stack([vertices,np.ones(len(vertices))]);posed=np.zeros((len(points),4))
    for k in range(4):posed+=np.einsum('nij,nj->ni',matrices[joints[:,k]],points)*weights[:,k,None]
    deviations=[]
    for a in np.arange(2.9,5.25,.05):
        use=(s>=a)&(s<a+.05)
        if use.sum()<20:continue
        q=np.quantile(posed[use,:2],[.05,.95],axis=0).mean(axis=0)
        deviations.append(np.linalg.norm(q-np.array(segments[0]['head'])[:2]))
    return {'skin_vertices':len(vertices),'section_center_rms_m':float(np.sqrt(np.mean(np.square(deviations))))*2,'section_center_peak_m':float(max(deviations))*2}

old=study(ROOT/'cache/clay-before-tail-fix.glb',ROOT/'cache/clay-before-tail-fix.json') if (ROOT/'cache/clay-before-tail-fix.glb').exists() else None
new=study(ROOT/'game/assets/clay.glb',ROOT/'game/assets/clay_rig.json')
print(json.dumps({'old_curled_12_bone_bind':old,'extended_36_bone_bind':new},indent=2))
(ROOT/'cache/tail-bind-comparison.json').write_text(json.dumps({'old':old,'new':new},indent=2))

assert new["section_center_rms_m"] < 0.01 and new["section_center_peak_m"] < 0.02
print("PASS: straightened tail cross-section centers stay within the smooth-bind tolerance")
