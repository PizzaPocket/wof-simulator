# Continuous wing deployment

This pass preserves Clay's approved spread and folded wing endpoints, finger
lengths, outward brown armor, socket placement and the explicit half-length
accessory-finger convention. It changes the path between those endpoints.

## Evidence and articulation

The near plated fan on `clayref/ClayTemplateS978.png` supplies the existing
folded centerlines; the far plain fan is a different wing. The official
`covers/Clay_SEPoster_Isolated_Edit_png.png` supplies the spread fan order, and
`covers/Clay_sticker_no_bg_png.png` shows the outer arm armor and wrist claw.
Existing measurements and anatomical proportions are retained from the body
sheet. These static drawings do not specify animation timing.

Bat studies support coordinated groups of joints rather than treating a wing
as one rigid rotating panel: [Riskin et al., 2008](https://pubmed.ncbi.nlm.nih.gov/18621062/).
The staged timing here is an artistic adaptation for Clay, not measured dragon
biomechanics or a literal bat skeleton.

The shoulder carries the humerus, the elbow rotates relative to that moving
upper arm, and the wrist rotates relative to the forearm. Each finger is a
three-link forward-kinematic chain with invariant link lengths. Rotations at
its base, middle and tip overlap with small delays. This replaces tip-target IK
and blended centerline seeds, which could change the selected knuckle bend
between endpoint poses. The compact socket and existing posed muscle fields
continue to generate the skin and armor corrections.

`prototypes/clay/body/wing_motion.json` contains the timing windows separately
from the shared body/head design file. During folding, the hand begins gathering
before the shoulder finishes stowing; unfolding releases the shoulder first
and spreads the fan later. The same continuous path permits arbitrary partial
folds. Every joint window eases in and out. The wrist claw follows the forearm's
ending knuckle independently of finger motion. The accessory retracts through
its own smooth window.

Membranes follow the posed centerlines. Gathering starts after retraction begins;
pleat depth depends on local span compression and is capped by the available
space, instead of adding a fixed ripple to narrow panels. Sixteen corrective
samples replace eight, with adjacent absolute weights applied at runtime.

## Runtime control

Nominal fold/spread travel takes 0.65/0.55 seconds, with a short acceleration and
braking envelope (about 0.72/0.62 seconds total at 60 Hz). Reversing midway first brakes the moving wing. Reset clears
the controller's velocity. Flight keeps its separate deployment setting.
Flap-recovery reference rotations are sampled by normalized fold position,
independent of the number of exported corrective samples.

## Isolated build and review

The head/mouth sculpt remains separate. `game/tools/build_wing_preview.py`
builds wings only, with the actual skin, armor, claws and membranes. It saves
`cache/wing-fold-review/wing.glb`, unjoined `wing-parts.blend`, and the exact
exported animation tracks. It never writes `game/assets/clay.glb` or the shared
rig metadata. The preview uses the current body field only to locate the flank
membrane attachments; it does not build or alter the head.

```sh
Blender --background --python game/tests/check_wing_motion.py
Blender --background --python game/tools/build_wing_preview.py
Godot --headless --path game --script res://tests/wing_fold_review.gd
Godot --rendering-method gl_compatibility --resolution 1100x800 --path game --script res://tests/wing_fold_review.gd -- --render
```

The render script checks the real exported clip through the runtime sampler,
then writes side, front, plain-clay and joint close-up frames plus a moving
fold/spread sequence. The corresponding source viewer can read the updated
corrective count from its existing wing metadata.

## Integration and limits

The authored path and rebuilt corrective geometry become part of the main model
on the next coordinated full-body export after head sculpting. Runtime timing
changes are available immediately; the old exported asset retains its old
geometric fold path until rebuilt. No full dragon export is installed by this
pass. End-to-end body clearance in the combined final head/body asset remains a
check for that integration, since the isolated rig cannot prove it.

The membrane is posed geometry rather than simulated cloth; shared fingers do
not solve independent contact forces. Endpoint likeness still depends on the
existing approved construction and the differing perspectives of the source art.

Lesson: preserve endpoint silhouettes with joint-relative rotations and invariant
link lengths. A tip that reaches its intended destination does not establish a
natural intermediate knuckle path. Keep the number of corrective samples out of
flap and deployment timing assumptions.

## Verification results

The 501-pose source check passed: maximum link-length error 1.1e-15 model units,
maximum joint rotation between 0.002-spaced fold samples 0.536 degrees, and
preserved finger order and ground clearance. Both unjoined WingArm skins are
single connected closed surfaces (48,070 / 48,034 vertices), with no open or
nonmanifold edges and finite corrective shapes.

The actual Godot import passed 201 scrubbed poses: maximum local attachment
drift 1.2e-6 model units, mirrored joint positions, all 16 corrective samples,
0.717/0.617-second fold/spread and braking on a mid-fold reversal. Existing
motion, active tail/flight, and gaze/jump/flight integration checks passed on
the shared game asset with the runtime timing/controller changes.

Painted, plain-clay, joint close-up, side/front/top and moving review frames were
inspected in `cache/wing-fold-review/`. `fold-spread.gif` and `reference-review.jpg`
provide the review artifacts. The wing remains a stylized membrane with visible
gathering ridges rather than simulated cloth; final torso clearance is deferred
to the coordinated combined-asset review described above.
