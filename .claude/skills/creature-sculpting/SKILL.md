---

name: creature-sculpting
description: Sculpt a creature model from reference art one element at a time (nose, eye, cheekbone, horn, jaw, neck, limb, hand, wing, tail), the way an architect designs a building and a sculptor builds from bone and muscle outward, then encode it as measured data and build it. Use when modelling or fixing any part of the Clay (Wings of Fire) model, or any character model built from reference images in this repo.
---

# Creature sculpting

A reference-fitted resting cloth surface cannot simply be inverse-skinned into
the flight bind pose: that can preserve its outline at rest while creating huge
balloon-like lobes in flight. Keep a shallow flight surface and fit intermediate
cloth corrections in the actual posed frames. Preserve sampled support and arm
boundaries in every correction; inspect spread, quarter, half and resting poses.
Relax a compact cervical S by removing the centerline hump behind the occiput,
while retaining neck depth and a continuous throat attachment behind the moving
jaw. Slimming a muzzle requires adjusting the anterior dentary as well as the
premaxilla; narrowing the whole braincase is not an equivalent change.
An occipital/throat union must stop behind the rear oral lining throughout jaw
opening. Closing a skull-to-neck gap can otherwise push external ventral scales
into the mouth; inspect the open-mouth view after changing cervical geometry.
Keep this transition shallow and inside the shared cervical envelope: an
ellipsoid hanging below the ramus fills a gap but creates an unwanted jowl.
Ventral jaw pigmentation should follow the surface sector, not an absolute
depth threshold that removes its pale color when the dentary becomes thinner.

For four wings, check fore/hind triangle intersections in the actual launch and
cruise stroke poses. A neutral spread pose and separate lobe silhouettes can
both pass while their body webs cross during an upstroke. Sweep deployed
hindwings without changing the standing arm lengths/directions. Transport the
resting lobe curve in the wing frame; keep the broad lobe weighted to its
support, with body weights confined to the inner attachment web. Check outer
arc length through the flap, not only attachment seams and finite coordinates.

## Lessons from the NightWing study

Construct the skull along its anatomical plane and the dentary along its own plane. Reference head tilt belongs in pose transforms, not in image-horizontal construction sections. Show a level head before matching the drawing's pose.

Use the successful MudWing as the anatomical prototype: retain useful skeleton, musculature organization and proportional cranial breadth, then encode the other tribe's specific differences. Distinct tribes do not justify discarding all shared dragon anatomy. A narrower muzzle does not imply a paper-thin cranium. When Moon's art hides the front or top, seek official views of other NightWings (for example Starflight and Morrowseer) before declaring width or roof angles established. Keep character differences, age, perspective and artist style separate; graphic-novel snout compression must not silently replace Joy Ang's muzzle proportions.

An outer jaw/cheek/throat contour and individual tooth tips are not a rigid dentary outline. Build the hidden ramus into a seated joint using the established prototype, and mark hidden forms as inference. Check a closed blink with mesh colors and ray intersections: subdivision over a deep socket cut can pull the host wall behind the globe. A socket needs sufficient local resolution and a fitted floor/host, not just a circular eye patch. Diagnostic materials must enable morph targets or the supposed closed-blink diagnostic will silently show the rest shape.

## Lessons from the rejected shoulder pass

A muzzle can taper correctly in profile and still have a flat nose in front or
top view. Inspect both views. Round the anterior footprint separately from the
cranial width, and give a nonlinearly curved nose cap interior topology: bending
the perimeter of a single ngon does not sculpt its interior surface. Preserve
the broad orbital foundation while shaping the beaked premaxilla.

Keep the orbital rim separate from the cranial vault, and the tooth-bearing
arcade separate from the visible lip contour. A wavy traced lip is not a wavy
jaw bone. Fit both arcades in one smooth bite frame, then fit the lip drape and
soft cheek commissure over them. Check open-mouth views for cervical skin
showing through the pharyngeal wall. Fit the tongue to the actual oral trough.

Retargeting named limb muscles alone does not retain the prototype's torso or
cervical anatomy. Preserve section depths, keel, shoulder transitions and the
curved attachment to the skull. Separate iris discs can stand above otherwise
fitted lids: prefer pigments on one seated globe, and ray-check closed-lid
coverage through the actual orbital host instead of counting morph targets.

A connected mesh and normalized weights do not establish natural anatomy. Inspect the shoulder at intermediate folds in plain clay before accepting it. Reconstruct posed soft tissue in joint-local frames; do not stretch a chest strap into a humerus. Preserve anatomical fan order throughout retraction: the body-side digit stays
closest to the flank and the outboard flight digit stays farthest out. Label
them by anatomy; ambiguous array labels such as first/last can reverse the fold. Attach the wrist claw to the actual arm knuckle. Separate the visible lip drape from structural bite geometry, and shorten the head along its anatomical axis rather than world forward alone.


Axial head shortening can make unchanged cheek width read as puffiness. Inspect and flatten the side cross-section between the lip and shield instead of repeatedly reducing small muscle brushes. Preserve the bite bed and lip profile while doing so.

Tiny moving field branches at a wrist can pinch shell topology during retraction. Prefer a compact terminal knuckle with digit bases embedded inside it; verify the junction in a close render. Keep the shoulder socket centered on its actual pivot instead of building a moving chest-to-insertion strap.

