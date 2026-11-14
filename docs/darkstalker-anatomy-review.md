# Darkstalker: ancient-adult model pass

Darkstalker is now a scene resident in the village clearing at the user's request.
He remains outside the collectible roster. This pass uses the corrected full NightWing construction from Moon,
with character differences recorded in `game/data/darkstalker_design.json`.
The earlier thin independent NightWing approximation is no longer his builder.

## Reference and scale

The [book-cited character description](https://mirror.wingsoffire.wiki/wiki/Darkstalker_(L1))
identifies ebony scales, midnight wings, black eyes, a long neck, powerful build,
long twisted horns, silver mind-reader tears, icy white scales at the wing/body
junction and a white bone half-hoop in the left ear. Joy Ang's *Legends Darkstalker*
cover supplies facial/tribal character; that cover depicts his youth and cannot
establish the ancient body's scale. Mike Holmes's adult graphic-novel image
(`cache/protagonist-references/darkstalker-adult-gn.png`) supplies the mature
thorax/neck impression, with broader shoulders and a deep ventral body.

The [publisher's Talons of Power excerpt](https://pr-media.scholastic.com/assets/pdf/978-0545685436.pdf)
places him at least three times the biggest full-grown dragons Turtle has seen;
the text distinguishes that from literally being as large as the whole mountain.
A mountain-wide wing impression is not an independently measurable metre value.
No verified canonical height, span or mass was found.

The provisional world scale is 10.8, three times an assumed large-adult reference
scale of 3.6 in the same NightWing construction convention. The adult reference is
an explicit art-direction assumption. This is about 6.55 times Moon's model scale,
before the mature torso/muscle changes. It is not three times a four-year-old and
is not age divided by a maturation age. The camera fitting the body on screen
must never be interpreted as evidence for world size.

The asset metadata exports measured game dimensions and a separately labeled
speculative density-based mass estimate. Those values are fictional scale choices,
not biological facts or measurements quoted from the books.

## Construction carried forward

- Full supported skull, fitted short nasal cap and recessed nostrils.
- Smooth upper/lower bite geometry, seated front/side teeth, fitted tongue floor,
  lip drape and deforming cheek corners.
- One lateral pigmented eye globe per side, staged fitted eyelids, no closed-blink
  globe exposure in the sampled iris region.
- S-curve neck, broad mature thorax, deeper belly, full Clay-derived muscle
  architecture, segmented toes and hooked claws.
- Skull-grown horn housings, much longer swept/twisted shafts and restrained dark
  keratin; character-specific bone hoop and pale fitted wing-root scales.
- Actual two-segment wing arms and fingers, muscular arm skin and shared arm/web/
  digit membrane boundaries. The web follows the trailing shoulder–elbow–wrist
  chain, with no leading-side fill triangle. Rest fans remain ordered and cupped.
- Clay's common motion components through the same anatomy adapter. The model is
  not enabled as a gameplay protagonist.

## Additional lessons caught by visual inspection

Ray-fitting plate corners was insufficient: the faces between them could cut
through the belly and create competing surfaces. Plate patches now follow actual
host triangles. Concave transitions receive adaptive interior fitting, matching
skin weights and host shading normals, and a signed-clearance check on emitted face interiors. Tiny
remaining overlaps are trimmed over the closed body host; the final omitted
area is under 0.4% of the plate area, rather than holes in the body.

The rest asset also had nonzero blink/mouth samples, concealed by animation reset.
The exporter now zeros non-Basis expression values, so a first-frame or offline
consumer starts with a neutral open-eyed face. This is checked before animation
initialization in the Godot asset test.

## Validation and remaining review

`game/tests/darkstalker_anatomy.gd` checks the imported rig, facial metadata,
neutral initial expression, fitted detail counts, measured grounding, fixed wing
lengths and arm/web/finger seams at five fold positions. Seam error is multiplied
by the full world scale. The cast regression checks that Darkstalker is present in
the village and stays outside the collection and the playable characters keep their capabilities.

Offline renders of the exported asset inspect the spread body, three-quarter
head and front head. They are internal QA captures, not updates to the separate
interactive preview. The ancient silhouette, twisted-horn character and final
likeness remain subject to visual review; this is a first complete variant pass,
not an approved finished character. Blue's next construction starts from the
separate anatomy notes rather than copying this final NightWing shape.
