"""Assemble ignored local review artifacts after render_sheet.py has run."""
from pathlib import Path
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'cache/moon-head-study'
HERE=Path(__file__).resolve().parent
for name in ['review.html','study-viewer.js']:
    shutil.copy(HERE/name,OUT/name)
for name in ['three.min.js','GLTFLoader.js']:
    shutil.copy(ROOT/'cache/shader-source-viewer'/name,OUT/name)

try: font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',20)
except OSError: font=ImageFont.load_default()

def tile(path,label,size=(650,550)):
    im=Image.open(path).convert('RGB');im.thumbnail((size[0]-24,size[1]-70))
    out=Image.new('RGB',size,(34,39,45))
    out.paste(im,((size[0]-im.width)//2,55+(size[1]-70-im.height)//2))
    ImageDraw.Draw(out).text((16,15),label,font=font,fill=(231,234,238))
    return out

items=[('starflight-front-reference.jpg','Starflight: near front · Mike Holmes'),
       ('starflight-dorsal-oblique.jpg','Starflight: dorsal oblique · Mike Holmes'),
       ('morrowseer-front-oblique.jpg','Morrowseer: front oblique · Mike Holmes')]
sheet=Image.new('RGB',(1950,620),(34,39,45))
for i,(file,label) in enumerate(items):sheet.paste(tile(OUT/file,label),(650*i,0))
d=ImageDraw.Draw(sheet)
d.text((20,560),'Official Dark Secret graphic novel preview · PDF pages 24 and 11 / printed pages 19 and 6',font=font,fill=(231,234,238))
d.text((20,590),'Perspective views; graphic-novel muzzle styling is kept separate from Joy Ang Moon proportions.',font=font,fill=(200,208,216))
sheet.save(OUT/'nightwing-reference-board.jpg',quality=94)

if (OUT/'structure.jpg').exists() and (OUT/'clay-foundation.jpg').exists():
    baseline=Image.open(OUT/'clay-foundation.jpg')
    study=Image.open(OUT/'structure.jpg')
    comparison=Image.new('RGB',(2100,1100),(34,39,45))
    comparison.paste(baseline,(0,0))
    for col,(x,y) in enumerate([(1400,0),(1400,520),(0,1040)]):
        comparison.paste(study.crop((x,y,x+700,y+520)),(700*col,520))
    ImageDraw.Draw(comparison).text((20,1060),'Top: accepted Clay facial volume. Below: NightWing volume study, including separate jaw. Equal anatomical head length.',font=font,fill=(231,234,238))
    comparison.save(OUT/'comparison.jpg',quality=94)
    progress=Image.new('RGB',(1400,1100),(34,39,45))
    labels=['Level skull and jaw','Three-quarter','Front · shared proportional breadth','Top · taper into the cranial mass']
    for i,((x,y),label) in enumerate(zip([(1400,0),(700,520),(1400,520),(0,1040)],labels)):
        panel=study.crop((x,y+25,x+700,y+520))
        progress.paste(panel,((i%2)*700,(i//2)*535+40))
        ImageDraw.Draw(progress).text(((i%2)*700+16,(i//2)*535+12),label,font=font,fill=(231,234,238))
    ImageDraw.Draw(progress).text((16,1070),'NightWing structural study · jaw and blink fitted · character details still to come',font=font,fill=(231,234,238))
    progress.save(OUT/'head-progress.jpg',quality=94)
print(OUT/'review.html')