A fan's signed plane normal is not necessarily its dorsal side through a fold. Check the visible brown/orange side at the socket, forearm and wrist independently. Give arm tissue an anatomical dorsal frame and prevent changing muscle-origin frames from rolling material to the opposite side. A wrist claw continues from the ending knuckle; a palm-face attachment is a different construction. Compare resting fan angles against folded art as well as checking digit order.

A continuous skin union is useful for construction, but fitting a deforming finger to the union of all fingers can capture its surface onto a neighbor when the fan closes. Preserve per-digit surface domains beyond the shared palm. Check plain-clay close-ups: connected/manifold topology alone did not reveal this pinching. Sample folded centerlines to set link lengths, then use the same lengths in flight; do not use arbitrary endpoint compression to fake retraction. Derive membrane edges from posed centerlines rather than rest-path bone selectors.

Model one element at a time. Treat each element like a building:
- find its load-bearing masses;
- find the bones and muscles that shape them;
- find the planes, ridges, plates and creases the artist drew;
- write all of that down as numbers before building anything.

Never tune the whole creature at once, and never guess a shape the references show.

## How we work

The user reviews every step by eye. Their notes are the most valuable input, and they have repeatedly caught what the numbers missed. Work so their review is fast and every note gets fixed properly.

- **Show, side by side.** End every step with a sheet that puts the model next to the reference it is judged against:
  - a side view aligned with the side sheet;
  - the official three-quarter and front art;
  - a plain clay render;
  - the part articulated (jaw open, blink, expressions).

  Use `scripts/render_sheet.py` with the part's `views.json`.
- **Fix exactly what is named, at its source.** When the user names a feature ("his cheekbone", "the inside eye point"), first find the exact drawn line or shape they mean in the reference: zoom in, and make a line map. Measure it, then change the data. If the meaning is unclear, ask; don't build a guess.
- **Answer the question.** If asked "does X look right?", check the reference and answer plainly. Say what was wrong and why, including your own earlier mistakes. ("Yes, I invented that ridge" is the right answer when it is true.)
- **Report what is still off.** Every report ends with the remaining differences you can see. Never call a part done because it "looks fine".
- **One commit per fix.** After each fix, update the data file, the element sheet (`*_sheets.md`) and this skill's lessons, then commit and push. The repo is public: never commit the reference images or generated `.glb` files.

## The loop, for each element

1. **Isolate.** Crop the element at full resolution from every reference that shows it, with a measuring grid in reference pixels (`scripts/study_crop.py`). Use the official art first and fan sheets second, and note where they disagree. Where the lines are hard to see (dark ink on dark paint), extract them with `scripts/line_map.py` and trace from the line map.
2. **Read it as architecture.** Write an element sheet (template below):
   - **Primary mass:** what simple solid is it (wedge, box, drum, cone)? Its length, height and width. Take lengths and heights from the side view and **widths from the front and top views**. A side profile alone hides a box nose.
   - **Bone, muscle, skin:** what has to exist underneath to make this shape (see "Sculpt from the inside out").
   - **Planes:** the flat faces, and where they meet in a hard edge or a soft turn.
   - **Drawn lines:** each line as a polyline in reference pixels, and what it is: an edge between planes, a ridge, a groove, a plate joint, or the outline of an opening.
   - **Pieces:** which colour areas are separate solids fitted together, which features are sculpted into a host surface, and which are separate attachments.
   - **Articulation:** what moves, around which pivot, and which side of a seam is rigid.
3. **Encode.** Put the numbers in the element's data file, not in code:
   - stations (cross-sections);
   - polylines for ridges, rims and creases;
   - plate layouts;
   - pivots and attachment frames;
   - a `why` for every form, naming its evidence.

   Convert reference pixels to model units with one documented mapping (for Clay: `z = (700 - px) / 343`, `y = (830 - py) / 343`).
4. **Build** from the data with the toolkit below.
5. **Check** with a sheet: the aligned side view against the line map, three-quarter and front against the official art, plain clay under a raking light, and the part moving through its range. Write down what still differs, and fix the data, not the code.
6. **Record** what this element taught you in "Lessons", so the next element starts ahead.

## Evidence rules

