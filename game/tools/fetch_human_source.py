"""Fetch pinned CC0 MakeHuman anatomy sources. No executable dependencies are fetched."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import urllib.request
ROOT = Path(__file__).resolve().parents[2]
COMMIT = json.loads((ROOT/'game/data/scavenger_design.json').read_text())['source']['commit']
DEST = ROOT/'cache/human-source'
PATHS = ['makehuman/data/3dobjs/base.obj', 'makehuman/data/rigs/default.mhskel',
         'makehuman/data/rigs/default_weights.mhw', 'makehuman/data/eyes/high-poly/high-poly.mhclo',
         'makehuman/data/eyes/high-poly/high-poly.obj', 'LICENSE.md', 'LICENSE.ASSETS.md']
for sex in ['male', 'female']:
    PATHS += [f'makehuman/data/targets/macrodetails/caucasian-{sex}-child.target',
              f'makehuman/data/targets/macrodetails/universal-{sex}-child-averagemuscle-averageweight.target']
for stage in ['baby','child']:
    PATHS += [f'makehuman/data/targets/macrodetails/caucasian-male-{stage}.target']
    for muscle in ['minmuscle','averagemuscle']:
        for weight in ['minweight','averageweight']:
            PATHS += [f'makehuman/data/targets/macrodetails/universal-male-{stage}-{muscle}-{weight}.target']
PATHS += ['makehuman/apps/human.py','makehuman/plugins/0_modeling_a_measurement.py']
for name in ['shoulder-dist','upperarm-length','lowerarm-length']:
    for direction in ['decr','incr']:
        PATHS += [f'makehuman/data/targets/measure/measure-{name}-{direction}.target']
for side in ['l','r']:
    for name in ['hand-scale','upperarm-shoulder-muscle']:
        PATHS += [f'makehuman/data/targets/armslegs/{side}-{name}-decr.target']
PATHS = list(dict.fromkeys(PATHS))
def fetch(path):
    data = urllib.request.urlopen(f'https://raw.githubusercontent.com/makehumancommunity/makehuman/{COMMIT}/{path}', timeout=60).read()
    (DEST/Path(path).name).write_bytes(data)
    return {'path': path, 'sha256': hashlib.sha256(data).hexdigest()}
def main():
    DEST.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        manifest = list(pool.map(fetch, PATHS))
    (DEST/'manifest.json').write_text(json.dumps({'commit': COMMIT, 'files': manifest}, indent=2)+'\n')
    print('Fetched CC0 anatomy sources to', DEST)
if __name__ == '__main__':
    main()
