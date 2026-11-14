"""Check tail terminal coverage and that exported eyes resolve iris boundaries."""
import runpy
from pathlib import Path
x = runpy.run_path(str(Path(__file__).with_name('verify_foot_skin.py')))
np, array, attributes = x['np'], x['array'], x['attributes']
p = array(attributes['POSITION'])
part = x['part']
a = array(attributes['_ABZ'])
skin, shell = x['skin'], abs(part - 13) < .1
skin_end, shell_end = float(p[skin, 2].min()), float(p[shell, 2].min())
assert abs(shell_end - skin_end) < .008, (skin_end, shell_end)
terminal = skin & (p[:, 2] < skin_end + .03)
assert a[terminal, 2].max() < .25, 'Bare light skin at terminal cap'
for side in (-1, 1):
    eye = (abs(part - 6) < .1) & (p[:, 0] * side > 0)
    assert eye.sum() > 5000, 'Eye grid too coarse to resolve iris change'
    for edge in (.085, .09, .095, .155, .165):
        assert np.count_nonzero(eye & (abs(a[:, 0] - edge) < 1e-6)) >= 64, edge
print('PASS: tapered terminal shell reaches skin endpoint; iris/pupil edge rings resolve on both exported eyes')
