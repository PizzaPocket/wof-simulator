# Responsive movement and reference-led pose cleanup

## Jump and ground speed

Walk increased from 4.2 to 5.8 m/s and run from 7.5 to 12.5 m/s. Hold Shift or
controller LB/L1 to run. The existing controller action is exercised with an
injected shoulder-button event in the integration check.

Grounded jump preparation/push shortened from 260 to 65 ms. Preparation no longer
cuts horizontal speed to 30%. Takeoff adds a modest 1.15 multiplier to existing
horizontal velocity, and airborne control retains momentum when input is
released. Steering is limited to 5.5 m/s². Vertical launch is 9.2 m/s, gravity
24 m/s². Flat-ground integration measures approximately 5.2 m from a walking
jump and 11.3 m from a running jump, without flight activation. Stationary jumps
remain vertical. Moving landings return to the gait after 100 ms, while stationary
landings retain a longer 220 ms absorption; the torso blends out of that pose. Double taps still buffer/activate flight.

## Gallop

A transverse gallop uses staggered hind contacts (0.00/0.10), then fore contacts
(0.30/0.40), with 0.26 stance fraction and a gathered suspension phase. Its
4.2 m stride is driven by actual distance travelled. Foot anchors remain in
world space during stance; recovery folds the wrist/hock and curls digits.
Body rise/pitch, paired contacts and suspension distinguish it from the four-beat
walk. Entry/exit blend paw targets and torso motion. The IK preserves the
existing skeletal lengths, bend planes and soft-tissue controls. Walking
recovery duration now adapts during acceleration so an early slow step cannot
hold a hind paw behind the faster body.

This is an artistic dragon adaptation of the mechanics described by
[Bertram and Gutmann, 2009](https://doi.org/10.1098/rsif.2008.0328), not a dynamic
muscle/force simulation. The collision capsule stays grounded during the visual
gallop suspension; actual airborne collision follows jump/flight physics.

## Flying hindlimbs

The user-supplied flight illustrations favor more knee flexion and a foot closer
to the body. Asymmetry and engaged carriage remain. Hock bend is measured from
the actual posed shank and metatarsal directions; a body-space pitch alone would
not guarantee comfort during banking. Flight clamps that flexion to 35–95°
from straight. Glide/climb/descent/bank checks observe knees at roughly 66–86°
included, with hock flexion around 58–62°.

## Tail and mouth

The last 0.32 model units of needle taper are removed. The retained taper ends
in a short rounded closure, with all 36 tail segments and collision envelopes
rebuilt to match. The earlier long cap is no longer needed.

The accepted shortened snout stays the same length. Its shortening transition
now follows the muzzle axis, and jaw/face trimming uses the original coordinates
of the body-weld contour. This addresses the mismatched cut boundary and crease
artifacts. Per user correction, the original lower-jaw underside landmarks are
preserved: extra dentary thickness goes upward, with the rim tucked beneath the
upper lips. See the source head sheet for construction and matched views.

Remaining: fine surface faceting at the neck join; gallop torso dynamics and
muscle-volume changes are stylized rather than physically simulated.
