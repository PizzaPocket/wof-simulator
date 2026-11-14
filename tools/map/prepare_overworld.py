"""Build an exportable atlas from stage 1; keep downloaded book art local.

Run fetch_sources.py and extract_landmask.py first. The SVG contains simplified
coastline geometry and annotation labels, never the source illustration.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from skimage.measure import approximate_polygon, find_contours

ROOT = Path(__file__).resolve().parents[2]

def main():
    annotations = json.loads((ROOT / 'data/pyrrhia/map_annotations.json').read_text())
    mask = np.asarray(Image.open(ROOT / 'cache/stage1/landmask.png'))
    height, width = mask.shape
    output = ROOT / 'game/assets/maps'
    output.mkdir(parents=True, exist_ok=True)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             '<rect width="100%" height="100%" fill="#254a51"/>',
             '<g fill="#84956b" stroke="#d1c896" stroke-width="3" stroke-linejoin="round">']
    coastlines = []
    for contour in find_contours(np.pad(mask > 127, 1), .5):
        polygon = approximate_polygon(contour - 1, tolerance=2.5)
        coastlines.append([[round(float(x), 1), round(float(y), 1)] for y, x in polygon])
        points = ' '.join(f'{x:.1f},{y:.1f}' for y, x in polygon)
        parts.append(f'<polygon points="{points}"/>')
    parts.append('</g>')
    # Kingdom names only: annotation positions remain in the same pixel space.
    names = {'Ice Kingdom', 'Sky Kingdom', 'Kingdom of Sand', 'Mud Kingdom',
             'Rainforest Kingdom', 'Kingdom of the Sea', 'Jade Mountain'}
    # SVG text isn't supported by Godot's SVG importer. Export label positions
    # separately so the runtime draws real resolution-independent text.
    labels = []
    for label in annotations['labels']:
        if label['name'] not in names:
            continue
        x0, y0, x1, y1 = label['boxes'][0]
        labels.append({'name': label['name'], 'position': [(x0+x1)/2, (y0+y1)/2]})
    parts.append('</svg>')
    (output / 'pyrrhia_coast.svg').write_text('\n'.join(parts) + '\n')
    (ROOT / 'game/data/pyrrhia_coast.json').write_text(json.dumps(
        {'map_size': [width, height], 'coastlines': coastlines}, separators=(',', ':')) + '\n')
    (ROOT / 'game/data/overworld_labels.json').write_text(json.dumps(labels, indent=2) + '\n')
    source = Image.open(ROOT / 'cache/maps' / annotations['source'])
    margin = int(source.width * annotations['crop_fraction'])
    cropped = source.crop((margin, margin, source.width-margin, source.height-margin))
    if cropped.size != (width, height):
        raise ValueError('Source map and extracted coastline sizes differ')
    cropped.save(output / 'pyrrhia_reference.png')
    print(f'Prepared {width} × {height} atlas, {len(labels)} labels; source illustration stays ignored.')

if __name__ == '__main__':
    main()