- **Never invent a form.** Every ridge, crease, plate and mass must point to a specific line or shading in a specific reference, and its `why` says which. Don't assemble a feature from loosely matching lines across several images, and don't add textbook anatomy the art doesn't show. (Invented and removed on Clay: a pit-to-jaw "cheekbone ridge" and a postorbital bar.)
- **Model what every depiction agrees on.** A single sheet, especially fan art, has quirks. Before encoding a curve, line it up across every official image (`all_heads`-style sheets of the same part) and keep what is consistent. Clay's side sheet sags his lip line, while no official image does.
- **Measure, don't eyeball.** Read positions off gridded crops and line maps. Measure each corner, joint and stroke where it actually is. A measurement between the wrong two points gives a confident wrong number: Clay's eye tilt was first measured to where two creases meet, not to the eye's corner, and came out 26° instead of about 45°.
- **Trace colour boundaries; don't sketch them.** For a colour edge (roof over face, face over jaw), classify the reference's pixels by colour and read the boundary off, column by column. Then prove it: render a true side view framed at the reference's scale and blend it over the reference. Clay's roof edge and lip were twice hand-placed "from every depiction" and were 0.07 off. The trace and the blend caught it at once.
- **Don't dismiss a reference's shape as its quirk until you have looked for it in the others.** Clay's overhanging upper lip was dropped as a side-sheet oddity, but *How to Draw* and the flight render show it too.
- **A drawn line's weight is the edge's strength.** A heavy stroke means a crisp, deep edge; a tapering stroke means the form fades out. Sculpt the edge on the side the line is drawn.
- **The references decide.** When the model and the art disagree, the model is wrong.
- **Tell overlapping layers apart before measuring.** A side view can draw the far limb peeking out behind the near one, offset by the sheet's slight elevation. On Clay's side sheet the far wing's plain fingers show above and ahead of the near wing's studded ones, so the folded fan looks twice as broad as either wing. Match details (studs, claws, shading) to decide which layer a line belongs to.
- **Know each reference's view angle before measuring from it.** Clay's "side" sheet shows the snout at about three-quarters. Its front-of-snout diagonal is the front face seen obliquely, and its short chin is the front of the chin seen at an angle. Tracing them as a true profile produced a short, set-back lower jaw, a concave muzzle front and a 45° front lip ramp, each fixed only after rounds of user corrections. For a foreshortened region, take the art's intent (what form it depicts) and build that form from anatomy; don't trace its outline.
- **When a part is "modelled after" an animal, study how that animal's part sits on its head, then find the same arrangement in the art.** The user said Clay's nose is a lion's. It was first read as the end of the muzzle shield (wrong), then as the shield itself (wrong). The references (Dragonet Prophecy cover, the top-view painting) show a lion's arrangement: the nose bridge rises out of the middle of the muzzle shield, runs forward and down along its top, and ends in a rounded leather cap set back from the shield's tip, the shield's rim carrying on round the front ahead of and below it. Same material and colour as the shield: it reads by form, not colour.
- Left and right are mirrored: model the left side and mirror it.
- Organic, not mechanical. Plates and scales vary in size and follow the form; never use a regular grid or brick pattern.
- **When the user names a part, ask what it is before building.** "Front ridge" was built three wrong ways (a bar, part of the nose, a separate shelf) before the user explained it: an extension of the roof's front. Restate your reading in one line and build the simplest version of that.
- **Simple first.** When the user says a form is too complicated, rebuild it from fewer, plainer pieces, not by adding corrections to the complicated one.
- **Check geometry numerically, not only by eye.** Probe which mesh is on top at a spot (a gap, a flap), and project measured landmarks (eye corners, lid margins) onto the reference. Both found causes that renders hid: the brown hanging below a lifted lip corner, an inner eye corner turned to 83° instead of 57°.
- **Don't stop at a list of known faults.** If a render still shows a fault you can fix, fix it before reporting.

## Construction principles

- **Look for fitted pieces.** A different colour area is often a different solid. Clay's head is an orange face mass with a dark roof of plates fitted over it, standing proud so its edge overhangs.
- **Sculpt features into their host.** A nose pad, a horn root or a brow belongs to the surface it rises from:
  - a nose pad is a height field on its plate, with the nostrils cut into it;
  - a horn root is the roof moved onto the smooth union (exponential smooth-min with a fillet radius) of roof and horn, so the plates swell up into the horn.

  Separate pieces planted on top, flared collars and separate root lofts all failed: they read as stuck on.
