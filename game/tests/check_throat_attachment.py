"""Check that tissue remains inside the fitted lateral jaw-to-throat bridge."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'cache/clay-python'),str(ROOT/'prototypes/clay/body'),str(ROOT/'prototypes/clay/head')]
sys.argv=['check_throat_attachment']
import numpy as np
import build_body as B
B.skin_setup()
points=np.array(B.B['anatomy']['head_weld']['fit_probe_points'])
distance=B.SK.field(points,B._SKIN['trunk'],B._SKIN['parts'])
assert distance.max()<-.001, list(zip(points.tolist(),distance.tolist()))
print('PASS: posterior lateral jaw-to-throat tissue remains connected; field distances',distance.tolist())
