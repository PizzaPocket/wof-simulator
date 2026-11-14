# Connected front and hind feet

## Diagnosis and evidence

The existing hand/foot belly was a single ellipsoid. Its distal end narrowed to
a point near the central knuckle/ball, while four toe roots were offset sideways.
The outer roots lacked a corresponding metapodial continuation. The toe skin had
three segment-shaped field pieces, but every segment and claw followed one bone.
The comment saying “a bone per segment” described the field construction, not
the exported animation hierarchy.

The indexed side sheet shows a continuous hand dividing into clawed digits and
long hind-foot rays. How to Draw gives a clearer oblique front view: the hand is
compact and broad; the hind metatarsal region continues into individual toes.
The SE poster and limited-edition render inform the carried, flexed pose.
Occluded digits are not treated as evidence for deleting an authored digit.

Reference crops use a 1400-pixel working width:

| Image | Crop (x0, y0, x1, y1) | What it establishes |
| --- | --- | --- |
| ClayTemplateS978.png | 320, 725, 600, 860 | Palm, knuckles, terminal claws |
| ClayTemplateS978.png | 850, 725, 1150, 860 | Continuity through the hind-foot rays |
| Clay_htd_png.png | 305, 1170, 750, 1450 | Oblique fore/hind digit roots and splay |

For the side sheet only, the existing mapping is z = (700 − px) / 343,
y = (830 − py) / 343. How to Draw is oblique and supplies structural evidence,
not interchangeable orthographic coordinates.

Real anatomy references:

- [University of Illinois forelimb examination](https://vetmed.illinois.edu/demo-sa-orthopedics/orthopedic-exam-forelimb/)
  distinguishes metacarpals, digital joints and flexor/extensor action.
- [University of Illinois rearlimb examination](https://vetmed.illinois.edu/demo-sa-orthopedics/orthopedic-exam-rearlimb/)
  distinguishes the tarsus, metatarsal region and digital articulation.
- [Franini et al., 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9559242/)
  describes separate extensor tendons continuing over the metacarpals into the
  digits. This supports a continuous ray/joint/tendon arrangement.
- [Komodo hindlimb anatomy, 2025](https://pubmed.ncbi.nlm.nih.gov/39794978/)
  provides reptilian comparison for metatarsals, phalanges and clawed digits.
  Its five-digit arrangement is not substituted for Clay's design.

## Source changes

Each main digit now continues from its own metacarpal/metatarsal ray into three
phalangeal controls. Ray roots stay embedded in the existing palm/foot mass and
fan toward the actual digit bases. Their capsule fields fuse into the existing
skin, rather than adding separate visible bones or collars. The front thumb keeps
two phalanges; the heel spur stays attached to the hind foot.

The existing main digit root names remain valid. Added controls are fmeta/hmeta
1–4 and toe-name_p2/p3 on both sides, plus fthumb_p2. Claws are rigidly weighted
to terminal phalanges. Joint skin weights blend along adjacent segments. The
body's vertex-weight path now samples those gradients, as the wing-only path
already did, instead of reading only each field piece's fixed weight dictionary.

Outer main digits are 90% of the existing center-digit lengths, preserving the
existing segment ratios and claw dimensions. This modest taper is an artistic
adaptation from oblique references. It is not claimed as a precise measurement
of hidden anatomy. Ray radii, root fractions, blend widths, curl shares and
joint limits are encoded in body_design.json.

## Runtime articulation and review

The metapodial rays inherit the hand/foot transform. Phalanges inherit joint
positions from their parents; the runtime rotates them without relocating or
stretching individual segments. Main-digit flexion is shared 45/35/20 percent
across the three controls, with a two-joint thumb split. Supported digits extend
against distal-foot roll; recovery, jumping and flight use distributed curl.
The joint limits are conservative game tuning, not species-specific measured
range-of-motion claims.

Checks include source skeleton and skin-field continuity, actual exported skin
and claw influences, and runtime walk/turn/jump/flight/landing/reset articulation.
Native Godot captures show the same framing before/after, plain clay, sides,
top views and close-up motion. Review files and source artwork stay in ignored
cache/reference folders.

Final checks pass: 64 main ray/phalangeal source links have a continuous skin-field
margin of at least 0.027 model units; all 48 main phalanges and all 16 supporting
rays influence actual exported skin; all 18 main/thumb claws follow terminal
phalanges. The 973-frame runtime check retains connected joint positions and
segment lengths through walking, turning, jumping, flying, landing and reset.
Gait, gaze/flight, source wing-sampling parity and the 2,358-frame tail stress
regression also pass. The controlled tail-bind geometry check is unchanged.

The current skin remains voxel-derived and has visible faceting at extreme
close range. This pass does not add individual tendon simulation, toe pressure
or terrain-specific per-digit contact IK. Those are distinct from the corrected
skeletal and skin attachment paths.