- **Lines are geometry, never ink.** Every line in the art becomes an edge, ridge, crease, plate gap or rim. Don't draw lines on the skin in the shader: they read as scratches on a sculpted model. Ink is acceptable only in a groove that already exists in the geometry, such as a horn ring.
- **A shield is one solid piece; its plating is carved into it.** Clay's muzzle shield was first built as separate tiles plus a front cap fitted to the front curve; the seams and the fitted cap read as a workaround (user: why can't this be one solid piece?). Build the shield as one surface with a rounded edge all round, and carve the plating into it (grooves at the joints, a low dome per tile, like an ankylosaur's fused osteoderms). Separate tiles still suit loose overlapping scales elsewhere.
- **Design clearances in, don't patch collisions.** Where a moving or nearby part (the ear) shares space with a shell, set the shell's edge by design on a line clear of that part's whole path, measured from its mesh with a margin, and check the gap numerically.
- **Lay plates out in the art's own directions.** Joints run perpendicular to the form's flow line, and strips run along it. Use coordinates that follow the profile: s along it, d the depth perpendicular to it. On a sloping muzzle the joints are therefore not vertical cuts.
- **Colour and pattern edges are measured lines.** Trace a zone edge as a side-view polyline from the art. Don't use a fraction of the body's depth: a fraction runs parallel to the spine, while the art's edges sweep (Clay's dark neck edge drops straight down into the shoulder).
- **Measure pattern rhythm.** Scan across the ink lines on the sheet to get each pattern's spacing (bands, plates, scales). Lay patterns out in model units, not normalised parameters, so sizes stay true on thick and thin parts. Put the pattern's wrap-around seam on a hidden side.
- **Resolution must match the sharpest edge.** The mesh spacing must be finer than the narrowest crease or overhang, or it renders soft.
- **Smooth, never stepped.** When carving or uniting surfaces (sockets, fillets), use a smooth minimum, and clamp it so it never cuts into a neighbouring part.
- **One piece means one mesh.** A part that should read as continuous with another (the front ridge with the roof's front band) must be built as more rows of the same surface. A separate mesh fitted flush still reads as tacked on.
- **Blink along the meridians.** Lids hinge on the canthal axis (the line between the corners, through the eyeball's centre); the margin sweeps across the eye at right angles to it. Store the blink as several in-between shapes along that arc: one straight-line shape cuts through the eyeball mid-blink.

## Sculpt from the inside out: bone, muscle, skin

No surface form is free-floating: something under it pushes it out, holds it up or lets it fold. Write every element in three layers, in this order:

1. **Bone (landmarks).** Rims round openings, arches, crests, bars and joints. Bone makes crisp edges and flat-ish planes, and does not change shape when the creature moves.
2. **Muscle (masses).** Each muscle runs from an origin to an insertion. It bulges in its belly and flattens toward its tendons. Know which one fills each region, because that tells you both its shape and how the region moves.
3. **Skin (creases, openings, scales).** A crease forms where two muscles meet, or where skin folds over something that moves (lids, mouth corner, joints). Trace each drawn line back to the boundary that causes it, and sculpt that boundary.

**Judge the forms in a plain clay render.** Paint hides missing anatomy.

**Encode the anatomy as structure, not as notes.** Name the bones, muscles and parts in the design data and generate the shape from them: landmarks (a chin's symphysis, a jaw's angular corner, a hinge) that a profile is built through, layers of named brushes, named sub-parts (shield, nose bridge, cap, nostrils). A hand-made table of numbers with the anatomy only in its note loses it: the next session can't edit "the dentary" or keep the rows true to it.

### The face is how a creature communicates

Expression is muscle, and every subtlety in the eye, brow, cheek and mouth matters. Model the face so these actions are possible:

| Muscle | Action (FACS unit) | What it does to the surface |
| --- | --- | --- |
| Orbicularis oculi, around the lid | blink (AU45) | the lids slide over the eyeball |
| Orbicularis oculi, outer ring | cheek raise / squint (AU6, AU7) | the cheek pad rises, the lower lid bunches up, creases fan from the outer corner |
| Levator of the upper lid | lid raise (AU5) | more white above the iris: surprise, fear |
| Corrugator and procerus | brow lower (AU4) | brow skin drawn down and in over the upper lid: anger, concentration |
| Frontalis, inner part | inner brow raise (AU1) | the skin above the inner corner lifts: worry, sadness |
| Zygomaticus major | lip corner pull (AU12) | mouth corner up and back, cheek rises; a real smile is AU6 + AU12 |
| Levator labii (with alaeque nasi) | lip raise, nose wrinkle (AU10, AU9) | upper lip lifts off the teeth, snout wrinkles: snarl, disgust |
| Depressor anguli oris | lip corner down (AU15) | mouth corner drops: sadness |
| Masseter, temporalis | jaw | bunch when the jaw clenches |

Build each muscle action as a face morph target: a push of the region plus the creases it makes. Lid tilts go on bones (split the upper lid into inner and outer halves); the blink is a shape of the lids themselves. Write expressions as mixes of actions. A rigid brow plate doesn't move: brow actions move the skin and lids under it.

### Eyes

- **The eye sits in a socket.** Carve the face into a socket that holds the eye assembly. Inside the lids' footprint the skin runs in just under them, and a rounded rim turns it back out.
  - No bone or muscle form may raise the skin over the eye opening; they only frame it.
  - Seat the eye along the face's true normal at its centre, deep enough that the lids barely stand above the face. A visible lid dome reads as a bulge.
- **The corners differ, and each has its own angle.** Measure each corner's angle from the eye centre on a line map. Clay's inner corner drops about 58° below horizontal, down and forward to the tear duct; his outer corner rises only about 32°. Bend the lid frame so each corner lands at its measured angle.
- **The corners sit on the visible eyeball,** where it meets the face, not at the buried ends of the eye's axis.
  - The inner corner is rounded and holds the caruncle: a fleshy pink teardrop lying on the eyeball between the margins. Never a bead.
  - The outer corner closes where the art's outline closes.
- **Follow the eyeliner's path.** If the art draws a closed round ring, the corner must close round where the ring ends. A corner placed too far back drags the dark rim into a wing.
- **The margins are not mirror images.** The upper lid peaks toward the inner corner; the lower dips lowest toward the outer corner.
- **Lids have thickness:** shells with a rounded margin, sliding over the eyeball. They are pinned at the corners, moving most mid-eye. A blink is a shape key of the lids; a large bone turn tears the corners.
- **Read the opening as one outline first.** Clay's eye opening is a teardrop: the round eye with its inner corner drawn into the pink point. Build the lids over that outline and let the blink cover all of it. Corner angles, bent axes and separate tear-duct pieces were a long detour from a shape that was obvious in the drawing.
- **The cheekbone is the socket's rim.** On Clay it is the heavy hooked line under the eye. Sculpt it as a `rim`: raised, gentle toward the eye, crisp on the outside where the line is drawn.

## Toolkit

**Masses**
- Lofted quad meshes: rings of points at measured stations, each ring a superellipse or profile. The exponent sets boxiness: 2 is round, 5 a crisp box.

**Brushes** (data, grouped into `bone`, `muscle` and `skin` layers)
- `ridge(polyline, height, width)`
- `crease(polyline, depth, width)`
- `dent(point, depth, radius)`
- `rim(polyline, around, height, width_in, width_out)`: a bony rim round an opening
- `bulge(centre, amount, radii)`: a muscle belly
- `pad(centre, radii, tilt, height)`: a raised plateau, such as the lid ring

**Plates**
- Tiles over (s, d) ranges of a profile-following layout, with bevel, back-edge thickening and overlap.
- Sculpted height fields (nose pad, nostrils) and smooth-union fillets (horn roots) are applied to the tiles' surface.

**Attachments** (each on its own bone)
- Tubes along splines for horns and claws, smooth with hairline rings.
- Fins for frills and membranes.
- Eyes with lid shells.

**Actions**
- Face morph targets for muscle actions.
- Lid shape keys for the blink.
- Bones for the jaw, tongue and lid tilts.

**Scripts** (`scripts/`)
- `study_crop.py`: a gridded full-resolution crop of a reference.
- `line_map.py`: extracts a reference's ink lines into a clean, gridded line map.
- `overlay_side.py`: renders a true side view at the side sheet's scale and lays the model's outline (cyan) and a half blend over the sheet. Use it to check any outline.
- `render_sheet.py` with `shoot.js`: renders painted and plain-clay views, posed, next to reference crops, from a `views.json`. Needs Playwright's Chromium and three r128's `three.min.js` and `GLTFLoader.js` in a folder (`npm i three@0.128.0`).

**Technical notes**
- WebGL allows 16 vertex attributes, and morph targets use them up, so pack custom attributes into vectors.
- three r128 needs `skinning: true` and `morphTargets: true` on the material.

## Element sheet template

```
## <element>
References: <files and crops used; where they disagree>
Primary mass: <solid, size in model units; widths from the front/top views>
Bone: <landmarks (rims, arches, bars, joints) and the crisp edges/planes they make>
Muscle: <each mass: origin -> insertion, where it bulges, what it moves>
Skin: <creases and folds, and which boundary each one marks>
Planes: <faces and the edges between them (hard/soft)>
Drawn lines: <name: polyline in ref px, ridge|crease|edge|joint|outline, stroke weight>
Pieces: <separate solids, features sculpted into a host, attachments>
Articulation: <bone, pivot, range; rigid vs skinned; morph targets>
Build: <which toolkit pieces>
Check: <what to compare; known differences>
```

## Lessons (Clay)

**Front muzzle and nose frame**
- When the user describes the angle between the shield and front muzzle, check
  those two planes. Reducing a convex bulge does not correct their angle.
- Keep the alveolar base, lip and lower-jaw closure coherent when changing the
  premaxilla's crown. Check the closed bite and the mouth open.
- A surface attachment built before a muzzle deformation can be sheared flat.
  Build the nose on the final shield in an orthonormal frame; measure its cap
  angle relative to that shield, not only to a world axis.
- Do not flatten overshooting loft rings into a cap: trim the meridians and
  close one face. Topology checks must accompany reference silhouette checks;
  a valid closed mesh can still depict the wrong shape.

**Muzzle**
- Bone and muscle, not a box: the premaxilla rounds the front into a U in top view, and the front is convex everywhere (an earlier box read square, then caved-in concave when its front was traced from the three-quarter sheet).
- The muzzle shield: one solid piece over the top and down round the front corner, plating carved into it.
- The nose: a lion's: a short bridge, a crisp box (flat top, upright sides), ending in the leather cap whose front is its own upright plane facing forward (cut perpendicular to a steep slope, a face points down), just behind the shield's front; comma nostrils in that face.
- Under the shield's front, orange whisker pads drape over the front teeth into the lips; the cheeks are flesh draped over the teeth and jaw, not a puffed shelf.

**Roof rim and lip**
- The roof's lower edge is a rim of square marginal scutes, like a turtle shell's edge.
- It sits about mid-height on the muzzle side and rises steadily to the eye, with small notches at the joints. Not a staircase.
- The upper lip line is straight and level, then sweeps up concave into the mouth corner.

**Roof (the brown crest)**
- Plating laid out along the profile (now carved into one solid shield; see Construction principles):
  - a nose plate;
  - top bands that wrap down to a first line (d ≈ 0.054);
  - a narrow strip of long plates down to d ≈ 0.075;
  - an edge row of near-square plates (joints about every 0.062) down to the orange.
- Over the eye the edge steps up, and the eye sits tucked under it.

**Horns**
- The roof's back corner drawn out: the roof's top line runs on into the horn's.
- Thick at the root.
- A long, nearly straight sweep back, curling up only at the tip.
- Smooth, *lined but not bumpy*: hairline rings.
- The root is sculpted into the roof plates.

**Eye**
- An almond: the outer corner comes to a soft point and the upper lid rests over the top of the iris (the covers); the side sheet's round stare read as too wide.
- The inner corner points down and forward to the tear duct (pink caruncle).
- A thin liner on the lid margins, which stays on them through the blink.
- The cheekbone is the hooked rim under and behind it.

**Jaw**
- A dragon's lower jaw from its bones, not traced from the three-quarter sheet: the dentary carries the teeth forward to a rounded U-shaped chin (the symphysis) just behind the snout's tip, under a slight overbite. It deepens steadily backward under the jaw muscles (surangular, angular), and the retroarticular process curves up behind the hinge.
- The lip line is nearly straight: level at the front, rising gently back to the mouth corner. A lip edge that rises toward the snout's tip makes the jaw curve up like a bowl ("a Nike check").
- Judge the jaw in a true side view: its underside must be one elegant line from the chin into the throat. Where a separate part meets the skin, run the weld line along the part's own outline (the jaw's underside), never across it: a vertical cut left a stair step.
- The hinge sits under the back of the eye; the jaw drops down and back, and the cheek skin stretches across the corner of the gape (a web), not a rigid slot.
- The cream lower jaw continues up behind the mouth corner as a jowl under the ear.
- Teeth are recurved cones, oval in section; the tongue is a muscular, grooved body on bones; the lips have fleshy margins moved by FACS lip actions.

**Ear**
- A flap of skin on a thin stalk out of the face's flesh, flaring and curling like a tulip petal: orange outside, cream inside. Built as a separate hovering leaf or a solid wedge, it failed.
- Behind the head the neck's top is lower than the ear's top edge, so the neck's shell there is defined by its place round the body (a band over the top), not by a side-view line, to pass above the ear and meet the head's shield.
- It sits high at the back of the cheek, under the horn, its tip curving back toward the horn's underside. Shells near it are set clear of its path by design.
- The ear opening is a small hole below it.

**Head-neck weld**
- A separately built part never reads as one piece with the body's skin, however closely it is fitted. Put the part's own shape into the skin's field (from its measured cross-sections, which give an exact inside test, unlike nearest-face normals). Trim the part's mesh on a drawn line, and let the skin be its surface beyond it.
- Where two surfaces must meet, keep one strictly under the other up to the line and let it out gradually beyond. Surfaces that cross at a shallow angle sawtooth, and a hard cut leaves a kink the marching cubes steps on.
- The skin at a seam must carry the same bone weights as the part it meets, or the seam opens when the creature moves.
- Check bone weights numerically: list the largest weight difference across any mesh edge. A rest pose hides weight jumps, and a bend shows them as crisp bands. Clay's spine had one at every joint for many rounds.

**Body**
- Build limbs as bones with muscles laid from origin to insertion, under one skin (a smooth union of fields), never as tubes stuck onto the body. A limb with no shoulder or haunch muscles reads as chopped off.
- Trace the body's outline under the mane, spikes and frills, at their bases. Clay's first trace ran over the spike tips and made his neck and back too big. Where a limb hides the body (the chest under the upper arm), the body's line is anatomy (a cat's breastbone at elbow height), not the limb's outline.
- One mass per joint: a flat layer over the shoulder blade or hip, then the big belly below it, blended wide (0.07-0.12). Two bellies side by side read as double shoulders or balloons.
- The chest's section is a keel, not a barrel: widest up at the shoulders, so the legs hang close beside it, like a cat's.

