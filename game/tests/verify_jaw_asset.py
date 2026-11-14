"""Check the exported jaw silhouette against the pre-sculpt local review asset."""
from pathlib import Path
import json, struct, sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
import numpy as np

def load(path):
    data=path.read_bytes()
    size=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+size])
    binary=data[28+size:]
    def array(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
        return np.frombuffer(binary,dtype='<f4',count=a['count']*width,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    attributes=doc['meshes'][0]['primitives'][0]['attributes']
    return array(attributes['POSITION']), array(attributes['_PART']).ravel(), attributes

points,part,attributes=load(ROOT/'game/assets/clay.glb')
assert np.isfinite(points).all()
assert 'HEAD_JOIN_SOURCE' not in ''.join(attributes).upper()
jaw=points[abs(part-2)<.01]
assert len(jaw)>5000
baseline=ROOT/'cache/clay-before-gallop-tail.glb'
if baseline.exists():
    old,oldpart,_=load(baseline)
    oldjaw=old[abs(oldpart-2)<.01]
    drop=float(oldjaw[:,1].min()-jaw[:,1].min())
    assert drop < .004, ('Jaw underside extruded downward',drop)
    nose=points[(abs(part-13)<.01)&(points[:,2]>1.6)]
    oldnose=old[(abs(oldpart-13)<.01)&(old[:,2]>1.6)]
    assert abs(float(nose[:,2].max()-oldnose[:,2].max()))<.005
    print('PASS: exported jaw adds no downward chin extrusion (delta %.6f model); accepted front snout length retained; temporary weld attribute removed' % drop)
else:
    print('PASS: finite exported jaw and temporary weld attribute removed; no local comparison asset')
