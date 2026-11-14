"""Check that limb attachment/forearm controls deform the exported skin."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
data = runpy.run_path(str(ROOT / "game/tests/verify_foot_skin.py"))
np = data["np"]
names, joints, weights, skin = (data[key] for key in ("names", "joints", "weights", "skin"))
for name in (f"{prefix}.{side}" for prefix in ("shoulder_soft", "hip_soft", "forearm_twist", "wrist_arc1", "wrist_arc2") for side in ("L", "R")):
    index = names.index(name)
    influence = np.where(joints == index, weights, 0).sum(axis=1)
    count = np.count_nonzero(skin & (influence > .05))
    assert count > 20, (name, "does not influence the skin", count)
    print(name, int(count), "skin vertices")
print("PASS: actual exported skin follows shoulder/hip attachment helpers and distributed forearm rotation")
