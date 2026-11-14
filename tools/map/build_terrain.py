"""Bake original bare terrain from versioned geographic rules, never book artwork.

PYTHONPATH=cache/map-python python3 tools/map/build_terrain.py
All small-scale relief/elevation and inter-map sizes are authored interpretations.
The source drawings do not provide a common measured scale or surveyed heights.
"""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image, ImageDraw, PngImagePlugin
from scipy.ndimage import distance_transform_edt, gaussian_filter, zoom

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'data/terrain/world_regions.json'
OUT = ROOT / 'game/data/terrain'
ASSETS = ROOT / 'game/assets/terrain'


def polygon_mask(points, size, map_size):
    image = Image.new('L', size)
    ImageDraw.Draw(image).polygon([(x / map_size[0] * (size[0]-1), y / map_size[1] * (size[1]-1)) for x, y in points], fill=255)
    return np.asarray(image, dtype=np.float32) / 255


def smooth(a, b, v):
    t = np.clip((v-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def path_distance(x, z, points, values=None):
    distance = np.full_like(x, 1e9)
    profile = np.zeros_like(x)
    for i, (a, b) in enumerate(zip(points, points[1:])):
        dx, dz = b[0]-a[0], b[1]-a[1]
        t = np.clip(((x-a[0])*dx+(z-a[1])*dz)/max(dx*dx+dz*dz, 1e-6), 0, 1)
        d = np.hypot(x-a[0]-t*dx, z-a[1]-t*dz)
        closest = d < distance
        if values is not None:
            profile = np.where(closest, values[i]*(1-t)+values[i+1]*t, profile)
        distance = np.minimum(distance, d)
    return distance, profile


def bake(definition, resolution):
    d = dict(definition)
    mw, mh = d['map_size']
    width_m = d['width_m']
    extent = [width_m, width_m * mh / mw]
    nx = resolution + 1
    nz = round(resolution * mh / mw) + 1
    # Endpoint-aligned samples make the pixel → metre transform exact.
    x, z = np.meshgrid(np.linspace(0, mw, nx, dtype=np.float32), np.linspace(0, mh, nz, dtype=np.float32))
    land = np.zeros((nz, nx), dtype=np.float32)
    for coast in d['coastlines']:
        land = np.maximum(land, polygon_mask(coast, (nx,nz), (mw,mh)))
    spacing = width_m / resolution
    inland = distance_transform_edt(land > .5, sampling=(extent[1]/(nz-1),spacing))
    offshore = distance_transform_edt(land < .5, sampling=(extent[1]/(nz-1),spacing))
    # Smooth continent-scale landforms + small hills. Deterministic, no random state.
    xm, zm = x * width_m / mw, z * width_m / mw
    rng = np.random.default_rng(1947)
    def noise(cells):
        small = rng.random((max(3,round(cells*mh/mw)),cells)).astype(np.float32)
        return np.clip(zoom(small, (nz/small.shape[0],nx/small.shape[1]),order=3),0,1)
    broad = noise(18)*.65+noise(43)*.35
    fine = noise(110)
    rugged = noise(95)
    base = 22 + 65*broad + 13*fine
    color = np.zeros((nz,nx,3),dtype=np.float32)
    color[:] = np.array(d.get('base_color',[.49,.62,.32]))
    biome_id = np.zeros((nz,nx),dtype=np.uint8)
    for index, region in enumerate(d.get('regions',[]),1):
        blend = gaussian_filter(polygon_mask(region['polygon'],(nx,nz),(mw,mh)), 4.0)
        relief = region.get('relief_m',60)
        target = region.get('base_m',20)+relief*(.2+.8*broad)+fine*region.get('hills_m',10)
        if region.get('dunes'):
            target += 8*(np.sin(xm/65 + np.sin(zm/210)*1.7)+1)*.5
        base = base*(1-blend)+target*blend
        color = color*(1-blend[:,:,None])+np.array(region['color'])*blend[:,:,None]
        biome_id[blend>.5]=index
    # Mountains follow authored ridges. Branches share endpoints, so ranges join.
    mountain = np.zeros_like(base)
    for ridge in d.get('ridges',[]):
        dist, _ = path_distance(x,z,ridge['points'])
        dist_m = dist * width_m / mw
        shoulder = np.exp(-(dist_m/ridge['width_m'])**2)
        ridgeline = .54+.46*rugged
        mountain = np.maximum(mountain, ridge['height_m']*shoulder*ridgeline)
    base += mountain
    for peak in d.get('peaks',[]):
        radius = np.hypot((x-peak['center'][0])*width_m/mw,(z-peak['center'][1])*width_m/mw)
        base += peak['height_m'] * np.clip(1-radius/peak['radius_m'],0,1)**1.35
    for volcano in d.get('volcanoes',[]):
        radius = np.hypot((x-volcano['center'][0])*width_m/mw,(z-volcano['center'][1])*width_m/mw)
        cone = volcano['height_m']*np.clip(1-radius/volcano['radius_m'],0,1)**1.2
        crater = volcano['crater_m']
        cone -= volcano['height_m']*.43*(1-smooth(crater*.55,crater,radius))
        base += cone
    # Beach slopes reach zero at the traced shoreline; the shelf descends offshore.
    elevation = np.where(land>.5, base*smooth(0,140,inland), -np.minimum(300,offshore*.22+2))
    if d['id'] != 'nightwing_island':
        rock = smooth(280,700,mountain)*.82
        color = color*(1-rock[:,:,None])+np.array([.46,.48,.43])*rock[:,:,None]
        snow = smooth(1550,2100,elevation)
        color = color*(1-snow[:,:,None])+np.array([.95,.97,.98])*snow[:,:,None]
    for lake in d.get('lakes',[]):
        radius = np.hypot((x-lake['center'][0])/lake['radius'][0],(z-lake['center'][1])/lake['radius'][1])
        weight=1-smooth(.85,1.18,radius)
        bed=lake['level']-lake.get('depth_m',12)
        bank = 1-smooth(1.0,1.5,radius)
        elevation = np.maximum(elevation,elevation*(1-bank)+(lake['level']+3)*bank)
        elevation = elevation*(1-weight)+bed*weight
    for river in d.get('rivers',[]):
        dist, level = path_distance(x,z,river['points'],river['levels'])
        dist *= width_m/mw
        width = river['width_m']
        weight = 1-smooth(width*.35,width*1.35,dist)
        bed = level-river.get('depth_m',5)
        bank = 1-smooth(width*1.1,width*3.5,dist)
        elevation = np.maximum(elevation,elevation*(1-bank)+(level+4)*bank)
        elevation = elevation*(1-weight)+bed*weight
    beach = (1-smooth(20,95,inland))*(land>.5)
    sand = d.get('beach_color',[.81,.74,.50])
    color = color*(1-beach[:,:,None])+np.array(sand)*beach[:,:,None]
    color = np.where((land>.5)[:,:,None],color,np.array([.30,.41,.40]))
    # Guard the source/config contract before writing exportable files.
    assert np.isfinite(elevation).all() and np.isfinite(color).all()
    OUT.mkdir(parents=True,exist_ok=True); ASSETS.mkdir(parents=True,exist_ok=True)
    id = d['id']
    height_path=OUT/(id+'.height')
    elevation.astype('<f4').tofile(height_path)
    metadata=PngImagePlugin.PngInfo()
    metadata.add_text('Origin','Original procedural biome ground colors; tools/map/build_terrain.py and data/terrain/world_regions.json. No source illustration pixels.')
    Image.fromarray(np.uint8(np.clip(color,0,1)*255)).save(ASSETS/(id+'_color.png'),pnginfo=metadata)
    Image.fromarray(np.uint8(elevation < 0)*255).save(ASSETS/(id+'_ocean.png'),pnginfo=metadata)
    d.update(grid=[nx,nz],extent_m=extent,height_file='res://data/terrain/'+id+'.height',color_file='res://assets/terrain/'+id+'_color.png',ocean_mask_file='res://assets/terrain/'+id+'_ocean.png',sample_spacing_m=[extent[0]/(nx-1),extent[1]/(nz-1)],elevation_range_m=[float(elevation.min()),float(elevation.max())])
    (OUT/(id+'.json')).write_text(json.dumps(d,indent=2)+'\n')
    review=ROOT/'cache/terrain-review';review.mkdir(parents=True,exist_ok=True)
    # Relief overview for geographic QA only, not loaded by the game.
    gy,gx=np.gradient(elevation,extent[1]/(nz-1),spacing)
    light=np.clip((1-gx*.6-gy*.8)/np.sqrt(1+gx*gx+gy*gy),.30,1.2)
    overview=np.where((elevation>0)[:,:,None],color*light[:,:,None],np.array([.12,.33,.40]))
    Image.fromarray(np.uint8(np.clip(overview,0,1)*255)).resize((1000,round(1000*mh/mw))).save(review/(id+'_overview.png'))
    for entry in d['entries']:
        px,py=entry['position']; ix=round(px/mw*(nx-1));iz=round(py/mh*(nz-1))
        water_level = 0.0
        for lake in d.get('lakes',[]):
            if np.hypot((px-lake['center'][0])/lake['radius'][0],(py-lake['center'][1])/lake['radius'][1])<=1:
                water_level=max(water_level,lake['level'])
        for river in d.get('rivers',[]):
            distance, level=path_distance(np.array([px],dtype=float),np.array([py],dtype=float),river['points'],river['levels'])
            if distance[0]*width_m/mw < river['width_m']*.65: water_level=max(water_level,float(level[0]))
        if elevation[iz,ix]<water_level+1: raise ValueError(f'{id}: entry {entry["name"]} is not on dry ground')
    print(f'{id}: {nx}x{nz}, {extent[0]/1000:.2f} x {extent[1]/1000:.2f} km, {land.mean():.1%} land, max {elevation.max():.0f}m')
    return d



def world_atlas(world):
    """Illustrative world placement, with all shapes using one metre scale."""
    registry=json.loads((ROOT/'game/data/overworld_locations.json').read_text())
    atlas=dict(id='world',name='World',map_size=[1200000,700000],base_color=[.52,.66,.34],coastlines=[],regions=[],ridges=[],labels=[],locations=[],placement_note='Illustrative spacing and provisional island/continent sizes. Separate playable scenes.')
    for d in world['continents']:
        # Metadata on unrebaked maps must agree with their World overview position.
        existing=OUT/(d['id']+'.json')
        if existing.exists():
            current=json.loads(existing.read_text())
            current['world_offset_m']=d['world_offset_m']
            existing.write_text(json.dumps(current,indent=2)+'\n')
        scale=d['width_m']/d['map_size'][0]
        size=np.array(d['map_size'])*scale
        offset=np.array(d['world_offset_m'])+np.array([960000,260000])-size*.5
        def points(values):return (np.array(values)*scale+offset).tolist()
        atlas['coastlines'].extend(points(c) for c in d['coastlines'])
        for region in d['regions']:
            atlas['regions'].append(dict(polygon=points(region['polygon']),color=region['color']))
        atlas['labels'].append(dict(name=d['name'],position=(offset+size*.5+np.array([0,-size[1]*.45])).tolist()))
        location=next(l for l in registry['locations'] if l['id']=='terrain_'+d['id']).copy()
        location['position']=points([location['position']])[0]
        atlas['locations'].append(location)
    (OUT/'world.json').write_text(json.dumps(atlas,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--resolution',type=int,default=2048);parser.add_argument('--only')
    args=parser.parse_args()
    world=json.loads(SOURCE.read_text())
    for definition in world['continents']:
        if not args.only or definition['id']==args.only:
            bake(definition,args.resolution if definition['width_m']>=20000 else args.resolution//2)
            if definition.get('stream_pages'):
                from prepare_streaming import prepare
                prepare(definition['id'])
    world_atlas(world)

if __name__=='__main__':main()
