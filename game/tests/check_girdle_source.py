"""Check socket proximity, supported attachments and wing fold invariants."""
from pathlib import Path
import sys
import json
ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "cache/clay-python"), str(ROOT / "prototypes/clay/body")]
sys.argv = ["build_body.py"]
import build_body as builder
import wing_rig
import check_wing
import numpy as np

builder.skin_setup(weld=True)
rig = wing_rig.Rig(builder)
front = np.array(builder.B["front_leg"]["joints"]["shoulder"])
assert np.linalg.norm(rig.S - front) < .31
assert rig.S[1] > front[1] and abs(rig.S[2] - front[2]) < .24
anchor = np.array(rig.C["chest_attachment"])
for point in (rig.S, anchor):
    assert builder.SK.field(point[None], builder._SKIN["trunk"], builder._SKIN["parts"])[0] < -.01, point
for sign in (1, -1):
    for fold in (0., .25, .5, .75, 1.):
        pieces = rig.pieces(fold, sign)
        deltoid = next(piece for piece in pieces if piece.name == "deltoid")
        assert np.linalg.norm(deltoid.b - anchor * [sign, 1, 1]) < 1e-10
report = check_wing.check()
print("PASS: foreleg/wing sockets share the proximal girdle region, roots/anchors lie inside supporting body tissue, chest attachment stays fixed through folding")
print("WING_ANATOMY_CHECK", json.dumps(report))
