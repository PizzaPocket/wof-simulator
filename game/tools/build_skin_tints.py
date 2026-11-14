"""Bake natural skin/lip albedo using the CC0 HM08 UV-space vermilion mask."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
import numpy as np
from PIL import Image

def generate():
    folder=ROOT/'game/assets/scavengers'
    mask=np.asarray(Image.open(folder/'lip_boundary.jpg').convert('L'),float)/255
    mask=np.clip((mask-.035)/.93,0,1);mask=mask*mask*(3-2*mask)
    def linear(rgb):return np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    for name,p in json.loads((ROOT/'game/data/child_complexion.json').read_text()).items():
        rgb=lambda code:np.array([int(code[i:i+2],16)/255 for i in [0,2,4]])
        skin=linear(rgb(p['skin']));lips=linear(rgb(p['lip_color']))
        a=mask[...,None]*p['lip_strength']
        result=skin[None,None,:]*(1-a)+lips[None,None,:]*a
        srgb=np.where(result<=.0031308,result*12.92,1.055*np.maximum(result,0)**(1/2.4)-.055)
        Image.fromarray(np.round(np.clip(srgb,0,1)*255).astype('uint8')).save(folder/(name+'_skin.png'))
    print('Baked UV-aligned skin and lip colors')
if __name__=='__main__':generate()
