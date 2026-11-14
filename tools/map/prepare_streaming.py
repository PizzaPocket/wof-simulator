"""Split baked macro terrain into independent pages and a tiny resident overview.

Pages hold shared endpoint samples (129² float heights + RGB bytes); at runtime
only a bounded page cache is read. Fine terrain meshes are built asynchronously
from these pages, with deterministic local relief and analytic water channels.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

ROOT = Path(__file__).resolve().parents[2]
PAGE_CELLS = 128

def prepare(id):
    folder=ROOT/'game/data/terrain'
    p=folder/(id+'.json'); d=json.loads(p.read_text())
    nx,nz=d['grid']
    height=np.fromfile(ROOT/'game'/d['height_file'].removeprefix('res://'),dtype='<f4').reshape(nz,nx)
    color=np.asarray(Image.open(ROOT/'game'/d['color_file'].removeprefix('res://')).convert('RGB'))
    target=folder/(id+'_pages');target.mkdir(exist_ok=True)
    for z in range((nz-2)//PAGE_CELLS+1):
        for x in range((nx-2)//PAGE_CELLS+1):
            # Fixed-size padded pages simplify deterministic reads at map edges.
            xs=np.minimum(np.arange(x*PAGE_CELLS,x*PAGE_CELLS+PAGE_CELLS+1),nx-1)
            zs=np.minimum(np.arange(z*PAGE_CELLS,z*PAGE_CELLS+PAGE_CELLS+1),nz-1)
            h=height[np.ix_(zs,xs)].astype('<f4').tobytes()
            c=color[np.ix_(zs,xs)].astype('uint8').tobytes()
            (target/f'{x}_{z}.page').write_bytes(h+c)
    ox=257;oz=round(256*(nz-1)/(nx-1))+1
    xx,zz=np.meshgrid(np.linspace(0,nx-1,ox),np.linspace(0,nz-1,oz))
    small=map_coordinates(height,[zz,xx],order=1).astype('<f4')
    rgb=np.stack([map_coordinates(color[:,:,i],[zz,xx],order=1) for i in range(3)],axis=-1).astype('uint8')
    (folder/(id+'_overview.height')).write_bytes(small.tobytes())
    (folder/(id+'_overview.rgb')).write_bytes(rgb.tobytes())
    d['streaming']=dict(version=1,page_cells=PAGE_CELLS,page_dir=f'res://data/terrain/{id}_pages',page_cache_limit=4,
        overview_grid=[ox,oz],overview_height=f'res://data/terrain/{id}_overview.height',overview_color=f'res://data/terrain/{id}_overview.rgb',
        tile_size_m=2048,near_subdivisions=64,medium_subdivisions=16,near_radius=1,medium_radius=3,lookahead_seconds=8.0,max_jobs=2,max_resident_tiles=96,
        terrain_budget_bytes=64*1024*1024,commit_budget_usec=3000,local_relief_m=1.4)
    p.write_text(json.dumps(d,indent=2)+'\n')
    print(f'{id}: {len(list(target.glob("*.page")))} disk pages, overview {ox}x{oz}, {sum(f.stat().st_size for f in target.glob("*.page"))/1048576:.1f} MiB on disk')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('id',nargs='?',default='pyrrhia');args=parser.parse_args();prepare(args.id)