**Looking at a part**
- Judge a plate or face square to its own plane. Clay's muzzle shield seen straight down the y axis foreshortened its steep front and hid the hammer-shaped broadening that defines his face. A camera along the shield's normal showed it at once.
- A feature that sits "at the front edge" must follow the surface that is really there. The nose followed the top profile, which ended a plate row short of the shield's true front, and kept landing a row back until it was laid along the measured front shelf.
- A face that is "pitched forward" slopes down toward the tip, foot ahead of top. Leaned the other way it undercuts into a hood with a dark slot beneath.

**Hands and feet**
- The front hands are compact, with big hooked claws and a high dewclaw.
- The hind feet are long and digitigrade, with a heel spur and studs along the top.
- Verify the emitted rig, not only field-piece labels: three phalanx-shaped skin
  pieces can still be weighted to one animation bone. Continue each outer digit
  from its own metapodial ray inside the shared palm/foot mass; a central
  ellipsoid can taper away before reaching the outer roots. Exercise joint-local
  skin weights through the full body exporter, including fixed-weight head
  sections, rather than checking only the limb-only weight path. Keep rigid claws
  on the terminal phalanx and inspect their embedded roots during flexion.

**Leg/arm dual use**
- Raise the forelimb before accepting its standing sculpt. A broad field added
  to fill an armpit can become a chest-to-elbow sail. Place pectoral/latissimus
  insertions on the proximal humerus, retain the triceps' separate olecranon
  insertion, and keep the medial upper-arm envelope with the moving humerus.
  Inspect belly-to-tendon taper and the elbow/wrist/hock at multiple views.
  Use a shared bend plane for adjoining links and distribute forearm rotation;
  do not fake supination by twisting the wrist alone. Relaxed airborne asymmetry
  should alter plausible bend and height, not force every link into a zigzag.
