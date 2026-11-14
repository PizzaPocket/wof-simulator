# Clay runtime locomotion: first pass

The playground also has [camera gaze, jumping and demo flight](clay-gaze-jump-flight.md).

This changes the Godot integration, not Clay's sculpting source. Anatomy comes
from `prototypes/clay/body/body_design.json` and the exported skeleton. Runtime
choices are in `game/data/locomotion.json`; they are tunable adaptations for a
fictional dragon, not measurements of a real dragon or a muscle simulation.

## Wing discrepancy and repair

The web viewer samples `wings_fold` and also blends adjacent `wingFold1` through
`wingFold8` corrective shapes. The initial Godot playground sampled only the bone
clip. That omitted the authored membrane and soft-tissue corrections.

There was a second discrepancy at intermediate folds: the default Godot import
resampled/optimized animation keys. Comparing bone matrices with direct glTF
sampling found a maximum element difference of about 0.11 at a sampled fold.
Raising the import rate reduced but did not remove it. Runtime now samples the
original glTF translation, quaternion and scale keys exported in `clay_rig.json`.
The sampled comparison then agreed to about 0.0000005. Corrective weights use the
same adjacent-sample rule as `prototypes/clay/head/head-viewer.js`, without additive
accumulation. Godot's [import documentation](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)
describes animation optimization and the option to disable it for broken imports.

This establishes sampler parity, not a universal proof of membrane clearance.
There is no runtime cloth or membrane collision solver. The authored shape
samples remain responsible for the wing's clearance through its fold.

## Walk evidence and implementation

Cat forelimb studies show coordinated shoulder and elbow movement during recovery,
with the wrist contributing paw orientation. The implementation therefore solves
the paw path first, fits the two proximal links, and controls the distal link
separately. It does not drive all joints with independent sinusoidal swings.
[Forelimb coordination study](https://pmc.ncbi.nlm.nih.gov/articles/PMC6230802/).

The muscle model distinguishes stance support from recovery flexion and describes
different forelimb and hindlimb behavior. Clay's measured muscle attachments and
rig weights are retained; the forelimb gets a different wrist recovery angle from
the hindlimb hock. These are qualitative adaptations rather than copied cat joint
angles. [Forelimb morphology study](https://pmc.ncbi.nlm.nih.gov/articles/PMC11737544/).

Walking support alternates between two and three paws in the cited cat study.
The initial schedule is LH → LF → RH → RF, with a 0.68 stance fraction, and the
runtime admits no more than two recovery paws at once. Support/reach checks can
request an earlier step or slow a turn. This preserves stance contacts during
body translation and small body bob/roll. Raycasts set touchdown heights; they
do not simulate contact forces. [Walking support study](https://pmc.ncbi.nlm.nih.gov/articles/PMC4644224/).

Each recovery has lift, forward transport and a smooth landing. Wrist/hock flexion
provides clearance. Late stance raises the heel about the pad, with the toe bones
counter-rotating against the ground. The existing rig has one bone per digit,
so this cannot reproduce separate phalangeal flexion. It also lacks an independent
scapular bone; shoulder sliding would require a source rig change.

## Tail evidence and implementation

The source specifies 36 caudal vertebrae, with decreasing lengths and a curled
resting pose. Its modeling rig groups three vertebrae into each of 12 bones. The
game export now uses an extended bind and one bone per vertebra; see the
[tail and flight-limb update](clay-flight-limbs-tail.md). Runtime preserves segment
lengths and the dorsal frame, with a damped hip trail, ground clearance and
self-contact protection. Teleport/reset discards the previous trail.

Feline anatomy identifies separate dorsal, ventral and lateral tail actions.
This supports treating the tail as a jointed chain rather than a rigid appendage;
the particular idle wave and trail-following behavior here are animation choices.
[Tail muscle study](https://www.jstage.jst.go.jp/article/jvms1991/56/6/56_6_1107/_pdf).

## Remaining limits

- Sprint uses the walk solver at higher speed; a distinct trot/run is not authored.
- Uneven/steep ground needs better foot-normal alignment and body placement.
- There is no paw friction, dynamic balance, muscle bulging or secondary flesh simulation.
- Legs use the existing skin weights; deep flexion may still need corrective shapes
  to preserve muscle volume.
- Wing clearance inherits the source's finite samples; broad membrane self-collision
  guarantees would need further source checks or a cloth/contact solver.
- Tail and wing surfaces do not collide physically with props or the controller capsule.
