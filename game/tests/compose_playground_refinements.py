"""Compose matched native-render reviews; generated media stays in cache/."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'cache/clay-python'))
from PIL import Image, ImageDraw, ImageFont
try:
    FONT = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 20)
except OSError:
    FONT = ImageFont.load_default()

def sheet(items, filename):
    canvas = Image.new('RGB', (1200, ((len(items)+1)//2)*415), '#222629')
    draw = ImageDraw.Draw(canvas)
    for i, (path,label,crop) in enumerate(items):
        image = Image.open(path).convert('RGBA')
        if crop: image = image.crop(crop)
        background = Image.new('RGBA',image.size,'#343b38')
        background.alpha_composite(image)
        image = background.convert('RGB')
        image.thumbnail((600,375))
        x,y = (i%2)*600,(i//2)*415
        draw.text((x+10,y+8),label,font=FONT,fill='white')
        canvas.paste(image,(x+(600-image.width)//2,y+36+(375-image.height)//2))
    canvas.save(ROOT/'cache'/filename,quality=94)

def frame(group,name,label):
    return (ROOT/'cache'/group/(name+'.png'),label,None)

if (ROOT/'cache/head-review-after/jaw-119.png').exists():
    items=[]
    for name,kind in [('side-00-painted','Closed mouth'),('under-00-clay','Underside / plain clay'),('three-quarter-40-painted','Open mouth')]:
        items.extend([frame('head-review-before',name,'Before: '+kind),frame('head-review-after',name,'After: '+kind)])
    items.append((ROOT/'prototypes/clay/refs/clayref/SE_box_set_Clay.jpg','Indexed cover: jaw rim under upper lip',(225,15,540,210)))
    user = Path('/var/folders/60/r0np9k0138g44p3sgjthnj3w0000gn/T/codex-clipboard-80b3253c-4b07-44f7-9ff1-2a97d3a3c13c.png')
    if user.exists():items.append((user,'User reference: jaw tucked beneath muzzle',(270,40,815,365)))
    sheet(items,'clay-jaw-refinement-review.jpg')

sheet([frame('eye-tail-needle','tail-side','Previous needle tip'),frame('eye-tail-rounded','tail-side','Shortened rounded taper'),frame('eye-tail-needle','tail-top','Previous tip / top'),frame('eye-tail-rounded','tail-top','Rounded end / top')],'clay-rounded-tail-review.jpg')
if (ROOT/'cache/flight-hock-review/hind-close.png').exists():
    sheet([frame('flight-hock-review','side-painted','Flying: knees drawn up'),frame('flight-hock-review','rear-quarter-painted','Flying: asymmetrical carried feet'),frame('flight-hock-review','hind-close','Hocks keep a visible bend'),frame('flight-hock-review','rear-quarter-clay','Plain clay: hip / knee / hock')],'clay-flight-hock-review.jpg')
