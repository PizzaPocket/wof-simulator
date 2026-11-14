"""Build only Clay's wings into an isolated review asset; never install it.

Blender --background --python game/tools/build_wing_preview.py
Outputs cache/wing-fold-review/wing.glb, wing_rig.json and wing-parts.blend.
"""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'cache/clay-python'),
               str(ROOT / 'prototypes/clay/body'), str(ROOT / 'game/tools')]
sys.argv = ['wing_preview']
import bpy
import build_body as B
import wing_rig as W
from build_clay_asset import base_colours, compatible_pose_clips, read_wing_animation
from pack_clay_material import pack_material_channels


def main():
    output = ROOT / 'cache/wing-fold-review'
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    B.skin_setup(weld=False)
    bones, _ = B.trunk_bones()
    objects = []
    for side in (1, -1):
        print(f'Building isolated wing {side}', flush=True)
        parts, wing_bones, _ = W.build(B, side)
        objects.extend(parts)
        bones.extend(wing_bones)
    # Keep the unjoined skins available for topology and corrective inspection.
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'wing-parts.blend'))
    for obj in objects:
        base_colours(obj.data)
    B.H.pose_clips = compatible_pose_clips(B.H.pose_clips)
    B.H.assemble(objects, bones, str(output / 'wing.glb'), 'WingReviewRig',
                 clips={'wings_fold': W.fold_clip(B)},
                 extras={'wing_rig': B.B['wing']['canonical_fold']})
    pack_material_channels(output / 'wing.glb')
    (output / 'wing_rig.json').write_text(json.dumps({
        'wing_animation': read_wing_animation(output / 'wing.glb'),
        'motion': W.Rig(B).motion,
    }, indent=2) + '\n')
    print('Isolated wing preview ready; shared Clay asset unchanged', flush=True)


if __name__ == '__main__':
    main()
