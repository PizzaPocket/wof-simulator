"""Build only the sculpted head for quick lip/ear contour review in Godot."""
from pathlib import Path
import sys
import json
import hashlib
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'cache/clay-python'),str(ROOT/'prototypes/clay/body'),str(ROOT/'prototypes/clay/head'),str(ROOT/'game/tools')]
reuse='--reuse' in sys.argv
sys.argv=['head_preview']
import bpy
import build_head as H
import build_body as B
from build_clay_asset import base_colours
from pack_clay_material import pack_material_channels
cache=ROOT/'cache/head-untrimmed.blend'
metadata=ROOT/'cache/head-untrimmed.json'
fingerprint=hashlib.sha256((ROOT/'prototypes/clay/head/build_head.py').read_bytes()+(ROOT/'prototypes/clay/head/head_design.json').read_bytes()).hexdigest()
if reuse and cache.exists() and json.loads(metadata.read_text())['fingerprint']==fingerprint:
    bpy.ops.wm.open_mainfile(filepath=str(cache))
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bones=json.loads(metadata.read_text())['bones']
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs,bones=H.head_parts()
    bpy.ops.wm.save_as_mainfile(filepath=str(cache))
    metadata.write_text(json.dumps({'bones':bones,'fingerprint':fingerprint}))
B.head_weld()
B.trim_head(objs)
for ob in objs:base_colours(ob.data)
output=ROOT/'cache/head-lip-preview.glb'
H.assemble(objs,bones,str(output),name='ClayHeadPreview')
pack_material_channels(output)
