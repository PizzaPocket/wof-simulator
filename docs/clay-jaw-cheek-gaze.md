# Rear jaw, curved cheek attachments and upward breathing aim

The user rejected two features in the mouth review: a lower jaw that reads as
flat through its rear half, and straight cheek webs crossing the gape like
perpendicular curtains. The intended construction preserves the fairly straight
front dentary and restores the rear ramus/jowl sweeping upward into the head.
The How to Draw and limited-edition mouth references support the visible rear
return; their differing perspective is not treated as orthographic measurement.

## Geometry

The authoritative `resculpt_rim_zy` and `resculpt_bottom_zy` profiles in
`head_design.json` now rise smoothly in the finished skull frame after rearward
coordinate u=0.25, reaching their full adjustment at u=0.60. Rim adjustment is
0.105 model units, underside adjustment 0.075. The front bite margin, jaw width,
chin construction, hinge and tooth layout remain. The updated profiles were
inverted through the existing snout and axial compaction transforms, so the
curve is defined in the finished head rather than guessed in world height.
These are fitting parameters guided by the reference silhouette, not a claim
of exact dimensions reconstructed from the illustration.

The cheek web uses cubic curves in each actual open pose. At the front mouth
corner its upper tangent turns back along the upper jaw and its lower tangent
returns forward along the lower jaw. The two skin/lining layers and rounded
front rim stay connected. Three absolute corrective shapes at 0.3, 0.6 and
0.9 radians are solved back through the existing oral-bone skinning matrices.
Runtime weights adjacent `cheekOpen` samples, preserving the rigid upper/lower
attachments while the middle unfolds. This replaces the web's lateral-only
`jawOpen` bulge; the body's independent `jawOpen` lining correction remains.

## Camera tracking and skull lift

The emission axis in the sculpt's rest pose points steeply downward. The former
20-degree gaze correction could not counter it, so looking up still fired into
the ground. Gaze now calibrates against the actual rest emission axis, including
the existing mouth-normal slope. Camera elevation becomes the desired world
emission elevation in the rear tracking hemisphere. A 95-degree skeletal
correction limit covers the camera's upward range despite the downward sculpted
rest pose. Yaw and pitch are distributed through cumulative neck/head frames,
so side-looking does not dilute the upward correction. The front hemisphere
still eases back to its neutral display pose.

Breathing adds a five-degree upper-skull lift around the head's own right axis,
blended with mouth opening. The jaw/oral helpers follow that lifted head frame.
The emission origin follows the mouth, while its direction uses the pre-lift
gaze frame, preserving the player's intended aim. Reset restores the unlifted
head rotation. No extra flame layer is introduced.

## Checks and integration

The built head's cheek attachment error is at most 1.2e-7 model units. Its minimum
finite-difference tangent alignment with the jaw lines is 0.99973 across all
three authored poses and both layers/sides. The front rim remains planar to
its prior tolerance, the rear rises 0.106 normal units, and minimum jaw wall
depth remains over 0.071 model units.

Runtime checks matched camera/fire elevations at -22.9, 0, 20.1 and 37.2 degrees,
including left/right views in the rear hemisphere. The measured breathing skull
lift is five degrees without changing those aim angles. Gaze/jump/flight and
fire lifecycle regression checks pass on the previously installed asset.

The head-only preview was reviewed in paint and plain clay at closed, half-open
and full gape. Full-model export uses the verified untrimmed head cache and the
normal staged game exporter, regenerating the adjoining neck skin and lining.
Final combined-asset review and QA import follow that export.

Commands:

```sh
Blender --background --python game/tests/check_jaw_cheek_geometry.py
Godot --headless --fixed-fps 60 --path game --script res://tests/gaze_fire_elevation_smoke.gd
Godot --rendering-method gl_compatibility --path game --script res://tests/render_jaw_cheek_gaze_review.gd
```

An older `check_head_source.py` lip-depth assertion expects a minimum above
-0.013; the unchanged prior head already measures -0.02292. This baseline failure
is recorded rather than changing the unrelated approved lip contour or silently
relaxing its threshold.

Lesson: a straight tooth-bearing margin does not imply a planar entire jaw.
Round the cheek in its posed state, preserve its boundary tangents, and invert
skinning for corrective targets; volume-preserving weights alone do not define
a natural mouth-corner contour. Camera gaze should be calibrated against the
sculpt's real forward axis rather than assuming its rest pose is level.