- Do not reuse a walking rest-pole blindly for a forward/upward reaching hand:
  projection can send the elbow above and far outside the shoulder. Diagnose
  actual joint coordinates before sculpting tissue around a bad pose. At a large
  wrist bend, use intermediate carpal deformation frames about the actual joint
  center; a single forearm/hand weight blend can flatten the wrist despite a
  connected skeleton. Keep paired forearm bone fields distinct beneath it.

### Nose placement and nostril coordinates
Measure visible shield clearance relative to cap width before choosing setback.
An inward-tapered cap needs width-dependent nostril coordinates at each height;
a constant half-width misplaces the openings. Use the cap's up axis and side
normal, rather than world height and a front-only cut direction.


### Attachment tangent stability
Fit an attachment frame over the anatomical surface's local neighborhood, not
across one decorative groove; otherwise moving a cap slightly can change its
orientation sharply. Check placement and cap tilt independently.


### Mouth beds and rigid teeth
The ascending jaw crest is not the tongue's bed. Give the mouth floor an explicit
profile, check its wall thickness, and remove solid head/neck tissue behind the
gape. Build rigid crowns against the final deformed palate. Keep categorical
material IDs constant within a surface family: interpolating lining ID 3 to skin
ID 20 shades intermediate pixels as unrelated teeth, horn and armor materials.
Use a continuous lining mask instead, and keep that shading mask separate from
the shell-generation mask.


