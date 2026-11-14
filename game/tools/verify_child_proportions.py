"""Check the exported skin, not only authoring controls, against child references.

Uses numpy/scipy from the same local tool environment as the asset builder.
"""
from pathlib import Path
import sys,json,struct
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
import numpy as np
from scipy.spatial import cKDTree
from child_anatomy import section

def read_glb(path):
    data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length]);blob=data[28+length:]
    def array(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        dt=np.dtype(dtype);offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        return np.ndarray((a['count'],count),dtype=dt,buffer=blob,offset=offset,strides=(v.get('byteStride',count*dt.itemsize),dt.itemsize)).copy()
    primitive=next(m for m in doc['meshes'] if m['name'].startswith('Continuous anatomical skin'))['primitives'][0]
    return array(primitive['attributes']['POSITION']),array(primitive['indices']).reshape(-1,3)

def verify(name,settings):
    folder=ROOT/'game/assets/scavengers'
    report=json.loads((folder/(name+'_proportions.json')).read_text())
    points,tris=read_glb(folder/(name+'.glb'))
    tree=cKDTree(points)
    landmarks={k:points[tree.query(v)[1]] for k,v in report['surface_landmarks'].items()}
    profile=json.loads((ROOT/'game/data/child_proportions.json').read_text())['profiles'][settings['proportion_profile']]
    factor=settings['height_m']/profile['reference_height_m']
    measured={'biacromial_breadth_m':float(2*abs(landmarks['acromion'][0])),
      'upper_arm_external_length_m':float(np.linalg.norm(landmarks['acromion']-landmarks['olecranon'])),
      'forearm_external_length_m':float(np.linalg.norm(landmarks['elbow']-landmarks['wrist']))}
    for key,value in measured.items():
        expected=report['length_fit'][key]['target']
        assert abs(value/expected-1)<.035,(name,key,value,expected)
    # Exported-surface cuts also catch subdivision, unit, axis and export errors.
    cuts=report['section_planes']
    for key,plane in cuts.items():
        shape=section(points,tris,plane['center'],plane['normal'],plane['limit'])
        value=shape[plane['measure']];expected=profile['target'][key]*factor
        assert shape['closed'],(name,key,'open skin section')
        assert abs(value/expected-1)<.04,(name,key,value,expected)
        measured[key]=value
    print(name+': exported skin PASS; '+', '.join(k.replace('_m','')+'='+str(round(v*100,1))+'cm' for k,v in measured.items()))
    return measured
if __name__=='__main__':
    settings=json.loads((ROOT/'game/data/scavenger_design.json').read_text())
    result={name:verify(name,value) for name,value in settings['characters'].items()}
    (ROOT/'cache/child-proportions').mkdir(exist_ok=True,parents=True)
    (ROOT/'cache/child-proportions/exported_measurements.json').write_text(json.dumps(result,indent=2)+'\n')
