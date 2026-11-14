# NightWing skull and jaw study

This study is not a finished Moon model and is not installed in the game.

## Corrections to the first construction

The first pass treated image horizontal as the construction axis. The official tribe drawing has the head pointing downward. That put the cross-sections on the wrong planes. Skull and dentary now have separate longitudinal frames. Their profiles are transformed into those frames before sectioning; reference tilt is applied only by parent transforms. Frame round-trip error is checked during every build.

The first transverse envelope was also much too narrow. The side drawing cannot measure width. Rather than invent an unrelated slender skull, the current study samples the accepted Clay facial-volume generator, including its premaxilla, perspective and compact-head transforms. Its anatomical width/length ratio is about 0.730. That normalized width envelope supplies the foundation; the skull retains its proportional width and only the anterior muzzle narrows by a documented trial multiplier.

This transfers the useful anatomical foundation, not the MudWing's shield, lion-like nose, horn silhouette or painted appearance. Clay and Umber's sources are unchanged.

## Sources and measurements

- Joy Ang official NightWing tribe line art supplies cranial roof, upper lip, orbit and open-jaw outlines. Enlarged crop frame and source-pixel conversion are recorded in head_design.json. This view shows part of the front cap and is not perfectly orthographic.
- Joy Ang Moon Rising cover supplies a Moon-specific oblique cross-check. It must not supply a shortened side muzzle or a guessed width.
- Brianna C. Walsh official How to Draw Moon image supplies a second underside/taper check. Artist and view differences remain separate evidence.
- Other NightWings now provide the missing angles: Starflight's near-front and resting dorsal-oblique head, and Morrowseer's front-oblique portrait, in Scholastic's public Dark Secret graphic-novel excerpt (PDF pages 24 and 11; printed pages 19 and 6). These constrain the existence and arrangement of broad cranial, orbital and nasal planes. They are perspective drawings, not orthographic width measurements. Their more compressed/wrinkled muzzle style must not replace Joy Ang's Moon muzzle.
- Joy Ang's Starflight box-set poster and Brianna C. Walsh's Starflight How to Draw art provide style and anatomy cross-checks. Neither is mislabeled a top view.

The measured silhouettes are not themselves a complete skull. The posterior region is truncated for this volume study. A visible facial outline can include soft tissue over an underlying ramus; it must not automatically become rigid dentary geometry.

## Anatomical foundation and differences

| Area | Foundation retained | NightWing study difference |
| --- | --- | --- |
| Cranium / temporalis region | Clay's broad transverse envelope behind the orbit | New profile and orbital placement; no global width collapse |
| Maxilla / nasal bridge | Supported wedge with lateral facial planes | Longer sloping bridge and taper, based on NightWing lines |
| Orbit | Recess within facial host | Traced NightWing opening; fitted eyelids still needed |
| Dentary | Separate structural jaw on a hinge | New local axis and outline; ramus and muscle fitting still unresolved |
| Musculature | Clay's masseter/temporalis/levator and lid-ring organization is the prototype | Attachments must be relocated to the new bone landmarks before expressions are built |
| Other anatomy | Clay's skeleton, joint organization and muscle system remain the working dragon prototype | No body, limb, wing or animation changes in this head study |

## Review artifacts

Generated files live in cache/moon-head-study and are ignored by Git. structure.jpg shows reference pose, level skull, level front/top, and a rigid jaw hinge test. comparison.jpg places accepted Clay's facial volume above the NightWing study at equal anatomical head length. review.html allows orbiting, zooming, view switching and swapping the foundation/study.

Build with Blender's background Python and build_study.py. Render with the repository creature-sculpting render_sheet.py, using study-viewer.js, views.json, the generated GLBs, and three r128. The foundation set uses mountFoundation; the structure set uses mountStudy.

## Remaining differences and limits

The jaw pass separates the anterior dentary underside from the cheek/throat outline, removes tooth tips from its structural upper border, and reconstructs the ramus under the cheek using Clay's joint arrangement as a prototype. The old exposed hook is gone; the hinge is now inside the cranial host, with positive vertical clearance checked during build. The posterior cranium now continues underneath the horn-root/ear region instead of ending at the crown-plating boundary. These hidden bone volumes remain anatomical reconstructions rather than directly traced visible lines.

The eye pass replaces flat patches with full globes seated along the host's local normal. The skin outside the aperture encloses the globe; upper and lower lid shells fit to that same host and sphere. Three blink in-betweens follow the globe, pinning the canthi. A close render caught globe exposure below the lower lid and led to correcting the continuous orbital host, not merely painting over the gap.

A true-front geometry diagnostic then showed that the eyes were almost entirely hidden by the anterior cranial wall. The Starflight front view shows paired visible apertures. A fitted preorbital bevel now turns those local walls forward while retaining the broad posterior width envelope and unchanged side outline. Both globes are visible in the new true-front diagnostic. The bevel slope remains a reconstruction parameter; this does not claim a camera/landmark fit to the exact proportions of the graphic-novel panel.

This remains a coarse volume study. Section transitions and canthi need visual refinement; posterior bone/soft-tissue proportions need further fitting in the oblique references. Profile smoothing is bounded to two crop pixels. The broader skull is a foundation-derived hypothesis rather than a new orthographic measurement. Horns, ears, scales, teeth, Moon's tear scales, color, expression muscles and final jaw closure are not represented as completed work. The hinge test establishes a rigid local transform and a seated joint, not correct tooth occlusion. These issues must be resolved before replacing the game model.

## Verification

The background Blender build exports both GLBs and the canonical study blend. Skull/jaw coordinate round trips differ by less than 0.001 reference-crop pixel; tracing smoothing stays within two crop pixels; the relocated joint has positive clearance within the cranial section. The plain-clay reference, level side, front, top and jaw-test renders were visually inspected. Eye geometry colors distinguish the globe from the lids during closure; the lossless result is recorded in cache/moon-head-study/blink-check.json. Fine aperture resolution and a globe-following socket floor avoid the exposed lower strip caused by the earlier deep socket/subdivision combination. Chromium loaded the interactive review without JavaScript errors; view changes, jaw and blink controls changed the render, and both models swapped correctly. Old WebGL resources are disposed when swapping. Those checks establish working study artifacts, not anatomical likeness approval.

The current local review is served at http://127.0.0.1:8832/review.html. To restart it, serve cache/moon-head-study with Python's http.server bound to localhost. Reference board and comparison images are also directly viewable in that directory.
