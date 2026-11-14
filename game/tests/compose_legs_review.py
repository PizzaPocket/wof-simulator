"""Native Godot full-leg comparison with the indexed artwork crops."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "cache/clay-python"))
from PIL import Image, ImageDraw, ImageFont

font = ImageFont.load_default(size=20)
shots = [
    ("Foreleg - before", "legs-review-before/front-side-clay.png"),
    ("Foreleg - revised muscle/tendon form", "legs-review-after/front-side-clay.png"),
    ("Side-sheet foreleg architecture", "legs-side-reference.jpg"),
    ("Hind leg - before", "legs-review-before/hind-oblique-clay.png"),
    ("Hind leg - revised thigh/calf/hock", "legs-review-after/hind-oblique-clay.png"),
    ("How to Draw - oblique anatomy", "legs-htd-reference.jpg"),
    ("Flight - before", "legs-review-before/flight-side-clay.png"),
    ("Flight - held, engaged and asymmetrical", "legs-review-after/flight-side-clay.png"),
    ("SE poster - differing airborne limb carriage", "../prototypes/clay/refs/covers/Clay_SEPoster_Isolated_Edit_png.png"),
    ("Arm - reach", "legs-review-after/arm-mode-1.png"),
    ("Arm - forearm/palm rotation", "legs-review-after/arm-mode-2.png"),
    ("Flight - front view", "legs-review-after/flight-front-clay.png"),
    ("Wing girdle - revised socket placement", "legs-review-after/girdle-fold-50.png"),
    ("Forearm-relative wrist / palm", "legs-review-after/wrist-connection-clay.png"),
    ("Source radius / ulna / carpus paths", "legs-review-after/wrist-bone-paths.png"),
]
sheet = Image.new("RGB", (1800, 2100), "#202526")
draw = ImageDraw.Draw(sheet)
for index, (label, relative) in enumerate(shots):
    frame = Image.open(ROOT / "cache" / relative).convert("RGB")
    frame.thumbnail((600, 375), Image.Resampling.LANCZOS)
    x, y = (index % 3) * 600, (index // 3) * 420
    sheet.paste(frame, (x + (600 - frame.width) // 2, y + 40 + (375 - frame.height) // 2))
    draw.text((x + 12, y + 9), label, font=font, fill="#f4dbac")
sheet.save(ROOT / "cache/clay-full-legs-review.jpg", quality=92)
print("Created cache/clay-full-legs-review.jpg")
