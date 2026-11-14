"""Export timed gait previews from render_gait_review.gd's images and tick manifest.

Requires Pillow and imageio-ffmpeg. Use the workspace Python runtime, with
cache/clay-python available for imageio-ffmpeg if it is not otherwise installed.
"""
from pathlib import Path
import bisect
import json
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
try:
    import imageio_ffmpeg
except ImportError:
    sys.path.append(str(ROOT / "cache/clay-python"))
    import imageio_ffmpeg

SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "cache/gait-review"
TICKS = json.loads((SOURCE / "frame-ticks.json").read_text())
FPS = 30


def sequence(prefix):
    paths = sorted(SOURCE.glob(prefix + "*.png"))
    ticks = [TICKS[path.stem] for path in paths]
    times = [(tick - ticks[0]) / 60 for tick in ticks]
    duration = times[-1] + (times[-1] - times[-2])
    return paths, times, duration


def frame_at(sequence_data, time):
    paths, times, duration = sequence_data
    index = max(0, bisect.bisect_right(times, time % duration) - 1)
    with Image.open(paths[index]) as source:
        return source.convert("RGB")


def export(name, frames):
    width, height = frames[0].size
    encoder = subprocess.Popen([
        imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{width}x{height}",
        "-r", str(FPS), "-i", "-", "-an", "-c:v", "libx264", "-crf", "20",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        str(SOURCE / (name + ".mp4")),
    ], stdin=subprocess.PIPE)
    for frame in frames:
        encoder.stdin.write(frame.tobytes())
    encoder.stdin.close()
    if encoder.wait():
        raise RuntimeError("Encoding failed: " + name)
    if name == "sprint":
        preview = [frame.resize((800, 500), Image.Resampling.LANCZOS) for frame in frames[::2]]
        preview[0].save(SOURCE / "sprint.gif", save_all=True, append_images=preview[1:],
                        duration=67, loop=0)
    print(name, len(frames), "frames")


try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
except OSError:
    font = ImageFont.load_default()

modes = [("walk", "Walk - light stick"), ("lope", "Easy run - full stick"),
         ("sprint", "Gallop - sprint held")]
sequences = [sequence(mode + "-side-") for mode, _ in modes]
comparison = []
for i in range(4 * FPS):
    canvas = Image.new("RGB", (1440, 336), "#17231d")
    draw = ImageDraw.Draw(canvas)
    for index, ((mode, label), data) in enumerate(zip(modes, sequences)):
        frame = frame_at(data, i / FPS).resize((480, 300), Image.Resampling.LANCZOS)
        canvas.paste(frame, (index * 480, 36))
        draw.text((index * 480 + 14, 9), label, font=font, fill="white")
    comparison.append(canvas)
export("gait-comparison", comparison)
small = [frame.resize((1200, 280), Image.Resampling.LANCZOS) for frame in comparison[::2]]
small[0].save(SOURCE / "gait-comparison.gif", save_all=True, append_images=small[1:],
              duration=67, loop=0)
for (mode, _), data in zip(modes, sequences):
    export(mode, [frame_at(data, i / FPS) for i in range(round(data[2] * FPS))])
data = sequence("turn-")
export("walking-turn", [frame_at(data, i / FPS) for i in range(round(data[2] * FPS))])

# Show consecutive sprint poses, plus the extra viewpoints for assessing width.
for mode, _ in modes:
    files = sorted(SOURCE.glob(mode + "-side-*.png"))[::5]
    sheet = Image.new("RGB", (1280, 690), "white")
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(files[:12]):
        with Image.open(path) as frame:
            sheet.paste(frame.resize((320, 200)), (index % 4 * 320, index // 4 * 230))
        draw.text((index % 4 * 320 + 5, index // 4 * 230 + 202), path.stem, fill="black")
    sheet.save(SOURCE / (mode + "-contact-sheet.jpg"))
sheet = Image.new("RGB", (1440, 1008), "#17231d")
draw = ImageDraw.Draw(sheet)
for row, (mode, label) in enumerate(modes):
    for column, view in enumerate(["front", "rear", "overhead"]):
        path = sorted(SOURCE.glob(f"{mode}-{view}-*.png"))[3]
        with Image.open(path) as frame:
            sheet.paste(frame.resize((480, 300)), (column * 480, row * 336 + 36))
        draw.text((column * 480 + 12, row * 336 + 9), label + " / " + view,
                  font=font, fill="white")
sheet.save(SOURCE / "foot-placement-views.jpg")
