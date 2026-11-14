# Moon anatomy review — 13 November 2026

Research and diagnosis in response to the in-game review. The subsequent
corrective build is documented in character-models.md and implemented by
moon_full_pass.py and moon_face_anatomy.py; the table below records the rejected
build's causes, rather than describing the corrected asset. Gameplay tests established functionality, not
likeness, mouth clearance, blink coverage or parity with Clay's anatomical detail.

## Reference hierarchy

Use the cached Moon Rising cover and official How to Draw Moon image for Moon's
appearance, and the user-supplied colored NightWing image for the requested cap,
crest, musculature and resting-wing treatment. The coloring of that supplied
image is not independently attributed here. Its side view constrains silhouette,
not hidden transverse dimensions. Clay supplies the successful construction
methods; other NightWing views supply cross-checks for tribal skull shape.

The colored images show a bounded nasal cap with nostril structure, rather than
a horizontal transition into the throat color. The upper muzzle is a supported
wedge with a localized terminal overhang, not a generally drooping soft nose.
The cover's horn value is affected by strong green ambient lighting; material
differences must be judged under the same neutral lighting as the head.

## Confirmed construction problems

| Area | Current source | Consequence and correction |
| --- | --- | --- |
| Neck and torso | dragon_anatomy.json has a simple narrow elliptical trunk. moon_full_pass.py retargets named limb/girdle pieces, but does not retain Clay's detailed trunk sections, keel and asymmetric dorsal/ventral depths. | Limb muscle names alone do not reproduce Clay's anatomy. Retarget the full trunk architecture and cervical-to-shoulder transitions, then adjust NightWing proportions. |
| Relative size | Moon model scale is 1.5 versus Clay 2.0, in addition to narrower model-space sections and reduced muscle radii. | Several reductions compound. At the skull attachment, Moon's base half-width is .15 model units (~.225 world units); Clay's documented corresponding half-width is ~.234 (~.468 world units). These are base-section comparisons, not final posed skin measurements. Establish matched front/side/top proportions before selecting another head shrink factor. |
| Horns | Uniform satin color 697780 against much darker scales. | Excessively bright contrast in the game. Retain a different keratin response but use a darker, related charcoal tone and a root transition guided by the art. |
| Dorsal crest | Each body spike has four vertices and four triangular faces. | These are tetrahedral placeholders. Replace with seated, thickness-bearing swept blades, curved silhouettes, fitted roots and a graded neck-to-tail sequence. More polygons alone will not fix their shape. |
| Muzzle | Anterior extension, transverse rounding and downward displacement are applied to the facial host. | The local beak cue became an excessive whole-tip droop. Restore the supported maxillary profile and fit a separate nasal-cap object with a bounded seam and modeled nostril apertures/cavities. Preserve breadth behind the taper. |
| Color | mesh_color switches to a belly mixture whenever head y < 1.74; the whole jaw is mostly belly color. | This is an arbitrary world-height rule, not a traced anatomical boundary. Remove it in favor of reference-defined cap/face/jaw regions. |
| Teeth | Two lateral rows sampled at uniform longitudinal intervals; global y quantiles determine seats. Every crown advances .011 in z over .027 in height. There is no anterior arcade. | The visible forward lean and absent front lower teeth are explicit construction choices. Reuse Clay's final shared bite frame, surface-seated curved gum arches, anterior upper/lower rows, crown spacing and restrained recurve. |
| Tongue | A three-point flattened tube at fixed coordinates is bound to the jaw. | It is not fitted to the oral floor. Reuse the floor-referenced muscular tongue construction and verify full thickness clearance throughout jaw motion. |
| Lip/chin | Upper host and dentary are independently lofted, independently deformed and brought together with a 17-degree jaw rotation. | No shared final closure boundary guarantees a flush bite. This is a likely source of the ledge; confirm with sections. Reconstruct continuous lower lip/chin tissue around the bite, retaining a real opening seam between the jaws. |

## Eyes: research and the actual mismatch

UC Davis describes horses' eyes as laterally placed with extensive monocular
vision and a smaller frontal binocular field. This supports lateral orbital
placement as the structural analogy, not large humanlike forward-facing eyes.
[UC Davis Ophthalmology Service article](https://cehhorsereport.vetmed.ucdavis.edu/news/10-things-you-might-not-know-about-equine-ophthalmology).

The current Moon iris axis is hard-coded to [.65, .06, .76] (mirrored per side):
about 49.5 degrees forward from the transverse direction. Clay's [.98, -.12, .12]
is only about 7 degrees forward. These are geometry axes, not measured visual
fields. Moon's iris direction was chosen separately from her source socket/lids;
they should instead share an orbital frame fitted to the head.

An equine veterinary textbook describes a horizontally oval eyelid opening,
cornea and pupil, and predominantly downward upper-lid motion. Its excerpt is
searchable, but the full 43 MB PDF could not be opened by the web reader, so this
review does not claim a page-by-page examination.
[Equine Ophthalmology, examination chapter](https://catalogimages.wiley.com/images/db/pdf/9781119047742.excerpt.pdf).

A primary observational study measures corneal coverage during complete blinks,
which is a useful verification model: check actual visible coverage, not merely
the presence of morph targets.
[Blink patterns and kinematics of eyelid motion in ophthalmologically normal horses](https://pubmed.ncbi.nlm.nih.gov/30085864/).

For Moon, use the equine analogy for seated globe, orbital support, corneal
curvature, canthi and lids wrapping the globe. Retain the dragon reference's
green iris and slit pupil; a literal horse pupil would change the design.
Clay already has a shared eye frame, fitted facial host, canthal attachments,
curved staged lid surfaces and a caruncle. Port that assembly coherently instead
of combining separately generated sockets, eyelids and forward-pointing iris caps.

## Required verification for the corrective pass

1. Match whole-body front/side/top proportions before surface detail. Compare
   head/skull width, neck attachment, shoulder/chest depth, waist and haunches
   with Clay and the NightWing references at controlled camera settings.
2. Inspect the fitted nasal cap and nostril depth from front, top and profile;
   inspect horn contrast and the swept crest under neutral light.
3. Show closed, partly open and fully open bite sections. Verify upper/lower
   front teeth, gum-root seating, interdigitation, tongue-floor clearance and
   a lower lip/chin without an unintended shelf.
4. Inspect both eyes from front and each side at rest, partial blink and full
   closure. Check the host/globe/lid fit, canthal stability and iris coverage.
5. Verify those same structures in the actual village during walking, looking,
   fire and flight. Keep the separate preview untouched.

The prior inferred metric dimensions and mass are provisional and must be
recomputed after the proportions are corrected. They cannot justify the current
head/body imbalance.
