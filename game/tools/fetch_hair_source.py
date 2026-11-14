"""Fetch only selected authored hair files from the official MakeHuman archives.

Archives support HTTP byte ranges; unrelated assets are not downloaded.
Hair meshes/textures are data, not executable plugins. Credits are retained in
assets/scavengers/CREDITS.md and the generated GLB metadata.
"""
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'cache/human-source/authored-hair'
PACKS=[('makehuman_system_assets','cc0',['short02','long01']),('hair03','ccby',['punkduck_alpha7_curly2']),('hair02','ccby',['elvs_hazel_hair'])]
class RangeFile(io.RawIOBase):
    def __init__(self,url):
        self.url=url;self.position=0
        with urllib.request.urlopen(urllib.request.Request(url,method='HEAD'),timeout=60) as response:
            self.length=int(response.headers['Content-Length'])
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.position
    def seek(self,offset,whence=0):
        self.position=offset if whence==0 else self.position+offset if whence==1 else self.length+offset
        return self.position
    def read(self,size=-1):
        if size<0:size=self.length-self.position
        size=min(size,self.length-self.position)
        if size<=0:return b''
        request=urllib.request.Request(self.url,headers={'Range':f'bytes={self.position}-{self.position+size-1}'})
        with urllib.request.urlopen(request,timeout=90) as response:
            if response.status!=206:raise RuntimeError('Asset host did not honor byte ranges')
            data=response.read(size)
        self.position+=len(data)
        return data

def fetch_pack(spec):
    pack,license,names=spec
    url=f'https://files2.makehumancommunity.org/asset_packs/{pack}/{pack}_{license}.zip'
    records=[]
    with zipfile.ZipFile(RangeFile(url)) as archive:
        prefixes=tuple('hair/'+name+'/' for name in names)
        for name in archive.namelist():
            if not name.startswith(prefixes) or name.endswith('/'):continue
            relative=Path(name)
            if relative.is_absolute() or '..' in relative.parts:raise ValueError('Invalid asset member')
            data=archive.read(name);target=DEST/relative
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            records.append({'path':name,'sha256':hashlib.sha256(data).hexdigest()})
    print('Fetched authored hair:',', '.join(names))
    return {'url':url,'files':records}

def main():
    DEST.mkdir(parents=True,exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        records=list(pool.map(fetch_pack,PACKS))
    (DEST/'manifest.json').write_text(json.dumps(records,indent=2)+'\n')
if __name__=='__main__':main()
