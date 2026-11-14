"""Compose native Godot foot captures alongside the indexed artwork crops."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "cache/clay-python"))
from PIL import Image, ImageDraw, ImageFont

font = ImageFont.load_default(size=20)
shots = [
    ("Hind foot — before", "feet-review-before/hind-clay.png"),
    ("Hind foot — connected rays / phalanges", "feet-review-after/hind-clay.png"),
    ("Side-sheet hind foot (oblique)", "feet-hind-reference.jpg"),
    ("Front hand — before", "feet-review-before/front-clay.png"),
    ("Front hand — connected rays / phalanges", "feet-review-after/front-clay.png"),
    ("Side-sheet front hand (oblique)", "feet-front-reference.jpg"),
    ("How to Draw — fore/hind root structure", "feet-htd-reference.jpg"),
    ("Hind foot — flight carriage", "feet-review-after/hind-flight-clay.png"),
    ("Front hand — flight carriage", "feet-review-after/front-flight-clay.png"),
]
sheet = Image.new("RGB", (1800, 1260), "#202526")
draw = ImageDraw.Draw(sheet)
for index, (label, relative) in enumerate(shots):
    frame = Image.open(ROOT / "cache" / relative).convert("RGB")
    frame.thumbnail((600, 375), Image.Resampling.LANCZOS)
    x, y = (index % 3) * 600, (index // 3) * 420
    sheet.paste(frame, (x + (600 - frame.width) // 2, y + 40 + (375 - frame.height) // 2))
    draw.text((x + 12, y + 9), label.replace("—", "-"), font=font, fill="#f4dbac")
sheet.save(ROOT / "cache/clay-feet-review.jpg", quality=92)
print("Created cache/clay-feet-review.jpg")
