# Shared dragon movement

Clay, Umber, Moon and Blue now use the same procedural movement pipeline.
`tribe_dragon_motion.gd` inherits `creature_motion.gd`; its own work is limited to
anatomy-specific wing storage/folding and rig initialization. It does not carry a
second walking, running, jumping or flight loop.

## Anatomy contract

`dragon_rig_profile.gd` adapts each generated rig into the existing solver schema:

- Actual shoulder/elbow/wrist/knuckle and hip/knee/heel/ball positions supply limb
  lengths, bend planes and distal vectors. Joint rotations do not resize bones.
- The neck and tail supply their actual chains and lengths. The existing gaze,
  tail contact/follow-through and aerial posture solvers read those chains.
- Common limb/core bone roles use the generator's established names. Extra toe,
  metacarpal and thumb chains are discovered by the shared gait solver. Moon's
  rebuilt rig includes the articulated digits, rather than binding every toe to
  the hand/foot as one rigid piece.
- Wing roles identify each shoulder to the flight solver. A two-wing NightWing
  and four-wing SilkWing use the same launch effort, ascent, descent/glide,
  clearance, power-stroke and recovery timing. Recovery joint rotations sample
  a quarter of the rig's own fold and use Clay's common recovery limits.
- World stride distances scale against model size and measured limb lengths.
  The original Clay configuration at scale 2 stays the baseline. Smaller shared
  MudWing instances scale their distances through the same entry point.
- Retargeted landing contacts are projected into each limb's actual reachable
  ground region on touchdown. Stance anchors then remain in world space; the
  gait does not slide them every frame to conceal an unreachable target.

## Shared components

The adapters instantiate the actual existing `quadruped_gait.gd`,
`gallop_gait.gd`, `sprint_bound.gd`, `jump_motion.gd`, `flight_limbs.gd`,
`flight_motion.gd`, `neck_gaze.gd`, `tail_motion.gd`, `blink_cycle.gd` and
`fire_breath.gd`. All playable dragon actors can use `surface_climb.gd` through
the common player controller. Human capabilities remain separate.

The full sprint retains the accepted hand catch, hindquarter loading, suspension,
recovery, body pitch, spine/chest/pelvis movement and planted-foot logic. Flight
retains the stronger initial launch, sustained powered climbing and reduced
flapping during descent. There is no always-flapping tribe-specific oscillator.

## Moon's wing and surface attachment

Longer humeral and forearm segments support the spread fan. Outer rays extend
the span; body-side rays are shorter. Contracted fingers stay in anatomical order,
with the pointer lower than the second ray, while the fan gathers and cups outward.

The wing arms use the Clay construction pattern: humerus, radius/ulna,
olecranon, deltoid, upper-arm and forearm muscle profiles, terminal tendon,
carpal saddle and metacarpal knuckles. Finger skin contains the knuckle bulges
and blends around the articulated joints.

The main membrane and axillary web share every sample along the articulated
body-side finger, not just its wrist and tip. The web's proximal row follows the
actual trailing shoulder–elbow–wrist chain, slightly buried in arm tissue, with
bone weights following the articulated arm. There is no separate triangle
spanning shoulder to wrist: that shortcut put membrane in front of the elbow
during folding. The membrane releases smoothly from arm weights into the finger
and body web; all boundaries keep matching bind positions and weights. Rig
metadata records the trailing attachment samples for exported-skin checks.

The body is one continuous scaled host. Its ventral plates are ray-fitted to
that surface with interpolated host weights; the competing cervical overlay
was removed. The underside palette continues under the jaw. The rear oral wall
sits at the mouth hinge, and the tongue is fitted above the lower-jaw floor.

A measured lowest rest-skin point sets the model's offset above the collision
floor. The gait's pad height uses the same measurement, avoiding an elevated
visual model with independently guessed foot targets.

## Verification

`shared_dragon_motion.gd` uses real village actors on a flat collision fixture.
It checks common component implementations, four limb chains, distal digits,
sustained travel, full sprint and suspension, reachable planted contacts, staged
jump, launch effort, descent/gliding, powered ascent, flight limb carriage,
wall acquisition, vertical climbing and release. It also checks Blue's four
wing roles through the same system.

`moon_game_pass.gd` exercises actual possession, movement, fire and flight. It
skins vertices from the imported GLB at five fold amounts to check both membrane
seams, preserves every support length, and checks folded finger order/height.
It captures the actual village, including an intermediate fold, eye closure,
open mouth, walk, run and flight. No separate model preview is updated.

The existing Clay run/jump and cast/boundary smoke tests provide regression
coverage of the shared-code changes. Passing these checks establishes the
covered behavior; visual likeness and nuanced animation remain reviewable in
normal gameplay.


## Reusing the corrected construction

The future ancient Darkstalker asset now uses the same complete NightWing
construction as Moon, with profile deltas in `darkstalker_design.json`. His
actual shared movement adapter and articulated wing rig are checked in isolation;
he remains excluded from gameplay. Seam error is also checked after multiplication
by his much larger world scale. Blue's reference/anatomy pass is recorded in
`blue_design.json`; his existing mesh is not presented as the finished rebuild.

Darkstalker's larger body exposed a second surface-fitting lesson: connecting
ray-fitted plate corners can create chords that cut through a curved host between
the corners. Ventral patches are now clipped from actual host triangles, with
interpolated normals and matching skin weights, and the builder checks signed
centroid clearance. This construction change is available to both NightWing
profiles; this follow-on pass rebuilds Darkstalker only.
