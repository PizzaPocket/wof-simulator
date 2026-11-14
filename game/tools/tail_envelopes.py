"""Measure collision envelopes against the actual exported tail/armor vertices."""
import json
import struct
import numpy as np


def measure(path, segments, padding):
    with path.open("rb") as stream:
        header = stream.read(20)
        document = json.loads(stream.read(struct.unpack_from("<I", header, 12)[0]))
        stream.read(8)
        buffer = stream.read()

    def read(index):
        item = document["accessors"][index]
        view = document["bufferViews"][item["bufferView"]]
        width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[item["type"]]
        dtype = {5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}[item["componentType"]]
        result = np.frombuffer(buffer, dtype=dtype, count=item["count"] * width,
                               offset=view.get("byteOffset", 0) + item.get("byteOffset", 0)).reshape(-1, width)
        if item.get("normalized") and item["componentType"] != 5126:
            result = result.astype(float) / np.iinfo(result.dtype).max
        return result

    skin = document["skins"][0]
    is_tail = np.array([document["nodes"][node].get("name", "").startswith("tail") for node in skin["joints"]])
    vertices = []
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            if "JOINTS_0" not in attributes:
                continue
            points = read(attributes["POSITION"])
            share = np.zeros(len(points))
            for suffix in ("0", "1"):
                if "JOINTS_" + suffix in attributes:
                    joints = read(attributes["JOINTS_" + suffix]).astype(int)
                    weights = read(attributes["WEIGHTS_" + suffix])
                    share += (is_tail[joints] * weights).sum(axis=1)
            vertices.append(points[share > 0.6])
    points = np.concatenate(vertices)
    best = np.full(len(points), np.inf)
    assigned = np.zeros(len(points), dtype=int)
    for index, segment in enumerate(segments):
        start, end = np.array(segment["head"]), np.array(segment["end"])
        delta = end - start
        fraction = np.clip((points - start) @ delta / (delta @ delta), 0, 1)
        distance = ((points - start - fraction[:, None] * delta) ** 2).sum(axis=1)
        nearer = distance < best
        assigned[nearer] = index
        best[nearer] = distance[nearer]
    for index, segment in enumerate(segments):
        selection = assigned == index
        if not selection.any():
            continue
        actual = float(np.sqrt(best[selection]).max())
        segment["mesh_envelope_radius"] = actual
        segment["radius"] = max(float(segment["radius"]), actual + padding)
        bottom = float((segment["head"][1] - points[selection, 1]).max())
        segment["ventral_radius"] = max(float(segment["ventral_radius"]), bottom + padding)
    return {"vertices": int(len(points)), "padding_model": padding, "note": "Measured on exported tail-weighted skin, shell and spikes; continuous-neighbor overlaps are excluded from self-contact."}
