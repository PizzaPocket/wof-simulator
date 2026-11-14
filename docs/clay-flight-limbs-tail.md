# Flight limb carriage and smooth, protected tail

## Reference review

All 13 images listed in `prototypes/clay/tools/fetch_refs.py` were reviewed, with
local copies kept under the ignored `prototypes/clay/refs/`. The main flight-pose
evidence is the full flight render, special-edition poster, limited-edition render
and graphic-novel render. The standing side sheet remains useful for anatomy,
but its grounded limb pose is not a flight pose.

The repeated flight cues are flexed elbows, hanging/flexed wrists and hands, and
rear limbs carried behind the body. The poster has unequal hindlimb recovery;
the different illustrations do not prescribe one perfectly symmetric static tuck.
The horizontal flight render partly occludes the rear legs, so those hidden
joints were not treated as measurements. A gridded poster crop and projected
forelimb landmarks are recorded in `game/data/flight_limbs.json`; they are not
presented as orthographic 3D reconstruction.

The runtime now controls upper limb, lower limb, distal orientation and toe curl
separately. Measured segment lengths and joint roots remain fixed. Hands hang
rather than staying flat as if planted. The later [full-leg design pass](clay-full-legs.md)
replaces the initially exaggerated rearward hind-foot fold with relaxed,
gravity-led hanging and deliberate left/right differences in bend and height.
Entering/exiting flight and preparing
for landing blend the carriage continuously. The subsequent
[foot anatomy pass](clay-feet-anatomy.md) replaces the original one-bone toes
with articulated phalanges and supporting rays. Additional muscle-volume
corrective shapes remain future work.

## Why the extended tail had hiccups

The original game export used the sculpting source's tightly curled bind and
12 skinning bones, each spanning three of the 36 measured caudal vertebrae.
Rotating those long bones straight could not remove the curvature inside each
skinned span. Narrow weight handovers also emphasized individual bends.

The game export now makes an in-memory copy of the source data, builds the tail
extended, and uses one bone per measured vertebra. Smooth compact overlapping
weight kernels replace the narrow tail handovers. The sculpting source files and
their wrapped reference pose are unchanged. Export is staged in the ignored cache,
then installed only when complete; the previous asset is backed up there.

A controlled CPU-skinning comparison straightened both old and new binds and
sampled the centers of tail skin cross-sections. At the playground's scale, the
old bind had about **33 mm RMS / 124 mm peak** section-center error; the extended
36-bone bind had about **0.62 mm RMS / 1.35 mm peak** in the same sampled range.
This diagnoses the bind artifact, rather than claiming those values describe all
animated poses. Plain-clay and painted review captures check the rendered surface.

## Contact and continuity constraints

Runtime solves the whole chain instead of greedily aiming short bones one by one.
The latter became unstable during vertical root movement, so proximal points now
advect with the root while distal points lag. Targets follow the travelled path;
jumping eases into airborne carriage instead of dragging the tip toward the floor.

The solver restores measured lengths, regularizes curvature, limits bends to about
16° per control, respects ventral ground clearance, and separates nonlocal tail
capsules. Capsule radii are checked against the actual exported skin, armor and
spikes (over 36,000 tail-weighted vertices), with additional padding. Neighboring
parts of the same continuous skin are excluded from artificial self-collision.
A torso capsule also protects the free tail; the anatomical attachment region is
excluded because it is intentionally continuous with the hips.

Only an admissible solve is published. If an extreme target cannot converge in a
tick, the previous safe shape moves rigidly with the character while subsequent
ticks retry the target. That preserves self-clearance instead of displaying an
intersecting solver intermediate. It can make very tight path following lag.

T / D-pad down cycles normal follow, left curl and right curl. Curl magnitude
changes gradually and reverses through extension, making both side wraps easy to
review. R restores follow mode.

## Checks and remaining scope

`tail_flight_limbs_smoke.gd` exercises extension, both side wraps, reversal, a jump
with the tail curled, walking turns, climbing flight and sharp flight turns. It
checks conservative self/torso clearance, segment length, curvature, and actual
flight joint carriage. The graphical review includes a plain-clay tail close-up,
top views of the curls and side/front views of airborne limbs.

The final 2,358-frame stress run passed: minimum self clearance 40.2 mm, torso
clearance 41.9 mm, maximum local bend 16.56°, and maximum segment-length error
0.017 mm. Safe-shape carry was used on 578 stress frames. Movement, gait,
gaze/jump/flight and independent source-animation sampling checks also passed.

These are conservative kinematic contacts, not soft-body dynamics or per-triangle
collision with the entire character/world. The controller, toe rig and current
muscle skinning still limit extreme articulation. Source reference images and
generated GLBs remain ignored and are not committed to this public repository.