### Fitted roots and collars
Match root and leaf loop ordering before fitting to final body skin. A small
root distance cannot detect a twisted fillet. Protect the face seam when relaxing
a corrugated welded cheek. Restore dorsal armor thickness independently from the
cheek-edge taper, and carry matching bone weights at the collar boundary.


### Moving wing attachments
A muscle bridging chest and wing needs per-endpoint attachment frames, not one
dominant transform. Check the connected underlying mesh in folded, intermediate
and spread poses before judging the decorative armor over it.


### Unexplained dark marks
Trace conspicuous spots to shader masks as well as geometry. A circular paint
mask can look like a hole even when the mesh is continuous; remove the mask
when the user rejects the mark rather than adding geometry to conceal it.


### Wide-gape soft tissue
A direct head/jaw blend follows a chord and contracts the cheek and throat as
the jaw opens. Blend neighboring samples of the opening arc, keep both rigid
attachment boundaries, and test beyond the normal talking pose. An emission
ray check alone cannot establish that the enclosing tissues remain coherent.
Let a gum ridge continue past its last tooth, then taper and bury the end in
the corner tissue rather than leaving a full-radius capped tube visible.


### Pattern size and anatomical flow
When a size comparison is ambiguous, inspect the named region in the references
before choosing a direction. Compare scale rows/columns between fixed anatomical
boundaries, not crop sizes. Neck, face, torso and limbs may need different scale
sizes. For inclined limbs, use rest-skeleton segment frames rather than global
height; integrate a changing pattern density instead of dividing a coordinate by
a changing spacing, which can reverse or bunch rows.


### Wing roots and shared joint frames
Moving a muscle's endpoints in its construction pose does not make its skin
follow both attachments in animation. Sample weights along that attachment path;
a mostly chest-weighted deltoid leaves its armor upright as the humerus rotates.
Use the same joint frames for construction and their exact inverses for folding.
A shared arm bend plane avoids an artificial elbow corkscrew from independently
forcing both bones to a world-oriented armor normal. Rotate muscle cross-section
hints with their bones, and inspect socket, elbow and armor through intermediate
poses as well as at the endpoints.

Soft lining that overlaps a rigid jaw floor must share that floor's bone weights.
An arc blend preserves wall volume but cannot fix a misplaced rigid attachment.
Bind overlaps to the finished host surface and keep the correction inside the
oral envelope; verify the result in rendered wide-gape views.


### Preserve volume at a rotating shoulder
After fixing an attachment gradient, check the joint at its largest swing and
roll. Directly blending a fixed chest to a strongly rotated humerus can flatten
the deltoid and its armor. Neighboring helper frames on the same socket's rotation
arc preserve volume without adding anatomical joints or moving either endpoint.

Thin tail ends can lose their shell when categorical color zones are averaged
across a narrowing cone. Inspect terminal coverage after smoothing and taper
shell relief with local radius. For small iris changes, preserve pupil/globe
size and resolve the color boundary with adequate eye-only tessellation.


After a head-proportion warp, classify mesh trimming in the original contour
frame used by the body weld, not by comparing warped vertices with an old
cheek line. Preserve temporary source coordinates through trimming and remove
them before export. When thickening a jaw, preserve the approved underside
silhouette and consider raising its rim beneath the upper lips; do not assume
extra volume belongs below the chin.


### One lip boundary, independent dentary
Use the actual exterior lip endpoint for the oral closing surface; re-evaluating
a corner lift from an old width creates a seam. Replace alternating corrective
knots with one continuous lobe. Give a simplified lower jaw its own straight
rim instead of inheriting the upper lip drape or stacking a max-depth correction
on top. Build rigid tooth crowns after proportion warps, and size crown bases
from row spacing rather than a clearance-capped height.

After an axial proportion edit, author lip-lobe positions in the finished head
frame and invert the warp to obtain construction stations. A smooth source
profile can still place its arches too far forward. Distinguish the front-face
arc, corner turn, anterior side lobe, intermediate crest and shallow posterior
lobe. A boxy muzzle still carries an arched, tangent-continuous tooth/gum row.


A contour's endpoint is anatomical: Clay's full upper-lip/cheek line ends at the
ear root. Do not compress its arches into the oral opening alone. Its rear
backward hook and forward S return belong to the cheek-to-neck seam. Move the
closure with a raised outer border, and clip crossing polygons precisely;
deleting whole faces blunts the hook and leaves stairs. Preserve attributes,
weights and all expression samples with a common interpolation.


