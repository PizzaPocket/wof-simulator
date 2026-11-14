# Blue: reference and anatomy pass

The reference pass below now drives the rebuilt game asset in
`game/data/blue_model_design.json`. The earlier SilkWing mesh has been replaced. The target is winged Blue after Metamorphosis, using the *Lost
Continent* cover for overall character and the official tribe sheet for anatomy.
The data and initial measured image landmarks live in `game/data/blue_design.json`.

## What the references establish

| Evidence | What it resolves | Limits |
| --- | --- | --- |
| Joy Ang, *The Lost Continent* cover | Long rounded muzzle, supported cranial roof, swept horns separate from slender antennae, full thorax, long neck, four large supported blue wings | Airborne posed oblique view with green/yellow environmental lighting; wings extend beyond the front-cover crop |
| Joy Ang, official SilkWing tribe line art | Long face with rounded nasal pad, curved horns, brow antennae, smaller dorsal spines, larger forewings and smaller hindwings, rounded membrane lobes | Side/oblique view, overlapping far wings; does not independently establish skull width or a fully gathered resting pose |
| Brianna C. Walsh, *The Official How to Draw* Blue | Three-quarter head breadth, connected neck/shoulder/haunch masses, wrist and foot details, body palette variation | Blue is wingless here; the curled buds are not contracted adult wing fingers |
| Bluethedragoon, BlueCoverTemplateLoopy | Secondary fan interpretation of the character's palette and markings | Fan reference, not official colored tribe art or definitive wing mechanics |
| [Book-cited Blue description](https://mirror.wingsoffire.wiki/wiki/Blue) | Azure/blue/lavender/violet colors, purple muzzle, cerulean wings, flamesilk wrists; larger than Cricket | No verified metre dimensions or mass |
| [Book-cited SilkWing description](https://mirror.wingsoffire.wiki/wiki/SilkWings) | Metamorphosis around six, two pairs of strong wings, furling antennae and long curved horns | Four forewing/two hindwing visible support digits are an interpretation to check against art, not an engineering diagram |

Private cached images: `cache/protagonist-references/blue-cover.jpg`,
`blue-top-shot.png`, `blue-htd.png`, `silkwing-lineart.png`. Attribution was checked
against the wiki gallery. The older cached colored tribe-base sheet is by
Bluethedragoon; the previous Goosefeathers attribution in our notes was wrong.
The file called `blue-top-shot.png` is a cover crop, not a true dorsal camera view.

## Head, jaw and appendages

The skull's primary form is a long, low rounded wedge with a supported posterior
vault. The tribe sheet pitches the face downward. Initial source landmarks are
orbital center (149,805) and anterior nasal center (111,960) on the 1974×1872 sheet.
Their normalized image axis is approximately (-0.238,0.971). Build along that axis,
then level the construction frame; do not bake image-horizontal stations into the
head and introduce an accidental droop. Manual picks carry roughly ±8 px tolerance.

The muzzle rounds around its anterior footprint. Its visible pad is not Clay's
broad square shield and not Moon's hooked tip. The colored cover has a subtly raised,
rounded terminal profile. Retain meaningful cranial width behind it. Neither the
side sheet nor one oblique cover justifies reducing the skull to a narrow blade.
The *How to Draw* oblique head helps constrain breadth, but a precise hidden top
section remains inferred until another suitable SilkWing view is obtained.

Keep the structural bite frame independent from the visible wavy lip. Reuse the
construction methods for smooth upper/lower arcades, seated recurved teeth,
clearance above the oral floor, fitted lips and soft mouth corners. Rebuild their
seats against Blue's finished host; transplanting Moon's final coordinates would
repeat the old fitting errors. Lateral eyes need one pigmented globe and fitted
staged lids, validated at closed blink.

The long plated horns grow out of skull housings. A separate pair of slender,
furling antennae starts at the brow in front of the horns. The line-art data
records initial centerlines for each pair; the four appendages must not read as
four undifferentiated horns. Wings and antennae are separate anatomical systems.

## Body and wing deltas

Keep Clay's skeletal and muscular organization: full shoulder keel and haunches,
origin/insertion muscle profiles, coherent S-curve neck, palms, articulated toes,
terminal claws and smooth shared skin. Reduce cross-sectional breadth and muscle
bulk in measured degrees for the long slim SilkWing body. Narrow does not mean a
twig neck, hollow chest or rods for limbs. The cover has substantial proximal
wing-arm muscle and a deep ventral chest even though the waist is slim.

Reconstruct two forewings and two smaller hindwings with their own attachments.
The forewing outline is elongated with supported rounded lobes; the hindwing is
shorter and rounder. These are strong dragon wings. Remove the old complete wing
assemblies when replacing them; do not leave a MudWing-style fan moving through
the new wings. The tribe sheet's near/far outlines must be separated before
counting supports or measuring span.

A fully gathered rest pose is still unresolved by these references. The cover
shows spread wings, the tribe sheet an elevated display, and the *How to Draw*
Blue is wingless. Do not claim a definitive fold from any of them. A provisional
rig must preserve segment lengths, keep anatomical ray order, gather fingers
compactly and cup the fan outward. Its shoulder and wrist frames must be checked
in intermediate positions before decorative scales are added.

The proximal membrane must follow the trailing shoulder–elbow–wrist chain. Do
not bridge shoulder to wrist with a fill triangle: that produced a leading-side
sail in the folded NightWing. Release the arm weights smoothly into the posterior
web and support fingers.

Arm skin, axillary web and finger panels must agree on every boundary
sample and its bone weights. Matching endpoints alone was the source of the
NightWing gaps. Surface-fitting checks must also sample face interiors, since
fitted corners can still bridge through a concave host. Export expressions in
neutral rest state rather than relying only on animation initialization. Verify the actual exported skin at fold amounts 0, .25, .5, .75
and 1, plus stroke rotations. The flight system supplies Clay's actual launch,
climb and descent/glide timing; Blue supplies four anatomical wing roles.

## Size and next construction order

Six-year-old winged Blue is an advanced juvenile approaching maturity. Dragon
juvenile growth is rapid, then slows; neither dog-year arithmetic nor age/7 gives
a supported linear size fraction. The Cricket comparison supplies an ordering,
not an absolute measurement or a direct Moon comparison. Keep the current game
scale provisional and do not invent a canon mass.

Next build: level skull and bite, complete neck/trunk with shared muscle and digit
architecture, then the supported fore/hind wing rigs and continuous membranes.
Follow with fold/spread checks, scale flow and coloration. Validate grounded feet,
walk/run contacts, jumps, climbs, powered ascent and descending glides in the game.
No new separate interactive preview is required.


## Implemented full pass

The complete Blue asset now has a long rounded anterior muzzle without the
NightWing terminal hook, retained cranial support, smoothly fitted mouth and eyes,
separate swept housed horns and slender brow antennae. It uses a leaner retargeting
of the Clay muscle/digit architecture under a full continuous neck and trunk.

Four separate articulated wings replace all previous wing meshes: three clustered distal
arches per forewing and a long main arch plus short basal support per hindwing, shorter lower wing arms, rounded supported
membrane lobes, blue-to-violet edge color, cupped resting fans and the corrected
trailing arm-chain attachment. No NightWing silver tears, stars or old compressed
wing morphs remain. Two small wrist glands identify post-Metamorphosis flamesilk
Blue; he retains no fire breath. The common flight adapter uses each wing's actual
left/right role even though the rig has four banks.

`blue_game_pass.gd` checks 131 bones, fore/hind counts, trailing attachments and
finger seams at five folds, eyelid coverage, actual possession and travel. It
captures the village model from side/front/face, folded and spread, and can leave
Blue controlled with `--keep-playing`. Blue now starts ahead of Clay on the road.
Darkstalker is present in the nearby raised clearing at the requested ancient
scale, outside the collectible roster. Full likeness and resting fan overlap
remain appropriate subjects for visual review of this first complete pass.


## Head, wing-lobe and soft-flow refinement

The follow-up returns the head to the successful NightWing proportions with a
modestly more delicate muzzle, shorter nasal cap and less anterior extension.
The horns now rise from their housings, dip through the shaft, and turn upward
at the tips. Antennae begin just anterior to those housings and use a related,
slender rise–dip–upturn path rather than isolated high arches.

Each SilkWing support is a smooth Bezier arch with continuously tapered radius,
without the NightWing knuckle bulges. A common spline connects all support tips
and the trailing body attachment, giving each wing a continuous smooth lobe.
The panels meet that same outer curve and retain identical finger/web seam
weights. The hidden segment chain remains available for contraction without
putting angular joints into the visible support anatomy.

The skin and membrane shaders add a bounded view-dependent blue/violet/teal/gold
structural-color approximation. This is a material response to normal/view angle,
not a time-driven rainbow. Blue stays the base pigment. Moon's default material
has zero sheen strength and retains its existing appearance.

Antennae have three softly weighted sections per side, with the basal 14% bound
to the head. A damped spring supplies mild idle flow and turn follow-through,
with less stiffness near the tips. The solver preserves each bone's actual
resting rotation; replacing it with a small absolute quaternion initially
caused a large unintended bend and was corrected before presentation. The
exported-skin test checks fixed bases and small tip travel.

The Godot Blue scene import had retained old mesh subresources across a rebuild;
regenerating its generated scene cache restored the current geometry and colors.
The test now checks the actual imported crown colors and proximal web attributes,
not only the source GLB.


## Side-reference architecture correction

The first open-lobe pose still exposed an incorrect uniform-fan construction.
The official side illustration separates the large wing into three closely
clustered distal arches, the free hook at the arm bend, and a long banana-shaped
trailing membrane below the lowest arch. It does not distribute four equally
long spokes over the full height of the wing. The small wing has one long curved
arch and a short support at its base; most of the area is one large round lobe.

`silkwing_wings.py` now builds these two different surface layouts. The hindwing
basal support starts at the wing root and is parented to the proximal arm; it
does not pivot from the distal wrist. Its large membrane connects the actual
trailing arm chain, main arch and basal hook with matching boundary weights.
The separate small body web closes the basal edge. The forewing's lower banana
lobe has its own traced contour below the distal cluster, without an invented
fourth long supporting ray. The retained arm-bend hooks follow their actual
joints. Original picture landmarks and control points are in the model profile.

The three forewing arches move as one open fan into an upright resting plane.
The proximal hindwing support follows its arm independently. Pose checks verify
these attachment roles, short basal length, membrane continuity and fixed bone
lengths, rather than requiring unrelated supports to remain a rigid radial fan.
