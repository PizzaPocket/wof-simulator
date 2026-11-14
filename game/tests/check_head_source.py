"""Source checks for the compact muzzle and dentary body; run with Blender."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'cache/clay-python'))
sys.path.insert(0, str(ROOT/'prototypes/clay/head'))
sys.argv = ['check_head_source']
import numpy as np
import build_head as H
settings = H.D['head_compact_frame']
axis = H.norm(settings['axis_yz'])
anchor = np.array(settings['anchor_yz'])
u = np.linspace(-.05, .7, 2000)
points = np.column_stack([np.full(len(u), .1), anchor[0] + axis[0]*u, anchor[1] + axis[1]*u])
compacted = H.compact_head_points(points)
projected = (compacted[:,1:] - anchor) @ axis
minimum = np.gradient(projected, u).min()
assert minimum > .45, minimum
assert np.max(abs(compacted[:,0] - points[:,0])) == 0
forward = u > settings['axis_transition_model']
assert np.max(abs(projected[forward] - u[forward]*settings['length_scale'])) < 1e-9
# The lower rim is flat in the skull frame through its full length, without
# a separate steep coronoid ramp spliced into its rear.
frame=H.D['mouth']['frame']
origin=np.array(frame['origin_yz']);up=H.norm(frame['up_yz']);axis=H.norm(frame['forward_yz'])
def final(z,y):
    return H.compact_head_points(np.array([[0.,y,float(H.snout_z(H.premaxilla_z(np.array(z),np.array(y))))]]))[0,1:]
zs=np.linspace(1.405,1.98,400)
rim=np.array([final(z,H.interp(H.JAW,z,1)) for z in zs])
heights=(rim-origin)@up
u=-(rim-origin)@axis
assert np.max(abs(heights[u<.23]-frame['lower_rim_normal']))<.0007
assert heights[u>.5].max()>.05, (heights.min(),heights.max())
# The first lip relief is shallow and broad along the skull normal, not a -Y spike.
points=np.array([final(z,H.face_pt(z,0)[1]) for z in np.linspace(1.65,2.017,1500)])
u=-(points-origin)@axis;h=(points-origin)@up
first=(u>.07)&(u<.23)
assert h[first].min()>-.013,h[first].min()
flat=u[first][h[first]<-.009]
assert flat.max()-flat.min()>.025,(flat.min(),flat.max())
print('PASS: continuous skull-plane jaw rim and shallow broad lip relief perpendicular to the skull')
# Both oral closing surfaces must share their exact boundary with the outer skin.
for z in np.linspace(1.64, 2.002, 120):
    for contour in [H.upper_contour, H.jaw_contour]:
        points, edge = contour(z)
        assert abs(points[0][1] - edge(points[0][0])) < 1e-8, (z, points[0], edge(points[0][0]))
    assert H.oral_floor(z) >= H.interp(H.JAW, z, 2) + H.D['mouth']['floor_wall'] - 1e-9
# No little alternating dips/notches at the front/corner transition.
samples = np.linspace(1.88, 2.017, 400)
heights = np.array([H.lip_height(z) for z in samples])
slope = np.diff(heights)
turns = np.count_nonzero(slope[:-1] * slope[1:] < 0)
assert turns <= 1, turns
assert np.min(H.JAW[:,1]-H.JAW[:,2])>.035
print('PASS: monotonic shortening, straight independent dentary rim, continuous lip/palate and jaw/floor boundaries, one smooth anterior lobe, supported oral floor')

# The terminal cheek hook still returns to the actual ear base.
import json
body=json.load(open(ROOT/'prototypes/clay/body/body_design.json'))
line=np.array(body['anatomy']['head_weld']['cheek_line']['zy'])
hook=np.array([1.402,1.66]);ear=np.array([1.47,1.785])
assert np.min(np.linalg.norm(line-hook,axis=1))<1e-8
assert np.min(np.linalg.norm(line-ear,axis=1))<1e-8
print('PASS: complete cheek contour retains the rear hook and ear-root return')

# Front convexity ends on the real lip boundary, not on an obsolete station y.
points,edge=H.upper_contour(H.UPPER[0,0])
for x in np.linspace(-points[0][0]*.9,points[0][0]*.9,30):
    assert abs(H.front_setback(x,edge(x))) < 1e-8
print('PASS: front-cap convexity vanishes on the continuous lip edge')

# The front arc itself uses the lip height across its whole width. A side-only
# fix leaves the front centre on the old palate height and makes a corner notch.
z=H.UPPER[0,0]
points,edge=H.upper_contour(z)
assert abs(edge(0)-H.lip_height(z)) < 1e-8
assert 0 < edge(points[0][0])-edge(0) < .005
print('PASS: shallow full-width front lip arc meets both side corners')
