"""Blender-side check of digital roots, joint continuity and skin-field support.
Run with Blender --background --python-exit-code 1 --python this_file.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "cache/clay-python"), str(ROOT / "prototypes/clay/body")]
sys.argv = ["build_body.py"]
import build_body as builder
import numpy as np

builder.skin_setup(weld=True)
parts = builder._SKIN["parts"]
trunk = builder._SKIN["trunk"]
worst = -100.0
count = 0
for kind, prefix, function in (("front_leg", "ftoe", builder.front_leg), ("hind_leg", "htoe", builder.hind_leg)):
    for sign in (1, -1):
        _, bones = function(sign)
        by_name = {name: (np.array(a), np.array(b), parent) for name, a, b, parent in bones}
        side = "L" if sign > 0 else "R"
        for digit in range(1, 5):
            base = f"{prefix}{digit}"
            meta = f"{'fmeta' if prefix == 'ftoe' else 'hmeta'}{digit}.{side}"
            names = [meta] + [f"{name}.{side}" for name in builder.digit_names(base, 3)]
            for i, name in enumerate(names):
                a, b, parent = by_name[name]
                assert np.linalg.norm(b - a) > 0.01, name
                if i:
                    assert parent == names[i - 1], name
                    assert np.linalg.norm(a - by_name[parent][1]) < 1e-10, name
                # Require a positive flesh margin along the skeleton, not merely
                # topological parentage or surfaces touching at a single point.
                samples = a + np.linspace(0, 1, 21)[:, None] * (b - a)
                field = builder.SK.field(samples, trunk, parts)
                worst = max(worst, float(field.max()))
                assert field.max() < -0.015, (name, field.max())
                count += 1
        if prefix == "ftoe":
            assert by_name[f"fthumb_p2.{side}"][2] == f"fthumb.{side}"
            assert np.linalg.norm(by_name[f"fthumb_p2.{side}"][0] - by_name[f"fthumb.{side}"][1]) < 1e-10
print(f"PASS: {count} metapodial/phalangeal links, mirrored connected roots; minimum skin-field margin {-worst:.4f} model units")

# Exercise the full body path, including the head's fixed-weight section fields.
# Merely testing Piece.rig_at would miss a sampler that ignored it in export.
samples = np.array([[0.45, 0.06, -0.56], [0.41, 0.06, 0.76], [0.41, 0.08, 0.81]])
_, ranges = builder.trunk_bones()
weights, *_ = builder.SK.vertex_data(samples, trunk, parts,
    lambda s: builder.trunk_weights(s, ranges), builder.zone_value, builder.dark_value,
    builder.TR["zones"]["lines_until_s"] + 0.15, N=np.tile([0., 1., 0.], (len(samples), 1)))
assert all(abs(sum(weight for _, weight in entry) - 1) < 1e-8 for entry in weights)
assert any("_p2" in name or "_p3" in name for entry in weights for name, weight in entry if weight > .01)
print("PASS: full body skin-weight sampler includes phalangeal gradients and fixed head sections")