Lip relief on a sloping skull is normal to that skull, not world Y. A shared
frame must govern the external contour, palate, gum seats, tooth directions,
lower rim and underside. A remapped outer line with the old bite plane creates
a gap and a stepped jaw; a larger cheek web is not a substitute for fitting
the jaws. Keep a shallow dip broad rather than converging to one pointed knot.


An isolated jaw cannot validate the throat attachment. For a rounded section,
the lateral underside is higher than its centre-lowest line; using the centre
line for a side seam can clip away the bridge into the neck. Inspect the full
assembly and probe the actual tissue field at any visible gap.


A straight anterior tooth-bearing margin does not make the whole lower jaw a
plane. Preserve the rear ramus/jowl upsweep. For a mouth-corner web, tangent
continuity must be authored in the open pose, then inverted through skinning;
arc-weighting alone can still produce a straight curtain between the jaws.


A handful of interior field probes can miss a lateral opening higher on an
ascending jaw. Sample the complete junction and inspect the assembled profile
and three-quarter view. A clipping allowance cannot bridge a gap between two
disjoint section fields; the local tissue union must span that separation too.


### Transfer an approved anatomical system, not its old approximation
When another character belongs to the same tribe, inherit the corrected complete
construction and encode character differences as a profile. Do not keep the older
low-fidelity tribe generator under a different character name. Separate normalized
construction geometry, world scale, and camera framing; a giant cannot be validated
from a fitted-to-screen portrait. Age does not define a linear height equation.

A membrane seam needs identical boundary samples and bone weights on both sides,
including the edge between the arm patagium and axillary web. Matching only corners
leaves different subdivided curves during a bend. Check the exported skinned asset
at intermediate folds, and multiply numerical seam error by world scale for giants.

Keep official covers, official line art, edited extractions and fan recolor sheets
separate in the reference record. A source called TopShot may be an oblique cover
crop; a wingless juvenile illustration cannot establish adult folded wing anatomy.
Normalize the skull's own longitudinal frame before measuring a downward-posed face.


### Fitted corners do not establish a fitted surface
Connecting individually ray-fitted scute corners can still cut chords through
the host, especially where the connected trunk meets a shoulder or leg. Clip
patches from actual host triangles with interpolated skin weights; test interior
samples after offsetting them, and adaptively fit concave transitions. Check
vertices and face interiors separately. Reset all non-Basis expression samples
before export: animation initialization can conceal an asset that otherwise loads
with every blink stage and mouth correction enabled simultaneously.


### A closed seam can still attach to the wrong side
A shoulder-to-wrist chord and an elbow fill triangle can stay numerically sealed
yet create a membrane sail in front of the folded wing arm. Trace the actual
trailing shoulder–elbow–wrist chain, seat its samples inside the arm tissue and
release those joint weights smoothly into the posterior web. Verify the side of
the attachment, not only the seam distance. Reuse this constraint for every new
wing type; do not copy the NightWing outline as the SilkWing fan.


### Transfer fidelity without transferring tribal identity
Use the approved dragon skeleton, muscle origins, digit articulation, bite-seat
construction and eyelid method as reusable anatomy. Author the new tribe's skull
profile, anterior footprint, horns/antennae, wing support count, membrane outline
and attachment topology explicitly. Blue has separate supported fore/hind wings,
not extra NightWing fans or an oval wing card. Four-wing motion roles need an
explicit anatomical side; a key such as fore.L is not the literal side L.

Shared vertex-color materials require the same color attributes on every mesh
using them, including axillary webs. Otherwise a properly colored flight panel
can share a material with a white inner web. A Boolean-generated white-vertex
cleanup must identify actual white, not classify every bright pigment as an
artifact: a darkness threshold that worked for Moon erased Blue's violet head.
Check those colors in the actual game renderer before presenting the rebuild.


### Smooth SilkWing lobes and soft appendages
Do not create a SilkWing by rounding the scallops of a NightWing fan. Use smooth
curved support paths and one continuous outer contour through their endpoints.
Panels must reach the same curve; hide the contraction support chain beneath
continuous taper rather than sculpting visible joint swellings into each ray.

Soft antennae stay anchored at the skull, with flexible weighting increasing
toward the tip. A small damped spring can add idle flow and turn follow-through.
Preserve the skeleton's actual resting local rotation when applying the bend;
an absolute small quaternion can replace the bind orientation and flip the
appendage. Validate the exported skinned root and tip, not just spring angles.

When the imported game model disagrees with a directly decoded GLB, compare
actual vertex counts/colors and regenerate only the affected generated scene
cache. A new source checksum alone did not prove updated mesh subresources.


### Count support roles, not evenly distributed spokes
On the SilkWing side sheet, separate the clustered distal arches, free arm-bend
hook, proximal/basal support, and unsupported membrane contour. A regular fan
with a matching count of lines can still have the wrong anatomy. Trace each
line to its origin before creating the rig: the small wing's short basal support
must follow the proximal arm, not originate at the wrist like the long arch.
Build the long lower banana lobe and the small wing's broad round lobe as their
own boundary curves, not by spreading uniform radial fingers farther apart.
