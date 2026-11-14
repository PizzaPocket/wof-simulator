"""Partition Clay's dense morph targets for the web without decimating geometry.

The desktop GLB stays untouched. Triangles retain their original attributes and
skinning; web meshes carry only the morph families they actually use. Unused
expression controls are omitted. Normal deltas <= 1e-6 are export roundoff.
Requires numpy (also available in the local Clay build environment).
"""
import copy
import json
from pathlib import Path
import struct
import sys

import numpy as np

DTYPES = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def family(name):
    for prefix, bit in (("wingFold", 1), ("blink", 2), ("cheekOpen", 4)):
        if name.startswith(prefix):
            return bit
    return 0


def optimize(source, destination):
    with source.open("rb") as stream:
        assert struct.unpack("<III", stream.read(12))[:2] == (0x46546C67, 2)
        size, kind = struct.unpack("<II", stream.read(8))
        assert kind == 0x4E4F534A
        doc = json.loads(stream.read(size))
        size, kind = struct.unpack("<II", stream.read(8))
        assert kind == 0x004E4942
        binary = stream.read(size)

    def view(index, count, dtype, width, offset=0):
        item = doc["bufferViews"][index]
        dtype = np.dtype(dtype)
        return np.ndarray((count, width), dtype=dtype, buffer=binary,
                          offset=item.get("byteOffset", 0) + offset,
                          strides=(item.get("byteStride", dtype.itemsize * width), dtype.itemsize))

    def read(index):
        item = doc["accessors"][index]
        dtype, width = DTYPES[item["componentType"]], WIDTHS[item["type"]]
        array = (view(item["bufferView"], item["count"], dtype, width, item.get("byteOffset", 0)).copy()
                 if "bufferView" in item else np.zeros((item["count"], width), dtype=dtype))
        if "sparse" in item:
            sparse = item["sparse"]
            indices, values = sparse["indices"], sparse["values"]
            rows = view(indices["bufferView"], sparse["count"], DTYPES[indices["componentType"]],
                        1, indices.get("byteOffset", 0)).ravel()
            array[rows] = view(values["bufferView"], sparse["count"], dtype, width,
                               values.get("byteOffset", 0))
        return array

    # Repack only referenced accessors; never carry the old dense data forward.
    out = copy.deepcopy(doc)
    out["bufferViews"], out["accessors"], out["meshes"] = [], [], []
    packed = bytearray()

    def write(array, template):
        while len(packed) % 4:
            packed.append(0)
        data = np.ascontiguousarray(array).tobytes()
        buffer_view = len(out["bufferViews"])
        out["bufferViews"].append({"buffer": 0, "byteOffset": len(packed), "byteLength": len(data)})
        packed.extend(data)
        item = {k: copy.deepcopy(v) for k, v in template.items()
                if k not in ("bufferView", "byteOffset", "sparse", "min", "max", "count")}
        item.update(bufferView=buffer_view, count=len(array))
        if array.dtype.kind == "f":
            item["min"] = array.min(axis=0).tolist()
            item["max"] = array.max(axis=0).tolist()
        index = len(out["accessors"])
        out["accessors"].append(item)
        return index

    copied = {}

    def copy_accessor(index):
        if index not in copied:
            copied[index] = write(read(index), doc["accessors"][index])
        return copied[index]

    # The current model has no animated morph-weight channels. Fail explicitly
    # if a future source introduces them rather than silently changing playback.
    for animation in out.get("animations", []):
        if any(c["target"]["path"] == "weights" for c in animation["channels"]):
            raise ValueError("Animated morph weights need remapping before this model can be optimized")
        for sampler in animation["samplers"]:
            sampler["input"] = copy_accessor(sampler["input"])
            sampler["output"] = copy_accessor(sampler["output"])
    for skin in out.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = copy_accessor(skin["inverseBindMatrices"])
    if doc.get("images"):
        raise ValueError("Embedded textures need copying; this optimizer expects texture-free Clay")

    for mesh_index, mesh in enumerate(doc["meshes"]):
        if len(mesh["primitives"]) != 1:
            raise ValueError("Expected one source primitive per mesh")
        primitive = mesh["primitives"][0]
        if primitive.get("mode", 4) != 4:
            raise ValueError("Expected triangle geometry")
        attributes = {name: read(index) for name, index in primitive["attributes"].items()}
        triangles = read(primitive["indices"]).reshape(-1, 3)
        names = mesh.get("extras", {}).get("targetNames", [])
        if len(names) != len(primitive.get("targets", [])):
            raise ValueError("Morph target names are missing")
        targets = {i: {name: read(index) for name, index in target.items()}
                   for i, target in enumerate(primitive.get("targets", [])) if family(names[i])}
        mask = np.zeros(len(attributes["POSITION"]), dtype=np.uint8)
        for index, target in targets.items():
            for semantic, values in target.items():
                tolerance = 1e-6 if semantic == "NORMAL" else 0
                mask[np.any(np.abs(values) > tolerance, axis=1)] |= family(names[index])
        groups = np.bitwise_or.reduce(mask[triangles], axis=1)
        pieces = []
        for group in np.unique(groups):
            original = triangles[groups == group]
            vertices, remapped = np.unique(original, return_inverse=True)
            indices = remapped.reshape(-1, 1).astype("<u4")
            # Exact reconstruction proves that no triangles/vertex order within
            # triangles have changed, including winding and skinning attributes.
            assert np.array_equal(vertices[indices.reshape(-1, 3)], original)
            result = {k: copy.deepcopy(v) for k, v in primitive.items()
                      if k not in ("attributes", "indices", "targets")}
            result["attributes"] = {
                name: write(values[vertices], doc["accessors"][primitive["attributes"][name]])
                for name, values in attributes.items()}
            result["indices"] = write(indices, {"type": "SCALAR", "componentType": 5125})
            selected = [i for i in targets if family(names[i]) & int(group)]
            if selected:
                result["targets"] = [{
                    semantic: write(values[vertices], doc["accessors"][primitive["targets"][i][semantic]])
                    for semantic, values in targets[i].items()} for i in selected]
            for i in targets:
                if i not in selected:
                    for semantic, values in targets[i].items():
                        assert np.max(np.abs(values[vertices])) <= (1e-6 if semantic == "NORMAL" else 0)
            piece = {"name": f"Clay_web_{mesh_index}_{int(group)}", "primitives": [result]}
            if selected:
                piece["extras"] = {"targetNames": [names[i] for i in selected]}
                piece["weights"] = [mesh.get("weights", [0] * len(names))[i] for i in selected]
            pieces.append(len(out["meshes"]))
            out["meshes"].append(piece)
            print(f"Web mesh {int(group)}: {len(vertices):,} vertices, {len(selected)} morph targets")
        for node in out["nodes"][:len(doc["nodes"])]:
            if node.get("mesh") != mesh_index:
                continue
            del node["mesh"]
            skin = node.pop("skin", None)
            node.pop("weights", None)
            for piece in pieces:
                child = {"name": out["meshes"][piece]["name"], "mesh": piece}
                if skin is not None:
                    child["skin"] = skin
                node.setdefault("children", []).append(len(out["nodes"]))
                out["nodes"].append(child)

    while len(packed) % 4:
        packed.append(0)
    out["buffers"] = [{"byteLength": len(packed)}]
    metadata = json.dumps(out, separators=(",", ":")).encode()
    metadata += b" " * (-len(metadata) % 4)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as stream:
        stream.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(metadata) + 8 + len(packed)))
        stream.write(struct.pack("<II", len(metadata), 0x4E4F534A))
        stream.write(metadata)
        stream.write(struct.pack("<II", len(packed), 0x004E4942))
        stream.write(packed)
    print(f"Web model: {destination.stat().st_size / 1024**2:.1f} MiB (source unchanged)")


if __name__ == "__main__":
    optimize(Path(sys.argv[1]), Path(sys.argv[2]))
