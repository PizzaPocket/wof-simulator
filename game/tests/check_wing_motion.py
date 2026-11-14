"""Dense anatomical checks for Clay's continuous wing-fold path, in Blender."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'cache/clay-python'), str(ROOT / 'prototypes/clay/body')]
sys.argv = ['check_wing_motion']
import numpy as np
from scipy.spatial.transform import Rotation
import build_body as B
import wing_rig as W


def check():
    rig = W.Rig(B)
    maximum_length_error = 0.0
    maximum_rotation_step = 0.0
    minimum_fan_gap = float('inf')
    lowest_digit = float('inf')
    previous = None
    for u in np.linspace(0, 1, 501):
        pose = rig.state(float(u))
        tips = []
        for k, curve in enumerate(rig.curves):
            end = pose['wing_carpal'][1] + pose['wing_carpal'][0] @ (curve[0] - rig.restW)
            for j, suffix in enumerate(('', 'b', 'c')):
                rotation, head, scale = pose[f'wing_finger{k+1}{suffix}']
                assert np.linalg.norm(head-end) < 1e-8, 'A finger joint detached'
                assert scale == 1, 'Main phalanges must not telescope'
                end = head + rotation @ (curve[j+1]-curve[j])
                maximum_length_error = max(maximum_length_error, abs(np.linalg.norm(end-head)-np.linalg.norm(curve[j+1]-curve[j])))
                lowest_digit = min(lowest_digit, head[1], end[1])
            tips.append(end)
            if u == 1:
                assert np.linalg.norm(end-pose['wing_carpal'][1]-rig.fold_nodes[k][-1]) < 1e-8, 'Approved folded fingertip changed'
        rays = np.asarray(tips)-pose['wing_carpal'][1]
        carpal = pose['wing_carpal'][0]
        angles = np.arctan2(rays @ (carpal @ rig.across0), rays @ (carpal @ rig.avg0))
        minimum_fan_gap = min(minimum_fan_gap, float(np.diff(angles).min()))
        assert np.diff(angles).min() > 0, 'Finger order reversed during the fold'
        for name, (rotation, head, _) in pose.items():
            assert np.isfinite(head).all() and np.isfinite(rotation).all()
            assert abs(np.linalg.det(rotation)-1) < 1e-10
            if previous:
                change = Rotation.from_matrix(previous[name][0].T @ rotation).magnitude()
                maximum_rotation_step = max(maximum_rotation_step, float(change))
        previous = pose
        # Both side builders use the same path, mirrored at every sample.
        left, right = rig.clip(float(u), 1), rig.clip(float(u), -1)
        mirror = np.diag([-1., 1., 1.])
        for name, (rotation, head, scale) in left.items():
            other = right[name[:-1]+'R']
            assert np.max(abs(other[0]-mirror@rotation@mirror)) < 1e-10
            assert np.linalg.norm(other[1]-mirror@head) < 1e-10 and scale == other[2]
    assert maximum_length_error < 1e-10
    assert maximum_rotation_step < np.deg2rad(2), 'A joint snaps between adjacent poses'
    assert lowest_digit > .2, 'A wing finger sweeps below the intended ground clearance'
    # Each overlapping activation starts and finishes with zero angular speed.
    for name, interval in rig.motion.items():
        if not isinstance(interval, list):
            continue
        a, b = interval
        assert rig.progress(name, a) == 0 and rig.progress(name, b) == 1
        assert rig.progress(name, a+1e-5) < 1e-7
        assert 1-rig.progress(name, b-1e-5) < 1e-7
    return {'samples': 501, 'max_length_error': maximum_length_error,
            'max_joint_step_degrees': float(np.rad2deg(maximum_rotation_step)),
            'min_fan_gap_degrees': float(np.rad2deg(minimum_fan_gap)),
            'lowest_digit_model': float(lowest_digit)}


if __name__ == '__main__':
    print('WING_MOTION_CHECK ' + json.dumps(check()), flush=True)
