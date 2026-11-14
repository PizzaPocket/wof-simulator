"""Check actual exported skin weights and rigid claw attachment domains."""
from pathlib import Path
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "cache/clay-python"))
import numpy as np

with (ROOT / "game/assets/clay.glb").open("rb") as stream:
    header = stream.read(20)
    document = json.loads(stream.read(struct.unpack_from("<I", header, 12)[0]))
    stream.read(8)
    buffer = stream.read()

def array(index):
    item = document["accessors"][index]
    view = document["bufferViews"][item["bufferView"]]
    width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[item["type"]]
    dtype = {5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}[item["componentType"]]
    return np.frombuffer(buffer, dtype=dtype, count=item["count"] * width,
                         offset=view.get("byteOffset", 0) + item.get("byteOffset", 0)).reshape(-1, width)

attributes = document["meshes"][0]["primitives"][0]["attributes"]
part = array(attributes["_PART"]).ravel()
joints = array(attributes["JOINTS_0"]).astype(int)
weights = array(attributes["WEIGHTS_0"])
names = [document["nodes"][index]["name"] for index in document["skins"][0]["joints"]]
skin = (part > 19.5) & (part < 20.5)
claws = abs(part - 23) < 0.1
assert np.max(abs(weights.sum(axis=1) - 1)) < 1e-5
checked = 0
for prefix in ("ftoe", "htoe"):
    for side in ("L", "R"):
        for digit in range(1, 5):
            meta = names.index(f"{'fmeta' if prefix == 'ftoe' else 'hmeta'}{digit}.{side}")
            meta_influence = np.where(joints == meta, weights, 0).sum(axis=1)
            assert np.count_nonzero(skin & (meta_influence > 0.1)) > 5, (names[meta], "missing supporting ray skin")
            for segment in (1, 2, 3):
                name = f"{prefix}{digit}" + (f"_p{segment}" if segment > 1 else "") + "." + side
                index = names.index(name)
                influence = np.where(joints == index, weights, 0).sum(axis=1)
                assert np.count_nonzero(skin & (influence > 0.1)) > 5, (name, "missing skin influence")
                if segment == 3:
                    assert np.count_nonzero(claws & (influence > 0.999)) > 20, (name, "claw does not follow terminal phalanx")
                else:
                    assert np.count_nonzero(claws & (influence > 0.01)) == 0, (name, "claw incorrectly attached to proximal joint")
                checked += 1
for side in ("L", "R"):
    index = names.index("fthumb_p2." + side)
    influence = np.where(joints == index, weights, 0).sum(axis=1)
    assert np.count_nonzero(claws & (influence > 0.999)) > 20
print(f"PASS: {checked} main phalanges deform actual exported skin; all 18 main/thumb claws follow the terminal phalanx; normalized weights")
