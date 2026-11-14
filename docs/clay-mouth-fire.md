# Clay mouth resculpt and fire breath

The rejected mouth pass left several competing constructions: a detailed lip
height profile with small alternating troughs, an additional raised front
corner, a lower rim copied from the upper head, and a minimum-depth correction
pushing that rim up again. The lower jaw also narrowed behind the broad chin.
These read as a notched front-to-side lip, an irregular bite bed and a pinched jaw.

The new lip has a continuous front/corner turn, a broad first downward side
lobe behind the corner, and a shallower second lobe in the posterior half.
Landmarks are specified in the finished head frame and inverted through the
proportion edits before construction. Its
closing surface meets the exterior's actual endpoint, including the corner
lift, instead of estimating that endpoint from the unmodified station width.
The lower dentary has its own straight margin, a gradual width progression and
no separate front-lip lift. Its existing underside landmarks are preserved.
The original head compacting transform remains in place; the exposed rim is
straight in the head's anatomical frame. Behind it, the concealed ramus still
rises toward the hinge. The oral floor has 24 transverse segments rather than 6.

References inspected locally: `covers/Clay_htd_png.png`,
`clayref/Clay_TDPLE.jpg`, and the open-mouth art in the previous jaw review.
The front-face diagonal in the three-quarter drawing is not traced as a true
side profile. The upper lip dips around its anterior side lobe and returns
upward into the flatter rear run; the lower jaw is a simpler structure behind it.
Reference images and generated models remain ignored.

Teeth are an animal-inspired adaptation. The anatomical source is
[Janeczek et al., Biology 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC9953444/):
recurved crowns seated in oral tissue, with smaller anterior teeth. Clay uses a
fuller oval section rather than literal Komodo cutting blades. Teeth and their
U-shaped gum beds are now built against the final compacted jaw surfaces.
Crown widths follow their spacing independently of height, preventing the old
clearance-based length cap from shrinking both dimensions into tiny needles.
The side rows have 12 upper and 11 lower crowns per side and six smaller crowns
along each curved anterior arch. Paired corner crowns are 15% taller than the
largest regular crowns, with more space for fuller bases. The gum bed follows
a continuous ellipse into the side rows, rather than making square corners. Crowns are rigid with their jaw, not proportion-warped enamel.

Hold **R1 / right bumper** or **V** for fire breath. The jaw opens to 0.9 radians;
ignition waits until 0.68 radians. Releasing stops new particles immediately and
closes the jaw smoothly. Reset clears the flame. Right/left analog triggers
retain wing-fold adjustment. Fire currently supplies a visual jet, without
combat damage or ignition of scenery.

The flame recipe follows the local Eleblorb project's
`scripts/suit_power_fx.gd::make_fire_stream` and `particle_fx.gd`: soft irregular
billboards elongated along velocity, additive pale-yellow/orange/red lifetime
colors, and low turbulence. Here the stream uses world-space particles so an
already-emitted flame does not swivel with Clay's head. Its source follows the
actual `fire_origin` bone after gaze/neck motion. Jaw and oral-helper poses are
evaluated after gaze, preserving the hinge while opening the cheek and throat.

Verification commands (use the application's full path on this Mac):

```sh
Blender --background --python-exit-code 1 --python game/tests/check_head_source.py
Godot --headless --path game --log-file /tmp/wof-fire.log --script res://tests/fire_breath_smoke.gd
Godot --path game --log-file /tmp/wof-mouth-review.log --script res://tests/render_head_review.gd -- resculpt
```

The source check verifies monotonic proportion warping, the straight dentary
margin, exact mouth-surface boundaries and the final-frame placement of both lip lobes.
The runtime check exercises opening before ignition, sustained/released fire,
head tracking, hinge attachment and reset. Rendered review includes side, front,
three-quarter and underside views in paint/plain clay at 0, 0.4 and 0.9 radians,
plus the active flame.

Final front-corner correction: `upper_inner_edge` supplies one boundary to both
the loft closure and the front-cap convexity. Its front arc is shallow across
the whole width and meets the side endpoints; behind the corner it blends onto
the structural palate. A source check specifically prevents the old front-centre
height from returning. The graphical fire test also bakes the posed mesh and
checks three paths from the internal origin through the open mouth.

## Skull-frame fit after visual review

The full line ends at the front attachment of the ear. Its rear cheek hook is
part of that line, followed by an S return; the exact cheek cut preserves this
small feature and transfers skin weights, attributes and all expression keys.

The pointed front-side lobe in the rejected preview was a world-Y deformation.
The active contour now uses broad shallow relief along the skull normal. Both
jaw beds share that frame, the lower rim is one plane without a coronoid stair
step, and the underside has been resculpted at varying normal depth. This
supersedes the earlier attempt to preserve the old underside and fill the gap
with a longer cheek web. The upper palate, lower floor, gum arches and tooth
axes are fitted together; front teeth stay behind the muzzle wall. The posterior
fire source and oral cavity are remapped with them.

`game/tools/remap_mouth_frame.py` encodes canonical frame measurements into the
construction profiles. `game/tools/build_head_preview.py` builds an isolated
head (and caches its untrimmed parts for iteration). `render_head_preview.gd`
checks the actual closed and articulated shapes. Numeric checks verify fit
and interpolation; the rendered comparison is the aesthetic review.

The final assembled review exposed a jaw/throat gap that the isolated head
could not show. The attachment must follow the lateral underside of a rounded
jaw, rather than its lowest centre line. A forward fillet allowance retains
the connecting throat tissue, with a posterior section overlap into the neck.
`check_throat_attachment.py` probes those former gap locations in the actual
union field. This fit is also checked in closed and articulated native renders.


The front-corner follow-up increases the first side dip to 0.022 along the
skull normal, keeping its broad bottom and rearward position. The muzzle cap
and side share a rounded annulus; topology checks require two incident faces
per edge and no degenerate faces. This replaces the hard planar front seam.

The visible orange corner tab came from the old rapid lip-width tuck over
z=1.95–1.99, alongside the front chamfer. Its projected boundary doubled back
in three-quarter view. Spread that width transition over z=1.88–2.017 while
retaining the front width and the independent skull-normal side dip.
