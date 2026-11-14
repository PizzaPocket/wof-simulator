"""Build the current Clay source and give its exported mesh portable base colours.

Run with Blender's Python (see game/README.md), or a Python with bpy installed.
The prototype sources are not modified. Portable base colors remain available
for generic viewers; packed design channels drive the procedural Godot material.
"""
from pathlib import Path
import json
import hashlib
import struct
import sys
import shutil

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
# Optional dependencies installed for the bundled Blender Python (git-ignored).
DEPENDENCIES = ROOT / "cache" / "clay-python"
if DEPENDENCIES.exists():
    sys.path.insert(0, str(DEPENDENCIES))
sys.path.insert(0, str(ROOT / "prototypes" / "clay" / "body"))

import bpy
import numpy as np


def compatible_pose_clips(original):
    """Finish legacy prototype clips on Blender 5's slotted Action API.

    The prototype currently reads Action.fcurves after inserting every key.
    Blender 5 removed that alias. Keep this compatibility adapter outside the
    model source while another session is working on that source.
    https://developer.blender.org/docs/release_notes/5.0/python_api/
    """
    def build(arm, bones, clips):
        for name, pose in clips.items():
            try:
                original(arm, bones, {name: pose})
            except AttributeError as error:
                if "'Action' object has no attribute 'fcurves'" not in str(error):
                    raise
                action = arm.animation_data.action
                for layer in action.layers:
                    for strip in layer.strips:
                        for bag in strip.channelbags:
                            for curve in bag.fcurves:
                                for key in curve.keyframe_points:
                                    key.interpolation = "LINEAR"
                bpy.context.scene.frame_set(0)
                bpy.ops.object.mode_set(mode="OBJECT")
    return build


def base_colours(mesh):
    """Interpret the current head/body builder's _PART and _ABZ design channels.

    Keep this separate from sculpting: the renderer gets standard COLOR_0 instead
    of relying on three.js-only custom attributes or shader injection.
    """
    count = len(mesh.vertices)
    part = np.empty(count, dtype=np.float32)
    abz = np.empty(count * 3, dtype=np.float32)
    mesh.attributes["_PART"].data.foreach_get("value", part)
    mesh.attributes["_ABZ"].data.foreach_get("vector", abz)
    abz = abz.reshape(-1, 3)
    a, b, zone = abz.T
    # Linear RGB, matching the prototype viewer's palette conversion.
    def rgb(r, g, bl):
        return (np.array([r, g, bl]) / 255.0) ** 2.2

    orange = rgb(229, 88, 41)
    dark = rgb(98, 45, 33)
    cream = rgb(241, 196, 142)
    line = rgb(58, 24, 17)
    color = np.tile(orange, (count, 1))

    def mix(left, right, fraction):
        return left * (1 - fraction[:, None]) + right * fraction[:, None]

    def put(number, value):
        selected = abs(part - number) < 0.5
        color[selected] = value[selected] if np.ndim(value) == 2 else value

    put(2, cream)
    put(3, rgb(92, 26, 32))
    put(4, rgb(245, 238, 220))
    put(5, rgb(170, 70, 75))
    eye = np.tile(rgb(242, 236, 226), (count, 1))
    eye[a < 0.165] = rgb(112, 66, 34)
    eye[a < 0.09] = 0.01
    put(6, eye)
    put(7, mix(line * 0.6, orange, np.maximum(np.clip((a - 0.2) / 0.08, 0, 1), np.clip(b, 0, 1))))
    put(8, dark)
    put(9, mix(cream, orange, np.clip(zone, 0, 1)))
    put(10, mix(dark * 1.12, dark * 0.88, np.clip(b, 0, 1)))
    put(12, rgb(226, 140, 150))
    roof = mix(dark * 0.92, dark * 1.12, np.clip(b, 0, 1))
    roof[zone > 0.4] = rgb(12, 6, 5)
    put(13, roof)
    put(14, rgb(130, 56, 49))
    z = np.clip(zone, 0, 1)
    trunk = np.where((z < 0.5)[:, None], mix(dark, orange, z * 2), mix(orange, cream, z * 2 - 1))
    trunk[zone < -0.25] = rgb(92, 26, 32)
    put(20, trunk)
    put(21, mix(orange, cream, z))
    put(22, dark)
    put(23, rgb(72, 50, 58))
    put(24, mix(orange * 0.92, dark, np.clip((b - 0.58) / 0.1, 0, 1)))
    put(25, mix(rgb(232, 128, 70), rgb(246, 168, 106), np.clip(a, 0, 1)))
    attribute = mesh.color_attributes.new(name="ClayBaseColor", type="FLOAT_COLOR", domain="POINT")
    attribute.data.foreach_set("color", np.column_stack([np.clip(color, 0, 1), np.ones(count)]).astype(np.float32).ravel())
    mesh.color_attributes.active_color = attribute
    mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(attribute)


