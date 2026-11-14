"""Encode native game renders as a compact motion preview and face contact sheet."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'cache/clay-python'))
from PIL import Image,ImageDraw,ImageFont
folder=ROOT/'cache/child-motion'
frames=[Image.open(p).convert('RGB').resize((900,563)) for p in sorted(folder.glob('frame-*.png'))]
frames[0].save(folder/'children-motion.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=True,disposal=2)
canvas=Image.new('RGB',(1050,400),'#26373e');draw=ImageDraw.Draw(canvas);font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',24)
for i,name in enumerate(['kai','camille','corinne']):
 im=Image.open(folder/(name+'-face.png')).convert('RGB').crop((200,25,800,625)).resize((330,330))
 canvas.paste(im,(i*350+10,55));draw.text((i*350+15,15),name.capitalize(),font=font,fill='#f0e9dc')
canvas.save(folder/'complexions.png')
print(folder/'children-motion.gif');print(folder/'complexions.png')
