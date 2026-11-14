"""Verify the material repack preserves source geometry, rig and animation bytes."""
from pathlib import Path
import json, struct, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
import numpy as np

def read(path):
    data=path.read_bytes();size=struct.unpack_from('<I',data,12)[0]
    document=json.loads(data[20:20+size]);binary=data[28+size:]
    def array(index):
        a=document['accessors'][index];v=document['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        return np.frombuffer(binary,dtype='<f4',count=a['count']*width,
            offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    return document,binary,array

current,binary,array=read(ROOT/'game/assets/clay.glb')
for mesh in current['meshes']:
    for primitive in mesh['primitives']:
        a=primitive['attributes']
        if '_PART' not in a:continue
        part=array(a['_PART']);abz=array(a['_ABZ']);position=array(a['POSITION'])
        assert np.array_equal(array(a['TEXCOORD_2']),np.column_stack([part[:,0],abz[:,0]]))
        assert np.array_equal(array(a['TEXCOORD_3']),abz[:,1:3])
        assert np.array_equal(array(a['TEXCOORD_4']),position[:,:2])
        assert np.array_equal(array(a['TEXCOORD_5'])[:,0],position[:,2])
        assert np.isfinite(abz).all()
baseline=ROOT/'cache/clay-before-materials.glb'
if baseline.exists():
    old,old_binary,_=read(baseline)
    size=old['buffers'][0]['byteLength']
    assert binary[:size] == old_binary[:size], 'Repack changed an existing geometry/animation byte'
    for key in ['nodes','skins','animations']:
        assert current[key]==old[key],key
    print('PASS: all preexisting geometry, normals, weights, morphs and clip bytes unchanged')
print('PASS: exact float material IDs, design coordinates and original positions packed for Godot')