def main():
    destination = ROOT / "game" / "assets" / "clay.glb"
    destination.parent.mkdir(parents=True, exist_ok=True)
    # The prototype reads argv on import; don't pass Blender's flags through.
    rig_only = "--rig-only" in sys.argv
    output = destination if rig_only else ROOT / "cache" / "clay-game-build" / "clay.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    sys.argv = ["build_body.py", "--out", str(output)]
    import build_body
    from game_tail_bind import configure
    configure(build_body)
    if rig_only:
        with destination.open("rb") as stream:
            header = stream.read(20)
            gltf = json.loads(stream.read(struct.unpack_from("<I", header, 12)[0]))
        count = sum(node.get("name", "").startswith("tail") for node in gltf["nodes"])
        if count != int(build_body.TR["tail"]["vertebrae"]):
            raise RuntimeError("The local model still has the old tail rig. Run a full game asset build first.")
        names = {node.get("name", "") for node in gltf["nodes"]}
        required = {f"{prefix}{digit}_p{segment}.{side}"
                    for prefix in ("ftoe", "htoe") for digit in range(1, 5)
                    for segment in (2, 3) for side in ("L", "R")}
        required |= {"fthumb_p2.L", "fthumb_p2.R"}
        required |= {f"{name}.{side}" for name in ("shoulder_soft", "hip_soft", "forearm_twist", "wrist_arc1", "wrist_arc2") for side in ("L", "R")}
        if required - names:
            raise RuntimeError("The local model lacks the current digit/limb controls. Run a full game asset build first.")
        write_rig_data(build_body, output.with_name("clay_rig.json"))
        return
    from port_clay_shader import generate
    generate()
    build_body.H.pose_clips = compatible_pose_clips(build_body.H.pose_clips)
    print("Building current Clay source…", flush=True)
    build_body.main()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    material = bpy.data.materials.new("Clay portable base colours")
    material.use_nodes = True
    material.use_backface_culling = False
    nodes = material.node_tree.nodes
    vertex_color = nodes.new("ShaderNodeVertexColor")
    vertex_color.layer_name = "ClayBaseColor"
    surface = nodes.get("Principled BSDF")
    surface.inputs["Roughness"].default_value = 0.65
    material.node_tree.links.new(vertex_color.outputs["Color"], surface.inputs["Base Color"])
    for obj in meshes:
        base_colours(obj.data)
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_skins=True, export_attributes=True, export_yup=True,
        export_extras=True, export_animations=True, export_force_sampling=False,
        export_materials="EXPORT",
    )
    from pack_clay_material import pack_material_channels
    pack_material_channels(output)
    print(f"Game asset ready: {output}", flush=True)
    write_rig_data(build_body, output.with_name("clay_rig.json"))
    backup = ROOT / "cache" / "clay-before-tail-fix.glb"
    if destination.exists() and not backup.exists():
        shutil.copy2(destination, backup)
        shutil.copy2(destination.with_name("clay_rig.json"), backup.with_suffix(".json"))
    output.replace(destination)
    output.with_name("clay_rig.json").replace(destination.with_name("clay_rig.json"))
    print(f"Installed game asset: {destination}", flush=True)


