"""Blender-side profile, attachment and skeletal continuity checks."""
from pathlib import Path
import sys
import json

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "cache/clay-python"), str(ROOT / "prototypes/clay/body")]
sys.argv = ["build_body.py"]
import build_body as builder
import numpy as np

builder.skin_setup(weld=True)
parts = builder._SKIN["parts"]
trunk = builder._SKIN["trunk"]
bones = builder.trunk_bones()[0]
for sign in (1, -1):
    bones += builder.front_leg(sign)[1] + builder.hind_leg(sign)[1]
    from wing_rig import Rig
    bones += Rig(builder).bones(sign)
names = {entry[0] for entry in bones} | {"head", "jaw"}
report = {}
for part in parts:
    if part.kind == "section":
        continue
    samples = part.a + np.linspace(0, 1, 31)[:, None] * (part.b - part.a)
    weights = part.rig_at(samples)
    assert not (set(weights) - names), (part.name, set(weights) - names)
    assert np.max(abs(sum(weights.values()) - 1)) < 1e-8, part.name
    if len(part.profile):
        assert part.profile[0, 0] == 0 and part.profile[-1, 0] == 1
        assert np.all(np.diff(part.profile[:, 0]) > 0)
        assert np.all(part.profile_curve(np.linspace(0, 1, 101)) > 0)
        # The analytic surface passes through its actual station radii.
        radii = part.profile_curve(np.linspace(0, 1, 31)) * part.radii[None, 1:]
        surface = samples + radii[:, :1] * part.E[1]
        assert np.max(abs(part.sdf(surface))) < 1e-8, part.name
        report[part.name + (".L" if part.b[0] >= 0 else ".R")] = {"belly_radii": list(part.radii[1:]),
                             "distal_90_percent_radii": list(part.profile_curve(.9) * part.radii[1:])}

for sign in (1, -1):
    for function in (builder.front_leg, builder.hind_leg):
        _, limb = function(sign)
        by_name = {name: (np.array(a), np.array(b), parent) for name, a, b, parent in limb}
        for name, (a, b, parent) in by_name.items():
            if name.startswith(("upperarm", "forearm.", "thigh", "shin", "hand", "foot.")):
                samples = a + np.linspace(0, 1, 31)[:, None] * (b - a)
                assert builder.SK.field(samples, trunk, parts).max() < -.012, name
        side = "L" if sign > 0 else "R"
        if f"hand.{side}" in by_name:
            assert by_name[f"hand.{side}"][2] == f"forearm_twist.{side}"
            assert np.linalg.norm(by_name[f"hand.{side}"][0] - by_name[f"forearm.{side}"][1]) < 1e-10

(ROOT / "cache/leg-profile-check.json").write_text(json.dumps(report, indent=2))
print(f"PASS: {len(report)} mirrored muscle profiles, smooth taper surfaces, valid attachment weights, continuous limb centerlines and forearm/hand hierarchy")
