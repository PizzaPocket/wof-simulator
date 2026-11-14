"""Encode rendered runtime frames as MP4s and inline GIF previews."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "cache/clay-python"))
import imageio_ffmpeg
from PIL import Image

jobs = [
    ("head-review-after/jaw-*.png", "clay-jaw-articulation", 30),
    ("run-jump-review/walk-*.png", "clay-faster-walk", 30),
    ("run-jump-review/gallop-*.png", "clay-gallop", 30),
    ("run-jump-review/jump-*.png", "clay-responsive-jump", 60),
    ("flight-hock-review/flight-*.png", "clay-bent-hock-flight", 30),
    ("eye-tail-after/blink-*.png", "clay-natural-blink", 30),
    ("tail-limbs-review/flight-*.png", "clay-flight-limbs", 10),
    ("tail-limbs-review/curl-jump-*.png", "clay-curled-tail-jump", 15),
    ("tail-wrap-clip/wrap-*.png", "clay-tail-wrap", 15),
    ("feet-review-after/digits-*.png", "clay-toe-flexion", 20),
    ("feet-review-after/walk-*.png", "clay-feet-walk", 15),
    ("feet-review-after/jump-*.png", "clay-feet-jump", 15),
    ("legs-review-after/flight-[0-9][0-9][0-9].png", "clay-engaged-flight", 12),
    ("legs-review-after/walk-*.png", "clay-full-legs-walk", 12),
    (["legs-review-after/arm-1-*.png", "legs-review-after/arm-2-*.png", "legs-review-after/arm-0-*.png"], "clay-arm-use", 15),
]
for pattern, name, fps in jobs:
    if len(sys.argv) > 1 and name not in sys.argv[1:]:
        continue
    files = [path for part in (pattern if isinstance(pattern, list) else [pattern])
             for path in sorted((ROOT / "cache").glob(part))]
    if not files:
        continue
    frames = [Image.open(path).convert("RGB").resize((960, 600)) for path in files]
    frames[0].save(ROOT / "cache" / (name + ".gif"), save_all=True,
                   append_images=frames[1:], duration=round(1000 / fps), loop=0)
    encoder = subprocess.Popen([
        imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "960x600",
        "-r", str(fps), "-i", "-", "-an", "-c:v", "libx264",
        "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        str(ROOT / "cache" / (name + ".mp4")),
    ], stdin=subprocess.PIPE)
    for frame in frames:
        encoder.stdin.write(frame.tobytes())
    encoder.stdin.close()
    if encoder.wait():
        raise RuntimeError("Video encoding failed: " + name)
    print(name, len(frames), "frames", flush=True)
