"""Matched runtime close-ups; keep generated images under ignored cache/."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'cache/clay-python'))
from PIL import Image, ImageDraw
canvas = Image.new('RGB', (1440, 1960), '#222629')
draw = ImageDraw.Draw(canvas)
items = [
 ('eye-tail-before/tail-side.png', 'Before: shell ends early'),
 ('eye-tail-after/tail-side.png', 'After: tapered terminal shell'),
 ('eye-tail-before/eye-open.png', 'Before: coarse eye colors'),
 ('eye-tail-after/eye-open.png', 'After: iris diameter +10%, globe/pupil unchanged'),
 ('eye-tail-after/eye-050.png', 'Blink: halfway closed'),
 ('eye-tail-after/eye-100.png', 'Blink: fully closed'),
 ('eye-tail-after/tail-clay.png', 'Terminal cap: plain clay'),
]
for i, (path, label) in enumerate(items):
 x, y = (i % 2) * 720, (i // 2) * 490
 draw.text((x + 12, y + 12), label, fill='white')
 image = Image.open(ROOT / 'cache' / path).convert('RGB').resize((720, 450))
 canvas.paste(image, (x, y + 35))
reference = Image.open(ROOT / 'prototypes/clay/refs/clayref/ClayTemplateS978.png').convert('RGBA')
reference = reference.crop((1250, 1500, 3000, 2185))
background = Image.new('RGBA', reference.size, '#222629')
background.alpha_composite(reference)
background = background.convert('RGB')
background.thumbnail((700, 430))
canvas.paste(background, (730, 1510))
draw.text((732, 1482), 'Indexed side-sheet reference: dorsal shell / light underside', fill='white')
canvas.save(ROOT / 'cache/clay-eye-tail-review.jpg', quality=94)
