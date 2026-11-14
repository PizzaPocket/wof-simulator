"""Compose native-render geometry/reference comparisons; outputs stay in cache/."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
from PIL import Image,ImageDraw,ImageFont
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',20)
shots=ROOT/'cache/head-review-ear'
items=[
 (ROOT/'cache/head-review-after/side-00-clay.png','Before: lip corners and lower jaw',None),
 (shots/'side-00-clay.png','Resculpt: continuous turn and two side lobes',None),
 (ROOT/'prototypes/clay/refs/covers/Clay_htd_png.png','Official How to Draw: lip contour',(500,300,910,600)),
 (shots/'three-quarter-00-painted.png','Resculpt: closed mouth',None),
 (ROOT/'prototypes/clay/refs/clayref/Clay_TDPLE.jpg','Official limited edition: mouth / jaw',(410,95,655,270)),
 (shots/'three-quarter-40-painted.png','Resculpt: animal crowns and jaw rim',None),
 (shots/'rear-hook-painted.png','Rear hook and return into ear root',None),
 (shots/'under-90-painted.png','Palate, gum arches and skull-aligned teeth',None),
]
canvas=Image.new('RGB',(1200,4*415),'#222629');draw=ImageDraw.Draw(canvas)
for i,(path,label,crop) in enumerate(items):
 im=Image.open(path).convert('RGBA')
 if crop:im=im.crop(crop)
 bg=Image.new('RGBA',im.size,'#343b38');bg.alpha_composite(im);im=bg.convert('RGB');im.thumbnail((600,375))
 x,y=i%2*600,i//2*415;draw.text((x+10,y+8),label,font=font,fill='white');canvas.paste(im,(x+(600-im.width)//2,y+36+(375-im.height)//2))
canvas.save(ROOT/'cache/clay-mouth-resculpt-review.jpg',quality=94)
print('Saved cache/clay-mouth-resculpt-review.jpg')
