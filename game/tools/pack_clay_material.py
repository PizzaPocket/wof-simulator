"""Carry the source material channels through Godot's native glTF importer.

CUSTOM0 = (_PART, _ABZ.xyz), CUSTOM1.xyz = original model-space position.
Godot combines TEXCOORD_2/3 and TEXCOORD_4/5 into these full-float channels.
No positions, indices, normals, skin weights, corrective shapes or clips change.
"""
from pathlib import Path
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'cache/clay-python'))
import numpy as np
VERSION = 1


def pack_material_channels(path):
    path = Path(path)
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    document = json.loads(raw[20:20+size])
    if document.get('extras', {}).get('clay_material_channels') == VERSION:
        return
    binary = bytearray(raw[28+size:])
    original_length = document['buffers'][0]['byteLength']
    binary = binary[:original_length]
    def array(index):
        item = document['accessors'][index]; view = document['bufferViews'][item['bufferView']]
        width = {'SCALAR':1,'VEC3':3,'VEC4':4}[item['type']]
        assert item['componentType'] == 5126 and not view.get('byteStride')
        return np.frombuffer(binary, dtype='<f4', count=item['count']*width,
                offset=view.get('byteOffset',0)+item.get('byteOffset',0)).reshape(-1,width).copy()
    def append(values):
        while len(binary)%4: binary.append(0)
        offset = len(binary)
        binary.extend(np.asarray(values,dtype='<f4').tobytes())
        view = len(document['bufferViews'])
        document['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(values)*8,'target':34962})
        index = len(document['accessors'])
        document['accessors'].append({'bufferView':view,'componentType':5126,'count':len(values),'type':'VEC2'})
        return index
    count = 0
    for mesh in document['meshes']:
        for primitive in mesh['primitives']:
            a = primitive['attributes']
            if '_PART' not in a or '_ABZ' not in a: continue
            part, abz, position = array(a['_PART']), array(a['_ABZ']), array(a['POSITION'])
            zero = np.zeros((len(part),2),np.float32)
            channels = [zero,zero,np.column_stack([part[:,0],abz[:,0]]),abz[:,1:3],position[:,:2],np.column_stack([position[:,2],np.zeros(len(part))])]
            for index,values in enumerate(channels):
                a[f'TEXCOORD_{index}'] = append(values)
            count += len(part)
    if not count: raise ValueError('Clay source channels missing; rebuild the model')
    document['buffers'][0]['byteLength'] = len(binary)
    document.setdefault('extras',{})['clay_material_channels'] = VERSION
    encoded=json.dumps(document,separators=(',',':')).encode()
    encoded += b' '*((-len(encoded))%4)
    binary += b'\0'*((-len(binary))%4)
    result = struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(binary))
    result += struct.pack('<II',len(encoded),0x4e4f534a)+encoded
    result += struct.pack('<II',len(binary),0x004e4942)+binary
    temporary=path.with_suffix('.material-tmp')
    temporary.write_bytes(result)
    temporary.replace(path)
    print(f'Material channels packed: {count} vertices, source geometry/animation unchanged',flush=True)


if __name__ == '__main__':
    pack_material_channels(Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'game/assets/clay.glb')