def write_rig_data(builder, output):
    """Ship measured anatomy with the game without depending on repo-relative paths."""
    body = builder.B
    bones, _ = builder.trunk_bones()
    tail = []
    neck = []
    for name, head, end, parent in bones:
        if name.startswith("tail"):
            tail.append({"name": name, "head": list(head), "end": list(end),
                         "length": float(np.linalg.norm(np.array(end) - head)), "parent": parent})
        if name.startswith("neck"):
            neck.append({"name": name, "head": list(head), "end": list(end),
                         "length": float(np.linalg.norm(np.array(end) - head)), "parent": parent})
    source = ROOT / "prototypes/clay/body/body_design.json"
    if hasattr(builder, "GAME_TAIL_CONFIG"):
        from game_tail_bind import add_collision_data
        add_collision_data(builder, tail)
        from tail_envelopes import measure
        envelope = measure(output.with_name("clay.glb"), tail, builder.GAME_TAIL_CONFIG["collision_padding_model"])
    else:
        envelope = {}
    data = {
        "source": str(source.relative_to(ROOT)),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "skin_pattern": body["skin_pattern"],
        "tail": body["trunk"]["tail"], "tail_bones": tail,
        "tail_bind": getattr(builder, "GAME_TAIL_CONFIG", {}),
        "tail_source_pose": getattr(builder, "GAME_TAIL_SOURCE", {}),
        "tail_envelope": envelope,
        "neck_bones": neck,
        "front_joints": body["front_leg"]["joints"],
        "hind_joints": body["hind_leg"]["joints"],
        "feet": {kind: {"toes": body[key]["toes"], "thumb": body[key].get("thumb")}
                 for kind, key in (("front", "front_leg"), ("hind", "hind_leg"))},
        "limb_articulation": body.get("limb_articulation", {}),
        "wing_socket": body["wing"]["joints"]["shoulder"],
        "wing_chest_attachment": body["wing"]["canonical_fold"].get("chest_attachment"),
        "limb_bones": body["anatomy"]["bones"],
        "muscles": [{k: m[k] for k in ("name", "from", "to", "rig", "why") if k in m}
                    for m in body["anatomy"]["muscles"]],
        "wing_animation": read_wing_animation(output.with_name("clay.glb")),
    }
    output.write_text(json.dumps(data, indent=2) + "\n")
    print(f"Measured rig data ready: {output}", flush=True)


def read_wing_animation(path):
    """Preserve exact glTF keys; editor key reduction can break corrective poses."""
    if not path.exists():
        return {}
    with path.open("rb") as stream:
        header = stream.read(20)
        document = json.loads(stream.read(struct.unpack_from("<I", header, 12)[0]))
        stream.read(8)
        buffer = stream.read()

    def accessor(index):
        item = document["accessors"][index]
        view = document["bufferViews"][item["bufferView"]]
        width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[item["type"]]
        assert item["componentType"] == 5126, "Animation keys must be floats"
        offset = view.get("byteOffset", 0) + item.get("byteOffset", 0)
        return np.frombuffer(buffer, dtype="<f4", count=item["count"] * width,
                             offset=offset).reshape(item["count"], width)

    for clip in document.get("animations", []):
        if "wings_fold" not in clip.get("name", ""):
            continue
        tracks = []
        duration = 0.0
        for channel in clip["channels"]:
            if channel["target"]["path"] not in ("translation", "rotation", "scale"):
                continue
            sampler = clip["samplers"][channel["sampler"]]
            interpolation = sampler.get("interpolation", "LINEAR")
            assert interpolation in ("LINEAR", "STEP"), "Unsupported wing sampler interpolation"
            times = accessor(sampler["input"]).ravel()
            tracks.append({
                "bone": document["nodes"][channel["target"]["node"]]["name"],
                "property": channel["target"]["path"], "times": times.tolist(),
                "values": accessor(sampler["output"]).tolist(), "interpolation": interpolation,
            })
            duration = max(duration, float(times[-1]))
        return {"duration": duration, "tracks": tracks}
    return {}


if __name__ == "__main__":
    main()
