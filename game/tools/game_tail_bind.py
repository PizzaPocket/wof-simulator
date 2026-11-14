"""A runtime-friendly tail export, leaving every sculpting source file intact."""
import copy
import json
from pathlib import Path
import numpy as np


def configure(builder):
    config = json.loads((Path(__file__).resolve().parents[1] / "data/tail_bind.json").read_text())
    builder.B = copy.deepcopy(builder.B)
    builder.TR = builder.B["trunk"]
    tail = builder.TR["tail"]
    builder.GAME_TAIL_SOURCE = copy.deepcopy(tail)
    builder.GAME_TAIL_CONFIG = config
    start, end = tail["from_s"], builder.tail_end_s()
    tail["heading_keys"] = [[start, config["bind_pitch_degrees"], 0], [end, config["bind_pitch_degrees"], 0]]
    # The original ground-rest convention belongs to the wrapped reference pose.
    tail["rest_from_s"], tail["rest_to_s"] = end + 10, end + 11
    tail["top_up_s"] = [start, start + 0.1]
    original_bones = builder.trunk_bones
    original_weights = builder.trunk_weights
    edges = np.asarray(builder.tail_vertebrae(), float)
    centers = (edges[:-1] + edges[1:]) * 0.5
    widths = np.diff(edges) * config["weight_support_segments"]

    def bones():
        existing, ranges = original_bones()
        existing = [item for item in existing if not item[0].startswith("tail")]
        ranges = [item for item in ranges if not item[0].startswith("tail")]
        stations, points, *_ = builder.trunk_frames()
        at = lambda s: tuple(float(np.interp(s, stations, points[:, axis])) for axis in range(3))
        parent = builder.TR["bones"]["chain_forward"][0][0]
        for index, (a, b) in enumerate(zip(edges[:-1], edges[1:])):
            name = f"tail{index + 1}"
            existing.append((name, at(a), at(b), parent))
            ranges.append((name, float(a), float(b)))
            parent = name
        return existing, ranges

    def weights(s, ranges, blend=0.05):
        root_blend = config["root_blend_model"]
        if s < start - root_blend:
            body_ranges = [r for r in ranges if not r[0].startswith("tail") or r[0] == "tail1"]
            return original_weights(s, body_ranges, blend)
        # Compact C2 kernels overlap across multiple joints. The source's narrow
        # two-bone handover leaves visible bands when a curled bind is straightened.
        distance = abs(s - centers) / widths
        values = np.maximum(0.0, 1 - distance * distance) ** 3
        indices = np.argsort(values)[-3:]
        values /= max(float(values[indices].sum()), 1e-12)
        root_share = builder.smoothstep(start - root_blend, start + root_blend, s)
        out = [(f"tail{i + 1}", float(values[i]) * root_share) for i in indices if values[i] > 0]
        if root_share < 1:
            out.append(("hips", 1 - root_share))
        return out

    builder.trunk_bones = bones
    builder.trunk_weights = weights


def add_collision_data(builder, segments):
    stations, points, dorsal, ventral, *_ = builder.trunk_frames()
    padding = builder.GAME_TAIL_CONFIG["collision_padding_model"]
    for segment in segments:
        s0 = float(stations[np.argmin(np.linalg.norm(points - segment["head"], axis=1))])
        s1 = s0 + segment["length"]
        samples = np.linspace(s0, s1, 7)
        core = max(float(np.interp(samples, stations, dorsal).max()), float(np.interp(samples, stations, ventral).max()))
        spike = 0.0
        for row in builder.B["spikes"]["rows"]:
            if row["to_s"] >= s0 and row["from_s"] <= s1:
                table = np.asarray(row["height"])
                spike = max(spike, float(np.interp(samples, table[:, 0], table[:, 1]).max()))
        segment["radius"] = core + spike + float(builder.B["shell"]["thickness"]) + padding
        segment["ventral_radius"] = float(np.interp(samples, stations, ventral).max()) + padding
