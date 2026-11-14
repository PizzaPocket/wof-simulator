"""Assemble the rendered character, cloth and footwear review."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'cache/clay-python'))
from PIL import Image,ImageDraw,ImageFont
OUT=ROOT/'cache/child-proportions'
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
def font(size):return ImageFont.truetype(font_path,size)
canvas=Image.new('RGB',(1200,1260),'#202a34');d=ImageDraw.Draw(canvas)
d.text((25,20),'Children · revised silhouette and cloth garments',font=font(30),fill='#f4f1e8')
d.text((25,65),'Plain torsos, sloping shoulders, shorter arms and smaller hands. Backpacks removed.',font=font(20),fill='#bdccd7')
for col,(name,age) in enumerate([('kai',9),('camille',9),('corinne',6)]):
 x=col*400
 d.text((x+25,110),name.capitalize()+f' · {age} years',font=font(24),fill='#f4f1e8')
 im=Image.open(OUT/(name+'-front.png')).convert('RGB').crop((230,25,570,485)).resize((300,406))
 canvas.paste(im,(x+50,150))
 d.text((x+25,580),'Shirt drape',font=font(21),fill='#bdccd7')
 im=Image.open(OUT/(name+'-shirt.png')).convert('RGB').crop((170,40,630,470)).resize((360,337))
 canvas.paste(im,(x+20,615))
 d.text((x+25,975),'Closed footwear',font=font(21),fill='#bdccd7')
 im=Image.open(OUT/(name+'-shoes.png')).convert('RGB').crop((80,100,720,480)).resize((360,214))
 canvas.paste(im,(x+20,1010))
canvas.save(OUT/'review.png')
print(OUT/'review.png')
